import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/app_settings.dart';

/// 背景滤镜与页面内容分层，避免模糊效果影响文字和按钮。
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.settings, required this.child});
  final AppSettings settings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final path = settings.backgroundImage;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: settings.backgroundEnabled && path != null
              ? Colors.black
              : colors.surface,
        ),
        if (settings.backgroundEnabled && path != null)
          Positioned.fill(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: ClipRect(
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: settings.backgroundBlur,
                      sigmaY: settings.backgroundBlur,
                    ),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix([
                        settings.backgroundBrightness,
                        0,
                        0,
                        0,
                        0,
                        0,
                        settings.backgroundBrightness,
                        0,
                        0,
                        0,
                        0,
                        0,
                        settings.backgroundBrightness,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ]),
                      child: Image.file(
                        File(path),
                        key: ValueKey(path),
                        fit: settings.boxFit,
                        cacheWidth: 1920,
                        gaplessPlayback: true,
                        errorBuilder: (_, error, stack) =>
                            ColoredBox(color: colors.surface),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (settings.backgroundEnabled && path != null)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                key: const Key('backgroundOverlay'),
                color: Colors.black.withValues(
                  alpha: settings.backgroundOverlay,
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}
