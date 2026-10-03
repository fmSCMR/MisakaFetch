import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:misaka_fetch/services/background_image_service.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

void main() {
  testWidgets('不同副本的背景独立，替换或移除不影响另一副本', (tester) async {
    await tester.runAsync(() async {
      final root = await Directory.systemTemp.createTemp('misaka-bg-profiles-');
      try {
        final personal = BackgroundImageService(
          supportDirectory: () async =>
              Directory.fromUri(root.uri.resolve('personal/')),
          picker: () async => XFile.fromData(_png, name: 'personal.png'),
        );
        final development = BackgroundImageService(
          supportDirectory: () async =>
              Directory.fromUri(root.uri.resolve('development/')),
          picker: () async => XFile.fromData(_png, name: 'development.png'),
        );
        final personalImage = (await personal.chooseAndImport())!;
        final developmentImage = (await development.chooseAndImport())!;
        expect(await development.isUsable(personalImage), isFalse);
        expect(await development.remove(personalImage), isFalse);
        expect(await development.remove(developmentImage), isTrue);
        expect(await personal.isUsable(personalImage), isTrue);
      } finally {
        await root.delete(recursive: true);
      }
    });
  });
  testWidgets('导入副本不依赖原图，重启服务仍可读；移除不会删除原图', (tester) async {
    await tester.runAsync(() async {
      final root = await Directory.systemTemp.createTemp(
        'misakafetch-bg-test-',
      );
      try {
        final original = File.fromUri(root.uri.resolve('original.png'));
        await original.writeAsBytes(_png);
        final service = BackgroundImageService(
          supportDirectory: () async => root,
          picker: () async => XFile(original.path),
        );
        final first = (await service.chooseAndImport())!;
        expect(first, isNot(original.path));
        expect(await File(first).readAsBytes(), orderedEquals(_png));
        await original.delete();
        final restarted = BackgroundImageService(
          supportDirectory: () async => root,
        );
        expect(await restarted.isUsable(first), isTrue);
        final second = (await BackgroundImageService(
          supportDirectory: () async => root,
          picker: () async => XFile.fromData(_png, name: 'second.png'),
        ).chooseAndImport())!;
        expect(second, isNot(first));
        expect(await restarted.remove(first), isTrue);
        expect(await File(first).exists(), isFalse);
        expect(await restarted.isUsable(second), isTrue);
        expect(await restarted.remove(second), isTrue);
      } finally {
        await root.delete(recursive: true);
      }
    });
  });
  testWidgets('拒绝删除非内部文件和伪造内部文件名的外部图片', (tester) async {
    await tester.runAsync(() async {
      final root = await Directory.systemTemp.createTemp(
        'misakafetch-bg-test-',
      );
      try {
        final external = File.fromUri(
          root.uri.resolve('background_123_ab.png'),
        );
        await external.writeAsBytes(_png);
        final service = BackgroundImageService(
          supportDirectory: () async => root,
        );
        expect(await service.remove(external.path), isFalse);
        expect(await service.isUsable(external.path), isFalse);
        expect(await external.exists(), isTrue);
      } finally {
        await root.delete(recursive: true);
      }
    });
  });
  testWidgets('损坏图片和不支持的格式不会留下内部副本', (tester) async {
    await tester.runAsync(() async {
      final root = await Directory.systemTemp.createTemp(
        'misakafetch-bg-test-',
      );
      try {
        for (final bytes in [
          base64Decode('iVBORw0KGgo='),
          base64Decode('R0lGODlh'),
        ]) {
          final service = BackgroundImageService(
            supportDirectory: () async => root,
            picker: () async => XFile.fromData(bytes, name: 'bad.png'),
          );
          await expectLater(
            service.chooseAndImport(),
            throwsA(isA<BackgroundImageException>()),
          );
        }
        expect(
          await Directory.fromUri(root.uri.resolve('backgrounds/')).exists(),
          isFalse,
        );
      } finally {
        await root.delete(recursive: true);
      }
    });
  });
  test('取消选择不创建任何文件或读取存储目录', () async {
    final service = BackgroundImageService(
      picker: () async => null,
      supportDirectory: () async => throw StateError('must not run'),
    );
    expect(await service.chooseAndImport(), isNull);
  });
  test('选择器失败转为可读错误', () async {
    final service = BackgroundImageService(
      picker: () async => throw StateError('secret system detail'),
    );
    await expectLater(
      service.chooseAndImport(),
      throwsA(
        isA<BackgroundImageException>().having(
          (error) => error.message,
          'message',
          isNot(contains('secret')),
        ),
      ),
    );
  });
  test('文件超过上限在读取和解码前拒绝', () async {
    final service = BackgroundImageService(picker: () async => _LargeFile());
    await expectLater(
      service.chooseAndImport(),
      throwsA(
        isA<BackgroundImageException>().having(
          (error) => error.message,
          'message',
          contains('20 MB'),
        ),
      ),
    );
  });
  test('不存在的背景恢复默认路径；重复清理安全', () async {
    final service = BackgroundImageService();
    expect(await service.isUsable('missing-background.png'), isFalse);
    expect(await service.remove('missing-background.png'), isTrue);
  });
}

class _LargeFile extends XFile {
  _LargeFile() : super('not-read');
  @override
  Future<int> length() async => BackgroundImageService.maxBytes + 1;
}
