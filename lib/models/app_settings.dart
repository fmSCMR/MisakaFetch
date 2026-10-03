import 'package:flutter/material.dart';

enum BackgroundFit { cover, contain, fill }

enum FilenameFormat { title, titleBvid, bvidTitle }

enum SaveSuccessAction { notify, openFolder, silent }

/// 本地偏好设置；视频信息和封面文件由各自的服务管理。
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.backgroundEnabled = false,
    this.backgroundImage,
    this.backgroundBlur = 0,
    this.backgroundBrightness = 1,
    this.backgroundOverlay = 0.35,
    this.backgroundFit = BackgroundFit.cover,
    this.animationsEnabled = true,
    this.cardColor,
    this.cardOpacity = 1,
    this.cardBorderColor,
    this.cardBorderOpacity = 1,
    this.filenameFormat = FilenameFormat.titleBvid,
    this.defaultSaveDirectory,
    this.askSaveLocation = true,
    this.saveSuccessAction = SaveSuccessAction.notify,
  });

  final ThemeMode themeMode;
  final bool backgroundEnabled;
  final String? backgroundImage;
  final double backgroundBlur;
  final double backgroundBrightness;
  final double backgroundOverlay;
  final BackgroundFit backgroundFit;
  final bool animationsEnabled;
  final int? cardColor;
  final double cardOpacity;
  final int? cardBorderColor;
  final double cardBorderOpacity;
  final FilenameFormat filenameFormat;
  final String? defaultSaveDirectory;
  final bool askSaveLocation;
  final SaveSuccessAction saveSuccessAction;

  BoxFit get boxFit => switch (backgroundFit) {
    BackgroundFit.cover => BoxFit.cover,
    BackgroundFit.contain => BoxFit.contain,
    BackgroundFit.fill => BoxFit.fill,
  };

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? backgroundEnabled,
    String? backgroundImage,
    bool clearBackground = false,
    double? backgroundBlur,
    double? backgroundBrightness,
    double? backgroundOverlay,
    BackgroundFit? backgroundFit,
    bool? animationsEnabled,
    int? cardColor,
    bool clearCardColor = false,
    double? cardOpacity,
    int? cardBorderColor,
    bool clearCardBorderColor = false,
    double? cardBorderOpacity,
    FilenameFormat? filenameFormat,
    String? defaultSaveDirectory,
    bool clearSaveDirectory = false,
    bool? askSaveLocation,
    SaveSuccessAction? saveSuccessAction,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    backgroundEnabled: clearBackground
        ? false
        : backgroundEnabled ?? this.backgroundEnabled,
    backgroundImage: clearBackground
        ? null
        : backgroundImage ?? this.backgroundImage,
    backgroundBlur: _bounded(backgroundBlur ?? this.backgroundBlur, 0, 30, 0),
    backgroundBrightness: _bounded(
      backgroundBrightness ?? this.backgroundBrightness,
      0.5,
      1.5,
      1,
    ),
    backgroundOverlay: _bounded(
      backgroundOverlay ?? this.backgroundOverlay,
      0,
      0.8,
      0.35,
    ),
    backgroundFit: backgroundFit ?? this.backgroundFit,
    animationsEnabled: animationsEnabled ?? this.animationsEnabled,
    cardColor: clearCardColor ? null : _color(cardColor ?? this.cardColor),
    cardOpacity: _bounded(cardOpacity ?? this.cardOpacity, 0, 1, 1),
    cardBorderColor: clearCardBorderColor
        ? null
        : _color(cardBorderColor ?? this.cardBorderColor),
    cardBorderOpacity: _bounded(
      cardBorderOpacity ?? this.cardBorderOpacity,
      0,
      1,
      1,
    ),
    filenameFormat: filenameFormat ?? this.filenameFormat,
    defaultSaveDirectory: clearSaveDirectory
        ? null
        : defaultSaveDirectory ?? this.defaultSaveDirectory,
    askSaveLocation: askSaveLocation ?? this.askSaveLocation,
    saveSuccessAction: saveSuccessAction ?? this.saveSuccessAction,
  );

  /// 恢复背景参数，保留背景图片、主题和保存选项。
  AppSettings resetBackgroundParameters() => copyWith(
    backgroundBlur: 0,
    backgroundBrightness: 1,
    backgroundOverlay: 0.35,
    backgroundFit: BackgroundFit.cover,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'themeMode': themeMode.name,
    'backgroundEnabled': backgroundEnabled,
    'backgroundImage': backgroundImage,
    'backgroundBlur': backgroundBlur,
    'backgroundBrightness': backgroundBrightness,
    'backgroundOverlay': backgroundOverlay,
    'backgroundFit': backgroundFit.name,
    'animationsEnabled': animationsEnabled,
    'cardColor': cardColor,
    'cardOpacity': cardOpacity,
    'cardBorderColor': cardBorderColor,
    'cardBorderOpacity': cardBorderOpacity,
    'filenameFormat': filenameFormat.name,
    'defaultSaveDirectory': defaultSaveDirectory,
    'askSaveLocation': askSaveLocation,
    'saveSuccessAction': saveSuccessAction.name,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final image = _optionalString(json['backgroundImage']);
    return AppSettings(
      themeMode: _enum(json['themeMode'], ThemeMode.values, ThemeMode.system),
      backgroundEnabled: json['backgroundEnabled'] == true && image != null,
      backgroundImage: image,
      backgroundBlur: _bounded(json['backgroundBlur'], 0, 30, 0),
      backgroundBrightness: _bounded(json['backgroundBrightness'], 0.5, 1.5, 1),
      backgroundOverlay: _bounded(json['backgroundOverlay'], 0, 0.8, 0.35),
      backgroundFit: _enum(
        json['backgroundFit'],
        BackgroundFit.values,
        BackgroundFit.cover,
      ),
      animationsEnabled: _bool(json['animationsEnabled'], true),
      cardColor: _color(json['cardColor']),
      cardOpacity: _bounded(json['cardOpacity'], 0, 1, 1),
      cardBorderColor: _color(json['cardBorderColor']),
      cardBorderOpacity: _bounded(json['cardBorderOpacity'], 0, 1, 1),
      filenameFormat: _enum(
        json['filenameFormat'],
        FilenameFormat.values,
        FilenameFormat.titleBvid,
      ),
      defaultSaveDirectory: _optionalString(json['defaultSaveDirectory']),
      askSaveLocation: _bool(json['askSaveLocation'], true),
      saveSuccessAction: _enum(
        json['saveSuccessAction'],
        SaveSuccessAction.values,
        SaveSuccessAction.notify,
      ),
    );
  }

  static T _enum<T extends Enum>(Object? value, List<T> choices, T fallback) =>
      choices.where((choice) => choice.name == value).firstOrNull ?? fallback;
  static bool _bool(Object? value, bool fallback) =>
      value is bool ? value : fallback;
  static int? _color(Object? value) =>
      value is int && value >= 0 && value <= 0xFFFFFF ? value : null;
  static String? _optionalString(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
  static double _bounded(
    Object? value,
    double min,
    double max,
    double fallback,
  ) => value is num && value.isFinite
      ? value.toDouble().clamp(min, max)
      : fallback;
}
