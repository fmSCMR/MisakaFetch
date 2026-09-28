import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:misaka_fetch/controllers/settings_controller.dart';
import 'package:misaka_fetch/pages/settings_page.dart';
import 'package:misaka_fetch/services/background_image_service.dart';
import 'package:misaka_fetch/services/platform_actions_service.dart';
import 'package:misaka_fetch/services/settings_repository.dart';

class _Actions extends PlatformActionsService {
  _Actions(this.path);
  final String? path;
  int calls = 0;
  int projectCalls = 0;
  bool failProject = false;
  @override
  Future<void> openProject() async {
    projectCalls++;
    if (failProject) {
      throw const PlatformActionException('无法打开浏览器，请复制项目地址后手动打开。');
    }
  }

  @override
  Future<String?> chooseDirectory(String? current) async {
    calls++;
    return path;
  }
}

void main() {
  for (final fails in [false, true]) {
    testWidgets('GitHub 项目调用平台服务，失败=$fails', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final actions = _Actions(null)..failProject = fails;
      final controller = SettingsController(
        repository: SettingsRepository(
          read: () async => null,
          write: (_) async {},
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(
            controller: controller,
            backgroundService: BackgroundImageService(),
            actionsService: actions,
            loadVersion: () async => '1.0.0',
          ),
        ),
      );
      await _scrollTo(tester, find.byKey(const Key('githubProject')), 300);
      await tester.tap(find.byKey(const Key('githubProject')));
      await tester.pumpAndSettle();
      expect(actions.projectCalls, 1);
      if (fails) {
        expect(find.text('无法打开浏览器，请复制项目地址后手动打开。'), findsOneWidget);
        await tester.tap(find.text('复制地址'));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
        expect(copied, PlatformActionsService.projectUrl);
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('保存设置和关于信息按 $platform 展示，小屏字体放大无溢出', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final controller = SettingsController(
        repository: SettingsRepository(
          read: () async => null,
          write: (_) async {},
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(
            controller: controller,
            backgroundService: BackgroundImageService(),
            loadVersion: () async => '2.3.4',
          ),
        ),
      );
      await _scrollTo(tester, find.text('下载与保存'), 300);
      await tester.pumpAndSettle();
      expect(find.text('默认文件名格式'), findsOneWidget);
      expect(
        find.text('默认保存位置'),
        platform == TargetPlatform.windows ? findsOneWidget : findsNothing,
      );
      if (platform == TargetPlatform.android) {
        expect(find.byKey(const Key('chooseSaveDirectory')), findsNothing);
      }
      await _scrollTo(tester, find.text('开源许可证'), 300);
      await tester.pumpAndSettle();
      expect(find.text('版本 2.3.4'), findsOneWidget);
      expect(find.text(PlatformActionsService.projectUrl), findsOneWidget);
      expect(
        tester.widget<ListTile>(find.byKey(const Key('githubProject'))).onTap,
        isNotNull,
      );
      final license = await tester.runAsync(
        () => rootBundle.loadString('LICENSE'),
      );
      expect(license, contains('MIT License'));
      await tester.tap(
        find.ancestor(of: find.text('开源许可证'), matching: find.byType(ListTile)),
      );
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              (widget.data?.contains('Permission is hereby granted') ?? false),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(platform));
  }
  testWidgets('Windows 选择目录后可关闭询问，清除目录恢复询问', (tester) async {
    final actions = _Actions('C:/用户/很长的目录名称/保存位置');
    final controller = SettingsController(
      repository: SettingsRepository(
        read: () async => null,
        write: (_) async {},
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          controller: controller,
          backgroundService: BackgroundImageService(),
          actionsService: actions,
          loadVersion: () async => '2.3.4',
        ),
      ),
    );
    await _scrollTo(tester, find.text('保存时总是询问位置'), 300);
    await tester.pumpAndSettle();
    SwitchListTile tile() => tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text('保存时总是询问位置'),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(tile().onChanged, isNull);
    await tester.ensureVisible(find.byKey(const Key('chooseSaveDirectory')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chooseSaveDirectory')));
    await tester.pumpAndSettle();
    expect(controller.settings.defaultSaveDirectory, actions.path);
    expect(actions.calls, 1);
    await tester.ensureVisible(find.text('保存时总是询问位置'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存时总是询问位置'));
    await tester.pumpAndSettle();
    expect(controller.settings.askSaveLocation, isFalse);
    await tester.ensureVisible(find.text('清除目录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清除目录'));
    await tester.pumpAndSettle();
    expect(controller.settings.defaultSaveDirectory, isNull);
    expect(controller.settings.askSaveLocation, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  testWidgets('版本读取失败保留关于页面且不暴露底层错误', (tester) async {
    final controller = SettingsController(
      repository: SettingsRepository(
        read: () async => null,
        write: (_) async {},
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          controller: controller,
          backgroundService: BackgroundImageService(),
          loadVersion: () async => throw StateError('secret metadata'),
        ),
      ),
    );
    await _scrollTo(tester, find.text('版本信息暂不可用'), 300);
    await tester.pumpAndSettle();
    expect(find.text('版本信息暂不可用'), findsOneWidget);
    expect(find.textContaining('secret metadata'), findsNothing);
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
