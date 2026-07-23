import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../data/collections_providers.dart';
import 'collection_detail_page.dart';
import 'widgets/collection_picker_sheet.dart';
import 'widgets/work_cover.dart';

class CollectionsPage extends ConsumerWidget {
  const CollectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(collectionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('书架'),
        actions: [
          IconButton(
            tooltip: '新建分组',
            icon: const Icon(Icons.add),
            onPressed: () async {
              final name = await promptCollectionName(context);
              if (name == null) return;
              await ref.read(collectionRepositoryProvider).create(name);
            },
          ),
        ],
      ),
      body: collectionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (collections) => collections.isEmpty
            ? const _EmptyShelf()
            : ListView.builder(
                itemCount: collections.length,
                itemBuilder: (ctx, i) =>
                    _CollectionTile(collection: collections[i]),
              ),
      ),
    );
  }
}

class _CollectionTile extends ConsumerWidget {
  const _CollectionTile({required this.collection});

  final Collection collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final works =
        ref.watch(collectionWorksProvider(collection.id)).value ?? const [];
    return ListTile(
      leading: SizedBox(
        width: 52,
        height: 52,
        child: works.isEmpty
            ? Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bookmark_outline,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : WorkCover(
                work: works.first,
                borderRadius: BorderRadius.circular(8),
                iconSize: 24,
              ),
      ),
      title: Text(collection.name),
      subtitle: Text('${works.length} 个作品'),
      trailing: PopupMenuButton<_CollectionAction>(
        onSelected: (action) => _onAction(context, ref, action),
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _CollectionAction.rename,
            child: Row(
              children: [
                Icon(Icons.edit_outlined),
                SizedBox(width: 12),
                Text('重命名'),
              ],
            ),
          ),
          PopupMenuItem(
            value: _CollectionAction.delete,
            child: Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.red),
                SizedBox(width: 12),
                Text('删除分组', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => CollectionDetailPage(collectionId: collection.id),
          ),
        );
      },
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _CollectionAction action,
  ) async {
    final repo = ref.read(collectionRepositoryProvider);
    switch (action) {
      case _CollectionAction.rename:
        final name = await promptCollectionName(
          context,
          initial: collection.name,
        );
        if (name == null) return;
        await repo.rename(collection.id, name);
      case _CollectionAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('删除「${collection.name}」？'),
            content: const Text('只删除分组本身，里面的作品不受影响。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await repo.delete(collection.id);
    }
  }
}

enum _CollectionAction { rename, delete }

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf();

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
              Icons.collections_bookmark_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('书架还是空的', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '点右上角新建分组，或在媒体库长按作品加入分组',
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
