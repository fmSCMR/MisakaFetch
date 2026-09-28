import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/settings_repository.dart';

/// 即时更新界面，按顺序保存设置，避免较早的异步写入覆盖新值。
class SettingsController extends ChangeNotifier {
  SettingsController({
    required this.repository,
    AppSettings initialSettings = const AppSettings(),
    String? initialWarning,
  }) : _settings = initialSettings,
       _warning = initialWarning;

  final SettingsRepository repository;
  AppSettings _settings;
  String? _warning;
  bool _disposed = false;
  Future<void> _pending = Future.value();

  AppSettings get settings => _settings;
  String? get warning => _warning;

  Future<bool> setThemeMode(ThemeMode mode) =>
      update(_settings.copyWith(themeMode: mode));

  /// 滑块拖动时仅更新预览，拖动结束后再保存，减少频繁写入。
  Future<bool> update(AppSettings settings, {bool persist = true}) {
    if (_disposed) return Future.value(false);
    _settings = settings;
    notifyListeners();
    if (!persist) return Future.value(true);
    return _enqueue(settings);
  }

  Future<bool> retrySave() =>
      _disposed ? Future.value(false) : _enqueue(_settings);
  Future<void> get pendingWrites => _pending;

  Future<bool> _enqueue(AppSettings snapshot) {
    final task = _pending.then((_) async {
      try {
        await repository.save(snapshot);
        // 只有当前设置的保存成功才能清除提示，旧任务完成不代表新设置已保存。
        if (!_disposed && identical(snapshot, _settings)) {
          _warning = null;
          notifyListeners();
        }
        return true;
      } on SettingsStorageException catch (error) {
        if (!_disposed) {
          _warning = error.message;
          notifyListeners();
        }
        return false;
      }
    });
    _pending = task.then((_) {});
    return task;
  }

  @override
  void dispose() {
    _disposed = true;
    // 已排队的保存继续执行，页面销毁后停止通知，避免丢失最后一次设置。
    super.dispose();
  }
}
