import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/folder_picker_service.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(importedFoldersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('媒体库'),
        actions: [
          IconButton(
            tooltip: '导入文件夹',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => _onImport(context, ref),
          ),
        ],
      ),
      body: foldersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (folders) => folders.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                itemCount: folders.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final folder = folders[i];
                  return ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(folder.displayName),
                    subtitle: Text('导入于 ${_formatDate(folder.createdAt)}'),
                    trailing: IconButton(
                      tooltip: '移除',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
                          .read(folderPickerServiceProvider)
                          .remove(folder.id),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _onImport(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref.read(folderPickerServiceProvider).pickAndPersist();
      if (result != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导入 ${result.displayName}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败：$e')),
        );
      }
    }
  }

  static String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('媒体库还是空的', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '点右上角导入一个包含 RJ 编号的文件夹',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
