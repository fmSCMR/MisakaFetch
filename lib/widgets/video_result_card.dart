import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/downloaded_image.dart';
import '../models/video_info.dart';

class VideoResultCard extends StatelessWidget {
  const VideoResultCard({
    super.key,
    required this.video,
    required this.image,
    required this.isLoading,
    this.errorText,
    this.onRetry,
    this.onSave,
    this.isSaving = false,
    this.onCopy,
  });

  final VideoInfo video;
  final DownloadedImage? image;
  final bool isLoading;
  final String? errorText;
  final VoidCallback? onRetry;
  final VoidCallback? onSave;
  final bool isSaving;
  final VoidCallback? onCopy;

  Widget _failure(BuildContext context, String message) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, size: 32),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重新加载封面'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ownerName = video.ownerName;
    final bvid = video.bvid;
    final cover = image;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              video.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            SelectableText('UP主：$ownerName'),
            const SizedBox(height: 6),
            SelectableText('BV号：$bvid'),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) => Container(
                height: math.max(200, constraints.maxWidth * 9 / 16),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : cover != null
                    ? Image.memory(
                        cover.bytes,
                        key: const Key('coverPreview'),
                        fit: BoxFit.contain,
                        semanticLabel: '视频原始封面',
                        frameBuilder: (context, child, frame, synchronous) =>
                            synchronous || frame != null
                            ? child
                            : const Center(child: CircularProgressIndicator()),
                        errorBuilder: (context, error, stack) =>
                            _failure(context, '封面无法显示，请重新加载。'),
                      )
                    : _failure(context, errorText ?? '封面暂时无法显示。'),
              ),
            ),
            const SizedBox(height: 20),
            Text('原始封面图片地址', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            SelectableText(
              video.coverUrl,
              style: theme.textTheme.bodySmall,
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  key: const Key('saveImageButton'),
                  onPressed: onSave,
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                  label: Text(isSaving ? '正在保存…' : '保存原图'),
                ),
                OutlinedButton.icon(
                  key: const Key('copyLinkButton'),
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('复制图片链接'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
