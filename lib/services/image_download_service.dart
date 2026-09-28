import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/downloaded_image.dart';

enum ImageDownloadError { timeout, network, downloadFailed, invalidImage }

class ImageDownloadException implements Exception {
  const ImageDownloadException(this.code);
  final ImageDownloadError code;

  String get message => switch (code) {
    ImageDownloadError.timeout => '封面下载超时，请重试。',
    ImageDownloadError.network => '无法下载封面，请检查网络连接后重试。',
    ImageDownloadError.downloadFailed => '封面下载失败，请稍后重试。',
    ImageDownloadError.invalidImage => '返回的封面不是支持的图片或文件过大。',
  };

  @override
  String toString() => message;
}

class ImageDownloadService {
  /// 使用完毕调用 close；注入的 client 也由本 service 释放。
  ImageDownloadService({
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;
  static const _maxBytes = 20 * 1024 * 1024;
  static const _imageTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  };

  Future<DownloadedImage> download(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443)) {
      throw const ImageDownloadException(ImageDownloadError.invalidImage);
    }
    final abort = Completer<void>();
    try {
      return await _download(uri, abort.future).timeout(
        timeout,
        onTimeout: () {
          if (!abort.isCompleted) abort.complete();
          throw const ImageDownloadException(ImageDownloadError.timeout);
        },
      );
    } on ImageDownloadException {
      rethrow;
    } on TimeoutException catch (error, stack) {
      _log(error, stack);
      throw const ImageDownloadException(ImageDownloadError.timeout);
    } on http.ClientException catch (error, stack) {
      _log(error, stack);
      throw const ImageDownloadException(ImageDownloadError.network);
    } on IOException catch (error, stack) {
      _log(error, stack);
      throw const ImageDownloadException(ImageDownloadError.network);
    } finally {
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<DownloadedImage> _download(Uri url, Future<void> abort) async {
    final request = http.AbortableRequest('GET', url, abortTrigger: abort)
      ..followRedirects = false
      ..headers.addAll({
        'User-Agent': 'MisakaFetch/0.1 (public video cover metadata)',
        'Referer': 'https://www.bilibili.com/',
        'Accept': 'image/jpeg,image/png,image/webp,image/gif',
      });
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      await response.stream.listen((_) {}).cancel();
      throw const ImageDownloadException(ImageDownloadError.downloadFailed);
    }
    final mimeType = response.headers['content-type']
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    if (!_imageTypes.contains(mimeType) ||
        (response.contentLength ?? 0) > _maxBytes) {
      await response.stream.listen((_) {}).cancel();
      throw const ImageDownloadException(ImageDownloadError.invalidImage);
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      bytes.add(chunk);
      if (bytes.length > _maxBytes) {
        throw const ImageDownloadException(ImageDownloadError.invalidImage);
      }
    }
    if (bytes.isEmpty) {
      throw const ImageDownloadException(ImageDownloadError.invalidImage);
    }
    return DownloadedImage(bytes: bytes.takeBytes(), mimeType: mimeType!);
  }

  static void _log(Object error, StackTrace stack) {
    if (!const bool.fromEnvironment('dart.vm.product')) {
      developer.log(
        'Cover download failed',
        name: 'MisakaFetch',
        error: error,
        stackTrace: stack,
      );
    }
  }

  void close() => _client.close();
}
