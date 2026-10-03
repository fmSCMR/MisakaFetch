import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 已有提取功能测试先走新的工具入口，再检查原有行为。
Future<void> pumpExtractionApp(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  final tab = find.byKey(const Key('extractionTab'));
  if (tab.evaluate().isNotEmpty) {
    await tester.tap(tab);
    await tester.pump();
  }
}
