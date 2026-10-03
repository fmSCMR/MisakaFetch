import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:misaka_fetch/models/app_settings.dart';
import 'package:misaka_fetch/widgets/app_background.dart';

void main() {
  testWidgets('默认遮罩在明暗主题中产生相同背景像素，适应模式留白也一致', (tester) async {
    late Directory directory;
    late File file;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('misaka-overlay-');
      file = File('${directory.path}/background.png');
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 8, 8),
        Paint()..color = const Color(0xFF80C0E0),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(8, 8);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    });
    addTearDown(() => directory.delete(recursive: true));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.runAsync(
      () => precacheImage(
        ResizeImage(FileImage(file), width: 1920),
        tester.element(find.byType(SizedBox).first),
      ),
    );
    const captureKey = Key('capture');
    for (final fit in [BackgroundFit.cover, BackgroundFit.contain]) {
      List<int>? lightPixels;
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.teal,
                brightness: brightness,
              ),
            ),
            home: Center(
              child: SizedBox(
                width: 80,
                height: 40,
                child: RepaintBoundary(
                  key: captureKey,
                  child: AppBackground(
                    settings: AppSettings(
                      backgroundImage: file.path,
                      backgroundEnabled: true,
                      backgroundFit: fit,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final overlay = tester.widget<ColoredBox>(
          find.byKey(const Key('backgroundOverlay')),
        );
        expect(overlay.color, Colors.black.withValues(alpha: .35));
        final pixels = await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(captureKey),
          );
          final image = await boundary.toImage();
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final bytes = data!.buffer.asUint8List().toList();
          image.dispose();
          return bytes;
        });
        if (brightness == Brightness.light) {
          lightPixels = pixels;
        } else {
          expect(pixels, lightPixels);
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
