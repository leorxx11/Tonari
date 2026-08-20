import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/library_home_button.dart';
import '../../video_library/data/video_library_providers.dart';
import '../../video_library/presentation/video_library_page.dart';
import '../data/collections_providers.dart';
import 'widgets/works_grid.dart';

class CollectionDetailPage extends ConsumerWidget {
  const CollectionDetailPage({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider).value ?? const [];
    final collection = collections
        .where((c) => c.id == collectionId)
        .firstOrNull;
    final works = ref.watch(collectionWorksProvider(collectionId)).value;
    final videos = ref.watch(collectionVideosProvider(collectionId)).value;
    if (collection == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final loading = works == null || videos == null;
    final empty = !loading && works.isEmpty && videos.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(collection.name),
        actions: const [LibraryHomeButton()],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : empty
          ? const _EmptyCollection()
          : CustomScrollView(
              slivers: [
                if (works.isNotEmpty) ...[
                  if (videos.isNotEmpty) const _SectionHeader('音声'),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                    sliver: SliverGrid(
                      gridDelegate: workGridDelegate,
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => WorkGridCard(
                          work: works[i],
                          onRemoveFromCollection: () => ref
                              .read(collectionRepositoryProvider)
                              .setMembership(
                                works[i].productId,
                                collectionId,
                                member: false,
                              ),
                        ),
                        childCount: works.length,
                      ),
                    ),
                  ),
                ],
                if (videos.isNotEmpty) ...[
                  if (works.isNotEmpty) const _SectionHeader('视频'),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.15,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => VideoCard(
                          item: videos[i],
                          onRemoveFromCollection: () => ref
                              .read(videoLibraryRepositoryProvider)
                              .setCollectionMembership(
                                videos[i].id,
                                collectionId,
                                member: false,
                              ),
                        ),
                        childCount: videos.length,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class FavoritesDetailPage extends ConsumerWidget {
  const FavoritesDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final works = ref.watch(favoriteWorksProvider).value;
    final allVideos = ref.watch(videoItemsProvider).value;
    final videos = allVideos?.where((v) => v.isFavorite).toList();
    final loading = works == null || videos == null;
    final empty = !loading && works.isEmpty && videos.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('全部收藏'),
        actions: const [LibraryHomeButton()],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : empty
          ? const _EmptyFavorites()
          : CustomScrollView(
              slivers: [
                if (works.isNotEmpty) ...[
                  if (videos.isNotEmpty) const _SectionHeader('音声'),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                    sliver: SliverGrid(
                      gridDelegate: workGridDelegate,
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => WorkGridCard(work: works[i]),
                        childCount: works.length,
                      ),
                    ),
                  ),
                ],
                if (videos.isNotEmpty) ...[
                  if (works.isNotEmpty) const _SectionHeader('视频'),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.15,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => VideoCard(item: videos[i]),
                        childCount: videos.length,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          '还没有收藏\n点作品卡片右下角或详情页的红心即可加入',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: Text(title, style: Theme.of(context).textTheme.labelLarge),
      ),
    );
  }
}

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          '分组还是空的\n在媒体库长按作品或视频即可加入',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
