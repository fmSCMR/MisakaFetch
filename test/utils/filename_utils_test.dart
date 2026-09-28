import 'dart:convert';

import 'package:misaka_fetch/utils/filename_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('保留中文，清理路径和非法字符', () {
    expect(
      coverFilename(' 标题: /\\<>"|?*\x00. ', 'image/jpeg'),
      '标题_ _________.jpg',
    );
  });
  for (final title in ['CON', 'nul.txt', 'COM1', 'lpt9', 'COM¹']) {
    test('处理设备名 $title', () {
      expect(coverFilename(title, 'image/png'), '_$title.png');
    });
  }
  test('空标题和末尾句点', () {
    expect(coverFilename(' ... ', 'image/png'), 'MisakaFetch封面.png');
    expect(coverFilename('标题... ', 'image/gif'), '标题.gif');
  });
  test('扩展名对应真实格式', () {
    expect(coverFilename('图', 'image/webp'), '图.webp');
    expect(() => coverFilename('图', 'image/svg+xml'), throwsArgumentError);
  });
  test('长标题按码点截断', () {
    final filename = coverFilename(List.filled(120, '😀').join(), 'image/jpeg');
    expect(filename, '${List.filled(60, '😀').join()}.jpg');
  });
  test('长中文标题遵守 Android UTF-8 文件名限制', () {
    final filename = coverFilename(List.filled(120, '封').join(), 'image/webp');
    expect(filename, '${List.filled(80, '封').join()}.webp');
    expect(utf8.encode(filename).length, lessThanOrEqualTo(255));
  });
  test('截断后只剩句点时使用默认文件名', () {
    expect(
      coverFilename('${List.filled(101, '.').join()}标题', 'image/png'),
      'MisakaFetch封面.png',
    );
  });
}
