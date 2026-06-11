import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/files/folder_picker_service.dart';
import '../../library/data/folder_reimport_provider.dart';
import '../../library/data/import_service.dart';
import '../../library/data/library_task_controller.dart';

class ImportedFoldersPage extends ConsumerWidget {
  const ImportedFoldersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(importedFoldersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('已导入文件夹')),
      body: foldersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (folders) {
          if (folders.isEmpty) {
            return const Center(child: Text('还没有导入任何文件夹'));
          }
          return ListView.separated(
            itemCount: folders.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _FolderTile(folder: folders[index]),
          );
        },
      ),
    );
  }
}

class _FolderTile extends ConsumerWidget {
  const _FolderTile({required this.folder});

  final ImportedFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      workTaskControllerProvider.select(
        (tasks) => tasks[folder.id]?.active ?? false,
      ),
    );
    return ListTile(
      leading: Icon(_iconFor(folder.type)),
      title: Text(folder.displayName),
      subtitle: Text('${_sourceLabel(folder.type)} · 重新扫描只补充新作品'),
      trailing: TextButton(
        onPressed: active ? null : () => _rescan(context, ref),
        child: Text(active ? '扫描中' : '重新扫描'),
      ),
    );
  }

  Future<void> _rescan(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(workTaskControllerProvider.notifier);
    final reimport = ref.read(reimportFolderProvider);
    try {
      final summary = await controller.run<ImportSummary?>(
        productId: folder.id,
        kind: LibraryTaskKind.import,
        title: '重新扫描文件夹',
        initialStage: '扫描文件',
        action: (task) => reimport(folder, task: task),
      );
      if (!context.mounted) return;
      if (summary == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('来源不可用，无法重新扫描')),
        );
        return;
      }
      final n = summary.workIds.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(n > 0 ? '新增 $n 个作品' : '没有发现新作品')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('重新扫描失败：$e')));
    }
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
