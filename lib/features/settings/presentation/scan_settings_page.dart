import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/path_prefs.dart';

class ScanSettingsPage extends ConsumerWidget {
  const ScanSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(pathPrefsProvider);
    final notifier = ref.read(pathPrefsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('资源扫描')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.alt_route),
            title: const Text('启用智能路径'),
            subtitle: const Text('打开资源页时自动定位到唯一的播放目录'),
            value: prefs.smartPath,
            onChanged: notifier.setSmartPath,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.graphic_eq),
            title: const Text('优先有 SE'),
            subtitle: const Text('在含 SE / 不含 SE 之间选择时倾向有 SE 的版本'),
            value: prefs.preferEffectSound,
            onChanged: prefs.smartPath ? notifier.setPreferEffectSound : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.audio_file_outlined),
            title: const Text('按格式优先级筛选'),
            subtitle: const Text('在多种音频格式之间按下方顺序选择'),
            value: prefs.typeOrderEnabled,
            onChanged: prefs.smartPath ? notifier.setTypeOrderEnabled : null,
          ),
          _TypeOrderList(
            order: prefs.typeOrder,
            enabled: prefs.smartPath && prefs.typeOrderEnabled,
            onReorder: notifier.reorderType,
          ),
        ],
      ),
    );
  }
}

class _TypeOrderList extends StatelessWidget {
  const _TypeOrderList({
    required this.order,
    required this.enabled,
    required this.onReorder,
  });

  final List<String> order;
  final bool enabled;
  final Future<void> Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dimmedColor = theme.colorScheme.onSurface.withValues(alpha: 0.4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '拖拽调整格式优先级（顶部最高）',
            style: theme.textTheme.bodySmall?.copyWith(
              color: enabled ? theme.colorScheme.onSurfaceVariant : dimmedColor,
            ),
          ),
          const SizedBox(height: 8),
          AbsorbPointer(
            absorbing: !enabled,
            child: Opacity(
              opacity: enabled ? 1.0 : 0.5,
              child: ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (oldIndex, newIndex) =>
                    onReorder(oldIndex, newIndex),
                children: [
                  for (var i = 0; i < order.length; i++)
                    Card(
                      key: ValueKey(order[i]),
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            '${i + 1}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        title: Text(order[i].toUpperCase()),
                        trailing: ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_handle),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
