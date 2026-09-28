import 'package:flutter/material.dart';

import 'app.dart';
import 'controllers/settings_controller.dart';
import 'services/settings_repository.dart';
import 'services/background_image_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 首帧前恢复设置并检查背景副本，减少启动时的主题闪烁。
  final repository = SettingsRepository.local();
  final loaded = await repository.load();
  final background = BackgroundImageService();
  var settings = loaded.settings;
  var warning = loaded.warning;
  final path = settings.backgroundImage;
  if (path != null && !await background.isUsable(path)) {
    settings = settings.copyWith(clearBackground: true);
    warning = '上次的背景图片无法读取，已恢复默认背景。';
    try {
      await repository.save(settings);
    } on SettingsStorageException catch (error) {
      warning = '$warning ${error.message}';
    }
  }
  final controller = SettingsController(
    repository: repository,
    initialSettings: settings,
    initialWarning: warning,
  );
  runApp(
    MisakaFetchApp(
      settingsController: controller,
      backgroundService: background,
    ),
  );
}
