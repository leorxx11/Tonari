import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../data/library_view_prefs.dart';
import '../../data/work_actions_provider.dart';
import '../../data/works_providers.dart';
import '../open_work_detail.dart';
import 'collection_picker_sheet.dart';
import 'work_card.dart';

class WorksView extends ConsumerWidget {
  const WorksView({
    super.key,
    required this.works,
    this.controller,
    this.onRemove,
  });

  final List<Work> works;
  final ScrollController? controller;
  final ValueChanged<Work>? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(workViewModeProvider);
    Widget item(BuildContext ctx, int i) {
      final work = works[i];
      return LibraryWorkItem(
        work: work,
        mode: mode,
        onRemove: onRemove == null ? null : () => onRemove!(work),
      );
    }

    if (mode == LibraryViewMode.list) {
      return ListView.builder(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemExtent: workListTileExtent,
        itemCount: works.length,
        itemBuilder: item,
      );
    }
    if (mode == LibraryViewMode.card) {
      return ListView.separated(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _cardPadding,
        itemCount: works.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: item,
      );
    }
    return GridView.builder(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: workGridDelegate,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
      itemCount: works.length,
      itemBuilder: item,
    );
  }
}

/// Works as a sliver in the given [mode], for pages that stack several
/// sections in one [CustomScrollView].
Widget workItemsSliver({
  required List<Work> works,
  required LibraryViewMode mode,
  required Widget Function(BuildContext, int) itemBuilder,
}) {
  final delegate = SliverChildBuilderDelegate(
    itemBuilder,
    childCount: works.length,
  );
  if (mode == LibraryViewMode.list) {
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 16),
      sliver: SliverFixedExtentList(
        itemExtent: workListTileExtent,
        delegate: delegate,
      ),
    );
  }
  if (mode == LibraryViewMode.card) {
    return SliverPadding(
      padding: _cardPadding,
      sliver: SliverList.separated(
        itemCount: works.length,
        itemBuilder: itemBuilder,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
      ),
    );
  }
  return SliverPadding(
    padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
    sliver: SliverGrid(gridDelegate: workGridDelegate, delegate: delegate),
  );
}

const _cardPadding = EdgeInsets.fromLTRB(10, 12, 10, 16);

const workGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  childAspectRatio: 0.52,
  crossAxisSpacing: 10,
  mainAxisSpacing: 10,
);

/// A work wired to the standard library actions, rendered as a [WorkCard] or
/// [WorkListTile] per [mode]; shared by the library and collection pages.
class LibraryWorkItem extends ConsumerWidget {
  const LibraryWorkItem({
    super.key,
    required this.work,
    required this.mode,
    this.onRemove,
    this.onRemoveFromCollection,
  });

  final Work work;
  final LibraryViewMode mode;
  final VoidCallback? onRemove;
  final VoidCallback? onRemoveFromCollection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remoteIds =
        ref.watch(remoteFolderIdsProvider).value ?? const <String>{};
    final isRemote =
        work.importedFolderId != null &&
        remoteIds.contains(work.importedFolderId);
    void onToggleFavorite() =>
        ref.read(toggleFavoriteProvider)(work.productId, !work.isFavorite);
    void onAddToCollection() => showCollectionPicker(context, work);
    void onTap() => openWorkDetail(context, ref, work);
    final durationMs = ref.watch(
      workDurationsProvider.select((d) => d.value?[work.productId]),
    );
    if (mode == LibraryViewMode.list) {
      return WorkListTile(
        work: work,
        isRemote: isRemote,
        durationMs: durationMs,
        onRemove: onRemove,
        onToggleFavorite: onToggleFavorite,
        onAddToCollection: onAddToCollection,
        onRemoveFromCollection: onRemoveFromCollection,
        onTap: onTap,
      );
    }
    return WorkCard(
      work: work,
      isRemote: isRemote,
      large: mode == LibraryViewMode.card,
      durationMs: durationMs,
      onRemove: onRemove,
      onToggleFavorite: onToggleFavorite,
      onAddToCollection: onAddToCollection,
      onRemoveFromCollection: onRemoveFromCollection,
      onTap: onTap,
    );
  }
}
