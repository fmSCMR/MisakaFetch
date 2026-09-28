/// 本地识别结果。短链接的网络跳转由 service 完成。
sealed class BilibiliInput {
  const BilibiliInput();
}

final class BvidInput extends BilibiliInput {
  const BvidInput(this.bvid);
  final String bvid;
  Uri get videoUrl => Uri.https('www.bilibili.com', '/video/$bvid/');
}

/// 兼容旧版视频链接，由 service 使用 aid 查询，无需本地转换算法。
final class AidInput extends BilibiliInput {
  const AidInput(this.aid);
  final int aid;
}

final class ShortLinkInput extends BilibiliInput {
  const ShortLinkInput(this.url);
  final Uri url;
}
