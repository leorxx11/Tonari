import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/library_home_button.dart';
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
          const LibraryHomeButton(),
        ],
      ),
      body: collectionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (collections) => CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 24),
              sliver: SliverGrid(
                gridDelegate: _gridDelegate,
                delegate: SliverChildListDelegate([
                  const _AllFavoritesCard(),
                  for (final c in collections) _CollectionCard(collection: c),
                ]),
              ),
            ),
            if (collections.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Text(
                    '还没有分组，点右上角新建，或在媒体库长按作品加入分组',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: 10,
  crossAxisSpacing: 10,
  childAspectRatio: 0.9,
);

const _favoriteColor = Color(0xFFEC407A);

String _countText(List<Work> works, List<VideoItem> videos) => [
  if (works.isNotEmpty || videos.isEmpty) '${works.length} 个作品',
  if (videos.isNotEmpty) '${videos.length} 个视频',
].join(' · ');

class _AllFavoritesCard extends ConsumerWidget {
  const _AllFavoritesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final works = ref.watch(favoriteWorksProvider).value ?? const [];
    final videos = (ref.watch(videoItemsProvider).value ?? const <VideoItem>[])
        .where((v) => v.isFavorite)
        .toList();
    return _GroupCard(
      title: '全部收藏',
      subtitle: _countText(works, videos),
      cover: _Cover(
        work: works.firstOrNull,
        video: videos.firstOrNull,
        placeholder: Icons.favorite,
        placeholderColor: _favoriteColor,
      ),
      badge: const Icon(Icons.favorite, size: 20, color: _favoriteColor),
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(builder: (_) => const FavoritesDetailPage()),
      ),
    );
  }
}

class _CollectionCard extends ConsumerWidget {
  const _CollectionCard({required this.collection});

  final Collection collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final works =
        ref.watch(collectionWorksProvider(collection.id)).value ?? const [];
    final videos =
        ref.watch(collectionVideosProvider(collection.id)).value ?? const [];
    return _GroupCard(
      title: collection.name,
      subtitle: _countText(works, videos),
      cover: _Cover(
        work: works.firstOrNull,
        video: videos.firstOrNull,
        placeholder: Icons.bookmark_outline,
      ),
      menu: PopupMenuButton<_CollectionAction>(
        tooltip: '分组操作',
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert, size: 20),
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
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => CollectionDetailPage(collectionId: collection.id),
        ),
      ),
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

/// Newest item's cover: works first (their lists are newest-first), then
/// videos, else a tinted placeholder icon.
class _Cover extends StatelessWidget {
  const _Cover({
    required this.work,
    required this.video,
    required this.placeholder,
    this.placeholderColor,
  });

  final Work? work;
  final VideoItem? video;
  final IconData placeholder;
  final Color? placeholderColor;

  @override
  Widget build(BuildContext context) {
    final work = this.work;
    if (work != null) return WorkCover(work: work);
    final video = this.video;
    if (video != null) return VideoCover(coverPath: video.coverPath);
    final theme = Theme.of(context);
    final color = placeholderColor ?? theme.colorScheme.onSurfaceVariant;
    return ColoredBox(
      color: color.withValues(alpha: 0.12),
      child: Icon(placeholder, size: 40, color: color),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.title,
    required this.subtitle,
    required this.cover,
    required this.onTap,
    this.badge,
    this.menu,
  });

  final String title;
  final String subtitle;
  final Widget cover;
  final VoidCallback onTap;
  final Widget? badge;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  cover,
                  if (badge != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: badge,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ?menu,
                    if (menu == null) const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
