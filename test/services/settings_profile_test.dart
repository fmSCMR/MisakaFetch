import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:misaka_fetch/models/app_settings.dart';
import 'package:misaka_fetch/services/app_storage_service.dart';
import 'package:misaka_fetch/services/settings_repository.dart';

void main() {
  test('准确识别开发与历史目录，不把自用和开源目录判为重置模式', () {
    for (final path in [
      r'C:\Users\someone\Desktop\MisakaFetch开发\app\Windows\MisakaFetch.exe',
      r'C:\Users\someone\Desktop\MisakaFetch历史版本\V1.0.0\app\Windows\MisakaFetch.exe',
      'C:/Users/someone/Desktop/MisakaFetch开发/source/build/MisakaFetch.exe',
    ]) {
      expect(AppStorageService.startsFreshForExecutable(path), isTrue);
    }
    for (final path in [
      r'C:\Users\someone\Desktop\MisakaFetch\app\Windows\MisakaFetch.exe',
      r'C:\Users\someone\Desktop\MisakaFetch开源\app\Windows\MisakaFetch.exe',
      r'C:\MisakaFetch开发者自用\MisakaFetch.exe',
    ]) {
      expect(AppStorageService.startsFreshForExecutable(path), isFalse);
    }
  });
  if (Platform.isWindows) {
    test('保留设置开关支持直接启动，开发和历史目录不受开关影响', () async {
      final root = await Directory.systemTemp.createTemp('misaka-keep-switch-');
      try {
        for (final name in [
          'MisakaFetch',
          'MisakaFetch开源',
          'MisakaFetch开发',
          'MisakaFetch历史版本',
        ]) {
          final folder = Directory.fromUri(root.uri.resolve('$name/'));
          await folder.create();
          final marker = File.fromUri(
            folder.uri.resolve(AppStorageService.keepSettingsMarker),
          );
          final executable = File.fromUri(
            folder.uri.resolve('app/Windows/MisakaFetch.exe'),
          ).path;
          expect(
            AppStorageService.keepsSettingsForExecutable(executable),
            false,
          );
          await marker.writeAsString('invalid');
          expect(
            AppStorageService.keepsSettingsForExecutable(executable),
            false,
          );
          await marker.writeAsString('keep\n');
          final keep = name == 'MisakaFetch' || name == 'MisakaFetch开源';
          expect(
            AppStorageService.keepsSettingsForExecutable(executable),
            keep,
          );
          await SettingsRepository.local(
            windowsExecutablePath: executable,
          ).save(
            const AppSettings(themeMode: ThemeMode.dark, backgroundBlur: .5),
          );
          final restarted = await SettingsRepository.local(
            windowsExecutablePath: executable,
          ).load();
          expect(
            restarted.settings.themeMode,
            keep ? ThemeMode.dark : ThemeMode.system,
          );
          expect(restarted.settings.backgroundBlur, keep ? .5 : 0);
        }
      } finally {
        await root.delete(recursive: true);
      }
    });
    test('真实本地仓库：开发历史忽略旧配置，自用开源保留设置', () async {
      final root = await Directory.systemTemp.createTemp(
        'misaka-role-profiles-',
      );
      try {
        for (final name in [
          'MisakaFetch开发',
          'MisakaFetch历史版本',
          'MisakaFetch',
          'MisakaFetch开源',
        ]) {
          final executable = File.fromUri(
            root.uri.resolve('$name/app/Windows/MisakaFetch.exe'),
          ).path;
          final directory = AppStorageService.windowsDirectoryFor(executable);
          final disk = SettingsRepository.file(directory);
          const old = AppSettings(
            themeMode: ThemeMode.dark,
            backgroundEnabled: true,
            backgroundImage: 'old.png',
            backgroundBlur: 1.23,
            cardColor: 0x123456,
            cardOpacity: .3,
            askSaveLocation: false,
            animationsEnabled: false,
          );
          await disk.save(old);
          final local = SettingsRepository.local(
            windowsExecutablePath: executable,
          );
          final fresh =
              const bool.fromEnvironment('MISAKAFETCH_FRESH_PROFILE') ||
              name == 'MisakaFetch开发' ||
              name == 'MisakaFetch历史版本';
          expect(
            (await local.load()).settings.toJson(),
            (fresh ? const AppSettings() : old).toJson(),
          );
          final changed = old.copyWith(backgroundBlur: .51, cardOpacity: .7);
          await local.save(changed);
          final restarted = SettingsRepository.local(
            windowsExecutablePath: executable,
          );
          expect(
            (await restarted.load()).settings.toJson(),
            (fresh ? const AppSettings() : changed).toJson(),
          );
          expect(
            (await disk.load()).settings.toJson(),
            (fresh ? old : changed).toJson(),
          );
        }
      } finally {
        await root.delete(recursive: true);
      }
    });
  }
  if (const bool.fromEnvironment('MISAKAFETCH_FRESH_PROFILE')) {
    test('历史构建标志使实际 Windows 本地仓库始终从默认设置启动', () async {
      final history = SettingsRepository.local();
      await history.save(const AppSettings(themeMode: ThemeMode.dark));
      expect(
        (await SettingsRepository.local().load()).settings.toJson(),
        const AppSettings().toJson(),
      );
    });
  }
  test('历史展示包每次加载恢复原版默认设置，不保留上次预览', () async {
    final history = SettingsRepository.defaultsOnly();
    await history.save(
      const AppSettings(
        themeMode: ThemeMode.dark,
        backgroundEnabled: true,
        backgroundImage: 'preview.png',
        backgroundBlur: 1,
      ),
    );
    expect(
      (await history.load()).settings.toJson(),
      const AppSettings().toJson(),
    );
    expect(
      (await SettingsRepository.defaultsOnly().load()).settings.toJson(),
      const AppSettings().toJson(),
    );
  });
  test('不同运行包使用独立设置；新副本默认、重启保留、更新不串用', () async {
    final root = await Directory.systemTemp.createTemp('misaka-profiles-');
    try {
      final personalDirectory = AppStorageService.windowsDirectoryFor(
        File.fromUri(root.uri.resolve('personal/MisakaFetch.exe')).path,
      );
      final developmentDirectory = AppStorageService.windowsDirectoryFor(
        File.fromUri(root.uri.resolve('development/MisakaFetch.exe')).path,
      );
      final historyDirectory = AppStorageService.windowsDirectoryFor(
        File.fromUri(root.uri.resolve('history/MisakaFetch.exe')).path,
      );
      final personal = SettingsRepository.file(personalDirectory);
      final development = SettingsRepository.file(developmentDirectory);
      final history = SettingsRepository.file(historyDirectory);
      await personal.save(
        const AppSettings(
          themeMode: ThemeMode.dark,
          backgroundEnabled: true,
          backgroundImage: 'personal-background.png',
          backgroundBlur: 2,
        ),
      );
      expect((await development.load()).settings.backgroundImage, isNull);
      expect((await history.load()).settings.backgroundImage, isNull);
      await development.save(const AppSettings(backgroundBlur: 7));
      // 覆盖已有文件，验证真实文件持久化而非只验证首次创建。
      await development.save(const AppSettings(backgroundBlur: 3));
      expect(
        (await SettingsRepository.file(
          developmentDirectory,
        ).load()).settings.backgroundBlur,
        3,
      );
      expect((await personal.load()).settings.backgroundBlur, 2);
      expect(
        (await personal.load()).settings.backgroundImage,
        'personal-background.png',
      );
      expect(
        (await history.load()).settings.toJson(),
        const AppSettings().toJson(),
      );
      expect(
        await File.fromUri(
          developmentDirectory.uri.resolve('settings.json.tmp'),
        ).exists(),
        isFalse,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });
}
