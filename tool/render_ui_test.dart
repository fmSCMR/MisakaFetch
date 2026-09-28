import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:misaka_fetch/app.dart';
import 'package:misaka_fetch/controllers/settings_controller.dart';
import 'package:misaka_fetch/services/settings_repository.dart';
import 'package:misaka_fetch/models/downloaded_image.dart';
import 'package:misaka_fetch/models/video_info.dart';
import 'package:misaka_fetch/services/bilibili_service.dart';
import 'package:misaka_fetch/services/image_download_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Videos extends BilibiliService {
  _Videos(this.video);
  final VideoInfo video;
  @override
  Future<VideoInfo> fetchVideo(String text) async => video;
}

class _Images extends ImageDownloadService {
  _Images(this.image);
  final DownloadedImage image;
  @override
  Future<DownloadedImage> download(String url) async => image;
}

/// 显式 UI 渲染检查，读取 verify_cover 生成的公开样例，不访问网络。
void main() {
  testWidgets('渲染实际界面与原始封面，导出浅色和深色预览', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(960, 1100);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late final VideoInfo video;
    late final DownloadedImage image;
    await tester.runAsync(() async {
      final data = jsonDecode(
        await File('build/qa/video.json').readAsString(),
      ) as Map<String, dynamic>;
      video = VideoInfo(
        title: data['title'] as String,
        bvid: data['bvid'] as String,
        ownerName: data['ownerName'] as String,
        coverUrl: data['coverUrl'] as String,
      );
      image = DownloadedImage(
        bytes: await File('build/qa/cover.bin').readAsBytes(),
        mimeType: data['mimeType'] as String,
      );
      // Use actual Windows Latin and Chinese families in this explicit QA render.
      // Never alias the Latin family to a Chinese font: that hides fallback issues.
      final latin = await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes();
      final chinese = await File('C:/Windows/Fonts/msyh.ttc').readAsBytes();
      for (final family in ['Segoe UI', 'Ahem']) {
        await (FontLoader(
          family,
        )..addFont(Future.value(ByteData.sublistView(latin)))).load();
      }
      for (final family in ['Microsoft YaHei', 'Microsoft YaHei UI']) {
        await (FontLoader(
          family,
        )..addFont(Future.value(ByteData.sublistView(chinese)))).load();
      }
      final iconBytes = await File(
        'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
      ).readAsBytes();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(iconBytes)))).load();
    });
    const boundaryKey = Key('renderBoundary');
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MisakaFetchApp(
          settingsController: SettingsController(
            repository: SettingsRepository(
              read: () async => null,
              write: (_) async {},
            ),
          ),
          videoService: _Videos(video),
          imageService: _Images(image),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('videoInput')), video.bvid);
    await tester.runAsync(
      () => precacheImage(
        MemoryImage(image.bytes),
        tester.element(find.byKey(const Key('videoInput'))),
      ),
    );
    await tester.tap(find.byKey(const Key('extractButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coverPreview')), findsOneWidget);
    expect(find.text('封面无法显示，请重新加载。'), findsNothing);
    expect(tester.takeException(), isNull);
    Future<void> capture(String name) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      await tester.runAsync(() async {
        final bitmap = await boundary.toImage(pixelRatio: 1);
        try {
          final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
          await File('build/qa/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          bitmap.dispose();
        }
      });
    }

    await capture('home-light');
    await tester.tap(find.byTooltip('选择主题'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色模式').last);
    await tester.pumpAndSettle();
    await capture('home-dark');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
