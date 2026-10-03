import 'package:flutter/material.dart';

/// 标题始终显示，展开和收起只影响提取区域，不丢失页面状态。
class WorkspacePage extends StatefulWidget {
  const WorkspacePage({
    super.key,
    required this.extractionPageBuilder,
    required this.onOpenSettings,
  });

  final Widget Function(bool visible) extractionPageBuilder;
  final VoidCallback onOpenSettings;

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  bool _visible = false;
  final _contentKey = GlobalKey();

  Widget _tab() => Semantics(
    selected: _visible,
    button: true,
    child: OutlinedButton.icon(
      key: const Key('extractionTab'),
      onPressed: () {
        if (_visible) FocusManager.instance.primaryFocus?.unfocus();
        setState(() => _visible = !_visible);
      },
      icon: Icon(
        _visible ? Icons.close : Icons.image_search_outlined,
        size: 20,
      ),
      label: const Text('视频封面提取'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        backgroundColor: Theme.of(context).cardTheme.color,
        side: (Theme.of(context).cardTheme.shape as RoundedRectangleBorder?)
            ?.side,
      ),
    ),
  );

  Widget _settingsButton() => IconButton.filledTonal(
    key: const Key('settingsButton'),
    tooltip: '设置',
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    onPressed: widget.onOpenSettings,
    icon: const Icon(Icons.settings_outlined),
  );

  Widget _content() => KeyedSubtree(
    key: _contentKey,
    child: widget.extractionPageBuilder(_visible),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 700
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 180,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [_tab(), const Spacer(), _settingsButton()],
                      ),
                    ),
                  ),
                  Expanded(child: _content()),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [_tab(), const Spacer(), _settingsButton()],
                    ),
                  ),
                  Expanded(child: _content()),
                ],
              ),
      ),
    ),
  );
}
