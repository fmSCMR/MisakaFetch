import 'package:misaka_fetch/models/bilibili_input.dart';
import 'package:misaka_fetch/utils/bilibili_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bvid = 'BV1xx411c7mD';
  Matcher parseError(BilibiliParseError code) =>
      isA<BilibiliParseException>().having((e) => e.code, 'code', code);

  group('BV 与分享文本', () {
    for (final input in [
      bvid,
      ' \n$bvid\t ',
      'bv1xx411c7mD',
      '推荐视频【$bvid】，快来看看！',
      '视频 BV号：$bvid',
    ]) {
      test(input, () {
        final parsed = BilibiliParser.parse(input) as BvidInput;
        expect(parsed.bvid, bvid);
        expect(
          parsed.videoUrl.toString(),
          'https://www.bilibili.com/video/$bvid/',
        );
      });
    }
    test('不改变主体大小写', () {
      expect(BilibiliParser.normalizeBvid('bv1Xx411c7mD'), 'BV1Xx411c7mD');
    });
    test('不截断更长的 BV', () {
      expect(
        () => BilibiliParser.parse('${bvid}extra'),
        throwsA(parseError(BilibiliParseError.invalidBvid)),
      );
    });
    for (final invalid in [
      'BV',
      'BV123',
      'BV2xx411c7mD',
      'BV1xx411c7m_',
      'BV1xx411c7m',
    ]) {
      test('错误 BV：$invalid', () {
        expect(
          () => BilibiliParser.parse(invalid),
          throwsA(parseError(BilibiliParseError.invalidBvid)),
        );
      });
    }
  });

  group('视频链接', () {
    for (final input in [
      'https://www.bilibili.com/video/$bvid/',
      'http://www.bilibili.com/video/$bvid',
      'https://bilibili.com/video/$bvid/?p=2&share_source=copy#reply',
      'https://m.bilibili.com/video/$bvid/',
      'https://m.bilibili.com/s/video/$bvid/',
      'www.bilibili.com/video/$bvid/',
      '//www.bilibili.com/video/$bvid/',
      'HTTPS://WWW.BILIBILI.COM/video/$bvid/',
      'https://www.bilibili.com:443/video/$bvid/',
      'https://www.bilibili.com/video/%42%561xx411c7mD/',
      '【分享标题】 https://www.bilibili.com/video/$bvid/。来自哔哩哔哩',
      '(https://www.bilibili.com/video/$bvid/).',
      "'https://www.bilibili.com/video/$bvid/'",
    ]) {
      test(input, () {
        expect((BilibiliParser.parse(input) as BvidInput).bvid, bvid);
      });
    }
    test('旧版 AV 视频链接', () {
      expect(
        (BilibiliParser.parse(
          'https://www.bilibili.com/video/av170001/',
        ) as AidInput).aid,
        170001,
      );
    });
    test('优先视频链接，不误选标题中的 BV', () {
      final input = '对比 BV1Q541167Qg：https://www.bilibili.com/video/$bvid/';
      expect((BilibiliParser.parse(input) as BvidInput).bvid, bvid);
    });
    test('跳过无效链接寻找后面的有效链接', () {
      final input =
          'https://www.bilibili.com/video/BV123/ '
          'https://www.bilibili.com/video/$bvid/';
      expect((BilibiliParser.parse(input) as BvidInput).bvid, bvid);
    });
    test('多个有效链接取第一个', () {
      final input =
          'https://www.bilibili.com/video/$bvid/ '
          'https://www.bilibili.com/video/BV1Q541167Qg/';
      expect((BilibiliParser.parse(input) as BvidInput).bvid, bvid);
    });
    test('链接中 BV 格式错误', () {
      expect(
        () => BilibiliParser.parse('https://www.bilibili.com/video/BV123/'),
        throwsA(parseError(BilibiliParseError.invalidBvid)),
      );
    });
    for (final invalid in [
      'https://www.bilibili.com/',
      'https://www.bilibili.com/video/',
      'https://www.bilibili.com/video/av0/',
      'https://www.bilibili.com/video/av99999999999999999999999999/',
      'https://www.bilibili.com/video/$bvid/other',
      'https://www.bilibili.com/video/%FF/',
      'ftp://www.bilibili.com/video/$bvid/',
      'https://user@www.bilibili.com/video/$bvid/',
      'https://www.bilibili.com:8080/video/$bvid/',
      'https://www.bilibili.com/?bvid=$bvid',
    ]) {
      test('无效链接：$invalid', () {
        expect(
          () => BilibiliParser.parse(invalid),
          throwsA(parseError(BilibiliParseError.invalidLink)),
        );
      });
    }
  });

  group('短链接', () {
    for (final input in [
      'https://b23.tv/AbC1234',
      'b23.tv/AbC1234',
      '【标题】 https://b23.tv/AbC1234。来自哔哩哔哩',
      'http://B23.TV:80/AbC1234',
    ]) {
      test(input, () {
        final parsed = BilibiliParser.parse(input) as ShortLinkInput;
        expect(parsed.url.toString(), 'https://b23.tv/AbC1234');
      });
    }
    test('保留查询，去除片段', () {
      final parsed = BilibiliParser.parse(
        'https://b23.tv/AbC1234?share_source=copy#fragment',
      ) as ShortLinkInput;
      expect(parsed.url.toString(), 'https://b23.tv/AbC1234?share_source=copy');
    });
    test('BV 短链接也是待跳转结果', () {
      expect(
        BilibiliParser.parse('https://b23.tv/$bvid'),
        isA<ShortLinkInput>(),
      );
    });
    for (final invalid in [
      'https://b23.tv/',
      'https://b23.tv/foo/bar',
      'https://b23.tv/%2F',
      'https://b23.tv/a-b',
      'https://b23.tv:8080/abc',
    ]) {
      test('无效短链接：$invalid', () {
        expect(
          () => BilibiliParser.parse(invalid),
          throwsA(parseError(BilibiliParseError.invalidLink)),
        );
      });
    }
  });

  group('不识别无关地址或伪装域名中的 BV', () {
    for (final invalid in [
      '没有视频地址',
      'prefix${bvid}suffix',
      'https://example.com/video/$bvid/',
      'example.com/video/$bvid/',
      'https://www.bilibili.com.evil.example/video/$bvid/',
      'https://evil.example/?next=https://www.bilibili.com/video/$bvid/',
      'https://www.bilibili.com@evil.example/video/$bvid/',
      'https://evilbilibili.com/video/$bvid/',
      'https://space.bilibili.com/123?bvid=$bvid',
    ]) {
      test(invalid, () {
        expect(
          () => BilibiliParser.parse(invalid),
          throwsA(parseError(BilibiliParseError.unrecognizedInput)),
        );
      });
    }
    test('第三方 URL 后独立 BV 仍可用', () {
      expect(
        (BilibiliParser.parse('https://example.com/ $bvid') as BvidInput).bvid,
        bvid,
      );
    });
    for (final empty in ['', ' \t\n']) {
      test('空输入', () {
        expect(
          () => BilibiliParser.parse(empty),
          throwsA(parseError(BilibiliParseError.emptyInput)),
        );
      });
    }
    test('错误消息适合用户阅读', () {
      const error = BilibiliParseException(
        BilibiliParseError.unrecognizedInput,
      );
      expect(error.message, '没有识别到有效的 Bilibili 视频链接或 BV 号。');
      expect(error.toString(), error.message);
    });
  });
}
