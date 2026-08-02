import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../data/work_actions_provider.dart';
import '../../data/works_providers.dart';
import '../work_detail_page.dart';
import 'collection_picker_sheet.dart';
import 'work_card.dart';

class WorksGrid extends ConsumerWidget {
  const WorksGrid({
    super.key,
    required this.works,
    this.onRemove,
    this.onRemoveFromCollection,
  });

  final List<Work> works;
  final ValueChanged<Work>? onRemove;
  final ValueChanged<Work>? onRemoveFromCollection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: workGridDelegate,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
      itemCount: works.length,
      itemBuilder: (ctx, i) {
        final work = works[i];
        return WorkGridCard(
          work: work,
          onRemove: onRemove == null ? null : () => onRemove!(work),
          onRemoveFromCollection: onRemoveFromCollection == null
              ? null
              : () => onRemoveFromCollection!(work),
        );
      },
    );
  }
}

const workGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  childAspectRatio: 0.6,
  crossAxisSpacing: 10,
  mainAxisSpacing: 10,
);

/// A [WorkCard] wired to the standard library actions, shared by the library
/// grid and the collection detail page.
class WorkGridCard extends ConsumerWidget {
  const WorkGridCard({
    super.key,
    required this.work,
    this.onRemove,
    this.onRemoveFromCollection,
  });

  final Work work;
  final VoidCallback? onRemove;
  final VoidCallback? onRemoveFromCollection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remoteIds =
        ref.watch(remoteFolderIdsProvider).value ?? const <String>{};
    return WorkCard(
      work: work,
      isRemote:
          work.importedFolderId != null &&
          remoteIds.contains(work.importedFolderId),
      onRemove: onRemove,
      onToggleFavorite: () =>
          ref.read(toggleFavoriteProvider)(work.productId, !work.isFavorite),
      onAddToCollection: () => showCollectionPicker(context, work),
      onRemoveFromCollection: onRemoveFromCollection,
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(builder: (_) => WorkDetailPage(work: work)),
        );
      },
    );
  }
}
