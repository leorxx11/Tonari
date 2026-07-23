import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final worksAsync = ref.watch(collectionWorksProvider(collectionId));
    if (collection == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    return Scaffold(
      appBar: AppBar(title: Text(collection.name)),
      body: worksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (works) => works.isEmpty
            ? const _EmptyCollection()
            : WorksGrid(
                works: works,
                onRemoveFromCollection: (work) => ref
                    .read(collectionRepositoryProvider)
                    .setMembership(work.productId, collectionId, member: false),
              ),
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
          '分组还是空的\n在媒体库长按作品即可加入',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
