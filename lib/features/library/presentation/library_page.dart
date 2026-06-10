import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/files/folder_picker_service.dart';
import '../data/import_flow.dart';
import '../data/import_service.dart';
import '../data/library_task_controller.dart';
import '../data/metadata_enrichment.dart';
import '../data/work_actions_provider.dart';
import '../data/works_providers.dart';
import '../../p115/data/p115_cookie_store.dart';
import '../../p115/presentation/p115_browser_page.dart';
import '../../p115/presentation/p115_login_page.dart';
import '../../webdav/data/webdav_client.dart';
import '../../webdav/data/webdav_server_repository.dart';
import '../../webdav/presentation/webdav_browser_page.dart';
import 'widgets/library_task_status.dart';
import 'work_detail_page.dart';
import 'widgets/work_card.dart';

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
            onIdlePressed: _onImportMenu,
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

  Future<void> _onImportMenu() async {
    final servers = await ref.read(webdavServerRepositoryProvider).listAll();
    final p115Cookie = await ref.read(p115CookieProvider.future);
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
            ListTile(
              leading: const Icon(Icons.cloud_queue_outlined),
              title: const Text('115 网盘'),
              subtitle: Text(p115Cookie == null ? '未登录，先登录' : '已登录'),
              onTap: () {
                Navigator.of(ctx).pop();
                _openP115ImportBrowser(loginRequired: p115Cookie == null);
              },
            ),
            if (servers.isEmpty)
              const ListTile(
                enabled: false,
                leading: Icon(Icons.cloud_off_outlined),
                title: Text('未配置 WebDAV'),
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

  Future<void> _openP115ImportBrowser({required bool loginRequired}) async {
    if (loginRequired) {
      final loggedIn = await Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute(builder: (_) => const P115LoginPage()));
      if (loggedIn != true || !mounted) return;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      CupertinoSheetRoute<void>(
        scrollableBuilder: (_, _) => const P115BrowserPage(enableImport: true),
        showDragHandle: true,
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
        scrollableBuilder: (_, _) => WebdavBrowserPage(
          server: server,
          config: config,
          enableImport: true,
        ),
        showDragHandle: true,
      ),
    );
  }

  Future<void> _onImportLocal() async {
    final folder = await ref.read(folderPickerServiceProvider).pickAndPersist();
    if (folder == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final taskController = ref.read(libraryTaskControllerProvider.notifier);
    final flow = ref.read(importFlowProvider);
    final enrichment = ref.read(metadataEnrichmentProvider);
    try {
      final summary = await taskController.run<ImportSummary>(
        kind: LibraryTaskKind.import,
        title: '导入本地文件夹',
        initialStage: '扫描文件',
        action: (task) async {
          task.update(stage: '扫描文件', message: folder.displayName);
          final summary = await flow.importFromFolder(folder, enrich: false);
          task.update(stage: '写入媒体库', message: '${summary.workIds.length} 个作品');
          await _enrichImportedWorks(enrichment, summary, task);
          return summary;
        },
      );
      if (!mounted) return;
      await _showImportDebugDialog(summary);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('导入失败：$e')));
    }
  }

  Future<void> _enrichImportedWorks(
    MetadataEnrichmentService enrichment,
    ImportSummary summary,
    LibraryTaskReporter task,
  ) async {
    if (summary.workIds.isEmpty) return;
    await enrichment.enrichBatch(
      summary.workIds,
      onProgress: (completed, total, current) {
        task.update(
          stage: '补全元数据',
          message: current,
          completed: completed,
          total: total,
        );
      },
    );
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
