import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:misaka_fetch/models/app_settings.dart';

void main() {
  test('新用户默认值符合设置需求', () {
    const settings = AppSettings();
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.backgroundEnabled, false);
    expect(settings.backgroundImage, isNull);
    expect(settings.backgroundBlur, 0);
    expect(settings.backgroundBrightness, 1);
    expect(settings.backgroundOverlay, 0.35);
    expect(settings.boxFit, BoxFit.cover);
    expect(settings.animationsEnabled, true);
    expect(settings.filenameFormat, FilenameFormat.titleBvid);
    expect(settings.askSaveLocation, true);
    expect(settings.saveSuccessAction, SaveSuccessAction.notify);
  });
  test('所有字段使用稳定名称序列化并恢复', () {
    final original = const AppSettings().copyWith(
      themeMode: ThemeMode.dark,
      backgroundEnabled: true,
      backgroundImage: 'background-123.png',
      backgroundBlur: 21,
      backgroundBrightness: 1.2,
      backgroundOverlay: 0.6,
      backgroundFit: BackgroundFit.contain,
      animationsEnabled: false,
      cardColor: 0x123456,
      cardOpacity: 0.35,
      cardBorderColor: 0xABCDEF,
      cardBorderOpacity: 0.4,
      filenameFormat: FilenameFormat.bvidTitle,
      defaultSaveDirectory: 'C:/Pictures',
      askSaveLocation: false,
      saveSuccessAction: SaveSuccessAction.openFolder,
    );
    expect(AppSettings.fromJson(original.toJson()).toJson(), original.toJson());
  });
  test('字段缺失、错误类型和未知枚举退回默认，不影响合法字段', () {
    final settings = AppSettings.fromJson({
      'themeMode': 'dark',
      'animationsEnabled': 'false',
      'filenameFormat': 'future',
      'backgroundBlur': '30',
      'defaultSaveDirectory': 123,
      'askSaveLocation': false,
      'unknownField': 'ignored',
    });
    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.animationsEnabled, true);
    expect(settings.filenameFormat, FilenameFormat.titleBvid);
    expect(settings.backgroundBlur, 0);
    expect(settings.defaultSaveDirectory, isNull);
    expect(settings.askSaveLocation, false);
  });
  test('背景数值边界被限制，NaN 和 Infinity 使用默认值', () {
    final settings = AppSettings.fromJson({
      'backgroundBlur': -5,
      'backgroundBrightness': 99,
      'backgroundOverlay': double.nan,
    });
    expect(settings.backgroundBlur, 0);
    expect(settings.backgroundBrightness, 1.5);
    expect(settings.backgroundOverlay, 0.35);
    expect(
      const AppSettings()
          .copyWith(backgroundBlur: double.infinity)
          .backgroundBlur,
      0,
    );
    expect(
      const AppSettings().copyWith(backgroundOverlay: 2).backgroundOverlay,
      0.8,
    );
  });
  test('无图片不能从存储恢复为已启用背景', () {
    final settings = AppSettings.fromJson({
      'backgroundEnabled': true,
      'backgroundImage': '   ',
    });
    expect(settings.backgroundEnabled, false);
    expect(settings.backgroundImage, isNull);
  });
  test('旧设置保留默认卡片外观，非法颜色及透明度被校验', () {
    final old = AppSettings.fromJson({'themeMode': 'dark'});
    expect(old.cardColor, isNull);
    expect(old.cardOpacity, 1);
    final invalid = AppSettings.fromJson({
      'cardColor': -1,
      'cardBorderColor': 0x1000000,
      'cardOpacity': double.nan,
      'cardBorderOpacity': -3,
    });
    expect(invalid.cardColor, isNull);
    expect(invalid.cardBorderColor, isNull);
    expect(invalid.cardOpacity, 1);
    expect(invalid.cardBorderOpacity, 0);
    final reset = const AppSettings(
      cardColor: 0x123456,
      cardOpacity: .5,
    ).copyWith(clearCardColor: true);
    expect(reset.cardColor, isNull);
    expect(reset.cardOpacity, .5);
  });
  test('重置背景参数保留用户图片、主题和保存设置', () {
    final settings = const AppSettings()
        .copyWith(
          backgroundEnabled: true,
          backgroundImage: 'owned.png',
          themeMode: ThemeMode.dark,
          backgroundBlur: 30,
          backgroundFit: BackgroundFit.fill,
          defaultSaveDirectory: 'C:/Pictures',
        )
        .resetBackgroundParameters();
    expect(settings.backgroundImage, 'owned.png');
    expect(settings.backgroundEnabled, true);
    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.defaultSaveDirectory, 'C:/Pictures');
    expect(settings.backgroundBlur, 0);
    expect(settings.boxFit, BoxFit.cover);
  });
  test('清空背景和目录字段不影响其他设置', () {
    final settings = const AppSettings()
        .copyWith(
          backgroundEnabled: true,
          backgroundImage: 'owned.png',
          defaultSaveDirectory: 'C:/Pictures',
          themeMode: ThemeMode.light,
        )
        .copyWith(clearBackground: true, clearSaveDirectory: true);
    expect(settings.backgroundEnabled, false);
    expect(settings.backgroundImage, isNull);
    expect(settings.defaultSaveDirectory, isNull);
    expect(settings.themeMode, ThemeMode.light);
  });
  for (final fit in BackgroundFit.values) {
    test('背景显示方式 ${fit.name} 可往返恢复', () {
      final restored = AppSettings.fromJson({'backgroundFit': fit.name});
      expect(restored.boxFit.name, fit.name);
    });
  }
}
