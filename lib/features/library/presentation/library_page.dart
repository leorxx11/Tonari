import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../shared/widgets/right_edge_swipe_detector.dart';
import '../data/work_navigation.dart';
import '../data/work_actions_provider.dart';
import '../data/works_providers.dart';
import '../../../shared/widgets/app_drawer.dart';
import 'import_entry.dart';
import 'work_detail_page.dart';
import 'widgets/library_task_status.dart';
import 'widgets/works_grid.dart';
import '../../../core/ui/app_toast.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  bool _searching = false;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final worksAsync = ref.watch(allWorksProvider);
    final sort = ref.watch(workSortProvider);
    final filter = ref.watch(workFilterProvider);
    final forwardWork = ref.watch(libraryForwardWorkProvider);
    final searching = _searching || filter.chips.isNotEmpty;
    return RightEdgeSwipeDetector(
      pageBuilder: forwardWork == null
          ? null
          : (_) => WorkDetailPage(work: forwardWork),
      onNavigationCommitted: forwardWork == null
          ? null
          : () => ref
                .read(lastOpenedWorkIdProvider.notifier)
                .set(forwardWork.productId),
      child: Scaffold(
        appBar: AppBar(
          leading: const DrawerMenuButton(),
          title: searching
              ? _SearchField(
                  controller: _searchController,
                  chips: filter.chips,
                  onQueryChanged: (q) =>
                      ref.read(workFilterProvider.notifier).setSearchQuery(q),
                  onRemoveChip: (c) =>
                      ref.read(workFilterProvider.notifier).removeChip(c),
                )
              : _SourceFilterMenu(
                  current: filter.source,
                  onChanged: (s) =>
                      ref.read(workFilterProvider.notifier).setSource(s),
                ),
          actions: [
            if (searching)
              IconButton(
                tooltip: '关闭搜索',
                icon: const Icon(Icons.close),
                onPressed: _closeSearch,
              )
            else ...[
              IconButton(
                tooltip: '搜索',
                icon: const Icon(Icons.search),
                onPressed: () => setState(() => _searching = true),
              ),
              IconButton(
                tooltip: filter.favoritesOnly ? '取消只看收藏' : '只看收藏',
                icon: Icon(
                  filter.favoritesOnly
                      ? Icons.favorite
                      : Icons.favorite_outline,
                ),
                onPressed: () =>
                    ref.read(workFilterProvider.notifier).toggleFavoritesOnly(),
              ),
            ],
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
            const EnrichmentStatusAction(),
            const LibraryTaskStatusButton(showWhenIdle: false),
          ],
        ),
        body: worksAsync.when(
          // Filter/sort tweaks rebuild the works stream; keep the previous
          // grid on screen during the reload instead of flashing a spinner.
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败：$e')),
          data: (works) => works.isEmpty
              ? _EmptyState(
                  filter: filter,
                  onImport: () => showImportSourcesSheet(context, ref),
                )
              : WorksGrid(works: works, onRemove: _onRemoveWork),
        ),
      ),
    );
  }

  Future<void> _onRemoveWork(Work work) async {
    await ref.read(removeWorkProvider).call(work.productId);
    if (!mounted) return;
    showAppToast('已移除 ${work.title}');
  }

  void _closeSearch() {
    setState(() => _searching = false);
    _searchController.clear();
    ref.read(workFilterProvider.notifier).clearSearch();
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.chips,
    required this.onQueryChanged,
    required this.onRemoveChip,
  });

  final TextEditingController controller;
  final List<WorkChipFilter> chips;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<WorkChipFilter> onRemoveChip;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          if (chips.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.7),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  children: [
                    for (final chip in chips)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _FilterToken(
                          chip: chip,
                          onRemove: () => onRemoveChip(chip),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: chips.isEmpty,
              decoration: InputDecoration(
                hintText: chips.isEmpty ? '搜索 RJ、标题、CV、社团，#标签…' : null,
                border: InputBorder.none,
              ),
              onChanged: onQueryChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterToken extends StatelessWidget {
  const _FilterToken({required this.chip, required this.onRemove});

  final WorkChipFilter chip;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            chipLabel(chip),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.cancel,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceFilterMenu extends StatelessWidget {
  const _SourceFilterMenu({required this.current, required this.onChanged});

  final SourceFilter current;
  final ValueChanged<SourceFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<SourceFilter>(
      tooltip: '来源筛选',
      initialValue: current,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final source in SourceFilter.values)
          PopupMenuItem(
            value: source,
            child: Row(
              children: [
                if (source == current)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 12),
                Text(source.label),
              ],
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            current.label,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

extension on SourceFilter {
  String get label {
    return switch (this) {
      SourceFilter.all => '全部',
      SourceFilter.local => '本地',
      SourceFilter.remote => '远程',
    };
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter, required this.onImport});

  final WorkFilter filter;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFiltered =
        filter.favoritesOnly ||
        filter.searchQuery.trim().isNotEmpty ||
        filter.chips.isNotEmpty ||
        filter.source != SourceFilter.all;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFiltered
                        ? Icons.filter_alt_outlined
                        : Icons.library_music_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isFiltered ? '没有匹配的作品' : '媒体库还是空的',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isFiltered ? '换个搜索词，或者关掉"只看收藏"过滤' : '导入一个包含 RJ 编号的文件夹开始使用',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!isFiltered) ...[
                    const SizedBox(height: 20),
                    FilledButton.tonalIcon(
                      onPressed: onImport,
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('导入'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
