import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:misaka_fetch/controllers/settings_controller.dart';
import 'package:misaka_fetch/models/app_settings.dart';
import 'package:misaka_fetch/services/settings_repository.dart';

void main() {
  test('首次启动没有存储值时返回默认配置', () async {
    final result = await SettingsRepository(
      read: () async => null,
      write: (_) async {},
    ).load();
    expect(result.settings.themeMode, ThemeMode.system);
    expect(result.warning, isNull);
  });
  test('写入后新 repository 实例可以恢复全部配置', () async {
    String? stored;
    SettingsRepository repository() => SettingsRepository(
      read: () async => stored,
      write: (value) async => stored = value,
    );
    final original = const AppSettings().copyWith(
      themeMode: ThemeMode.dark,
      backgroundBlur: 17,
      animationsEnabled: false,
    );
    await repository().save(original);
    final restored = await repository().load();
    expect(restored.settings.toJson(), original.toJson());
    expect(restored.warning, isNull);
  });
  for (final value in ['broken json', '[]', 'null', 'true']) {
    test('损坏的存储 $value 使用默认值并保留原始记录', () async {
      var writes = 0;
      final result = await SettingsRepository(
        read: () async => value,
        write: (_) async => writes++,
      ).load();
      expect(result.warning, contains('默认设置'));
      expect(result.settings.themeMode, ThemeMode.system);
      expect(writes, 0);
    });
  }
  test('平台读取失败转换为中文警告', () async {
    final result = await SettingsRepository(
      read: () async => throw StateError('private platform error'),
      write: (_) async {},
    ).load();
    expect(result.warning, contains('未能读取'));
    expect(result.warning, isNot(contains('private')));
  });
  test('平台写入失败转换为设置存储异常', () async {
    await expectLater(
      SettingsRepository(
        read: () async => null,
        write: (_) async => throw StateError('private'),
      ).save(const AppSettings()),
      throwsA(
        isA<SettingsStorageException>().having(
          (error) => error.message,
          'message',
          contains('未能保存'),
        ),
      ),
    );
  });
  test('快速连续切换立即更新，但存储严格按顺序完成', () async {
    final first = Completer<void>();
    final saved = <String>[];
    final controller = SettingsController(
      repository: SettingsRepository(
        read: () async => null,
        write: (value) async {
          saved.add((jsonDecode(value) as Map)['themeMode'] as String);
          if (saved.length == 1) await first.future;
        },
      ),
    );
    addTearDown(controller.dispose);
    final dark = controller.setThemeMode(ThemeMode.dark);
    final light = controller.setThemeMode(ThemeMode.light);
    expect(controller.settings.themeMode, ThemeMode.light);
    await Future<void>.delayed(Duration.zero);
    expect(saved, ['dark']);
    first.complete();
    expect(await dark, true);
    expect(await light, true);
    expect(saved, ['dark', 'light']);
    expect(controller.warning, isNull);
  });
  test('保存失败不丢失本次选择，恢复后可重试', () async {
    var fails = true;
    String? stored;
    final controller = SettingsController(
      repository: SettingsRepository(
        read: () async => stored,
        write: (value) async {
          if (fails) throw StateError('disk');
          stored = value;
        },
      ),
    );
    addTearDown(controller.dispose);
    expect(await controller.setThemeMode(ThemeMode.dark), false);
    expect(controller.settings.themeMode, ThemeMode.dark);
    expect(controller.warning, contains('未能保存'));
    fails = false;
    expect(await controller.retrySave(), true);
    expect(controller.warning, isNull);
    expect((jsonDecode(stored!) as Map)['themeMode'], 'dark');
  });
  test('滑块预览不写盘，最终值写入', () async {
    var writes = 0;
    final controller = SettingsController(
      repository: SettingsRepository(
        read: () async => null,
        write: (_) async => writes++,
      ),
    );
    addTearDown(controller.dispose);
    await controller.update(
      controller.settings.copyWith(backgroundBlur: 22),
      persist: false,
    );
    expect(writes, 0);
    expect(controller.settings.backgroundBlur, 22);
    await controller.update(controller.settings);
    expect(writes, 1);
  });
  test('dispose 后排队写入仍完成，不通知已销毁 UI', () async {
    final done = Completer<void>();
    var notifications = 0;
    final controller = SettingsController(
      repository: SettingsRepository(
        read: () async => null,
        write: (_) async => done.future,
      ),
    );
    controller.addListener(() => notifications++);
    final write = controller.setThemeMode(ThemeMode.dark);
    expect(notifications, 1);
    controller.dispose();
    done.complete();
    expect(await write, true);
    expect(notifications, 1);
    expect(await controller.retrySave(), false);
  });
}
