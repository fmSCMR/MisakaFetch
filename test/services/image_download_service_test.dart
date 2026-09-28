import 'dart:async';
import 'dart:io';

import 'package:misaka_fetch/services/image_download_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _Client extends http.BaseClient {
  _Client(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

void main() {
  const url = 'https://i0.hdslb.com/bfs/archive/cover.jpg';
  ImageDownloadService service(
    Future<http.StreamedResponse> Function(http.BaseRequest) handler, {
    Duration timeout = const Duration(seconds: 1),
  }) {
    final result = ImageDownloadService(
      client: _Client(handler),
      timeout: timeout,
    );
    addTearDown(result.close);
    return result;
  }

  Matcher error(ImageDownloadError code) =>
      isA<ImageDownloadException>().having((e) => e.code, 'code', code);

  test('原始字节不重新编码，并发送 Referer', () async {
    final bytes = [255, 216, 255, 1, 2, 3];
    final downloader = service((request) async {
      expect(request.url.toString(), url);
      expect(request.headers['referer'], 'https://www.bilibili.com/');
      expect(request.followRedirects, isFalse);
      return http.StreamedResponse(
        Stream.value(bytes),
        200,
        headers: {'content-type': 'image/jpeg; charset=binary'},
      );
    });
    final image = await downloader.download(url);
    expect(image.bytes, bytes);
    expect(image.mimeType, 'image/jpeg');
  });
  for (final type in ['image/png', 'image/webp', 'image/gif']) {
    test('支持 $type', () async {
      final downloader = service(
        (_) async => http.StreamedResponse(
          Stream.value([1, 2]),
          200,
          headers: {'content-type': type},
        ),
      );
      expect((await downloader.download(url)).mimeType, type);
    });
  }
  for (final invalid in [
    'http://i0.hdslb.com/a.jpg',
    'not a url',
    'https://user@i0.hdslb.com/a.jpg',
  ]) {
    test('无效地址不请求 $invalid', () async {
      var sent = false;
      final downloader = service((_) async {
        sent = true;
        return http.StreamedResponse(const Stream.empty(), 200);
      });
      await expectLater(
        downloader.download(invalid),
        throwsA(error(ImageDownloadError.invalidImage)),
      );
      expect(sent, isFalse);
    });
  }
  for (final status in [403, 404, 500, 302]) {
    test('处理 HTTP $status', () async {
      final downloader = service(
        (_) async => http.StreamedResponse(const Stream.empty(), status),
      );
      await expectLater(
        downloader.download(url),
        throwsA(error(ImageDownloadError.downloadFailed)),
      );
    });
  }
  for (final type in [null, 'text/html', 'application/json', 'image/svg+xml']) {
    test('不接受图片以外响应 $type', () async {
      final downloader = service(
        (_) async => http.StreamedResponse(
          Stream.value([1, 2]),
          200,
          headers: type == null ? const {} : {'content-type': type},
        ),
      );
      await expectLater(
        downloader.download(url),
        throwsA(error(ImageDownloadError.invalidImage)),
      );
    });
  }
  test('空图片报错', () async {
    final downloader = service(
      (_) async => http.StreamedResponse(
        const Stream.empty(),
        200,
        headers: {'content-type': 'image/png'},
      ),
    );
    await expectLater(
      downloader.download(url),
      throwsA(error(ImageDownloadError.invalidImage)),
    );
  });
  test('响应长度超限提前取消', () async {
    final downloader = service(
      (_) async => http.StreamedResponse(
        const Stream.empty(),
        200,
        contentLength: 21 * 1024 * 1024,
        headers: {'content-type': 'image/jpeg'},
      ),
    );
    await expectLater(
      downloader.download(url),
      throwsA(error(ImageDownloadError.invalidImage)),
    );
  });
  test('无 Content-Length 时仍限制累计字节数', () async {
    final downloader = service(
      (_) async => http.StreamedResponse(
        Stream.value(List.filled(20 * 1024 * 1024 + 1, 0)),
        200,
        headers: {'content-type': 'image/png'},
      ),
    );
    await expectLater(
      downloader.download(url),
      throwsA(error(ImageDownloadError.invalidImage)),
    );
  });
  test('HTTP 客户端直接抛出 TimeoutException 仍转换为超时提示', () async {
    final downloader = service((_) async => throw TimeoutException('internal'));
    await expectLater(
      downloader.download(url),
      throwsA(error(ImageDownloadError.timeout)),
    );
  });
  test('SocketException 转换为用户错误', () async {
    final downloader = service(
      (_) async => throw const SocketException('internal'),
    );
    await expectLater(
      downloader.download(url),
      throwsA(error(ImageDownloadError.network)),
    );
  });
  test('超时取消正在读取的响应体', () async {
    final cancelled = Completer<void>();
    final downloader = service((request) async {
      final stream = StreamController<List<int>>();
      unawaited(
        (request as http.AbortableRequest).abortTrigger!.then((_) {
          stream.addError(http.RequestAbortedException());
          cancelled.complete();
          return stream.close();
        }),
      );
      return http.StreamedResponse(
        stream.stream,
        200,
        headers: {'content-type': 'image/png'},
      );
    }, timeout: const Duration(milliseconds: 30));
    await expectLater(
      downloader.download(url),
      throwsA(error(ImageDownloadError.timeout)),
    );
    await cancelled.future;
  });
}
