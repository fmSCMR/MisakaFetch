import 'package:misaka_fetch/models/video_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('核心信息与原始封面地址保持原样，次要字段可缺省', () {
    const cover = 'https://i0.hdslb.com/bfs/archive/example.png';
    const video = VideoInfo(
      title: '视频标题',
      bvid: 'BV1xx411c7mD',
      ownerName: 'UP 主',
      coverUrl: cover,
    );
    expect(video.title, '视频标题');
    expect(video.ownerName, 'UP 主');
    expect(video.coverUrl, cover);
    expect(
      video.videoUrl.toString(),
      'https://www.bilibili.com/video/BV1xx411c7mD/',
    );
    expect(video.aid, isNull);
    expect(video.publishedAt, isNull);
    expect(video.description, isNull);
  });
}
