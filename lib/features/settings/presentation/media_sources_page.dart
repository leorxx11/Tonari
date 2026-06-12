import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/files/folder_picker_service.dart';
import '../../library/data/folder_reimport_provider.dart';
import '../../library/data/library_task_controller.dart';

class MediaSourcesPage extends ConsumerWidget {
  const MediaSourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(importedFoldersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('媒体来源')),
      body: foldersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (folders) {
          if (folders.isEmpty) {
            return const Center(child: Text('还没有导入任何来源，去媒体库右上角导入'));
          }
          return ListView.separated(
            itemCount: folders.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _SourceTile(folder: folders[index]),
          );
        },
      ),
    );
  }
}

class _SourceTile extends ConsumerWidget {
  const _SourceTile({required this.folder});

  final ImportedFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Block delete while this folder's task or a global import is running, so
    // an in-flight import can't write works pointing at a just-deleted source.
    final busy =
        ref.watch(
          workTaskControllerProvider.select(
            (tasks) => tasks[folder.id]?.active ?? false,
          ),
        ) ||
        ref.watch(libraryTaskControllerProvider.select((s) => s.active));
    final count = ref.watch(
      folderWorkCountsProvider.select(
        (counts) => counts.value?[folder.id] ?? 0,
      ),
    );
    return ListTile(
      leading: Icon(_iconFor(folder.type)),
      title: Text(folder.displayName),
      subtitle: Text('${_sourceLabel(folder.type)} · $count 个作品'),
      trailing: IconButton(
        tooltip: '删除来源',
        icon: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.error,
        ),
        onPressed: busy ? null : () => _confirmDelete(context, ref, count),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除来源'),
        content: Text(
          count > 0
              ? '将移除来源「${folder.displayName}」及其下 $count 个作品（含播放记录、收藏），不可恢复。确定？'
              : '将移除来源「${folder.displayName}」。确定？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final removed = await ref.read(deleteSourceProvider)(folder.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed > 0
              ? '已删除来源「${folder.displayName}」及 $removed 个作品'
              : '已删除来源「${folder.displayName}」',
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'webdav':
        return Icons.cloud_outlined;
      case 'p115':
        return Icons.folder_special_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  String _sourceLabel(String type) {
    switch (type) {
      case 'webdav':
        return 'WebDAV';
      case 'p115':
        return '115 网盘';
      default:
        return '本地';
    }
  }
}
