import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/app_toast.dart';
import '../../features/library/data/app_events.dart';
import '../../features/library/data/works_providers.dart';
import '../../features/library/presentation/open_work_detail.dart';
import '../../features/library/presentation/widgets/app_events_sheet.dart';
import '../providers/selected_section.dart';

/// Section pages have their own Scaffolds, so their hamburger buttons reach
/// the root drawer through this key instead of Scaffold.of.
final rootScaffoldKey = GlobalKey<ScaffoldState>();

class DrawerMenuButton extends ConsumerWidget {
  const DrawerMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnread = ref.watch(
      unreadEventCountProvider.select((v) => (v.value ?? 0) > 0),
    );
    return IconButton(
      tooltip: '菜单',
      icon: Badge(
        isLabelVisible: hasUnread,
        smallSize: 8,
        child: const Icon(Icons.menu),
      ),
      onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
    );
  }
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(selectedSectionProvider);
    final unread = ref.watch(
      unreadEventCountProvider.select((v) => v.value ?? 0),
    );
    return NavigationDrawer(
      selectedIndex: section == AppSection.settings ? -1 : section.index,
      onDestinationSelected: (i) => _onSelected(context, ref, i),
      footer: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(),
            ),
            _SettingsDestination(
              selected: section == AppSection.settings,
              onTap: () => _selectSection(context, ref, AppSection.settings),
            ),
          ],
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 16, 12),
          child: Text(
            'Tonari',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.library_music_outlined),
          selectedIcon: Icon(Icons.library_music),
          label: Text('音声库'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.video_library_outlined),
          selectedIcon: Icon(Icons.video_library),
          label: Text('视频库'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.favorite_outline),
          selectedIcon: Icon(Icons.favorite),
          label: Text('收藏'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.label_outline),
          selectedIcon: Icon(Icons.label),
          label: Text('分类'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.history),
          label: Text('播放历史'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.folder_open_outlined),
          selectedIcon: Icon(Icons.folder_open),
          label: Text('浏览'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Divider(),
        ),
        NavigationDrawerDestination(
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.notifications_none_outlined),
          ),
          label: const Text('消息'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.casino_outlined),
          label: Text('随机来一部'),
        ),
      ],
    );
  }

  Future<void> _onSelected(
    BuildContext context,
    WidgetRef ref,
    int index,
  ) async {
    if (index < AppSection.settings.index) {
      _selectSection(context, ref, AppSection.values[index]);
      return;
    }
    // Query while the drawer (and its ref) is still alive.
    final work = index == AppSection.settings.index
        ? null
        : await ref.read(pickRandomWorkProvider)();
    if (!context.mounted) return;
    Navigator.of(context).pop();
    // The drawer context dies with the pop; actions need the root context.
    final rootContext = rootScaffoldKey.currentContext;
    if (rootContext == null) return;
    if (index == AppSection.settings.index) {
      ref.read(appEventSinkProvider).markAllRead();
      showAppEventsSheet(rootContext);
    } else if (work == null) {
      showAppToast('音声库还是空的');
    } else {
      openWorkDetail(rootContext, ref, work);
    }
  }

  void _selectSection(BuildContext context, WidgetRef ref, AppSection section) {
    Navigator.of(context).pop();
    ref.read(selectedSectionProvider.notifier).set(section);
  }
}

class _SettingsDestination extends StatelessWidget {
  const _SettingsDestination({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primary.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.3
                  : 0.12,
            )
          : Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.settings : Icons.settings_outlined,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  '设置',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? colors.primary : colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
