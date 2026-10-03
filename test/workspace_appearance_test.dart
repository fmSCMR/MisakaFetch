import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:misaka_fetch/app.dart';
import 'package:misaka_fetch/controllers/settings_controller.dart';
import 'package:misaka_fetch/models/app_settings.dart';
import 'package:misaka_fetch/services/settings_repository.dart';

void main() {
  testWidgets('启动只显示入口，设置可直接打开；返回后仍收起', (tester) async {
    final controller = SettingsController(
      repository: SettingsRepository(
        read: () async => null,
        write: (_) async {},
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MisakaFetchApp(
        settingsController: controller,
        loadVersion: () async => '1.0.0',
      ),
    );
    expect(find.byKey(const Key('extractionTab')), findsOneWidget);
    expect(find.byKey(const Key('appTitleCard')), findsOneWidget);
    expect(find.text('MisakaFetch'), findsOneWidget);
    expect(find.text('Bilibili 视频封面提取器'), findsOneWidget);
    expect(find.byKey(const Key('videoInput')), findsNothing);
    expect(find.byKey(const Key('appTitleCard')), findsOneWidget);
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('videoInput')), findsNothing);
    await tester.tap(find.byKey(const Key('extractionTab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('videoInput')), findsOneWidget);
    expect(find.byKey(const Key('appTitleCard')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('收起状态仍可切换主题，窄窗口和反复切换始终保留唯一标题', (tester) async {
    final controller = SettingsController(
      repository: SettingsRepository(
        read: () async => null,
        write: (_) async {},
      ),
    );
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MisakaFetchApp(settingsController: controller));
    await tester.tap(find.byTooltip('选择主题'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色模式'));
    await tester.pumpAndSettle();
    expect(controller.settings.themeMode, ThemeMode.dark);
    expect(find.byKey(const Key('videoInput')), findsNothing);
    for (final width in [320.0, 1280.0, 320.0]) {
      tester.view.physicalSize = Size(width, 640);
      await tester.pumpAndSettle();
      for (var index = 0; index < 4; index++) {
        expect(find.byKey(const Key('appTitleCard')), findsOneWidget);
        expect(find.text('Bilibili 视频封面提取器'), findsOneWidget);
        expect(find.byTooltip('选择主题'), findsOneWidget);
        await tester.tap(find.byKey(const Key('extractionTab')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('自定义底色和边框、透明度即时预览并持久化，恢复默认', (tester) async {
    String? stored;
    final controller = SettingsController(
      repository: SettingsRepository(
        read: () async => stored,
        write: (value) async => stored = value,
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MisakaFetchApp(
        settingsController: controller,
        loadVersion: () async => '1.0.0',
      ),
    );
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    Future<void> reveal(Key key) async {
      await tester.scrollUntilVisible(
        find.byKey(key),
        250,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('settingsList')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
    }

    await reveal(const Key('cardColorButton'));
    await tester.tap(find.byKey(const Key('cardColorButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('cardColorHex')), 'zzzzzz');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('请输入六位颜色代码'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('cardColorHex')), '123456');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await reveal(const Key('cardBorderColorButton'));
    await tester.tap(find.byKey(const Key('cardBorderColorButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('cardColorHex')), 'ABCDEF');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    for (final (key, transparency) in [
      (const Key('cardTransparencySlider'), .65),
      (const Key('cardBorderTransparencySlider'), .4),
    ]) {
      await reveal(key);
      final slider = tester.widget<Slider>(find.byKey(key));
      slider.onChanged!(transparency);
      slider.onChangeEnd!(transparency);
      await tester.pumpAndSettle();
    }
    final restored = AppSettings.fromJson(
      jsonDecode(stored!) as Map<String, dynamic>,
    );
    expect(restored.cardColor, 0x123456);
    expect(restored.cardOpacity, closeTo(.35, .0001));
    expect(restored.cardBorderColor, 0xABCDEF);
    expect(restored.cardBorderOpacity, closeTo(.6, .0001));
    final theme = Theme.of(
      tester.element(find.byKey(const Key('cardBorderColorButton'))),
    );
    expect(theme.cardTheme.color, theme.colorScheme.surfaceContainerLow);
    expect(theme.textTheme.bodyMedium!.color!.a, 1);
    expect((theme.cardTheme.shape as RoundedRectangleBorder).side.color.a, 1);
    expect(
      (theme.cardTheme.shape as RoundedRectangleBorder).side.color,
      theme.colorScheme.outlineVariant,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('extractionTab')));
    await tester.pumpAndSettle();
    final extractionTheme = Theme.of(
      tester.element(find.byKey(const Key('videoInput'))),
    );
    expect(extractionTheme.cardTheme.color!.a, closeTo(.35, .0001));
    expect(
      (extractionTheme.cardTheme.shape as RoundedRectangleBorder).side.color.a,
      closeTo(.6, .0001),
    );
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    await reveal(const Key('cardBorderTransparencySlider'));
    await tester.ensureVisible(find.text('恢复默认卡片外观'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复默认卡片外观'));
    await tester.pumpAndSettle();
    expect(controller.settings.cardColor, isNull);
    expect(controller.settings.cardBorderColor, isNull);
    expect(controller.settings.cardOpacity, 1);
    expect(controller.settings.cardBorderOpacity, 1);
    expect(tester.takeException(), isNull);
  });
}
