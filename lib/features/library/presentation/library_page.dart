import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/files/folder_picker_service.dart';
import '../data/import_flow.dart';
import '../data/work_actions_provider.dart';
import '../data/works_providers.dart';
import 'work_detail_page.dart';
import 'widgets/work_card.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  bool _importing = false;
  bool _rescanning = false;

  @override
  Widget build(BuildContext context) {
    final worksAsync = ref.watch(allWorksProvider);
    final folders = ref.watch(importedFoldersProvider).value ?? const [];
    final busy = _importing || _rescanning;
    final sort = ref.watch(workSortProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('媒体库'),
        actions: [
          PopupMenuButton<WorkSortMode>(
            tooltip: '排序',
            icon: const Icon(Icons.sort),
            initialValue: sort,
            onSelected: (mode) =>
                ref.read(workSortProvider.notifier).set(mode),
            itemBuilder: (context) => [
              for (final mode in WorkSortMode.values)
                PopupMenuItem(
                  value: mode,
                  child: Row(
                    children: [
                      if (mode == sort)
                        const Icon(Icons.check, size: 18)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 12),
                      Text(mode.label),
                    ],
                  ),
                ),
            ],
          ),
          if (folders.isNotEmpty)
            IconButton(
              tooltip: '重新扫描',
              icon: _rescanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: busy ? null : () => _onRescan(folders),
            ),
          IconButton(
            tooltip: '导入文件夹',
            icon: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.create_new_folder_outlined),
            onPressed: busy ? null : _onImport,
          ),
        ],
      ),
      body: worksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (works) => works.isEmpty
            ? const _EmptyState()
            : _WorksGrid(works: works, onRemove: _onRemoveWork),
      ),
    );
  }

  Future<void> _onImport() async {
    final folder = await ref.read(folderPickerServiceProvider).pickAndPersist();
    if (folder == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('扫描中…'),
          ],
        ),
        duration: Duration(minutes: 5),
      ),
    );
    setState(() => _importing = true);

    try {
      final summary = await ref
          .read(importFlowProvider)
          .importFromFolder(folder);
      if (!mounted) return;
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '导入完成：${summary.worksInserted} 部新作品 / '
            '${summary.worksUpdated} 部更新，共 ${summary.tracksTotal} 个音轨',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(content: Text('导入失败：$e')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _onRescan(List<ImportedFolder> folders) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('重新扫描中…'),
          ],
        ),
        duration: Duration(minutes: 5),
      ),
    );
    setState(() => _rescanning = true);

    final workIds = <String>{};
    final trackIds = <String>{};
    try {
      for (final folder in folders) {
        final summary = await ref
            .read(importFlowProvider)
            .importFromFolder(folder);
        workIds.addAll(summary.workIds);
        trackIds.addAll(summary.trackIds);
      }
      if (!mounted) return;
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('扫描完成：${workIds.length} 部作品，共 ${trackIds.length} 个音轨'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(content: Text('扫描失败：$e')));
    } finally {
      if (mounted) setState(() => _rescanning = false);
    }
  }

  Future<void> _onRemoveWork(Work work) async {
    await ref.read(removeWorkProvider).call(work.productId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已移除 ${work.title}')));
  }
}

class _WorksGrid extends StatelessWidget {
  const _WorksGrid({required this.works, required this.onRemove});

  final List<Work> works;
  final ValueChanged<Work> onRemove;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.82,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      padding: const EdgeInsets.all(8),
      itemCount: works.length,
      itemBuilder: (ctx, i) => WorkCard(
        work: works[i],
        onRemove: () => onRemove(works[i]),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => WorkDetailPage(work: works[i]),
            ),
          );
        },
      ),
    );
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
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
