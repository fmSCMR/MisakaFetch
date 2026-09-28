import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

typedef SettingsReader = Future<String?> Function();
typedef SettingsWriter = Future<void> Function(String value);

class SettingsLoadResult {
  const SettingsLoadResult(this.settings, {this.warning});
  final AppSettings settings;
  final String? warning;
}

class SettingsStorageException implements Exception {
  const SettingsStorageException(this.message);
  final String message;
}

/// 用独立键保存整份 JSON，相关设置一起读写，避免影响其他偏好项。
class SettingsRepository {
  SettingsRepository({required this.read, required this.write});

  factory SettingsRepository.local() {
    SharedPreferencesAsync? preferences;
    SharedPreferencesAsync store() => preferences ??= SharedPreferencesAsync();
    return SettingsRepository(
      read: () => store().getString(storageKey),
      write: (value) => store().setString(storageKey, value),
    );
  }

  static const storageKey = 'misakafetch.settings.v1';
  final SettingsReader read;
  final SettingsWriter write;

  Future<SettingsLoadResult> load() async {
    try {
      final value = await read();
      if (value == null) return const SettingsLoadResult(AppSettings());
      final json = jsonDecode(value);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Expected settings object');
      }
      return SettingsLoadResult(AppSettings.fromJson(json));
    } catch (error, stack) {
      _log('Reading settings failed', error, stack);
      // 读取失败时保留原值，后续保存操作再写入，便于恢复暂时不可用的数据。
      return const SettingsLoadResult(
        AppSettings(),
        warning: '未能读取上次设置，本次已使用默认设置。',
      );
    }
  }

  Future<void> save(AppSettings settings) async {
    try {
      await write(jsonEncode(settings.toJson()));
    } catch (error, stack) {
      _log('Writing settings failed', error, stack);
      throw const SettingsStorageException('设置已在本次运行中生效，但未能保存，请重试。');
    }
  }

  static void _log(String message, Object error, StackTrace stack) {
    if (kDebugMode) {
      developer.log(
        message,
        name: 'MisakaFetch.settings',
        error: error,
        stackTrace: stack,
      );
    }
  }
}
