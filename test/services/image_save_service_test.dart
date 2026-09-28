import 'dart:io';

import 'package:misaka_fetch/models/downloaded_image.dart';
import 'package:misaka_fetch/services/image_save_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('misakafetch/image_save');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  final image = DownloadedImage(
    bytes: Uint8List.fromList([0, 255, 3, 4]),
    mimeType: 'image/png',
  );
  test('Android 传递清理后的名称、真实 MIME 与原始字节', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'saveImage');
      final args = call.arguments as Map;
      expect(args['filename'], '标题_封面.png');
      expect(args['mimeType'], 'image/png');
      expect(args['bytes'], image.bytes);
      return '相册 / Pictures/MisakaFetch';
    });
    final service = ImageSaveService(
      platform: ImageSavePlatform.android,
      pickLocation: (_, _) async => fail('Android 不调用 Windows 对话框'),
      writeFile: (_, _) async => fail('Android 不直接写文件路径'),
    );
    expect(service.isSupported, isTrue);
    expect(await service.save(image, '标题:封面'), '相册 / Pictures/MisakaFetch');
  });
  test('Android 旧版取消系统另存为', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(
      await ImageSaveService(platform: ImageSavePlatform.android)
          .save(image, '图'),
      isNull,
    );
  });
  for (final error in [
    PlatformException(code: 'save_failed'),
    MissingPluginException('missing'),
  ]) {
    test('Android 平台错误转换 ${error.runtimeType}', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => throw error);
      await expectLater(
        ImageSaveService(platform: ImageSavePlatform.android).save(image, '图'),
        throwsA(
          isA<ImageSaveException>().having(
            (e) => e.message,
            'message',
            contains('保存失败'),
          ),
        ),
      );
    });
  }
  test('Android 异常结果不会误报保存成功', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => '');
    await expectLater(
      ImageSaveService(platform: ImageSavePlatform.android).save(image, '图'),
      throwsA(isA<ImageSaveException>()),
    );
  });
  test('不支持的平台不会调用系统接口', () async {
    final service = ImageSaveService(platform: ImageSavePlatform.unsupported);
    expect(service.isSupported, isFalse);
    await expectLater(
      service.save(image, '图'),
      throwsA(isA<ImageSaveException>()),
    );
  });
  test('实际写入原始字节且不额外下载', () async {
    final dir = await Directory.systemTemp.createTemp('misakafetch-save-test-');
    try {
      final path = '${dir.path}${Platform.pathSeparator}测试.png';
      final service = ImageSaveService(
        platform: ImageSavePlatform.windows,
        pickLocation: (name, extension) async {
          expect(name, '测试.png');
          expect(extension, 'png');
          return path;
        },
      );
      expect(await service.save(image, '测试'), path);
      expect(await File(path).readAsBytes(), image.bytes);
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test('取消不会写入文件', () async {
    var writes = 0;
    final service = ImageSaveService(
      platform: ImageSavePlatform.windows,
      pickLocation: (_, _) async => null,
      writeFile: (_, _) async {
        writes++;
      },
    );
    expect(await service.save(image, '图'), isNull);
    expect(writes, 0);
  });
  test('不存在的目录显示可读错误', () async {
    final dir = await Directory.systemTemp.createTemp(
      'misakafetch-missing-test-',
    );
    try {
      final service = ImageSaveService(
        platform: ImageSavePlatform.windows,
        pickLocation: (_, _) async => '${dir.path}/missing/image.png',
      );
      await expectLater(
        service.save(image, '图'),
        throwsA(
          isA<ImageSaveException>().having(
            (e) => e.message,
            'message',
            contains('保存失败'),
          ),
        ),
      );
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test('对话框异常转换', () async {
    final service = ImageSaveService(
      platform: ImageSavePlatform.windows,
      pickLocation: (_, _) async => throw PlatformException(code: 'dialog'),
    );
    await expectLater(
      service.save(image, '图'),
      throwsA(isA<ImageSaveException>()),
    );
  });
  test('空数据不打开对话框', () async {
    final service = ImageSaveService(
      platform: ImageSavePlatform.windows,
      pickLocation: (_, _) async => fail('不能打开对话框'),
    );
    await expectLater(
      service.save(
        DownloadedImage(bytes: Uint8List(0), mimeType: 'image/png'),
        '图',
      ),
      throwsA(isA<ImageSaveException>()),
    );
  });
}
