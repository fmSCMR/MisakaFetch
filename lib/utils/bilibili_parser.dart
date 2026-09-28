import '../models/bilibili_input.dart';

enum BilibiliParseError {
  emptyInput,
  unrecognizedInput,
  invalidBvid,
  invalidLink,
}

class BilibiliParseException implements Exception {
  const BilibiliParseException(this.code);
  final BilibiliParseError code;

  String get message => switch (code) {
    BilibiliParseError.emptyInput => '请先输入 Bilibili 视频链接或 BV 号。',
    BilibiliParseError.unrecognizedInput => '没有识别到有效的 Bilibili 视频链接或 BV 号。',
    BilibiliParseError.invalidBvid => 'BV 号格式不正确，请检查后重试。',
    BilibiliParseError.invalidLink => 'Bilibili 链接无效，请使用视频页面链接或 b23.tv 短链接。',
  };

  @override
  String toString() => message;
}

/// 纯文本解析，无网络请求。格式有效不代表视频存在或可访问。
class BilibiliParser {
  BilibiliParser._();

  // 同时识别第三方 URL，避免随后误提取其路径/查询里的 BV 号。
  static final _urls = RegExp(
    r'(?<![A-Za-z0-9_@./-])(?:[a-z][a-z0-9+.-]*://|//|(?:[a-z0-9-]+\.)+[a-z]{2,}/)[^\s<>\x22\x27“”‘’，。！？；、（）【】「」]+',
    caseSensitive: false,
  );
  static final _trailingPunctuation = RegExp(r'[)\]}>.,!?:;]+$');
  static final _bvidTokens = RegExp(
    r'(?<![A-Za-z0-9_])BV[A-Za-z0-9_]*(?![A-Za-z0-9_])',
    caseSensitive: false,
  );
  static final _validBvid = RegExp(r'^[Bb][Vv]1[A-Za-z0-9]{9}$');
  static final _shortToken = RegExp(r'^[A-Za-z0-9]{1,128}$');
  static final _aidToken = RegExp(r'^[Aa][Vv]([0-9]+)$');
  static const _videoHosts = {
    'bilibili.com',
    'www.bilibili.com',
    'm.bilibili.com',
  };

  /// 仅统一 BV 前缀，保留标识其余部分的大小写。
  static String? normalizeBvid(String value) {
    if (!_validBvid.hasMatch(value)) return null;
    return 'BV${value.substring(2)}';
  }

  /// 优先取第一个有效 Bilibili 链接，否则寻找独立 BV 号。
  static BilibiliInput parse(String text) {
    if (text.trim().isEmpty) {
      throw const BilibiliParseException(BilibiliParseError.emptyInput);
    }
    BilibiliParseException? firstError;
    for (final match in _urls.allMatches(text)) {
      try {
        final input = _parseUrl(match.group(0)!);
        if (input != null) return input;
      } on BilibiliParseException catch (error) {
        firstError ??= error;
      }
    }
    // URL 内的 BV 不可绕过协议、域名和路径验证。
    final remainingText = text.replaceAll(_urls, ' ');
    for (final match in _bvidTokens.allMatches(remainingText)) {
      final bvid = normalizeBvid(match.group(0)!);
      if (bvid != null) return BvidInput(bvid);
      firstError ??= const BilibiliParseException(
        BilibiliParseError.invalidBvid,
      );
    }
    throw firstError ??
        const BilibiliParseException(BilibiliParseError.unrecognizedInput);
  }

  static BilibiliInput? _parseUrl(String raw) {
    var value = raw.replaceFirst(_trailingPunctuation, '');
    if (value.startsWith('//')) {
      value = 'https:$value';
    } else if (!value.contains('://')) {
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null) {
      throw const BilibiliParseException(BilibiliParseError.invalidLink);
    }
    final host = uri.host.toLowerCase();
    if (!_videoHosts.contains(host) && host != 'b23.tv') return null;
    if ((uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
      throw const BilibiliParseException(BilibiliParseError.invalidLink);
    }

    late final List<String> segments;
    try {
      segments = uri.pathSegments.toList();
    } on FormatException {
      throw const BilibiliParseException(BilibiliParseError.invalidLink);
    }
    if (segments.isNotEmpty && segments.last.isEmpty) segments.removeLast();
    if (host == 'b23.tv') {
      if (segments.length != 1 || !_shortToken.hasMatch(segments.single)) {
        throw const BilibiliParseException(BilibiliParseError.invalidLink);
      }
      // 保留跳转可能需要的查询，移除片段并统一 HTTPS。
      return ShortLinkInput(
        Uri(
          scheme: 'https',
          host: 'b23.tv',
          pathSegments: segments,
          query: uri.hasQuery ? uri.query : null,
        ),
      );
    }
    // 标准视频页，以及移动端旧版 /s/video/ 路径。
    if (segments.length == 3 && segments.first == 's') segments.removeAt(0);
    if (segments.length != 2 || segments.first != 'video') {
      throw const BilibiliParseException(BilibiliParseError.invalidLink);
    }
    final token = segments.last;
    final bvid = normalizeBvid(token);
    if (bvid != null) return BvidInput(bvid);
    if (token.toLowerCase().startsWith('bv')) {
      throw const BilibiliParseException(BilibiliParseError.invalidBvid);
    }
    final aidMatch = _aidToken.firstMatch(token);
    final aid = aidMatch == null ? null : int.tryParse(aidMatch.group(1)!);
    if (aid != null && aid > 0) return AidInput(aid);
    throw const BilibiliParseException(BilibiliParseError.invalidLink);
  }
}
