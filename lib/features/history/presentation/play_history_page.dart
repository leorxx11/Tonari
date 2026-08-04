import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../library/data/works_providers.dart';
import '../../library/presentation/widgets/work_cover.dart';
import '../../library/presentation/work_detail_page.dart';
import '../../video_library/data/video_library_providers.dart';
import '../../video_library/presentation/video_library_page.dart';
import '../data/history_playback.dart';
import '../data/play_history_repository.dart';
import '../../../core/ui/app_toast.dart';
import '../../../shared/widgets/app_drawer.dart';

class PlayHistoryPage extends ConsumerWidget {
  const PlayHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(playHistoryProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('播放历史'),
        actions: [
          IconButton(
            tooltip: '清空历史',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => _confirmClear(context, ref),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (entries) => entries.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 0.5, indent: 72),
                itemBuilder: (_, i) => _HistoryRow(entry: entries[i]),
              ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空播放历史'),
        content: const Text('删除所有历史记录？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirm ?? false) {
      await ref.read(playHistoryRepositoryProvider).clear();
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text('还没有播放记录', style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.entry});

  final PlayHistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subtitle = _subtitleText();
    return ListTile(
      leading: _Leading(entry: entry),
      title: Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () => _onTap(context, ref),
      onLongPress: () => _showMenu(context, ref),
    );
  }

  String _subtitleText() {
    final parts = <String>[
      switch (entry.kind) {
        'work' => '作品',
        'video' => '视频',
        _ => '音频',
      },
      if (entry.sourceName != null && entry.sourceName!.isNotEmpty)
        entry.sourceName!,
      relativeTimeText(entry.playedAt),
    ];
    final duration = entry.durationMs;
    final position = entry.positionMs;
    if (entry.kind == 'video' && duration != null && duration > 0) {
      final percent = (position / duration * 100).clamp(0, 100).round();
      if (percent > 0) parts.add('看到 $percent%');
    }
    return parts.join(' · ');
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    if (entry.kind == 'work') {
      final workId = entry.workId;
      if (workId == null) return;
      final work = await ref.read(workByIdProvider(workId).future);
      if (!context.mounted) return;
      if (work == null || work.isRemoved) {
        showAppToast('该作品已不在媒体库中');
        return;
      }
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => WorkDetailPage(work: work)));
      return;
    }
    await ref.read(historyPlaybackProvider).play(entry);
  }

  Future<void> _showMenu(BuildContext context, WidgetRef ref) async {
    final isVideo = entry.kind == 'video';
    final inLibrary = isVideo
        ? (ref.read(videoInLibraryProvider(entry.id)).value ?? false)
        : false;
    final action = await showModalBottomSheet<_HistoryAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isVideo && !inLibrary)
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('加入视频库'),
                onTap: () =>
                    Navigator.of(ctx).pop(_HistoryAction.addToVideoLibrary),
              ),
            if (isVideo && inLibrary)
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('从视频库移除'),
                onTap: () =>
                    Navigator.of(ctx).pop(_HistoryAction.removeFromVideoLibrary),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除这条记录'),
              onTap: () => Navigator.of(ctx).pop(_HistoryAction.delete),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _HistoryAction.addToVideoLibrary:
        final item = ref.read(historyPlaybackProvider).playableFrom(entry);
        if (item == null) return;
        final added = await ref.read(videoLibraryRepositoryProvider).add(item);
        showAppToast(added ? '已加入视频库' : '已在视频库中');
      case _HistoryAction.removeFromVideoLibrary:
        await ref.read(videoLibraryRepositoryProvider).remove(entry.id);
        showAppToast('已从视频库移除');
      case _HistoryAction.delete:
        await ref.read(playHistoryRepositoryProvider).remove(entry.id);
    }
  }
}

enum _HistoryAction { addToVideoLibrary, removeFromVideoLibrary, delete }

class _Leading extends ConsumerWidget {
  const _Leading({required this.entry});

  final PlayHistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (entry.kind == 'work' && entry.workId != null) {
      final work = ref.watch(workByIdProvider(entry.workId!)).value;
      if (work != null) {
        return SizedBox(
          width: 48,
          height: 48,
          child: WorkCover(
            work: work,
            borderRadius: BorderRadius.circular(8),
            iconSize: 24,
          ),
        );
      }
    }
    if (entry.kind == 'video') {
      final row = ref.watch(videoItemByIdProvider(entry.id)).value;
      if (row?.coverPath != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 48,
            height: 48,
            child: VideoCover(coverPath: row!.coverPath, iconSize: 24),
          ),
        );
      }
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        switch (entry.kind) {
          'work' => CupertinoIcons.music_albums_fill,
          'video' => CupertinoIcons.videocam_fill,
          _ => CupertinoIcons.music_note,
        },
        size: 24,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

String relativeTimeText(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
  if (diff.inDays < 1 && now.day == time.day) return '${diff.inHours} 小时前';
  final yesterday = now.subtract(const Duration(days: 1));
  if (time.year == yesterday.year &&
      time.month == yesterday.month &&
      time.day == yesterday.day) {
    return '昨天';
  }
  if (time.year == now.year) return '${time.month}月${time.day}日';
  return '${time.year}/${time.month}/${time.day}';
}
