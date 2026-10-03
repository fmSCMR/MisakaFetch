import 'package:flutter/material.dart';

import '../controllers/settings_controller.dart';

class CardAppearanceControls extends StatelessWidget {
  const CardAppearanceControls({
    super.key,
    required this.controller,
    required this.enabled,
  });
  final SettingsController controller;
  final bool enabled;

  Future<void> _choose(BuildContext context, bool border) async {
    final chosen = await showDialog<int>(
      context: context,
      builder: (_) => _ColorDialog(
        border: border,
        initial: border
            ? controller.settings.cardBorderColor
            : controller.settings.cardColor,
      ),
    );
    if (!context.mounted || chosen == null) return;
    await controller.update(
      border
          ? controller.settings.copyWith(cardBorderColor: chosen)
          : controller.settings.copyWith(cardColor: chosen),
    );
  }

  Widget _colorControl(BuildContext context, bool border) {
    final color = border
        ? controller.settings.cardBorderColor
        : controller.settings.cardColor;
    final label = border ? '卡片边框颜色' : '卡片底色';
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          key: Key(border ? 'cardBorderColorButton' : 'cardColorButton'),
          onPressed: enabled ? () => _choose(context, border) : null,
          icon: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color == null
                  ? (border
                        ? scheme.outlineVariant
                        : scheme.surfaceContainerLow)
                  : Color(0xFF000000 | color),
              border: Border.all(color: scheme.outline),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          label: Text('$label · ${color == null ? '跟随主题' : '#${_hex(color)}'}'),
        ),
        TextButton(
          key: Key(border ? 'resetCardBorderColor' : 'resetCardColor'),
          onPressed: !enabled || color == null
              ? null
              : () => controller.update(
                  border
                      ? controller.settings.copyWith(clearCardBorderColor: true)
                      : controller.settings.copyWith(clearCardColor: true),
                ),
          child: const Text('跟随主题'),
        ),
      ],
    );
  }

  Widget _transparency(bool border) {
    final opacity = border
        ? controller.settings.cardBorderOpacity
        : controller.settings.cardOpacity;
    final label = border ? '卡片边框透明度' : '卡片底板透明度';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$label · ${((1 - opacity) * 100).round()}%'),
        Slider(
          key: Key(
            border ? 'cardBorderTransparencySlider' : 'cardTransparencySlider',
          ),
          value: 1 - opacity,
          divisions: 100,
          semanticFormatterCallback: (value) => '${(value * 100).round()}% 透明',
          onChanged: !enabled
              ? null
              : (value) => controller.update(
                  border
                      ? controller.settings.copyWith(
                          cardBorderOpacity: 1 - value,
                        )
                      : controller.settings.copyWith(cardOpacity: 1 - value),
                  persist: false,
                ),
          onChangeEnd: !enabled ? null : (_) => controller.retrySave(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _colorControl(context, false),
      const SizedBox(height: 12),
      _transparency(false),
      _colorControl(context, true),
      const SizedBox(height: 12),
      _transparency(true),
      const Text('仅调整视频封面提取页面的卡片；设置页保持默认外观。'),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: !enabled
              ? null
              : () => controller.update(
                  controller.settings.copyWith(
                    clearCardColor: true,
                    cardOpacity: 1,
                    clearCardBorderColor: true,
                    cardBorderOpacity: 1,
                  ),
                ),
          child: const Text('恢复默认卡片外观'),
        ),
      ),
    ],
  );
}

String _hex(int color) => color.toRadixString(16).padLeft(6, '0').toUpperCase();

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.border, required this.initial});
  final bool border;
  final int? initial;
  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  final _form = GlobalKey<FormState>();
  late final _input = TextEditingController(
    text: _hex(widget.initial ?? 0x007F86),
  );
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.border ? '卡片边框颜色' : '卡片底色'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in [
                  0xFFFFFF,
                  0x151E20,
                  0x000000,
                  0x007F86,
                  0x364F6B,
                  0x6D597A,
                  0xB56576,
                  0xE9C46A,
                ])
                  IconButton(
                    tooltip: '#${_hex(color)}',
                    onPressed: () => _input.text = _hex(color),
                    icon: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(0xFF000000 | color),
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const Key('cardColorHex'),
              controller: _input,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: '自定义颜色',
                prefixText: '#',
                hintText: '例如 007F86',
              ),
              validator: (value) =>
                  RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value ?? '')
                  ? null
                  : '请输入六位颜色代码',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, int.parse(_input.text, radix: 16));
          }
        },
        child: const Text('确定'),
      ),
    ],
  );
}
