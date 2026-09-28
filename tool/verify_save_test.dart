import 'dart:io';

import 'package:misaka_fetch/models/downloaded_image.dart';
import 'package:misaka_fetch/services/image_save_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 显式 QA：复用联网下载的固定 JPEG 样例，验证实际保存后逐字节一致。
/// 只写 build/qa/，不打开对话框，不覆盖用户手工选择的图片。
void main() {
  test('真实封面原始字节保存校验', () async {
    final source = File('build/qa/cover.bin');
    final bytes = await source.readAsBytes();
    final image = DownloadedImage(bytes: bytes, mimeType: 'image/jpeg');
    final target = File('build/qa/saved-original.jpg');
    final service = ImageSaveService(
      pickLocation: (_, _) async => target.absolute.path,
    );
    expect(await service.save(image, '原图保存验证'), target.absolute.path);
    expect(await target.readAsBytes(), orderedEquals(bytes));
    // ignore: avoid_print
    print('已保存 ${bytes.length} 字节，逐字节一致：${target.absolute.path}');
  });
}
