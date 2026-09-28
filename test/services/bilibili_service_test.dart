import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:misaka_fetch/services/bilibili_service.dart';
import 'package:misaka_fetch/utils/bilibili_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const _bvid = 'BV1Q541167Qg';
Map<String, dynamic> _data() => {
  'title': '测试视频',
  'bvid': _bvid,
  'owner': {'name': '测试 UP 主'},
  'pic': 'http://i1.hdslb.com/bfs/archive/example.jpg',
  'aid': 455017605,
  'pubdate': 1584949634,
  'desc': '公开简介',
};

http.StreamedResponse _response(
  Object? json, {
  int status = 200,
  Map<String, String>? headers,
}) => http.StreamedResponse(
  Stream.value(utf8.encode(jsonEncode(json))),
  status,
  headers: headers ?? {},
);

class _Client extends http.BaseClient {
  _Client(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
  @override
  void close() => closed = true;
}

void main() {
  BilibiliService service(
    Future<http.StreamedResponse> Function(http.BaseRequest) handler, {
    Duration timeout = const Duration(seconds: 1),
  }) {
    final value = BilibiliService(client: _Client(handler), timeout: timeout);
    addTearDown(value.close);
    return value;
  }

  Matcher error(BilibiliServiceError code) =>
      isA<BilibiliServiceException>().having((e) => e.code, 'code', code);

  test('官方接口、中文解码、原始封面 HTTPS、无 Cookie', () async {
    final api = service((request) async {
      expect(request.url.host, 'api.bilibili.com');
      expect(request.url.path, '/x/web-interface/view');
      expect(request.url.queryParameters, {'bvid': _bvid});
      expect(request.followRedirects, isFalse);
      expect(request, isA<http.AbortableRequest>());
      expect(request.headers.containsKey('cookie'), isFalse);
      expect(request.headers.containsKey('authorization'), isFalse);
      return _response({'code': 0, 'data': _data()});
    });
    final video = await api.fetchVideo(_bvid);
    expect(video.title, '测试视频');
    expect(video.ownerName, '测试 UP 主');
    expect(video.coverUrl, 'https://i1.hdslb.com/bfs/archive/example.jpg');
    expect(video.aid, 455017605);
    expect(
      video.publishedAt,
      DateTime.fromMillisecondsSinceEpoch(1584949634000, isUtc: true),
    );
    expect(video.description, '公开简介');
  });
  test('AV 使用 aid 查询', () async {
    final api = service((request) async {
      expect(request.url.queryParameters, {'aid': '455017605'});
      return _response({'code': 0, 'data': _data()});
    });
    expect(
      (await api.fetchVideo('https://www.bilibili.com/video/av455017605/'))
          .bvid,
      _bvid,
    );
  });
  test('输入为空不发请求', () async {
    var sent = false;
    final api = service((_) async {
      sent = true;
      return _response(null);
    });
    await expectLater(
      api.fetchVideo(''),
      throwsA(isA<BilibiliParseException>()),
    );
    expect(sent, isFalse);
  });
  test('异常次要字段不影响核心结果', () async {
    final data = _data()
      ..['aid'] = 'invalid'
      ..['pubdate'] = 999999999999999999
      ..['desc'] = [];
    final api = service((_) async => _response({'code': 0, 'data': data}));
    final video = await api.fetchVideo(_bvid);
    expect(video.aid, isNull);
    expect(video.publishedAt, isNull);
    expect(video.description, isNull);
  });
  test('BV 返回值必须与请求一致', () async {
    final data = _data()..['bvid'] = 'BV17x411w7KC';
    final api = service((_) async => _response({'code': 0, 'data': data}));
    await expectLater(
      api.fetchVideo(_bvid),
      throwsA(error(BilibiliServiceError.invalidResponse)),
    );
  });
  test('AV 返回值必须与请求一致', () async {
    final api = service((_) async => _response({'code': 0, 'data': _data()}));
    await expectLater(
      api.fetchVideo('https://www.bilibili.com/video/av170001/'),
      throwsA(error(BilibiliServiceError.invalidResponse)),
    );
  });
  for (final field in ['title', 'bvid', 'owner', 'pic']) {
    test('缺少核心字段 $field', () async {
      final data = _data()..remove(field);
      final api = service((_) async => _response({'code': 0, 'data': data}));
      await expectLater(
        api.fetchVideo(_bvid),
        throwsA(error(BilibiliServiceError.invalidResponse)),
      );
    });
  }
  for (final data in [
    _data()..['title'] = 1,
    _data()..['title'] = '  ',
    _data()..['bvid'] = 'BV123',
    _data()..['owner'] = {'name': null},
    _data()..['owner'] = [],
    _data()..['pic'] = 'javascript:alert(1)',
    _data()..['pic'] = 'https://evil.example/cover.jpg',
    _data()..['pic'] = 'https://i0.hdslb.com.evil.example/cover.jpg',
    _data()..['pic'] = 'https://user@i0.hdslb.com/cover.jpg',
  ]) {
    test('非法核心数据 $data', () async {
      final api = service((_) async => _response({'code': 0, 'data': data}));
      await expectLater(
        api.fetchVideo(_bvid),
        throwsA(error(BilibiliServiceError.invalidResponse)),
      );
    });
  }
  for (final envelope in [
    null,
    [],
    'text',
    {'code': '0'},
    {'code': 0},
    {'code': 0, 'data': []},
  ]) {
    test('异常 JSON 结构 $envelope', () async {
      final api = service((_) async => _response(envelope));
      await expectLater(
        api.fetchVideo(_bvid),
        throwsA(error(BilibiliServiceError.invalidResponse)),
      );
    });
  }
  test('HTML 不泄漏 FormatException', () async {
    final api = service(
      (_) async => http.StreamedResponse(
        Stream.value(utf8.encode('<html>bad</html>')),
        200,
      ),
    );
    await expectLater(
      api.fetchVideo(_bvid),
      throwsA(error(BilibiliServiceError.invalidResponse)),
    );
  });
  for (final entry in {
    404: BilibiliServiceError.notFound,
    403: BilibiliServiceError.accessDenied,
    412: BilibiliServiceError.accessDenied,
    429: BilibiliServiceError.accessDenied,
    500: BilibiliServiceError.unavailable,
    302: BilibiliServiceError.unavailable,
  }.entries) {
    final status = entry.key;
    test('HTTP 状态 $status', () async {
      final api = service((_) async => _response(null, status: status));
      await expectLater(api.fetchVideo(_bvid), throwsA(error(entry.value)));
    });
  }
  for (final entry in {
    -404: BilibiliServiceError.notFound,
    -403: BilibiliServiceError.accessDenied,
    -412: BilibiliServiceError.accessDenied,
    -352: BilibiliServiceError.accessDenied,
    -101: BilibiliServiceError.unavailable,
    -99999: BilibiliServiceError.unavailable,
  }.entries) {
    final code = entry.key;
    test('API 状态 $code', () async {
      final api = service(
        (_) async => _response({'code': code, 'message': 'internal raw error'}),
      );
      await expectLater(api.fetchVideo(_bvid), throwsA(error(entry.value)));
    });
  }
  for (final exception in [
    http.ClientException('internal request failure'),
    const SocketException('internal socket error'),
    const HandshakeException('internal TLS error'),
  ]) {
    final type = exception.runtimeType;
    test('网络异常转换 $type', () async {
      final api = service((_) async => throw exception);
      await expectLater(
        api.fetchVideo(_bvid),
        throwsA(error(BilibiliServiceError.network)),
      );
    });
  }
  test('响应体大小受限制', () async {
    final api = service(
      (_) async => http.StreamedResponse(
        Stream.value(List.filled(2 * 1024 * 1024 + 1, 32)),
        200,
      ),
    );
    await expectLater(
      api.fetchVideo(_bvid),
      throwsA(error(BilibiliServiceError.invalidResponse)),
    );
  });
  test('Content-Length 超限立即取消读取', () async {
    final controller = StreamController<List<int>>();
    addTearDown(controller.close);
    final api = service(
      (_) async => http.StreamedResponse(
        controller.stream,
        200,
        contentLength: 3 * 1024 * 1024,
      ),
    );
    await expectLater(
      api.fetchVideo(_bvid),
      throwsA(error(BilibiliServiceError.invalidResponse)),
    );
  });
  test('请求头超时触发取消', () async {
    final cancelled = Completer<void>();
    final api = service((request) async {
      await (request as http.AbortableRequest).abortTrigger;
      cancelled.complete();
      throw http.RequestAbortedException();
    }, timeout: const Duration(milliseconds: 30));
    await expectLater(
      api.fetchVideo(_bvid),
      throwsA(error(BilibiliServiceError.timeout)),
    );
    await cancelled.future;
  });
  test('响应体读取也受总超时限制', () async {
    final cancelled = Completer<void>();
    final api = service((request) async {
      final controller = StreamController<List<int>>();
      unawaited(
        (request as http.AbortableRequest).abortTrigger!.then((_) {
          controller.addError(http.RequestAbortedException());
          cancelled.complete();
          return controller.close();
        }),
      );
      return http.StreamedResponse(controller.stream, 200);
    }, timeout: const Duration(milliseconds: 30));
    await expectLater(
      api.fetchVideo(_bvid),
      throwsA(error(BilibiliServiceError.timeout)),
    );
    await cancelled.future;
  });
  test('协议相对封面地址保留查询参数', () async {
    final data = _data()
      ..['pic'] = '//i0.hdslb.com/bfs/archive/a.jpg?token=abc';
    final api = service((_) async => _response({'code': 0, 'data': data}));
    expect(
      (await api.fetchVideo(_bvid)).coverUrl,
      'https://i0.hdslb.com/bfs/archive/a.jpg?token=abc',
    );
  });
  group('短链接', () {
    test('跳转后直接查询 API，不请求 HTML', () async {
      final hosts = <String>[];
      final api = service((request) async {
        hosts.add(request.url.host);
        if (request.url.host == 'b23.tv') {
          expect(request.followRedirects, isFalse);
          return _response(
            null,
            status: 302,
            headers: {
              'location': 'https://www.bilibili.com/video/$_bvid/?share=copy',
            },
          );
        }
        return _response({'code': 0, 'data': _data()});
      });
      expect((await api.fetchVideo('https://b23.tv/AbC1234')).bvid, _bvid);
      expect(hosts, ['b23.tv', 'api.bilibili.com']);
    });
    test('相对短链跳转和 AV 目标', () async {
      var count = 0;
      final api = service((request) async {
        count++;
        if (count == 1) {
          return _response(null, status: 307, headers: {'location': '/next'});
        }
        if (count == 2) {
          return _response(
            null,
            status: 302,
            headers: {'location': 'http://www.bilibili.com/video/av455017605/'},
          );
        }
        expect(request.url.queryParameters, {'aid': '455017605'});
        return _response({'code': 0, 'data': _data()});
      });
      expect((await api.fetchVideo('https://b23.tv/start')).bvid, _bvid);
      expect(count, 3);
    });
    for (final location in [
      'https://evil.example/video/$_bvid/',
      'https://www.bilibili.com.evil.example/video/$_bvid/',
      'https://user@www.bilibili.com/video/$_bvid/',
      'https://www.bilibili.com:8080/video/$_bvid/',
      'file:///video/$_bvid/',
      'https://www.bilibili.com/',
      'https://www.bilibili.com/video/BV123/',
    ]) {
      test('拒绝跳转 $location', () async {
        var count = 0;
        final api = service((_) async {
          count++;
          return _response(null, status: 302, headers: {'location': location});
        });
        await expectLater(
          api.fetchVideo('https://b23.tv/start'),
          throwsA(error(BilibiliServiceError.invalidShortLink)),
        );
        expect(count, 1);
      });
    }
    test('循环跳转停止', () async {
      var count = 0;
      final api = service((_) async {
        count++;
        return _response(null, status: 302, headers: {'location': '/start'});
      });
      await expectLater(
        api.fetchVideo('https://b23.tv/start'),
        throwsA(error(BilibiliServiceError.invalidShortLink)),
      );
      expect(count, 1);
    });
    test('最多请求五次短链跳转', () async {
      var count = 0;
      final api = service((_) async {
        count++;
        return _response(
          null,
          status: 302,
          headers: {'location': '/next$count'},
        );
      });
      await expectLater(
        api.fetchVideo('https://b23.tv/start'),
        throwsA(error(BilibiliServiceError.invalidShortLink)),
      );
      expect(count, 5);
    });
    for (final response in [
      _response(null, status: 302),
      _response(null, status: 302, headers: {'location': ''}),
      _response(null, status: 200),
    ]) {
      test('无有效 Location 或没有跳转', () async {
        final api = service((_) async => response);
        await expectLater(
          api.fetchVideo('https://b23.tv/start'),
          throwsA(error(BilibiliServiceError.invalidShortLink)),
        );
      });
    }
  });
  test('close 释放 client', () {
    final client = _Client((_) async => _response(null));
    BilibiliService(client: client).close();
    expect(client.closed, isTrue);
  });
}
