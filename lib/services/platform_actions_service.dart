import 'dart:developer' as developer;
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class PlatformActionException implements Exception {
  const PlatformActionException(this.message);
  final String message;
}

class PlatformActionsService {
  static const projectUrl = 'https://github.com/gfang6530-gif/MisakaFetch';

  Future<void> openProject() async {
    try {
      // 直接尝试打开并处理失败，避免 Android 包可见性查询造成误判。
      final opened = await launchUrl(
        Uri.parse(projectUrl),
        mode: LaunchMode.externalApplication,
      ).timeout(const Duration(seconds: 10));
      if (!opened) throw StateError('No application opened the project URL');
    } catch (error, stack) {
      _log(error, stack);
      throw const PlatformActionException('无法打开浏览器，请复制项目地址后手动打开。');
    }
  }

  Future<String?> chooseDirectory(String? current) async {
    try {
      final initial = current != null && await Directory(current).exists()
          ? current
          : null;
      final selected = await getDirectoryPath(
        initialDirectory: initial,
        confirmButtonText: '选择保存目录',
      );
      if (selected != null && !await Directory(selected).exists()) {
        throw const PlatformActionException('所选目录不可用，请重新选择。');
      }
      return selected;
    } on PlatformActionException {
      rethrow;
    } catch (error, stack) {
      _log(error, stack);
      throw const PlatformActionException('未能选择保存目录，请重试。');
    }
  }

  Future<void> openSavedFolder(String path) async {
    try {
      if (!Platform.isWindows) throw UnsupportedError('Windows only');
      final directory = File(path).absolute.parent;
      if (!await directory.exists()) {
        throw const FileSystemException('Missing folder');
      }
      // 目录作为独立参数传给资源管理器，空格和特殊字符不会被解释成命令。
      await Process.start('explorer.exe', [
        directory.path,
      ], mode: ProcessStartMode.detached);
    } catch (error, stack) {
      _log(error, stack);
      throw const PlatformActionException('原图已保存，但文件夹未能打开。');
    }
  }

  static void _log(Object error, StackTrace stack) {
    if (kDebugMode) {
      developer.log(
        'Platform action failed',
        name: 'MisakaFetch',
        error: error,
        stackTrace: stack,
      );
    }
  }
}
