import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../video_library/data/video_library_providers.dart';
import '../../video_library/presentation/video_library_page.dart';
import '../data/collections_providers.dart';
import 'collection_detail_page.dart';
import 'widgets/collection_picker_sheet.dart';
import 'widgets/work_cover.dart';

class CollectionsPage extends ConsumerWidget {
  const CollectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final collectionsAsync = ref.watch(collectionsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('收藏'),
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
        data: (collections) => ListView(
          children: [
            const _AllFavoritesTile(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
              child: Text(
                '分组',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (collections.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  '还没有分组，点右上角新建，或在媒体库长按作品加入分组',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final c in collections) _CollectionTile(collection: c),
          ],
        ),
      ),
    );
  }
}

class _AllFavoritesTile extends ConsumerWidget {
  const _AllFavoritesTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final works = ref.watch(favoriteWorksProvider).value ?? const [];
    final videos = (ref.watch(videoItemsProvider).value ?? const <VideoItem>[])
        .where((v) => v.isFavorite)
        .toList();
    final counts = [
      if (works.isNotEmpty || videos.isEmpty) '${works.length} 个作品',
      if (videos.isNotEmpty) '${videos.length} 个视频',
    ].join(' · ');
    return ListTile(
      leading: SizedBox(
        width: 52,
        height: 52,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.favorite, color: theme.colorScheme.primary),
        ),
      ),
      title: const Text('全部收藏'),
      subtitle: Text(counts),
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(builder: (_) => const FavoritesDetailPage()),
        );
      },
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
    final videos =
        ref.watch(collectionVideosProvider(collection.id)).value ?? const [];
    final counts = [
      if (works.isNotEmpty || videos.isEmpty) '${works.length} 个作品',
      if (videos.isNotEmpty) '${videos.length} 个视频',
    ].join(' · ');
    return ListTile(
      leading: SizedBox(
        width: 52,
        height: 52,
        child: works.isNotEmpty
            ? WorkCover(
                work: works.first,
                borderRadius: BorderRadius.circular(8),
                iconSize: 24,
              )
            : videos.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: VideoCover(coverPath: videos.first.coverPath),
              )
            : Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bookmark_outline,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
      title: Text(collection.name),
      subtitle: Text(counts),
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
