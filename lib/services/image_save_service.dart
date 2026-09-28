import 'dart:developer' as developer;
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../models/downloaded_image.dart';
import '../utils/filename_utils.dart';

typedef SaveLocationPicker = Future<String?> Function(
  String filename,
  String extension,
);
typedef ImageFileWriter = Future<void> Function(String path, Uint8List bytes);

enum ImageSavePlatform { windows, android, unsupported }

class ImageSaveException implements Exception {
  const ImageSaveException(this.message);
  final String message;
}

/// 保存图片原始字节；按平台选择 Windows 文件路径或 Android 媒体存储。
class ImageSaveService {
  ImageSaveService({
    this.pickLocation,
    ImageFileWriter? writeFile,
    ImageSavePlatform? platform,
    this.androidChannel = const MethodChannel('misakafetch/image_save'),
  }) : _writeFile = writeFile ?? _writeOriginal,
       _platform =
           platform ??
           (Platform.isWindows
               ? ImageSavePlatform.windows
               : Platform.isAndroid
               ? ImageSavePlatform.android
               : ImageSavePlatform.unsupported);
  final SaveLocationPicker? pickLocation;
  final ImageFileWriter _writeFile;
  final ImageSavePlatform _platform;
  final MethodChannel androidChannel;
  bool get isSupported => _platform != ImageSavePlatform.unsupported;

  /// 取消选择返回 null；未提供 BV 号时使用标题命名。
  Future<String?> save(
    DownloadedImage image,
    String title, {
    String? bvid,
    AppSettings settings = const AppSettings(),
  }) async {
    if (!isSupported) throw const ImageSaveException('当前平台暂未支持保存原图。');
    try {
      if (image.bytes.isEmpty) throw const ImageSaveException('图片数据为空，请重新提取。');
      final filename = coverFilename(
        title,
        image.mimeType,
        bvid: bvid,
        format: settings.filenameFormat,
      );
      if (_platform == ImageSavePlatform.android) {
        final location = await androidChannel.invokeMethod<String>(
          'saveImage',
          {
            'bytes': image.bytes,
            'mimeType': image.mimeType,
            'filename': filename,
          },
        );
        if (location != null && location.trim().isEmpty) {
          throw const ImageSaveException('保存失败，系统没有返回保存结果。');
        }
        return location;
      }
      if (!settings.askSaveLocation) {
        final directory = settings.defaultSaveDirectory;
        if (directory == null || !await Directory(directory).exists()) {
          throw const ImageSaveException('默认保存目录不可用，请在设置中重新选择目录或开启询问保存位置。');
        }
        return await _saveInDirectory(directory, filename, image.bytes);
      }
      final extension = filename.split('.').last;
      final picker = pickLocation;
      final path = picker != null
          ? await picker(filename, extension)
          : await _windowsLocation(
              filename,
              extension,
              settings.defaultSaveDirectory,
            );
      if (path == null) return null;
      await _writeFile(path, image.bytes);
      return path;
    } on ImageSaveException {
      rethrow;
    } catch (error, stack) {
      _log(error, stack);
      throw const ImageSaveException('保存失败，请检查保存位置是否可写以及磁盘剩余空间。');
    }
  }

  Future<String> _saveInDirectory(
    String directory,
    String filename,
    Uint8List bytes,
  ) async {
    final folder = Directory(directory);
    final dot = filename.lastIndexOf('.');
    for (var index = 0; index < 1000; index++) {
      final candidate = index == 0
          ? filename
          : '${filename.substring(0, dot)} ($index)${filename.substring(dot)}';
      final target = File.fromUri(
        folder.uri.resolve(Uri.encodeComponent(candidate)),
      );
      try {
        // 排他创建把重名检查与占位合为一步，避免并发保存时覆盖已有文件。
        await target.create(exclusive: true);
      } on FileSystemException {
        if (await FileSystemEntity.type(target.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          continue;
        }
        rethrow;
      }
      try {
        await _writeFile(target.path, bytes);
        return target.path;
      } catch (error, stack) {
        try {
          await target.delete();
        } catch (cleanupError, cleanupStack) {
          _log(cleanupError, cleanupStack);
        }
        Error.throwWithStackTrace(error, stack);
      }
    }
    throw const ImageSaveException('同名文件过多，请更换保存目录或文件名格式。');
  }

  static Future<String?> _windowsLocation(
    String filename,
    String extension,
    String? directory,
  ) async {
    final initialDirectory =
        directory != null && await Directory(directory).exists()
        ? directory
        : null;
    final location = await getSaveLocation(
      suggestedName: filename,
      initialDirectory: initialDirectory,
      acceptedTypeGroups: [
        XTypeGroup(label: '原始封面图片', extensions: [extension]),
      ],
    );
    return location?.path;
  }

  static Future<void> _writeOriginal(String path, Uint8List bytes) async {
    await File(path).writeAsBytes(bytes, flush: true);
  }

  static void _log(Object error, StackTrace stack) {
    if (kDebugMode) {
      developer.log(
        'Saving original image failed',
        name: 'MisakaFetch',
        error: error,
        stackTrace: stack,
      );
    }
  }
}
