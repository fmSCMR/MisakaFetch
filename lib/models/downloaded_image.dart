import 'dart:typed_data';

/// 下载的原始图片字节。预览与后续保存共用，不进行重新编码。
class DownloadedImage {
  const DownloadedImage({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}
