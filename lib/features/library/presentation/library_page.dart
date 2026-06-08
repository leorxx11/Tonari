import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/files/folder_picker_service.dart';
import '../data/import_flow.dart';
import '../data/import_service.dart';
import '../data/metadata_enrichment.dart';
import '../data/work_actions_provider.dart';
import '../data/works_providers.dart';
import '../../webdav/data/webdav_client.dart';
import '../../webdav/data/webdav_import_flow.dart';
import '../../webdav/data/webdav_server_repository.dart';
import '../../webdav/presentation/webdav_browser_page.dart';
import 'work_detail_page.dart';
import 'widgets/work_card.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  bool _importing = false;
  bool _refreshing = false;
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
    final folders = ref.watch(importedFoldersProvider).value ?? const [];
    final remoteIds =
        ref.watch(remoteFolderIdsProvider).value ?? const <String>{};
    final busy = _importing || _refreshing;
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
            : const Text('媒体库'),
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
          IconButton(
            tooltip: '导入文件夹',
            icon: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.create_new_folder_outlined),
            onPressed: busy ? null : _onImportMenu,
          ),
        ],
      ),
      body: worksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (works) => Column(
          children: [
            if (remoteIds.isNotEmpty)
              _SourceFilterBar(
                current: filter.source,
                onChanged: (s) =>
                    ref.read(workFilterProvider.notifier).setSource(s),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _onPullToRefresh(folders),
                child: works.isEmpty
                    ? _EmptyState(filter: filter)
                    : _WorksGrid(
                        works: works,
                        remoteFolderIds: remoteIds,
                        onRemove: _onRemoveWork,
                        onToggleFavorite: _onToggleFavorite,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onImportMenu() async {
    final servers = await ref.read(webdavServerRepositoryProvider).listAll();
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('本地文件夹'),
              onTap: () {
                Navigator.of(ctx).pop();
                _onImportLocal();
              },
            ),
            for (final s in servers)
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Text(s.name),
                subtitle: const Text('WebDAV'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openWebdavBrowser(s);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWebdavBrowser(WebdavServer server) async {
    final password = await ref
        .read(webdavServerRepositoryProvider)
        .readPassword(server.id);
    final config = WebdavConfig(
      scheme: server.scheme,
      host: server.host,
      port: server.port,
      basePath: server.basePath,
      username: server.username,
      password: password,
    );
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      CupertinoSheetRoute<void>(
        scrollableBuilder: (_, _) =>
            WebdavBrowserPage(server: server, config: config),
        showDragHandle: true,
      ),
    );
  }

  Future<void> _onImportLocal() async {
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
      await _showImportDebugDialog(summary);
    } catch (e) {
      if (!mounted) return;
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(content: Text('导入失败：$e')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _onPullToRefresh(List<ImportedFolder> folders) async {
    if (_importing || _refreshing) return;
    setState(() => _refreshing = true);
    try {
      for (final folder in folders) {
        if (folder.type == 'webdav') {
          await ref.read(webdavImportFlowProvider).rescanFolder(folder);
        } else {
          await ref.read(importFlowProvider).importFromFolder(folder);
        }
      }
      await ref.read(metadataEnrichmentProvider).enrichPending();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刷新失败：$e')));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _onRemoveWork(Work work) async {
    await ref.read(removeWorkProvider).call(work.productId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已移除 ${work.title}')));
  }

  Future<void> _showImportDebugDialog(ImportSummary s) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入诊断'),
        content: SingleChildScrollView(
          child: SelectableText(
            '根路径: ${s.scannedRootPath}\n'
            '\n'
            '总扫描文件: ${s.filesScanned}\n'
            '识别作品: ${s.workIds.length}（新增 ${s.worksInserted} / 更新 ${s.worksUpdated}）\n'
            '识别音轨: ${s.tracksTotal}\n'
            '\n'
            '未识别的子目录 (${s.unrecognizedDirs.length}):\n'
            '${s.unrecognizedDirs.take(20).join("\n")}\n'
            '\n'
            '错误 (${s.scanErrors.length}):\n'
            '${s.scanErrors.take(10).join("\n")}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
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

class _SourceFilterBar extends StatelessWidget {
  const _SourceFilterBar({required this.current, required this.onChanged});

  final SourceFilter current;
  final ValueChanged<SourceFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, SourceFilter value) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: current == value,
        onSelected: (_) => onChanged(value),
      ),
    );
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
        child: Row(
          children: [
            chip('全部', SourceFilter.all),
            chip('本地', SourceFilter.local),
            chip('远程', SourceFilter.remote),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final WorkFilter filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFiltered =
        filter.favoritesOnly || filter.searchQuery.trim().isNotEmpty;
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
