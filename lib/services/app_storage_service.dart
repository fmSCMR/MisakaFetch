import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Windows 运行包携带自己的用户数据，开发、自用及历史副本互不干扰。
class AppStorageService {
  static const keepSettingsMarker = 'misakafetch.keep-settings';

  /// Only the personal and public folders can opt into retained settings.
  static bool keepsSettingsForExecutable(String executablePath) {
    if (startsFreshForExecutable(executablePath)) return false;
    var directory = File(executablePath).parent;
    while (true) {
      final name = directory.path.split(RegExp(r'[/\\]')).last;
      if (name == 'MisakaFetch' || name == 'MisakaFetch开源') {
        try {
          final marker = File.fromUri(
            directory.uri.resolve(keepSettingsMarker),
          );
          return marker.existsSync() &&
              marker.readAsStringSync().trim() == 'keep';
        } on FileSystemException {
          return false;
        }
      }
      final parent = directory.parent;
      if (parent.path == directory.path) return false;
      directory = parent;
    }
  }

  /// 按完整路径中的目录段识别用途，防止开发成果复制到自用版后仍重置。
  static bool startsFreshForExecutable(String executablePath) => executablePath
      .split(RegExp(r'[/\\]'))
      .any((part) => part == 'MisakaFetch开发' || part == 'MisakaFetch历史版本');

  static Directory windowsDirectoryFor(String executablePath) =>
      Directory.fromUri(File(executablePath).parent.uri.resolve('user_data/'));

  static Directory get windowsDirectory =>
      windowsDirectoryFor(Platform.resolvedExecutable);

  static Future<Directory> supportDirectory() async => Platform.isWindows
      ? windowsDirectory
      : await getApplicationSupportDirectory();
}
