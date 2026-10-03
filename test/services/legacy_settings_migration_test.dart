import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:misaka_fetch/models/app_settings.dart';
import 'package:misaka_fetch/services/settings_repository.dart';

void main() {
  test('旧设置先备份，背景复制到独立目录；重启优先已有设置', () async {
    final root = await Directory.systemTemp.createTemp('misaka-migrate-');
    try {
      final originalImage = File('${root.path}/original.png');
      await originalImage.writeAsBytes([1, 2, 3]);
      final directory = Directory('${root.path}/user_data');
      final legacy = jsonEncode(
        AppSettings(
          themeMode: ThemeMode.dark,
          backgroundEnabled: true,
          backgroundImage: originalImage.path,
          backgroundBlur: 3,
          defaultSaveDirectory: 'C:/Pictures',
        ).toJson(),
      );
      var reads = 0;
      final repository = SettingsRepository.file(
        directory,
        legacyRead: () async {
          reads++;
          return legacy;
        },
      );
      final loaded = await repository.load();
      expect(loaded.warning, isNull);
      expect(loaded.settings.themeMode, ThemeMode.dark);
      expect(loaded.settings.backgroundBlur, 3);
      expect(loaded.settings.defaultSaveDirectory, 'C:/Pictures');
      expect(loaded.settings.backgroundImage, isNot(originalImage.path));
      expect(await File(loaded.settings.backgroundImage!).readAsBytes(), [
        1,
        2,
        3,
      ]);
      expect(await originalImage.readAsBytes(), [1, 2, 3]);
      expect(
        await File('${directory.path}/settings-v1.0.0-backup.json')
            .readAsString(),
        legacy,
      );
      await repository.save(loaded.settings.copyWith(backgroundBlur: .5));
      expect((await repository.load()).settings.backgroundBlur, .5);
      expect(reads, 1);
    } finally {
      await root.delete(recursive: true);
    }
  });
  test('非法旧配置不覆盖或删除旧数据，也不生成新配置', () async {
    final root = await Directory.systemTemp.createTemp(
      'misaka-migrate-invalid-',
    );
    try {
      final loaded = await SettingsRepository.file(
        root,
        legacyRead: () async => 'invalid',
      ).load();
      expect(loaded.warning, isNotNull);
      expect(await File('${root.path}/settings.json').exists(), false);
    } finally {
      await root.delete(recursive: true);
    }
  });
}
