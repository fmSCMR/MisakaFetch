import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/bilibili_input.dart';
import '../models/video_info.dart';
import '../utils/bilibili_parser.dart';

enum BilibiliServiceError {
  timeout,
  network,
  notFound,
  unavailable,
  accessDenied,
  invalidResponse,
  invalidShortLink,
}

class BilibiliServiceException implements Exception {
  const BilibiliServiceException(this.code);
  final BilibiliServiceError code;

  String get message => switch (code) {
    BilibiliServiceError.timeout => '请求超时，请稍后重试。',
    BilibiliServiceError.network => '无法连接网络，请检查网络连接后重试。',
    BilibiliServiceError.notFound => '视频不存在或已被删除。',
    BilibiliServiceError.unavailable => '视频暂时无法访问，可能受访问限制，请稍后重试。',
    BilibiliServiceError.accessDenied => 'Bilibili 暂时拒绝了请求，请稍后重试。',
    BilibiliServiceError.invalidResponse => 'Bilibili 返回的信息不完整或格式异常，请稍后重试。',
    BilibiliServiceError.invalidShortLink => '短链接无法解析，请试用完整视频链接或 BV 号。',
  };

  @override
  String toString() => message;
}

/// 仅查询官方公开 Web 接口，无登录、Cookie、第三方解析服务或 HTML 解析。
///
/// /x/web-interface/view 是网站使用的公开接口，并非对第三方保证稳定的
/// 开放 API。接口、JSON 映射与跳转策略均集中在本文件中维护。
class BilibiliService {
  /// service 拥有 client；使用完毕（包括注入测试 client）后调用 close。
  BilibiliService({
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;
  static const _maxRedirects = 5;
  static const _maxResponseBytes = 2 * 1024 * 1024;
  static const _headers = {
    'User-Agent': 'MisakaFetch/0.1 (public video cover metadata)',
    'Referer': 'https://www.bilibili.com/',
    'Accept': 'application/json',
  };
  static const _redirectCodes = {301, 302, 303, 307, 308};
  static const _allowedHosts = {
    'b23.tv',
    'bilibili.com',
    'www.bilibili.com',
    'm.bilibili.com',
  };

  /// 总超时覆盖全部短链跳转、API 请求和响应体读取，并取消正在进行的请求。
  Future<VideoInfo> fetchVideo(String text) async {
    final input = BilibiliParser.parse(text);
    final abort = Completer<void>();
    try {
      return await _fetch(input, abort.future).timeout(
        timeout,
        onTimeout: () {
          if (!abort.isCompleted) abort.complete();
          throw const BilibiliServiceException(BilibiliServiceError.timeout);
        },
      );
    } on BilibiliServiceException {
      rethrow;
    } on TimeoutException catch (error, stack) {
      _log(error, stack);
      throw const BilibiliServiceException(BilibiliServiceError.timeout);
    } on http.ClientException catch (error, stack) {
      _log(error, stack);
      throw const BilibiliServiceException(BilibiliServiceError.network);
    } on IOException catch (error, stack) {
      _log(error, stack);
      throw const BilibiliServiceException(BilibiliServiceError.network);
    } on FormatException catch (error, stack) {
      _log(error, stack);
      throw const BilibiliServiceException(
        BilibiliServiceError.invalidResponse,
      );
    } finally {
      // 出错或完成后释放仍在进行的响应，不影响下一次请求。
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<VideoInfo> _fetch(BilibiliInput input, Future<void> abort) async {
    final resolved = input is ShortLinkInput
        ? await _resolveShortLink(input.url, abort)
        : input;
    final parameters = switch (resolved) {
      BvidInput(:final bvid) => {'bvid': bvid},
      AidInput(:final aid) => {'aid': aid.toString()},
      ShortLinkInput() => throw const BilibiliServiceException(
        BilibiliServiceError.invalidShortLink,
      ),
    };
    final url = Uri.https(
      'api.bilibili.com',
      '/x/web-interface/view',
      parameters,
    );
    final response = await _send(url, abort);
    if (response.statusCode != 200) {
      await _discard(response);
      throw BilibiliServiceException(_statusError(response.statusCode));
    }
    final bytes = BytesBuilder(copy: false);
    if ((response.contentLength ?? 0) > _maxResponseBytes) {
      await _discard(response);
      throw const BilibiliServiceException(
        BilibiliServiceError.invalidResponse,
      );
    }
    await for (final chunk in response.stream) {
      bytes.add(chunk);
      if (bytes.length > _maxResponseBytes) {
        throw const BilibiliServiceException(
          BilibiliServiceError.invalidResponse,
        );
      }
    }
    final json = jsonDecode(utf8.decode(bytes.takeBytes()));
    return _videoFromResponse(json, resolved);
  }

  Future<http.StreamedResponse> _send(Uri url, Future<void> abort) {
    final request = http.AbortableRequest('GET', url, abortTrigger: abort)
      ..followRedirects = false
      ..headers.addAll(_headers);
    return _client.send(request);
  }

  Future<BilibiliInput> _resolveShortLink(
    Uri initial,
    Future<void> abort,
  ) async {
    var current = initial;
    final visited = <Uri>{};
    for (var hops = 0; hops < _maxRedirects; hops++) {
      if (!visited.add(current)) {
        throw const BilibiliServiceException(
          BilibiliServiceError.invalidShortLink,
        );
      }
      final response = await _send(current, abort);
      final location = response.headers['location'];
      await _discard(response);
      if (!_redirectCodes.contains(response.statusCode)) {
        if (response.statusCode >= 400) {
          throw BilibiliServiceException(_statusError(response.statusCode));
        }
        throw const BilibiliServiceException(
          BilibiliServiceError.invalidShortLink,
        );
      }
      if (location == null || location.trim().isEmpty) {
        throw const BilibiliServiceException(
          BilibiliServiceError.invalidShortLink,
        );
      }
      late final Uri next;
      late final BilibiliInput parsed;
      try {
        next = current.resolve(location);
        if (!_allowedHosts.contains(next.host.toLowerCase()) ||
            (next.scheme != 'http' && next.scheme != 'https') ||
            next.userInfo.isNotEmpty ||
            (next.hasPort &&
                next.port != (next.scheme == 'https' ? 443 : 80))) {
          throw const BilibiliServiceException(
            BilibiliServiceError.invalidShortLink,
          );
        }
        parsed = BilibiliParser.parse(next.toString());
      } on FormatException {
        throw const BilibiliServiceException(
          BilibiliServiceError.invalidShortLink,
        );
      } on BilibiliParseException {
        throw const BilibiliServiceException(
          BilibiliServiceError.invalidShortLink,
        );
      }
      if (parsed is! ShortLinkInput) return parsed;
      current = parsed.url;
    }
    throw const BilibiliServiceException(BilibiliServiceError.invalidShortLink);
  }

  static Future<void> _discard(http.StreamedResponse response) =>
      response.stream.listen((_) {}).cancel();

  static BilibiliServiceError _statusError(int status) => switch (status) {
    404 => BilibiliServiceError.notFound,
    401 || 403 || 412 || 429 => BilibiliServiceError.accessDenied,
    _ => BilibiliServiceError.unavailable,
  };

  static VideoInfo _videoFromResponse(dynamic json, BilibiliInput requested) {
    const invalid = BilibiliServiceException(
      BilibiliServiceError.invalidResponse,
    );
    if (json is! Map<String, dynamic> || json['code'] is! int) throw invalid;
    final code = json['code'] as int;
    if (code != 0) {
      if (!const bool.fromEnvironment('dart.vm.product')) {
        developer.log('Video API code: $code', name: 'MisakaFetch');
      }
      throw BilibiliServiceException(switch (code) {
        -404 => BilibiliServiceError.notFound,
        -403 || -412 || -352 => BilibiliServiceError.accessDenied,
        _ => BilibiliServiceError.unavailable,
      });
    }
    final data = json['data'];
    if (data is! Map<String, dynamic>) throw invalid;
    final title = _nonEmptyString(data['title']);
    final rawBvid = _nonEmptyString(data['bvid']);
    final bvid = rawBvid == null ? null : BilibiliParser.normalizeBvid(rawBvid);
    final owner = data['owner'];
    final ownerName = owner is Map<String, dynamic>
        ? _nonEmptyString(owner['name'])
        : null;
    final coverUrl = _coverUrl(data['pic']);
    if (title == null ||
        bvid == null ||
        ownerName == null ||
        coverUrl == null) {
      throw invalid;
    }
    final aid = data['aid'] is int && (data['aid'] as int) > 0
        ? data['aid'] as int
        : null;
    if ((requested is BvidInput && bvid != requested.bvid) ||
        (requested is AidInput && aid != requested.aid)) {
      throw invalid;
    }
    return VideoInfo(
      title: title,
      bvid: bvid,
      ownerName: ownerName,
      coverUrl: coverUrl,
      aid: aid,
      publishedAt: _publishedAt(data['pubdate']),
      description: data['desc'] is String ? data['desc'] as String : null,
    );
  }

  static String? _nonEmptyString(dynamic value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static String? _coverUrl(dynamic value) {
    final text = _nonEmptyString(value);
    if (text == null) return null;
    final uri = Uri.tryParse(text.startsWith('//') ? 'https:$text' : text);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) ||
        uri.path.isEmpty ||
        !(uri.host == 'hdslb.com' ||
            uri.host.endsWith('.hdslb.com') ||
            uri.host == 'biliimg.com' ||
            uri.host.endsWith('.biliimg.com'))) {
      return null;
    }
    // 原始图片路径和查询不变，仅将官方图片 CDN 的 HTTP 升级为 HTTPS。
    return uri.scheme == 'http'
        ? uri.replace(scheme: 'https').toString()
        : uri.toString();
  }

  static DateTime? _publishedAt(dynamic value) {
    // 次要字段异常不影响封面提取；避免时间戳超出 DateTime 可表示范围。
    if (value is! int || value <= 0 || value > 253402300799) return null;
    return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
  }

  static void _log(Object error, StackTrace stack) {
    if (!const bool.fromEnvironment('dart.vm.product')) {
      developer.log(
        'Public video request failed',
        name: 'MisakaFetch',
        error: error,
        stackTrace: stack,
      );
    }
  }

  void close() => _client.close();
}
