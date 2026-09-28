import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppInfoService {
  Future<String> versionLabel() async {
    try {
      final info = await PackageInfo.fromPlatform().timeout(
        const Duration(seconds: 5),
      );
      if (info.version.isEmpty) throw const FormatException('Missing version');
      return info.version;
    } catch (error, stack) {
      if (kDebugMode) {
        developer.log(
          'Reading app metadata failed',
          name: 'MisakaFetch',
          error: error,
          stackTrace: stack,
        );
      }
      throw const FormatException('版本信息暂不可用');
    }
  }
}
