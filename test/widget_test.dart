import 'dart:async';
import 'dart:convert';

import 'package:misaka_fetch/app.dart';
import 'package:misaka_fetch/services/platform_actions_service.dart';
import 'package:misaka_fetch/models/app_settings.dart';
import 'package:misaka_fetch/controllers/settings_controller.dart';
import 'package:misaka_fetch/services/settings_repository.dart';
import 'package:misaka_fetch/models/downloaded_image.dart';
import 'package:misaka_fetch/models/video_info.dart';
import 'package:misaka_fetch/services/bilibili_service.dart';
import 'package:misaka_fetch/services/image_download_service.dart';
import 'package:misaka_fetch/services/image_save_service.dart';
import 'package:misaka_fetch/utils/bilibili_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _video = VideoInfo(
  title: '公开测试视频',
  bvid: 'BV1Q541167Qg',
  ownerName: '测试 UP 主',
  coverUrl: 'https://i0.hdslb.com/bfs/archive/test.png',
);
final _image = DownloadedImage(
  bytes: base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  ),
  mimeType: 'image/png',
);

class _Videos extends BilibiliService {
  _Videos(this.fetch);
  final Future<VideoInfo> Function(String) fetch;
  int calls = 0;
  bool closed = false;
  @override
  Future<VideoInfo> fetchVideo(String text) {
    calls++;
    return fetch(text);
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

class _Images extends ImageDownloadService {
  _Images(this.fetch);
  final Future<DownloadedImage> Function(String) fetch;
  int calls = 0;
  @override
  Future<DownloadedImage> download(String url) {
    calls++;
    return fetch(url);
  }
}

class _Saver extends ImageSaveService {
  _Saver(this.action);
  String? lastBvid;
  AppSettings? lastSettings;
  final Future<String?> Function(DownloadedImage, String) action;
  int calls = 0;
  @override
  bool get isSupported => true;
  @override
  Future<String?> save(
    DownloadedImage image,
    String title, {
    String? bvid,
    AppSettings settings = const AppSettings(),
  }) {
    calls++;
    lastBvid = bvid;
    lastSettings = settings;
    return action(image, title);
  }
}

void main() {
  Future<(_Videos, _Images)> start(
    WidgetTester tester, {
    Future<VideoInfo> Function(String)? fetchVideo,
    Future<DownloadedImage> Function(String)? fetchImage,
    ImageSaveService? saver,
    AppSettings settings = const AppSettings(),
    PlatformActionsService? actions,
  }) async {
    final videos = _Videos(fetchVideo ?? (_) async => _video);
    final images = _Images(fetchImage ?? (_) async => _image);
    await tester.pumpWidget(
      MisakaFetchApp(
        actionsService: actions,
        settingsController: SettingsController(
          initialSettings: settings,
          repository: SettingsRepository(
            read: () async => null,
            write: (_) async {},
          ),
        ),
        videoService: videos,
        imageService: images,
        saveService: saver,
      ),
    );
    // 图片解码运行在真实引擎线程，不能只推进测试的虚拟时钟等待它。
    await tester.runAsync(
      () => precacheImage(
        MemoryImage(_image.bytes),
        tester.element(find.byKey(const Key('videoInput'))),
      ),
    );
    await tester.pump();
    return (videos, images);
  }

  Future<void> extract(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('videoInput')), _video.bvid);
    await tester.ensureVisible(find.byKey(const Key('extractButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('extractButton')));
    await tester.pumpAndSettle();
  }

  testWidgets('保存使用现有原图且防止重复点击', (tester) async {
    final done = Completer<String?>();
    final saver = _Saver((image, title) {
      expect(identical(image, _image), isTrue);
      expect(title, _video.title);
      return done.future;
    });
    final (videos, images) = await start(tester, saver: saver);
    await extract(tester);
    await tester.ensureVisible(find.byKey(const Key('saveImageButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveImageButton')));
    await tester.pump();
    expect(find.text('正在保存…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('saveImageButton')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('extractButton')))
          .onPressed,
      isNull,
    );
    expect(saver.calls, 1);
    done.complete('C:/covers/test.png');
    await tester.pumpAndSettle();
    expect(find.text('原图已保存至：C:/covers/test.png'), findsOneWidget);
    expect(videos.calls, 1);
    expect(images.calls, 1);
  });
  testWidgets('取消保存恢复按钮且不显示成功提示', (tester) async {
    await start(tester, saver: _Saver((_, _) async => null));
    await extract(tester);
    await tester.ensureVisible(find.byKey(const Key('saveImageButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveImageButton')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('saveImageButton')))
          .onPressed,
      isNotNull,
    );
  });
  testWidgets('保存失败显示中文提示', (tester) async {
    await start(
      tester,
      saver: _Saver(
        (_, _) async => throw const ImageSaveException('保存失败，请检查保存位置。'),
      ),
    );
    await extract(tester);
    await tester.ensureVisible(find.byKey(const Key('saveImageButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveImageButton')));
    await tester.pumpAndSettle();
    expect(find.text('保存失败，请检查保存位置。'), findsOneWidget);
  });
  testWidgets('初始页面无网络请求', (tester) async {
    final (videos, images) = await start(tester);
    expect(find.text('MisakaFetch'), findsOneWidget);
    expect(find.text('Bilibili 视频封面提取器'), findsOneWidget);
    expect(find.text('提取封面'), findsOneWidget);
    expect(videos.calls, 0);
    expect(images.calls, 0);
  });
  testWidgets('成功显示信息、原图预览和图片地址', (tester) async {
    final (videos, images) = await start(tester);
    await extract(tester);
    expect(find.text(_video.title), findsOneWidget);
    expect(find.text('UP主：测试 UP 主'), findsOneWidget);
    expect(find.text('BV号：BV1Q541167Qg'), findsOneWidget);
    expect(find.text(_video.coverUrl), findsOneWidget);
    expect(find.byKey(const Key('coverPreview')), findsOneWidget);
    expect(videos.calls, 1);
    expect(images.calls, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('等待元数据时禁用输入和重复请求', (tester) async {
    final pending = Completer<VideoInfo>();
    final (videos, _) = await start(tester, fetchVideo: (_) => pending.future);
    await tester.enterText(find.byKey(const Key('videoInput')), _video.bvid);
    await tester.tap(find.byKey(const Key('extractButton')));
    await tester.pump();
    expect(find.text('正在提取…'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('videoInput'))).enabled,
      isFalse,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('extractButton')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('extractButton')));
    expect(videos.calls, 1);
    pending.complete(_video);
    await tester.pumpAndSettle();
  });
  testWidgets('等待图片时先展示视频信息，仍防重复请求', (tester) async {
    final pending = Completer<DownloadedImage>();
    final (videos, _) = await start(tester, fetchImage: (_) => pending.future);
    await tester.enterText(find.byKey(const Key('videoInput')), _video.bvid);
    await tester.tap(find.byKey(const Key('extractButton')));
    await tester.pump();
    expect(find.text(_video.title), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('extractButton')))
          .onPressed,
      isNull,
    );
    expect(videos.calls, 1);
    pending.complete(_image);
    await tester.pumpAndSettle();
  });
  testWidgets('输入错误显示中文提示，可继续使用', (tester) async {
    await start(
      tester,
      fetchVideo: (_) async =>
          throw const BilibiliParseException(BilibiliParseError.emptyInput),
    );
    await tester.tap(find.byKey(const Key('extractButton')));
    await tester.pumpAndSettle();
    expect(find.text('请先输入 Bilibili 视频链接或 BV 号。'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('extractButton')))
          .onPressed,
      isNotNull,
    );
  });
  testWidgets('接口错误不泄漏原始异常', (tester) async {
    await start(
      tester,
      fetchVideo: (_) async =>
          throw const BilibiliServiceException(BilibiliServiceError.timeout),
    );
    await extract(tester);
    expect(find.text('请求超时，请稍后重试。'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });
  testWidgets('封面失败保留元数据，重试不重新查询视频', (tester) async {
    var calls = 0;
    final (videos, images) = await start(
      tester,
      fetchImage: (_) async {
        calls++;
        if (calls == 1) {
          throw const ImageDownloadException(ImageDownloadError.network);
        }
        return _image;
      },
    );
    await extract(tester);
    expect(find.text(_video.title), findsOneWidget);
    expect(find.text('无法下载封面，请检查网络连接后重试。'), findsOneWidget);
    await tester.ensureVisible(find.text('重新加载封面'));
    await tester.tap(find.text('重新加载封面'));
    await tester.pumpAndSettle();
    expect(videos.calls, 1);
    expect(images.calls, 2);
    expect(find.byKey(const Key('coverPreview')), findsOneWidget);
  });
  testWidgets('图片解码失败显示友好提示', (tester) async {
    final saver = _Saver((_, _) async => fail('无效图片不能保存'));
    var downloads = 0;
    await start(
      tester,
      saver: saver,
      fetchImage: (_) async => ++downloads == 1
          ? DownloadedImage(bytes: base64Decode('AQID'), mimeType: 'image/png')
          : _image,
    );
    await tester.enterText(find.byKey(const Key('videoInput')), _video.bvid);
    // 等待按钮异步处理中的真实引擎解码，避免只推进虚拟时钟。
    final action =
        tester
                .widget<FilledButton>(find.byKey(const Key('extractButton')))
                .onPressed
            as Future<void> Function();
    await tester.runAsync(action);
    await tester.pumpAndSettle();
    expect(find.text('封面无法显示，请重新加载。'), findsOneWidget);
    expect(find.text(_video.title), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('saveImageButton')))
          .onPressed,
      isNull,
    );
    expect(saver.calls, 0);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('重新加载封面'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新加载封面'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coverPreview')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('saveImageButton')))
          .onPressed,
      isNotNull,
    );
  });
  testWidgets('保存等待期间关闭页面不会触发已销毁状态更新', (tester) async {
    final pending = Completer<String?>();
    final saver = _Saver((_, _) => pending.future);
    await start(tester, saver: saver);
    await extract(tester);
    await tester.ensureVisible(find.byKey(const Key('saveImageButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveImageButton')));
    await tester.pump();
    expect(saver.calls, 1);
    await tester.pumpWidget(const SizedBox());
    pending.complete('saved.png');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('剪贴板失败不导致页面崩溃', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'failed');
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
    await start(tester);
    await extract(tester);
    await tester.ensureVisible(find.byKey(const Key('copyLinkButton')));
    await tester.tap(find.byKey(const Key('copyLinkButton')));
    await tester.pumpAndSettle();
    expect(find.text('复制失败，请重试或手动选择图片链接。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('复制到剪贴板并提示成功', (tester) async {
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
    await start(tester);
    await extract(tester);
    await tester.ensureVisible(find.byKey(const Key('copyLinkButton')));
    await tester.tap(find.byKey(const Key('copyLinkButton')));
    await tester.pumpAndSettle();
    expect(copied, _video.coverUrl);
    expect(find.text('图片链接已复制。'), findsOneWidget);
  });
  testWidgets('切换浅色和深色保留结果，不触发网络请求', (tester) async {
    final (videos, _) = await start(tester);
    await extract(tester);
    await tester.tap(find.byTooltip('选择主题'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色模式').last);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byKey(const Key('videoInput')))).brightness,
      Brightness.dark,
    );
    expect(find.text(_video.title), findsOneWidget);
    expect(videos.calls, 1);
    await tester.tap(find.byTooltip('选择主题'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('浅色模式').last);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byKey(const Key('videoInput')))).brightness,
      Brightness.light,
    );
  });
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1280, 720),
  ]) {
    testWidgets('窗口与屏幕尺寸 $size 无布局异常', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await start(
        tester,
        fetchVideo: (_) async => VideoInfo(
          title: List.filled(12, '一个包含中文与 English 的长视频标题').join(' '),
          bvid: _video.bvid,
          ownerName: List.filled(8, '较长的 UP 主名称').join(' '),
          coverUrl: _video.coverUrl,
        ),
      );
      await extract(tester);
      await tester.ensureVisible(find.byKey(const Key('copyLinkButton')));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('页面关闭后异步结果不会 setState', (tester) async {
    final pending = Completer<VideoInfo>();
    final (videos, images) = await start(
      tester,
      fetchVideo: (_) => pending.future,
    );
    await tester.enterText(find.byKey(const Key('videoInput')), _video.bvid);
    await tester.tap(find.byKey(const Key('extractButton')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete(_video);
    await tester.pumpAndSettle();
    expect(videos.closed, isTrue);
    expect(images.calls, 0);
    expect(tester.takeException(), isNull);
  });
  for (final action in SaveSuccessAction.values) {
    testWidgets('保存成功后的行为 $action 与文件名设置传递', (tester) async {
      final actions = _FolderActions();
      final saver = _Saver((_, _) async => 'C:/covers/test.png');
      final settings = AppSettings(
        saveSuccessAction: action,
        filenameFormat: FilenameFormat.bvidTitle,
      );
      await start(tester, saver: saver, settings: settings, actions: actions);
      await extract(tester);
      await tester.ensureVisible(find.byKey(const Key('saveImageButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveImageButton')));
      await tester.pumpAndSettle();
      expect(saver.lastBvid, _video.bvid);
      expect(saver.lastSettings?.filenameFormat, FilenameFormat.bvidTitle);
      expect(
        actions.paths,
        action == SaveSuccessAction.openFolder
            ? ['C:/covers/test.png']
            : isEmpty,
      );
      expect(
        find.text('原图已保存至：C:/covers/test.png'),
        action == SaveSuccessAction.notify ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
  testWidgets('打开目录失败说明原图已保存，不诱导重复保存', (tester) async {
    await start(
      tester,
      saver: _Saver((_, _) async => 'C:/covers/test.png'),
      settings: const AppSettings(
        saveSuccessAction: SaveSuccessAction.openFolder,
      ),
      actions: _FolderActions(fails: true),
    );
    await extract(tester);
    await tester.ensureVisible(find.byKey(const Key('saveImageButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveImageButton')));
    await tester.pumpAndSettle();
    expect(find.text('原图已保存，但文件夹未能打开。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  testWidgets('静默成功不隐藏保存失败提示', (tester) async {
    await start(
      tester,
      saver: _Saver(
        (_, _) async => throw const ImageSaveException('保存失败，请重试。'),
      ),
      settings: const AppSettings(saveSuccessAction: SaveSuccessAction.silent),
    );
    await extract(tester);
    await tester.ensureVisible(find.byKey(const Key('saveImageButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveImageButton')));
    await tester.pumpAndSettle();
    expect(find.text('保存失败，请重试。'), findsOneWidget);
  });
}

class _FolderActions extends PlatformActionsService {
  _FolderActions({this.fails = false});
  final bool fails;
  final paths = <String>[];
  @override
  Future<void> openSavedFolder(String path) async {
    paths.add(path);
    if (fails) throw const PlatformActionException('原图已保存，但文件夹未能打开。');
  }
}
