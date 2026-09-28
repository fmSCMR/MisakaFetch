import 'dart:convert';
import 'dart:io';

import 'package:misaka_fetch/services/bilibili_service.dart';
import 'package:misaka_fetch/utils/bilibili_parser.dart';

/// 显式运行的联网验证工具；默认单元测试不会访问 Bilibili。
Future<void> main(List<String> arguments) async {
  final inputs = arguments.isEmpty
      ? [
          'BV1xx411c7mD',
          'BV1Q541167Qg',
          'BV17x411w7KC',
          'https://www.bilibili.com/video/av170001/',
          'https://b23.tv/BV1Q541167Qg',
        ]
      : arguments;
  final service = BilibiliService();
  try {
    for (final input in inputs) {
      try {
        final video = await service.fetchVideo(input);
        stdout.writeln(
          jsonEncode({
            'input': input,
            'ok': true,
            'bvid': video.bvid,
            'title': video.title,
            'ownerName': video.ownerName,
            'coverUrl': video.coverUrl,
            'aid': video.aid,
            'publishedAt': video.publishedAt?.toIso8601String(),
          }),
        );
      } on BilibiliServiceException catch (error) {
        stdout.writeln(
          jsonEncode({'input': input, 'ok': false, 'error': error.message}),
        );
        exitCode = 1;
      } on BilibiliParseException catch (error) {
        stdout.writeln(
          jsonEncode({'input': input, 'ok': false, 'error': error.message}),
        );
        exitCode = 1;
      }
    }
  } finally {
    service.close();
  }
}
