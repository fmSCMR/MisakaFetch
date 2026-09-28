import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class BackgroundImageException implements Exception {
  const BackgroundImageException(this.message);
  final String message;
}

/// 管理应用私有目录中的背景副本，删除时校验目录和文件名。
/// 选择器可能返回临时文件，导入时复制以保证下次启动仍可读取。
class BackgroundImageService {
  BackgroundImageService({
    Future<Directory> Function()? supportDirectory,
    Future<XFile?> Function()? picker,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _picker = picker ?? _pick;

  final Future<Directory> Function() _supportDirectory;
  final Future<XFile?> Function() _picker;
  static const maxBytes = 20 * 1024 * 1024;
  static final _managedName = RegExp(
    r'^background_[0-9]+_[0-9a-f]+\.(jpg|png|webp)$',
  );

  static Future<XFile?> _pick() => openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: '背景图片',
        extensions: ['jpg', 'jpeg', 'png', 'webp'],
        mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
      ),
    ],
  );

  Future<Directory> _directory() async {
    final support = await _supportDirectory();
    return Directory.fromUri(support.uri.resolve('backgrounds/'));
  }

  Future<String?> chooseAndImport() async {
    File? target;
    try {
      final selected = await _picker();
      if (selected == null) return null;
      final length = await selected.length();
      if (length <= 0 || length > maxBytes) {
        throw const BackgroundImageException('请选择不超过 20 MB 的背景图片。');
      }
      final bytes = await selected.readAsBytes();
      if (bytes.length > maxBytes) {
        throw const BackgroundImageException('请选择不超过 20 MB 的背景图片。');
      }
      final extension = _extension(bytes);
      if (extension == null) {
        throw const BackgroundImageException('请选择 JPG、PNG 或 WebP 格式的图片。');
      }
      await _validate(bytes);
      final directory = await _directory();
      await directory.create(recursive: true);
      final token = Random.secure().nextInt(0x7fffffff).toRadixString(16);
      target = File.fromUri(
        directory.uri.resolve(
          'background_${DateTime.now().microsecondsSinceEpoch}_$token.$extension',
        ),
      );
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (error, stack) {
      if (target != null) await remove(target.path);
      _log(error, stack);
      if (error is BackgroundImageException) rethrow;
      throw const BackgroundImageException('背景图片未能导入，请检查图片和可用存储空间后重试。');
    }
  }

  static String? _extension(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71 &&
        bytes[4] == 13 &&
        bytes[5] == 10 &&
        bytes[6] == 26 &&
        bytes[7] == 10) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'jpg';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
      return 'webp';
    }
    return null;
  }

  static Future<void> _validate(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width * descriptor.height > 40000000) {
        throw const BackgroundImageException('图片尺寸过大，请选择不超过 4000 万像素的图片。');
      }
      codec = await descriptor.instantiateCodec(
        targetWidth: min(1920, descriptor.width),
      );
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  Future<bool> _owns(File file) async {
    if (!_managedName.hasMatch(file.uri.pathSegments.last)) return false;
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return false;
    }
    final directory = await _directory();
    if (!await directory.exists()) return false;
    // 解析真实父目录，避免通过相对路径或符号链接误删目录外的文件。
    return await file.parent.resolveSymbolicLinks() ==
        await directory.resolveSymbolicLinks();
  }

  Future<bool> isUsable(String path) async {
    try {
      final file = File(path);
      if (!await _owns(file)) return false;
      final length = await file.length();
      if (length <= 0 || length > maxBytes) return false;
      final bytes = await file.readAsBytes();
      if (_extension(bytes) == null) return false;
      await _validate(bytes);
      return true;
    } catch (error, stack) {
      _log(error, stack);
      return false;
    }
  }

  /// 删除导入的背景副本；路径检查用于区分应用副本与用户原图。
  Future<bool> remove(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return true;
      if (!await _owns(file)) return false;
      await file.delete();
      return true;
    } catch (error, stack) {
      _log(error, stack);
      return false;
    }
  }

  static void _log(Object error, StackTrace stack) {
    if (kDebugMode) {
      developer.log(
        'Background operation failed',
        name: 'MisakaFetch',
        error: error,
        stackTrace: stack,
      );
    }
  }
}
