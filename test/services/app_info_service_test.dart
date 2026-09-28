import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:misaka_fetch/services/app_info_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final build in ['8', '']) {
    test('版本读取元数据，构建号为 "$build"', () async {
      PackageInfo.setMockInitialValues(
        appName: 'MisakaFetch',
        packageName: 'test.metadata',
        version: '2.3.4',
        buildNumber: build,
        buildSignature: '',
      );
      expect(await AppInfoService().versionLabel(), '2.3.4');
    });
  }
  test('版本缺失显示可读错误', () async {
    PackageInfo.setMockInitialValues(
      appName: 'MisakaFetch',
      packageName: 'test.metadata',
      version: '',
      buildNumber: '',
      buildSignature: '',
    );
    await expectLater(
      AppInfoService().versionLabel(),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          '版本信息暂不可用',
        ),
      ),
    );
  });
}
