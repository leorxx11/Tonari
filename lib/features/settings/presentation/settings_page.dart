import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/path_prefs.dart';
import '../data/theme_prefs.dart';
import 'removed_works_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(pathPrefsProvider);
    final notifier = ref.read(pathPrefsProvider.notifier);
    final themeMode = ref.watch(themePrefsProvider);
    final themeNotifier = ref.read(themePrefsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _SectionHeader(theme: theme, label: '外观'),
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (mode) {
              if (mode != null) themeNotifier.setMode(mode);
            },
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  title: Text('跟随系统'),
                  secondary: Icon(Icons.brightness_auto_outlined),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  title: Text('浅色'),
                  secondary: Icon(Icons.light_mode_outlined),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  title: Text('深色'),
                  secondary: Icon(Icons.dark_mode_outlined),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          _SectionHeader(theme: theme, label: '资源页智能路径'),
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
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.restore_from_trash_outlined),
            title: const Text('已移除作品'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RemovedWorksPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.theme, required this.label});
  final ThemeData theme;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
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
              color: enabled
                  ? theme.colorScheme.onSurfaceVariant
                  : dimmedColor,
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
