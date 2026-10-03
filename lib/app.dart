import 'package:flutter/material.dart';

import 'controllers/settings_controller.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/workspace_page.dart';
import 'services/background_image_service.dart';
import 'services/platform_actions_service.dart';
import 'widgets/app_background.dart';
import 'services/settings_repository.dart';
import 'services/bilibili_service.dart';
import 'services/image_download_service.dart';
import 'services/image_save_service.dart';

class MisakaFetchApp extends StatefulWidget {
  const MisakaFetchApp({
    super.key,
    this.settingsController,
    this.backgroundService,
    this.actionsService,
    this.loadVersion,
    this.videoService,
    this.imageService,
    this.saveService,
  });

  final SettingsController? settingsController;
  final BackgroundImageService? backgroundService;
  final PlatformActionsService? actionsService;
  final Future<String> Function()? loadVersion;
  final BilibiliService? videoService;
  final ImageDownloadService? imageService;
  final ImageSaveService? saveService;

  @override
  State<MisakaFetchApp> createState() => _MisakaFetchAppState();
}

class _MisakaFetchAppState extends State<MisakaFetchApp> {
  late final SettingsController _settings;
  late final BackgroundImageService _backgroundService;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  String? _shownWarning;

  @override
  void initState() {
    super.initState();
    _backgroundService = widget.backgroundService ?? BackgroundImageService();
    _settings =
        widget.settingsController ??
        SettingsController(repository: SettingsRepository.local());
    _settings.addListener(_settingsChanged);
    _queueWarning();
  }

  void _settingsChanged() {
    setState(() {});
    _queueWarning();
  }

  void _queueWarning() {
    final message = _settings.warning;
    if (message == null) {
      _shownWarning = null;
      return;
    }
    if (message == _shownWarning) return;
    _shownWarning = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || message != _settings.warning) return;
      _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }

  @override
  void dispose() {
    _settings.removeListener(_settingsChanged);
    if (widget.settingsController == null) _settings.dispose();
    super.dispose();
  }

  ThemeData _theme(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF007F86),
      brightness: brightness,
    );
    final theme = ThemeData(
      useMaterial3: true,
      // 保留平台默认的拉丁字体，通过简体中文字体回退补齐汉字。

      fontFamilyFallback: const [
        'Microsoft YaHei',
        'Microsoft YaHei UI',
        'Noto Sans CJK SC',
        'Noto Sans SC',
      ],
      colorScheme: colors,
      cardTheme: CardThemeData(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        color:
            (_settings.settings.cardColor == null
                    ? colors.surfaceContainerLow
                    : Color(0xFF000000 | _settings.settings.cardColor!))
                .withValues(alpha: _settings.settings.cardOpacity),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color:
                (_settings.settings.cardBorderColor == null
                        ? colors.outlineVariant
                        : Color(
                            0xFF000000 | _settings.settings.cardBorderColor!,
                          ))
                    .withValues(alpha: _settings.settings.cardBorderOpacity),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );
    return theme.copyWith(
      textTheme: _chineseGlyphs(theme.textTheme),
      primaryTextTheme: _chineseGlyphs(theme.primaryTextTheme),
    );
  }

  // 同一码点的汉字在不同地区可能有不同字形，区域设定采用简体中文。

  TextTheme _chineseGlyphs(TextTheme theme) {
    const locale = Locale('zh', 'CN');
    return TextTheme(
      displayLarge: theme.displayLarge?.copyWith(locale: locale),
      displayMedium: theme.displayMedium?.copyWith(locale: locale),
      displaySmall: theme.displaySmall?.copyWith(locale: locale),
      headlineLarge: theme.headlineLarge?.copyWith(locale: locale),
      headlineMedium: theme.headlineMedium?.copyWith(locale: locale),
      headlineSmall: theme.headlineSmall?.copyWith(locale: locale),
      titleLarge: theme.titleLarge?.copyWith(locale: locale),
      titleMedium: theme.titleMedium?.copyWith(locale: locale),
      titleSmall: theme.titleSmall?.copyWith(locale: locale),
      bodyLarge: theme.bodyLarge?.copyWith(locale: locale),
      bodyMedium: theme.bodyMedium?.copyWith(locale: locale),
      bodySmall: theme.bodySmall?.copyWith(locale: locale),
      labelLarge: theme.labelLarge?.copyWith(locale: locale),
      labelMedium: theme.labelMedium?.copyWith(locale: locale),
      labelSmall: theme.labelSmall?.copyWith(locale: locale),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MisakaFetch',
    scaffoldMessengerKey: _messengerKey,
    debugShowCheckedModeBanner: false,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    themeMode: _settings.settings.themeMode,
    themeAnimationDuration: _settings.settings.animationsEnabled
        ? const Duration(milliseconds: 200)
        : Duration.zero,
    builder: (context, child) => AppBackground(
      settings: _settings.settings,
      child: child ?? const SizedBox.shrink(),
    ),
    home: Builder(
      builder: (context) => WorkspacePage(
        extractionPageBuilder: (visible) => HomePage(
          extractionVisible: visible,
          videoService: widget.videoService,
          imageService: widget.imageService,
          saveService: widget.saveService,
          settings: _settings.settings,
          actionsService: widget.actionsService,
          themeMode: _settings.settings.themeMode,
          onThemeChanged: (mode) => _settings.setThemeMode(mode),
        ),
        onOpenSettings: () {
          Navigator.of(context).push(
            _SettingsRoute(
              settingsController: _settings,
              pageBuilder: (context, animation, secondaryAnimation) =>
                  SettingsPage(
                    controller: _settings,
                    backgroundService: _backgroundService,
                    actionsService: widget.actionsService,
                    loadVersion: widget.loadVersion,
                  ),
            ),
          );
        },
      ),
    ),
  );
}

// 返回时读取最新设置，而不是沿用进入设置页时的开关状态。
class _SettingsRoute extends PageRouteBuilder<void> {
  _SettingsRoute({required this.settingsController, required super.pageBuilder})
    : super(
        transitionDuration: settingsController.settings.animationsEnabled
            ? const Duration(milliseconds: 180)
            : Duration.zero,
        reverseTransitionDuration: settingsController.settings.animationsEnabled
            ? const Duration(milliseconds: 180)
            : Duration.zero,
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            ListenableBuilder(
              listenable: settingsController,
              builder: (_, _) => settingsController.settings.animationsEnabled
                  ? FadeTransition(opacity: animation, child: child)
                  : child,
            ),
      );

  final SettingsController settingsController;

  @override
  bool didPop(void result) {
    controller?.reverseDuration = settingsController.settings.animationsEnabled
        ? const Duration(milliseconds: 180)
        : Duration.zero;
    return super.didPop(result);
  }
}
