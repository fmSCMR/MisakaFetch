import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:misaka_fetch/models/app_settings.dart';
import 'package:misaka_fetch/models/downloaded_image.dart';
import 'package:misaka_fetch/services/image_save_service.dart';
import 'package:misaka_fetch/utils/filename_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bvid = 'BV1Q541167Qg';
  final image = DownloadedImage(
    bytes: Uint8List.fromList([1, 2, 3, 255]),
    mimeType: 'image/png',
  );
  for (final format in FilenameFormat.values) {
    test('文件名格式 $format 清理字符并保留真实扩展名', () {
      final name = coverFilename(
        '标题:封面',
        'image/webp',
        bvid: bvid,
        format: format,
      );
      expect(name, switch (format) {
        FilenameFormat.title => '标题_封面.webp',
        FilenameFormat.titleBvid => '标题_封面_$bvid.webp',
        FilenameFormat.bvidTitle => '${bvid}_标题_封面.webp',
      });
    });
  }
  for (final format in [FilenameFormat.titleBvid, FilenameFormat.bvidTitle]) {
    test('长中文和 emoji 标题保留 BV 并符合文件名限制 $format', () {
      final name = coverFilename(
        List.filled(200, '封😀').join(),
        'image/webp',
        bvid: bvid,
        format: format,
      );
      expect(name, contains(bvid));
      expect(utf8.encode(name).length, lessThanOrEqualTo(255));
      expect(name.runes.length, lessThanOrEqualTo(105));
    });
  }
  test('非法或缺失 BV 不引入路径片段', () {
    expect(
      coverFilename(
        'CON',
        'image/png',
        bvid: '../外部',
        format: FilenameFormat.titleBvid,
      ),
      '_CON.png',
    );
    expect(
      coverFilename('图', 'image/png', format: FilenameFormat.titleBvid),
      '图.png',
    );
  });
  test('直接保存原字节，同名与并发请求均不覆盖已有文件', () async {
    final directory = await Directory.systemTemp.createTemp(
      'misakafetch-save-settings-',
    );
    try {
      final original = File.fromUri(directory.uri.resolve('标题_$bvid.png'));
      await original.writeAsBytes([9, 8]);
      final service = ImageSaveService(
        platform: ImageSavePlatform.windows,
        pickLocation: (_, _) async => fail('直接保存不询问位置'),
      );
      final settings = AppSettings(
        defaultSaveDirectory: directory.path,
        askSaveLocation: false,
      );
      final paths = await Future.wait(
        List.generate(
          3,
          (_) => service.save(image, '标题', bvid: bvid, settings: settings),
        ),
      );
      expect(paths.toSet().length, 3);
      expect(await original.readAsBytes(), [9, 8]);
      for (final path in paths) {
        expect(await File(path!).readAsBytes(), image.bytes);
      }
      expect(await directory.list().length, 4);
    } finally {
      await directory.delete(recursive: true);
    }
  });
  test('直接保存失败清理预留的空文件', () async {
    final directory = await Directory.systemTemp.createTemp(
      'misakafetch-save-settings-',
    );
    try {
      final service = ImageSaveService(
        platform: ImageSavePlatform.windows,
        writeFile: (_, _) async =>
            throw const FileSystemException('disk detail'),
      );
      await expectLater(
        service.save(
          image,
          '标题',
          bvid: bvid,
          settings: AppSettings(
            defaultSaveDirectory: directory.path,
            askSaveLocation: false,
          ),
        ),
        throwsA(isA<ImageSaveException>()),
      );
      expect(await directory.list().length, 0);
    } finally {
      await directory.delete(recursive: true);
    }
  });
  test('默认目录缺失时提示重新选择，不悄悄回退其他位置', () async {
    await expectLater(
      ImageSaveService(
        platform: ImageSavePlatform.windows,
      ).save(image, '标题', settings: const AppSettings(askSaveLocation: false)),
      throwsA(
        isA<ImageSaveException>().having(
          (e) => e.message,
          'message',
          contains('默认保存目录不可用'),
        ),
      ),
    );
  });
  test('每次询问保留系统对话框，应用选定的文件名格式', () async {
    final service = ImageSaveService(
      platform: ImageSavePlatform.windows,
      pickLocation: (filename, extension) async {
        expect(filename, '${bvid}_标题.png');
        expect(extension, 'png');
        return null;
      },
      writeFile: (_, _) async => fail('取消不写入'),
    );
    expect(
      await service.save(
        image,
        '标题',
        bvid: bvid,
        settings: const AppSettings(filenameFormat: FilenameFormat.bvidTitle),
      ),
      isNull,
    );
  });
  test('Android 接收文件名格式并忽略 Windows 默认目录与询问设置', () async {
    const channel = MethodChannel('misakafetch/image_save');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect((call.arguments as Map)['filename'], '标题_$bvid.png');
      expect((call.arguments as Map)['bytes'], image.bytes);
      return '相册 / Pictures/MisakaFetch';
    });
    try {
      final service = ImageSaveService(platform: ImageSavePlatform.android);
      expect(
        await service.save(
          image,
          '标题',
          bvid: bvid,
          settings: const AppSettings(
            defaultSaveDirectory: '不存在的 Windows 路径',
            askSaveLocation: false,
          ),
        ),
        '相册 / Pictures/MisakaFetch',
      );
    } finally {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });
}
