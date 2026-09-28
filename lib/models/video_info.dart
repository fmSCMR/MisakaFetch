/// 视频公开信息。由 service 验证后构造，UI 不直接读取 API JSON。
class VideoInfo {
  const VideoInfo({
    required this.title,
    required this.bvid,
    required this.ownerName,
    required this.coverUrl,
    this.aid,
    this.publishedAt,
    this.description,
  });

  final String title;
  final String bvid;
  final String ownerName;

  /// API 提供的原始地址，不添加缩放、裁剪或压缩参数。
  final String coverUrl;
  final int? aid;
  final DateTime? publishedAt;
  final String? description;

  Uri get videoUrl => Uri.https('www.bilibili.com', '/video/$bvid/');
}
