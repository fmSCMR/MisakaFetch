import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/downloaded_image.dart';
import '../models/app_settings.dart';
import '../services/platform_actions_service.dart';
import '../models/video_info.dart';
import '../services/bilibili_service.dart';
import '../services/image_download_service.dart';
import '../services/image_save_service.dart';
import '../utils/bilibili_parser.dart';
import '../widgets/video_result_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.videoService,
    this.imageService,
    this.saveService,
    required this.themeMode,
    required this.onThemeChanged,
    this.onOpenSettings,
    this.settings = const AppSettings(),
    this.actionsService,
    this.extractionVisible = true,
  });
  final BilibiliService? videoService;
  final ImageDownloadService? imageService;
  final ImageSaveService? saveService;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final VoidCallback? onOpenSettings;
  final AppSettings settings;
  final PlatformActionsService? actionsService;
  final bool extractionVisible;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _input = TextEditingController();
  late final BilibiliService _videoService;
  late final ImageDownloadService _imageService;
  late final ImageSaveService _saveService;
  late final PlatformActionsService _actions;
  VideoInfo? _video;
  DownloadedImage? _image;
  String? _error;
  String? _coverError;
  bool _extracting = false;
  bool _downloading = false;
  bool _copying = false;
  bool _saving = false;
  bool get _busy => _extracting || _downloading || _saving;
  @override
  void initState() {
    super.initState();
    _videoService = widget.videoService ?? BilibiliService();
    _imageService = widget.imageService ?? ImageDownloadService();
    _saveService = widget.saveService ?? ImageSaveService();
    _actions = widget.actionsService ?? PlatformActionsService();
  }

  @override
  void dispose() {
    _input.dispose();
    _videoService.close();
    _imageService.close();
    super.dispose();
  }

  Future<void> _extract() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final text = _input.text;
    setState(() {
      _extracting = true;
      _error = null;
      _video = null;
      _image = null;
      _coverError = null;
    });
    try {
      final video = await _videoService.fetchVideo(text);
      if (!mounted) return;
      setState(() => _video = video);
      await _loadCover(video);
    } on BilibiliParseException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on BilibiliServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error, stack) {
      _log(error, stack);
      if (mounted) setState(() => _error = '提取失败，请稍后重试。');
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  Future<void> _loadCover(VideoInfo video) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _image = null;
      _coverError = null;
    });
    try {
      final image = await _imageService.download(video.coverUrl);
      if (!mounted) return;
      Object? decodeError;
      StackTrace? decodeStack;
      // 先解码验证图片可用，再允许保存；写入仍使用原始字节以保留画质。
      await precacheImage(
        MemoryImage(image.bytes),
        context,
        onError: (error, stack) {
          decodeError = error;
          decodeStack = stack;
        },
      );
      if (!mounted) return;
      if (decodeError != null) {
        _log(decodeError!, decodeStack ?? StackTrace.current);
        setState(() => _coverError = '封面无法显示，请重新加载。');
      } else {
        setState(() => _image = image);
      }
    } on ImageDownloadException catch (error) {
      if (mounted) setState(() => _coverError = error.message);
    } catch (error, stack) {
      _log(error, stack);
      if (mounted) setState(() => _coverError = '封面加载失败，请重试。');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _saveImage() async {
    final image = _image;
    final video = _video;
    if (image == null || video == null || _busy) return;
    final settings = widget.settings;
    final windows = Theme.of(context).platform == TargetPlatform.windows;
    setState(() => _saving = true);
    try {
      final path = await _saveService.save(
        image,
        video.title,
        bvid: video.bvid,
        settings: settings,
      );
      if (path != null && mounted) {
        if (settings.saveSuccessAction == SaveSuccessAction.openFolder &&
            windows) {
          try {
            await _actions.openSavedFolder(path);
          } catch (error, stack) {
            _log(error, stack);
            if (mounted) {
              _notice(
                error is PlatformActionException
                    ? error.message
                    : '原图已保存，但文件夹未能打开。',
              );
            }
          }
        } else if (settings.saveSuccessAction != SaveSuccessAction.silent) {
          _notice('原图已保存至：$path');
        }
      }
    } on ImageSaveException catch (error) {
      if (mounted) _notice(error.message);
    } catch (error, stack) {
      _log(error, stack);
      if (mounted) _notice('保存失败，请重试。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copyLink() async {
    final video = _video;
    if (video == null || _copying) return;
    setState(() => _copying = true);
    try {
      await Clipboard.setData(ClipboardData(text: video.coverUrl));
      if (mounted) _notice('图片链接已复制。');
    } catch (error, stack) {
      _log(error, stack);
      if (mounted) _notice('复制失败，请重试或手动选择图片链接。');
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static void _log(Object error, StackTrace stack) {
    if (kDebugMode) {
      developer.log(
        'Home page action failed',
        name: 'MisakaFetch',
        error: error,
        stackTrace: stack,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final video = _video;
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: widget.onOpenSettings == null
          ? null
          : SafeArea(
              top: false,
              child: Align(
                heightFactor: 1,
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton.filledTonal(
                    key: const Key('settingsButton'),
                    tooltip: '设置',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: widget.onOpenSettings,
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ),
              ),
            ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Material(
                    key: const Key('appTitleCard'),
                    color: theme.cardTheme.color,
                    shape: theme.cardTheme.shape,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MisakaFetch',
                                  style: theme.textTheme.headlineLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Bilibili 视频封面提取器',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          PopupMenuButton<ThemeMode>(
                            tooltip: '选择主题',
                            initialValue: widget.themeMode,
                            onSelected: widget.onThemeChanged,
                            icon: Icon(
                              theme.brightness == Brightness.dark
                                  ? Icons.dark_mode_outlined
                                  : Icons.light_mode_outlined,
                            ),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: ThemeMode.system,
                                child: Text('跟随系统'),
                              ),
                              PopupMenuItem(
                                value: ThemeMode.light,
                                child: Text('浅色模式'),
                              ),
                              PopupMenuItem(
                                value: ThemeMode.dark,
                                child: Text('深色模式'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Offstage(
                    offstage: !widget.extractionVisible,
                    child: TickerMode(
                      enabled: widget.extractionVisible,
                      child: ExcludeFocus(
                        excluding: !widget.extractionVisible,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 28),
                            Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextField(
                                      key: const Key('videoInput'),
                                      controller: _input,
                                      enabled: !_busy,
                                      minLines: 2,
                                      maxLines: 4,
                                      keyboardType: TextInputType.multiline,
                                      decoration: InputDecoration(
                                        labelText: 'Bilibili 链接 / BV 号',
                                        hintText: '粘贴视频链接、BV 号或分享文本',
                                        alignLabelWithHint: true,
                                        suffixIcon: IconButton(
                                          tooltip: '清空输入',
                                          onPressed: _busy
                                              ? null
                                              : _input.clear,
                                          icon: const Icon(Icons.close),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    FilledButton.icon(
                                      key: const Key('extractButton'),
                                      onPressed: _busy ? null : _extract,
                                      icon: _extracting || _downloading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.image_search_outlined,
                                            ),
                                      label: Text(
                                        _extracting || _downloading
                                            ? '正在提取…'
                                            : '提取封面',
                                      ),
                                    ),
                                    if (_error != null) ...[
                                      const SizedBox(height: 16),
                                      Semantics(
                                        liveRegion: true,
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: theme
                                                .colorScheme
                                                .errorContainer,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                Icons.error_outline,
                                                color: theme
                                                    .colorScheme
                                                    .onErrorContainer,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  _error!,
                                                  style: TextStyle(
                                                    color: theme
                                                        .colorScheme
                                                        .onErrorContainer,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (video != null)
                              VideoResultCard(
                                video: video,
                                image: _image,
                                isLoading: _downloading,
                                errorText: _coverError,
                                onRetry: _busy ? null : () => _loadCover(video),
                                onCopy: _copying ? null : _copyLink,
                                isSaving: _saving,
                                onSave:
                                    !_busy &&
                                        _image != null &&
                                        _saveService.isSupported
                                    ? _saveImage
                                    : null,
                              )
                            else if (!_busy && _error == null)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 24,
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    '输入一个视频链接，获取它的原始封面。',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
