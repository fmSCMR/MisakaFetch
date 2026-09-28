import 'dart:convert';

import '../models/app_settings.dart';

/// 按图片实际格式生成扩展名，标题截断时保留 BV 号用于识别视频。
String coverFilename(
  String title,
  String mimeType, {
  String? bvid,
  FilenameFormat format = FilenameFormat.title,
}) {
  final extension = switch (mimeType) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/gif' => 'gif',
    _ => throw ArgumentError.value(mimeType, 'mimeType', '不支持的图片格式'),
  };
  final includeBvid =
      bvid != null &&
      RegExp(r'^BV[1-9A-HJ-NP-Za-km-z]{10}$').hasMatch(bvid) &&
      format != FilenameFormat.title;
  final reserved = includeBvid ? bvid.length + 1 : 0;
  final stem = _safeStem(
    title,
    maxRunes: 100 - reserved,
    maxBytes: 240 - reserved,
  );
  final name = !includeBvid
      ? stem
      : format == FilenameFormat.bvidTitle
      ? '${bvid}_$stem'
      : '${stem}_$bvid';
  return '$name.$extension';
}

String _safeStem(String title, {required int maxRunes, required int maxBytes}) {
  var name = title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f\x7f]'), '_');
  name = name.trim().replaceAll(RegExp(r'[. ]+$'), '');
  if (name.isEmpty) name = 'MisakaFetch封面';
  if (RegExp(
    r'^(CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³])(?:\.|$)',
    caseSensitive: false,
  ).hasMatch(name)) {
    name = '_$name';
  }
  final runes = <int>[];
  var byteCount = 0;
  for (final rune in name.runes) {
    final size = utf8.encode(String.fromCharCode(rune)).length;
    if (runes.length == maxRunes || byteCount + size > maxBytes) break;
    runes.add(rune);
    byteCount += size;
  }
  name = String.fromCharCodes(runes).replaceAll(RegExp(r'[. ]+$'), '');
  return name.isEmpty ? 'MisakaFetch封面' : name;
}
