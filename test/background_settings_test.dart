import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:misaka_fetch/app.dart';
import 'package:misaka_fetch/controllers/settings_controller.dart';
import 'package:misaka_fetch/models/app_settings.dart';
import 'package:misaka_fetch/services/background_image_service.dart';
import 'package:misaka_fetch/services/settings_repository.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class _Backgrounds extends BackgroundImageService {
  _Backgrounds(this.next);
  final String next;
  final removed = <String>[];
  @override
  Future<String?> chooseAndImport() async => next;
  @override
  Future<bool> remove(String path) async {
    removed.add(path);
    return true;
  }
}

void main() {
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'MisakaFetch',
      packageName: 'com.example.misakafetch',
      version: '9.8.7',
      buildNumber: '6',
      buildSignature: '',
    ),
  );
  for (final fails in [false, true]) {
    testWidgets('更换背景先提交配置再清理；存储失败=$fails', (tester) async {
      late Directory root;
      late String oldPath;
      late String newPath;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('misakafetch-ui-bg-');
        oldPath = File.fromUri(root.uri.resolve('old.png')).path;
        newPath = File.fromUri(root.uri.resolve('new.png')).path;
        await File(oldPath).writeAsBytes(_png);
        await File(newPath).writeAsBytes(_png);
      });
      final service = _Backgrounds(newPath);
      String? stored;
      final controller = SettingsController(
        repository: SettingsRepository(
          read: () async => stored,
          write: (value) async {
            if (fails) throw StateError('storage');
            stored = value;
          },
        ),
        initialSettings: AppSettings(
          backgroundImage: oldPath,
          backgroundEnabled: false,
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await root.delete(recursive: true);
      });
      await tester.pumpWidget(
        MisakaFetchApp(
          settingsController: controller,
          backgroundService: service,
        ),
      );
      await tester.tap(find.byKey(const Key('settingsButton')));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          ResizeImage(FileImage(File(newPath)), width: 1920),
          tester.element(find.byKey(const Key('chooseBackground'))),
        ),
      );
      await tester.tap(find.byKey(const Key('chooseBackground')));
      await tester.pumpAndSettle();
      expect(controller.settings.backgroundImage, newPath);
      expect(controller.settings.backgroundEnabled, isTrue);
      expect(service.removed, fails ? isEmpty : equals([oldPath]));
      if (!fails) {
        expect(
          AppSettings.fromJson(jsonDecode(stored!) as Map<String, dynamic>)
              .backgroundImage,
          newPath,
        );
        await tester.tap(find.byKey(const Key('removeBackground')));
        await tester.pumpAndSettle();
        expect(controller.settings.backgroundImage, isNull);
        expect(service.removed, [oldPath, newPath]);
        expect(
          tester
              .widgetList<Slider>(find.byType(Slider))
              .every((slider) => slider.onChanged == null),
          isTrue,
        );
      } else {
        expect(find.textContaining('未能保存'), findsWidgets);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('滑块实时更新并保存最终值；恢复参数保留背景图片', (tester) async {
    late Directory root;
    late String imagePath;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('misakafetch-ui-bg-');
      imagePath = File.fromUri(root.uri.resolve('image.png')).path;
      await File(imagePath).writeAsBytes(_png);
    });
    String? stored;
    final controller = SettingsController(
      repository: SettingsRepository(
        read: () async => stored,
        write: (value) async => stored = value,
      ),
      initialSettings: AppSettings(
        backgroundImage: imagePath,
        backgroundEnabled: true,
      ),
    );
    addTearDown(() async {
      controller.dispose();
      await root.delete(recursive: true);
    });
    await controller.update(
      controller.settings.copyWith(backgroundEnabled: false),
      persist: false,
    );
    await tester.pumpWidget(MisakaFetchApp(settingsController: controller));
    await tester.runAsync(
      () => precacheImage(
        ResizeImage(FileImage(File(imagePath)), width: 1920),
        tester.element(find.byKey(const Key('videoInput'))),
      ),
    );
    await controller.update(
      controller.settings.copyWith(backgroundEnabled: true),
      persist: false,
    );
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    for (var index = 0; index < 3; index++) {
      final sliderFinder = find.byType(Slider).at(index);
      await tester.ensureVisible(sliderFinder);
      await tester.pumpAndSettle();
      final center = tester.getCenter(sliderFinder);
      await tester.dragFrom(center, const Offset(90, 0));
      await tester.pumpAndSettle();
    }
    final restored = AppSettings.fromJson(
      jsonDecode(stored!) as Map<String, dynamic>,
    );
    expect(restored.backgroundBlur, controller.settings.backgroundBlur);
    expect(
      restored.backgroundBrightness,
      controller.settings.backgroundBrightness,
    );
    expect(restored.backgroundOverlay, controller.settings.backgroundOverlay);
    expect(restored.backgroundBlur, isNot(10));
    await tester.ensureVisible(find.text('恢复默认背景设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复默认背景设置'));
    await tester.pumpAndSettle();
    expect(controller.settings.backgroundImage, imagePath);
    expect(controller.settings.backgroundBlur, 10);
    expect(controller.settings.backgroundBrightness, 1);
    expect(controller.settings.backgroundOverlay, .35);
    expect(controller.settings.backgroundFit, BackgroundFit.cover);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
