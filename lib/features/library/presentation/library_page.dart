import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../settings/presentation/media_sources_page.dart';
import '../data/work_actions_provider.dart';
import '../data/works_providers.dart';
import 'widgets/library_task_status.dart';
import 'widgets/work_card.dart';
import 'work_detail_page.dart';

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
    final remoteIds =
        ref.watch(remoteFolderIdsProvider).value ?? const <String>{};
    final sort = ref.watch(workSortProvider);
    final filter = ref.watch(workFilterProvider);
    return Scaffold(
      appBar: AppBar(
        leading: _searching
            ? IconButton(
                tooltip: '关闭搜索',
                icon: const Icon(Icons.arrow_back),
                onPressed: _closeSearch,
              )
            : null,
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索 RJ 编号或标题…',
                  border: InputBorder.none,
                ),
                onChanged: (q) =>
                    ref.read(workFilterProvider.notifier).setSearchQuery(q),
              )
            : _SourceFilterMenu(
                current: filter.source,
                onChanged: (s) =>
                    ref.read(workFilterProvider.notifier).setSource(s),
              ),
        actions: [
          if (!_searching) ...[
            IconButton(
              tooltip: '搜索',
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searching = true),
            ),
            IconButton(
              tooltip: filter.favoritesOnly ? '取消只看收藏' : '只看收藏',
              icon: Icon(
                filter.favoritesOnly ? Icons.favorite : Icons.favorite_outline,
              ),
              onPressed: () =>
                  ref.read(workFilterProvider.notifier).toggleFavoritesOnly(),
            ),
          ],
          PopupMenuButton<WorkSortMode>(
            tooltip: '排序',
            icon: const Icon(Icons.sort),
            initialValue: sort,
            onSelected: (mode) => ref.read(workSortProvider.notifier).set(mode),
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
          LibraryTaskStatusButton(
            idleTooltip: '导入文件夹',
            idleIcon: const Icon(Icons.create_new_folder_outlined),
            onIdlePressed: _openSources,
          ),
        ],
      ),
      body: worksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (works) => works.isEmpty
            ? _EmptyState(filter: filter)
            : _WorksGrid(
                works: works,
                remoteFolderIds: remoteIds,
                onRemove: _onRemoveWork,
                onToggleFavorite: _onToggleFavorite,
              ),
      ),
    );
  }

  void _openSources() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MediaSourcesPage()));
  }

  Future<void> _onRemoveWork(Work work) async {
    await ref.read(removeWorkProvider).call(work.productId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已移除 ${work.title}')));
  }

  Future<void> _onToggleFavorite(Work work) async {
    final next = !work.isFavorite;
    await ref.read(toggleFavoriteProvider).call(work.productId, next);
  }

  void _closeSearch() {
    setState(() => _searching = false);
    _searchController.clear();
    ref.read(workFilterProvider.notifier).setSearchQuery('');
  }
}

class _WorksGrid extends StatelessWidget {
  const _WorksGrid({
    required this.works,
    required this.remoteFolderIds,
    required this.onRemove,
    required this.onToggleFavorite,
  });

  final List<Work> works;
  final Set<String> remoteFolderIds;
  final ValueChanged<Work> onRemove;
  final ValueChanged<Work> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
      itemCount: works.length,
      itemBuilder: (ctx, i) {
        final work = works[i];
        final isRemote =
            work.importedFolderId != null &&
            remoteFolderIds.contains(work.importedFolderId);
        return WorkCard(
          work: work,
          isRemote: isRemote,
          onRemove: () => onRemove(work),
          onToggleFavorite: () => onToggleFavorite(work),
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => WorkDetailPage(work: work),
              ),
            );
          },
        );
      },
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
  const _EmptyState({required this.filter});

  final WorkFilter filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFiltered =
        filter.favoritesOnly ||
        filter.searchQuery.trim().isNotEmpty ||
        filter.source != SourceFilter.all;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
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
                    isFiltered ? '换个搜索词，或者关掉"只看收藏"过滤' : '点右上角导入一个包含 RJ 编号的文件夹',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
