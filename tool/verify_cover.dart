import 'dart:convert';
import 'dart:io';

import 'package:misaka_fetch/services/bilibili_service.dart';
import 'package:misaka_fetch/services/image_download_service.dart';

/// 实际下载原始字节验证；可显式写入 build/qa 供 UI 渲染检查使用。
Future<void> main(List<String> arguments) async {
  final videos = BilibiliService();
  final images = ImageDownloadService();
  try {
    final video = await videos.fetchVideo('BV1Q541167Qg');
    final image = await images.download(video.coverUrl);
    final result = {
      'ok': true,
      'title': video.title,
      'bvid': video.bvid,
      'ownerName': video.ownerName,
      'coverUrl': video.coverUrl,
      'mimeType': image.mimeType,
      'byteLength': image.bytes.length,
    };
    stdout.writeln(jsonEncode(result));
    if (arguments.contains('--write-fixture')) {
      await Directory('build/qa').create(recursive: true);
      await File('build/qa/cover.bin').writeAsBytes(image.bytes);
      await File('build/qa/video.json').writeAsString(jsonEncode(result));
    }
  } on BilibiliServiceException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on ImageDownloadException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } finally {
    videos.close();
    images.close();
  }
}
