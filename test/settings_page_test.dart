import 'pump_app.dart';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:misaka_fetch/app.dart';
import 'package:misaka_fetch/controllers/settings_controller.dart';
import 'package:misaka_fetch/models/app_settings.dart';
import 'package:misaka_fetch/pages/settings_page.dart';
import 'package:misaka_fetch/services/background_image_service.dart';
import 'package:misaka_fetch/services/settings_repository.dart';

void main() {
  for (final initiallyEnabled in [true, false]) {
    testWidgets('设置页返回采用最新动画开关：初始 $initiallyEnabled', (tester) async {
      final controller = SettingsController(
        repository: SettingsRepository(
          read: () async => null,
          write: (_) async {},
        ),
        initialSettings: AppSettings(animationsEnabled: initiallyEnabled),
      );
      addTearDown(controller.dispose);
      await pumpExtractionApp(
        tester,
        MisakaFetchApp(settingsController: controller),
      );
      await tester.tap(find.byKey(const Key('settingsButton')));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('界面动画'), 300);
      await tester.tap(find.widgetWithText(SwitchListTile, '界面动画'));
      await tester.pumpAndSettle();
      expect(controller.settings.animationsEnabled, !initiallyEnabled);
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(
        find.byType(SettingsPage),
        initiallyEnabled ? findsNothing : findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'MisakaFetch',
      packageName: 'com.example.misakafetch',
      version: '9.8.7',
      buildNumber: '6',
      buildSignature: '',
    ),
  );
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final size in [const Size(320, 640), const Size(1280, 800)]) {
      testWidgets('$platform 设置入口及滚动布局 $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(bottom: 24);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = SettingsController(
          repository: SettingsRepository(
            read: () async => null,
            write: (_) async {},
          ),
        );
        addTearDown(controller.dispose);
        await pumpExtractionApp(
          tester,
          MisakaFetchApp(settingsController: controller),
        );
        expect(
          tester.getSize(find.byKey(const Key('settingsButton'))).shortestSide,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(find.byKey(const Key('settingsButton')));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(find.text('设置'), findsOneWidget);
        expect(
          tester
              .widgetList<Slider>(find.byType(Slider))
              .where(
                (slider) =>
                    slider.key?.toString().contains('background') ?? false,
              )
              .every((slider) => slider.onChanged == null),
          isTrue,
        );
        await _scrollTo(tester, find.text('恢复默认设置'), 300);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('恢复默认设置'));
        await tester.pumpAndSettle();
        await tester.pumpAndSettle();
        await tester.tap(find.text('恢复默认设置'));
        await tester.pumpAndSettle();
        expect(find.text('确定要恢复所有设置吗？'), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('videoInput')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant.only(platform));
    }
  }
  testWidgets('设置页修改主题共享控制器；全局重置需要确认', (tester) async {
    final controller = SettingsController(
      repository: SettingsRepository(
        read: () async => null,
        write: (_) async {},
      ),
      initialSettings: const AppSettings(
        themeMode: ThemeMode.dark,
        animationsEnabled: false,
      ),
    );
    addTearDown(controller.dispose);
    await pumpExtractionApp(
      tester,
      MisakaFetchApp(settingsController: controller),
    );
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('浅色模式').last);
    await tester.pumpAndSettle();
    expect(controller.settings.themeMode, ThemeMode.light);
    await _scrollTo(tester, find.text('恢复默认设置'), 300);
    await tester.tap(find.text('恢复默认设置'));
    await tester.pumpAndSettle();
    expect(controller.settings.animationsEnabled, isFalse);
    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();
    expect(controller.settings.themeMode, ThemeMode.system);
    expect(controller.settings.animationsEnabled, isTrue);
  });
  testWidgets('图片选择失败显示中文提示，页面仍可操作', (tester) async {
    final controller = SettingsController(
      repository: SettingsRepository(
        read: () async => null,
        write: (_) async {},
      ),
    );
    addTearDown(controller.dispose);
    await pumpExtractionApp(
      tester,
      MisakaFetchApp(
        settingsController: controller,
        backgroundService: BackgroundImageService(
          picker: () async => throw StateError('picker failed'),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chooseBackground')));
    await tester.pumpAndSettle();
    expect(find.textContaining('背景图片未能导入'), findsOneWidget);
    expect(controller.settings.backgroundImage, isNull);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _scrollTo(WidgetTester tester, Finder target, double delta) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('settingsList')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}
