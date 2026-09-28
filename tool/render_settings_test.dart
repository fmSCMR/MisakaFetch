import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:misaka_fetch/app.dart';
import 'package:misaka_fetch/controllers/settings_controller.dart';
import 'package:misaka_fetch/models/app_settings.dart';
import 'package:misaka_fetch/services/settings_repository.dart';

// Explicit desktop-only render QA. Not native Windows or Android screenshots.
void main() {
  testWidgets('渲染设置页和自定义背景下的主界面', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    late String qaVersion;
    await tester.runAsync(() async {
      final pubspec = await File('pubspec.yaml').readAsString();
      qaVersion = RegExp(
        r'^version: (.+)$',
        multiLine: true,
      ).firstMatch(pubspec)!.group(1)!.trim();
      for (final entry in {
        'Segoe UI': 'segoeui.ttf',
        'Ahem': 'segoeui.ttf',
        'Microsoft YaHei': 'msyh.ttc',
        'Microsoft YaHei UI': 'msyh.ttc',
      }.entries) {
        final bytes = await File('C:/Windows/Fonts/${entry.value}')
            .readAsBytes();
        await (FontLoader(
          entry.key,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
      final icons = await File(
        'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
      ).readAsBytes();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(icons)))).load();
    });
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final phone in [false, true]) {
        tester.view.physicalSize = phone
            ? const Size(390, 844)
            : const Size(1100, 1000);
        final controller = SettingsController(
          repository: SettingsRepository(
            read: () async => null,
            write: (_) async {},
          ),
          initialSettings: AppSettings(
            themeMode: mode,
            animationsEnabled: false,
            backgroundImage: File('build/qa/cover.bin').absolute.path,
            backgroundEnabled: false,
            backgroundBlur: 3,
            backgroundOverlay: .25,
          ),
        );
        const key = Key('settingsRenderBoundary');
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MisakaFetchApp(
              settingsController: controller,
              loadVersion: () async => qaVersion,
            ),
          ),
        );
        await tester.runAsync(
          () => precacheImage(
            ResizeImage(
              FileImage(File('build/qa/cover.bin').absolute),
              width: 1920,
            ),
            tester.element(find.byKey(const Key('videoInput'))),
          ),
        );
        await controller.update(
          controller.settings.copyWith(backgroundEnabled: true),
          persist: false,
        );
        await tester.pumpAndSettle();
        Future<void> capture(String name) async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(key),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            try {
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File('build/qa/$name.png')
                  .writeAsBytes(data!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }

        await capture(
          'background-home-${mode.name}-${phone ? 'phone' : 'desktop'}',
        );
        await tester.tap(find.byKey(const Key('settingsButton')));
        await controller.update(
          controller.settings.copyWith(backgroundEnabled: true),
          persist: false,
        );
        await tester.pumpAndSettle();
        await capture('settings-${mode.name}-${phone ? 'phone' : 'desktop'}');
        final scrollable = find
            .descendant(
              of: find.byKey(const Key('settingsList')),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('下载与保存'),
          300,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        await capture(
          'save-settings-${mode.name}-${phone ? 'phone' : 'desktop'}',
        );
        await tester.scrollUntilVisible(
          find.text('开源许可证'),
          300,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        await capture(
          'about-settings-${mode.name}-${phone ? 'phone' : 'desktop'}',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
