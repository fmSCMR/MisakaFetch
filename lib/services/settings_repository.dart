import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import 'app_storage_service.dart';

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

  factory SettingsRepository.local({String? windowsExecutablePath}) {
    if (Platform.isWindows) {
      final executable = windowsExecutablePath ?? Platform.resolvedExecutable;
      if (AppStorageService.startsFreshForExecutable(executable) ||
          (const bool.fromEnvironment('MISAKAFETCH_FRESH_PROFILE') &&
              !AppStorageService.keepsSettingsForExecutable(executable))) {
        return SettingsRepository.defaultsOnly();
      }
      return SettingsRepository.file(
        AppStorageService.windowsDirectoryFor(executable),
        legacyRead: executable.split(RegExp(r'[/\\]')).contains('MisakaFetch')
            ? () => SharedPreferencesAsync().getString(storageKey)
            : null,
      );
    }
    SharedPreferencesAsync? preferences;
    SharedPreferencesAsync store() => preferences ??= SharedPreferencesAsync();
    return SettingsRepository(
      read: () => store().getString(storageKey),
      write: (value) => store().setString(storageKey, value),
    );
  }

  /// 开发/历史展示包允许本次调整，但每次启动始终使用默认设置。
  factory SettingsRepository.defaultsOnly() =>
      SettingsRepository(read: () async => null, write: (_) async {});

  /// 不回退到旧的全局存储，避免目录不可写时重新串用自用版设置。
  factory SettingsRepository.file(
    Directory directory, {
    SettingsReader? legacyRead,
  }) {
    final file = File.fromUri(directory.uri.resolve('settings.json'));
    return SettingsRepository(
      read: () async {
        if (await file.exists()) return file.readAsString();
        final legacy = await legacyRead?.call();
        if (legacy == null) return null;
        final decoded = jsonDecode(legacy);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid legacy settings');
        }
        await directory.create(recursive: true);
        final backup = File.fromUri(
          directory.uri.resolve('settings-v1.0.0-backup.json'),
        );
        if (!await backup.exists()) {
          await backup.writeAsString(legacy, flush: true);
        }
        var migrated = AppSettings.fromJson(decoded);
        final imagePath = migrated.backgroundImage;
        if (imagePath != null && await File(imagePath).exists()) {
          final backgrounds = Directory.fromUri(
            directory.uri.resolve('backgrounds/'),
          );
          await backgrounds.create(recursive: true);
          final extension = imagePath.toLowerCase().endsWith('.webp')
              ? 'webp'
              : imagePath.toLowerCase().endsWith('.jpg') ||
                    imagePath.toLowerCase().endsWith('.jpeg')
              ? 'jpg'
              : 'png';
          final image = File.fromUri(
            backgrounds.uri.resolve(
              'background_${DateTime.now().microsecondsSinceEpoch}_0.$extension',
            ),
          );
          await File(imagePath).copy(image.path);
          migrated = migrated.copyWith(backgroundImage: image.path);
        }
        final value = jsonEncode(migrated.toJson());
        await SettingsRepository.file(directory).write(value);
        return value;
      },
      write: (value) async {
        await directory.create(recursive: true);
        final temporary = File('${file.path}.tmp');
        try {
          await temporary.writeAsString(value, flush: true);
          await temporary.rename(file.path);
        } finally {
          if (await temporary.exists()) await temporary.delete();
        }
      },
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
