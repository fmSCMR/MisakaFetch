import 'pump_app.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:misaka_fetch/app.dart';
import 'package:misaka_fetch/controllers/settings_controller.dart';
import 'package:misaka_fetch/models/app_settings.dart';
import 'package:misaka_fetch/services/settings_repository.dart';

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final mode in ThemeMode.values) {
      testWidgets('已加载设置在 $platform / $mode 第一帧生效', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final controller = SettingsController(
          repository: SettingsRepository(
            read: () async => null,
            write: (_) async {},
          ),
          initialSettings: AppSettings(themeMode: mode),
        );
        addTearDown(controller.dispose);
        await pumpExtractionApp(
          tester,
          MisakaFetchApp(settingsController: controller),
        );
        expect(
          Theme.of(tester.element(find.byKey(const Key('videoInput'))))
              .brightness,
          mode == ThemeMode.light ? Brightness.light : Brightness.dark,
        );
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant.only(platform));
    }
  }
  testWidgets('主页面主题菜单持久化后重建应用仍为所选主题', (tester) async {
    String? stored;
    final repository = SettingsRepository(
      read: () async => stored,
      write: (value) async => stored = value,
    );
    final first = SettingsController(repository: repository);
    addTearDown(first.dispose);
    await pumpExtractionApp(tester, MisakaFetchApp(settingsController: first));
    await tester.tap(find.byTooltip('选择主题'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色模式').last);
    await tester.pumpAndSettle();
    await first.pendingWrites;
    expect((jsonDecode(stored!) as Map)['themeMode'], 'dark');
    await pumpExtractionApp(tester, const SizedBox.shrink());
    final loaded = await repository.load();
    final second = SettingsController(
      repository: repository,
      initialSettings: loaded.settings,
    );
    addTearDown(second.dispose);
    await pumpExtractionApp(tester, MisakaFetchApp(settingsController: second));
    expect(
      Theme.of(tester.element(find.byKey(const Key('videoInput')))).brightness,
      Brightness.dark,
    );
  });
  testWidgets('读取失败可见中文提示，仍可操作主页面', (tester) async {
    final controller = SettingsController(
      repository: SettingsRepository(
        read: () async => null,
        write: (_) async {},
      ),
      initialWarning: '未能读取上次设置，本次已使用默认设置。',
    );
    addTearDown(controller.dispose);
    await pumpExtractionApp(
      tester,
      MisakaFetchApp(settingsController: controller),
    );
    await tester.pump();
    expect(find.text('未能读取上次设置，本次已使用默认设置。'), findsOneWidget);
    expect(find.byKey(const Key('videoInput')), findsOneWidget);
  });
}
