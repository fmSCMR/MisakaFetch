import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/settings_controller.dart';
import '../models/app_settings.dart';
import '../services/background_image_service.dart';
import '../services/platform_actions_service.dart';
import '../services/app_info_service.dart';
import '../widgets/app_background.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.backgroundService,
    this.actionsService,
    this.loadVersion,
  });
  final SettingsController controller;
  final BackgroundImageService backgroundService;
  final PlatformActionsService? actionsService;
  final Future<String> Function()? loadVersion;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;
  late final PlatformActionsService _actions;
  late final Future<String> _version;
  @override
  void initState() {
    super.initState();
    _actions = widget.actionsService ?? PlatformActionsService();
    _version = Future.sync(widget.loadVersion ?? AppInfoService().versionLabel)
        .then(
          (value) => '版本 $value',
          onError: (Object error, StackTrace stack) => '版本信息暂不可用',
        );
  }

  Future<void> _chooseDirectory() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await _actions.chooseDirectory(
        _settings.defaultSaveDirectory,
      );
      if (path != null && mounted) {
        await widget.controller.update(
          _settings.copyWith(defaultSaveDirectory: path),
        );
      }
    } on PlatformActionException catch (error) {
      _notice(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openProject() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _actions.openProject();
    } on PlatformActionException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          action: SnackBarAction(label: '复制地址', onPressed: _copyProjectUrl),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyProjectUrl() async {
    try {
      await Clipboard.setData(
        const ClipboardData(text: PlatformActionsService.projectUrl),
      );
      if (mounted) _notice('项目地址已复制。');
    } catch (error, stack) {
      if (kDebugMode) {
        developer.log(
          'Copying project URL failed',
          error: error,
          stackTrace: stack,
        );
      }
      if (mounted) _notice('复制失败，请手动使用关于页面中的项目地址。');
    }
  }

  Future<void> _showProjectLicense() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('MIT License'),
      content: SizedBox(
        width: 600,
        child: FutureBuilder<String>(
          future: rootBundle.loadString('LICENSE'),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              if (kDebugMode) {
                developer.log(
                  'Reading license failed',
                  name: 'MisakaFetch',
                  error: snapshot.error,
                );
              }
              return const Text('许可证文本暂时无法读取，请查看项目内的 LICENSE 文件。');
            }
            if (!snapshot.hasData) return const Text('正在读取许可证…');
            return SingleChildScrollView(child: SelectableText(snapshot.data!));
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
  Widget _saveSection(AppSettings settings, bool windows) => _section('下载与保存', [
    DropdownButtonFormField<FilenameFormat>(
      key: ValueKey(settings.filenameFormat),
      initialValue: settings.filenameFormat,
      isExpanded: true,
      decoration: const InputDecoration(labelText: '默认文件名格式'),
      items: const [
        DropdownMenuItem(value: FilenameFormat.title, child: Text('视频标题')),
        DropdownMenuItem(
          value: FilenameFormat.titleBvid,
          child: Text('视频标题 + BV号'),
        ),
        DropdownMenuItem(
          value: FilenameFormat.bvidTitle,
          child: Text('BV号 + 视频标题'),
        ),
      ],
      onChanged: (format) {
        if (format != null) {
          widget.controller.update(_settings.copyWith(filenameFormat: format));
        }
      },
    ),
    if (windows) ...[
      const SizedBox(height: 16),
      const Text('默认保存位置'),
      const SizedBox(height: 8),
      SelectableText(settings.defaultSaveDirectory ?? '尚未选择，每次由系统询问'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            key: const Key('chooseSaveDirectory'),
            onPressed: _busy ? null : _chooseDirectory,
            icon: const Icon(Icons.folder_open),
            label: const Text('选择目录'),
          ),
          if (settings.defaultSaveDirectory != null)
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      widget.controller.update(
                        _settings.copyWith(
                          clearSaveDirectory: true,
                          askSaveLocation: true,
                        ),
                      );
                    },
              child: const Text('清除目录'),
            ),
        ],
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('保存时总是询问位置'),
        subtitle: Text(
          settings.defaultSaveDirectory == null
              ? '先选择默认目录，才能关闭询问'
              : '关闭后直接保存，同名文件自动编号',
        ),
        value: settings.askSaveLocation,
        onChanged: settings.defaultSaveDirectory != null && !_busy
            ? (ask) {
                widget.controller.update(
                  _settings.copyWith(askSaveLocation: ask),
                );
              }
            : null,
      ),
    ],
    const SizedBox(height: 16),
    DropdownButtonFormField<SaveSuccessAction>(
      key: ValueKey((settings.saveSuccessAction, windows)),
      initialValue:
          !windows && settings.saveSuccessAction == SaveSuccessAction.openFolder
          ? SaveSuccessAction.notify
          : settings.saveSuccessAction,
      isExpanded: true,
      decoration: const InputDecoration(labelText: '保存成功后'),
      items: [
        const DropdownMenuItem(
          value: SaveSuccessAction.notify,
          child: Text('仅提示'),
        ),
        if (windows)
          const DropdownMenuItem(
            value: SaveSuccessAction.openFolder,
            child: Text('打开所在文件夹'),
          ),
        const DropdownMenuItem(
          value: SaveSuccessAction.silent,
          child: Text('不显示额外操作'),
        ),
      ],
      onChanged: (action) {
        if (action != null) {
          widget.controller.update(
            _settings.copyWith(saveSuccessAction: action),
          );
        }
      },
    ),
  ]);

  Widget _aboutSection() => _section('关于', [
    Text('MisakaFetch', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 6),
    const Text('Bilibili 视频封面提取工具'),
    const SizedBox(height: 6),
    FutureBuilder<String>(
      future: _version,
      builder: (context, snapshot) => Text(snapshot.data ?? '正在读取版本…'),
    ),
    ListTile(
      key: const Key('githubProject'),
      contentPadding: EdgeInsets.zero,
      enabled: !_busy,
      leading: const Icon(Icons.code),
      title: const Text('GitHub 项目'),
      subtitle: const Text(PlatformActionsService.projectUrl),
      trailing: const Icon(Icons.open_in_new),
      onTap: _busy ? null : _openProject,
    ),
    ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.description_outlined),
      title: const Text('开源许可证'),
      subtitle: const Text('MIT License'),
      onTap: _showProjectLicense,
    ),
    ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.library_books_outlined),
      title: const Text('第三方许可证'),
      onTap: () =>
          showLicensePage(context: context, applicationName: 'MisakaFetch'),
    ),
  ]);

  AppSettings get _settings => widget.controller.settings;

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _choose() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await widget.backgroundService.chooseAndImport();
      if (path == null) return;
      if (!mounted) {
        await widget.backgroundService.remove(path);
        return;
      }
      final oldPath = _settings.backgroundImage;
      final saved = await widget.controller.update(
        _settings.copyWith(backgroundEnabled: true, backgroundImage: path),
      );
      if (saved && oldPath != null && oldPath != path) {
        if (!await widget.backgroundService.remove(oldPath)) {
          _notice('背景已更换，但旧副本未能清理。');
        }
      }
    } on BackgroundImageException catch (error) {
      _notice(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove({bool resetAll = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final oldPath = _settings.backgroundImage;
      final saved = await widget.controller.update(
        resetAll
            ? const AppSettings()
            : _settings.copyWith(clearBackground: true),
      );
      if (saved && oldPath != null) {
        if (!await widget.backgroundService.remove(oldPath)) {
          _notice('设置已更新，但背景副本未能清理。');
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确定要恢复所有设置吗？'),
        content: const Text('主题、背景、界面和保存设置将恢复默认值。已保存的封面及应用外部文件不会删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('恢复默认'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _remove(resetAll: true);
  }

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    ),
  );

  Widget _slider({
    required String label,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required bool enabled,
    required AppSettings Function(double) change,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('$label · $valueLabel'),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: 60,
        semanticFormatterCallback: (_) => valueLabel,
        onChanged: enabled
            ? (value) {
                widget.controller.update(change(value), persist: false);
              }
            : null,
        onChangeEnd: enabled
            ? (_) {
                widget.controller.retrySave();
              }
            : null,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final settings = _settings;
      final windows = Theme.of(context).platform == TargetPlatform.windows;
      final hasImage = settings.backgroundImage != null;
      final editable = hasImage && settings.backgroundEnabled && !_busy;
      return PopScope(
        canPop: !_busy,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text('设置')),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: ListView(
                key: const Key('settingsList'),
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  _section('外观', [
                    DropdownButtonFormField<ThemeMode>(
                      key: ValueKey(settings.themeMode),
                      initialValue: settings.themeMode,
                      decoration: const InputDecoration(labelText: '主题模式'),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('跟随系统'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('浅色模式'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('深色模式'),
                        ),
                      ],
                      onChanged: (mode) {
                        if (mode != null) widget.controller.setThemeMode(mode);
                      },
                    ),
                  ]),
                  _section('背景', [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('自定义背景'),
                      subtitle: Text(
                        hasImage
                            ? (settings.backgroundEnabled ? '已启用' : '已停用')
                            : '尚未选择图片',
                      ),
                      value: settings.backgroundEnabled,
                      onChanged: hasImage && !_busy
                          ? (enabled) {
                              widget.controller.update(
                                _settings.copyWith(backgroundEnabled: enabled),
                              );
                            }
                          : null,
                    ),
                    if (hasImage) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 140,
                          child: AppBackground(
                            settings: settings,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '背景效果预览',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          key: const Key('chooseBackground'),
                          onPressed: _busy ? null : _choose,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(hasImage ? '更换图片' : '选择图片'),
                        ),
                        if (hasImage)
                          OutlinedButton.icon(
                            key: const Key('removeBackground'),
                            onPressed: _busy ? null : () => _remove(),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('移除背景'),
                          ),
                      ],
                    ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      ),
                    const SizedBox(height: 20),
                    _slider(
                      label: '背景模糊',
                      valueLabel: settings.backgroundBlur.toStringAsFixed(0),
                      value: settings.backgroundBlur,
                      min: 0,
                      max: 30,
                      enabled: editable,
                      change: (value) =>
                          _settings.copyWith(backgroundBlur: value),
                    ),
                    _slider(
                      label: '背景亮度',
                      valueLabel:
                          '${(settings.backgroundBrightness * 100).round()}%',
                      value: settings.backgroundBrightness,
                      min: 0.5,
                      max: 1.5,
                      enabled: editable,
                      change: (value) =>
                          _settings.copyWith(backgroundBrightness: value),
                    ),
                    _slider(
                      label: '遮罩强度',
                      valueLabel:
                          '${(settings.backgroundOverlay * 100).round()}%',
                      value: settings.backgroundOverlay,
                      min: 0,
                      max: 0.8,
                      enabled: editable,
                      change: (value) =>
                          _settings.copyWith(backgroundOverlay: value),
                    ),
                    DropdownButtonFormField<BackgroundFit>(
                      key: ValueKey(settings.backgroundFit),
                      initialValue: settings.backgroundFit,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '背景适配方式'),
                      items: const [
                        DropdownMenuItem(
                          value: BackgroundFit.cover,
                          child: Text('填充'),
                        ),
                        DropdownMenuItem(
                          value: BackgroundFit.contain,
                          child: Text('适应'),
                        ),
                        DropdownMenuItem(
                          value: BackgroundFit.fill,
                          child: Text('拉伸'),
                        ),
                      ],
                      onChanged: editable
                          ? (fit) {
                              if (fit != null) {
                                widget.controller.update(
                                  _settings.copyWith(backgroundFit: fit),
                                );
                              }
                            }
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: editable
                            ? () {
                                widget.controller.update(
                                  _settings.resetBackgroundParameters(),
                                );
                              }
                            : null,
                        child: const Text('恢复默认背景设置'),
                      ),
                    ),
                  ]),
                  _saveSection(settings, windows),
                  _section('界面', [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('界面动画'),
                      subtitle: const Text('减少主题和页面切换动画，保留加载指示'),
                      value: settings.animationsEnabled,
                      onChanged: (enabled) {
                        widget.controller.update(
                          _settings.copyWith(animationsEnabled: enabled),
                        );
                      },
                    ),
                  ]),
                  _aboutSection(),
                  if (widget.controller.warning != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          Text(widget.controller.warning!),
                          TextButton(
                            onPressed: () {
                              widget.controller.retrySave();
                            },
                            child: const Text('重试保存设置'),
                          ),
                        ],
                      ),
                    ),
                  OutlinedButton(
                    onPressed: _busy ? null : _resetAll,
                    child: const Text('恢复默认设置'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
