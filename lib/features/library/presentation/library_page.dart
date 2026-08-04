import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/files/folder_picker_service.dart';
import '../data/app_events.dart';
import '../data/enrichment_queue.dart';
import '../data/import_flow.dart';
import '../data/import_service.dart';
import '../data/library_task_controller.dart';
import '../data/work_actions_provider.dart';
import '../data/works_providers.dart';
import '../../p115/data/p115_cookie_store.dart';
import '../../p115/presentation/p115_browser_page.dart';
import '../../p115/presentation/p115_login_page.dart';
import '../../webdav/data/webdav_client.dart';
import '../../webdav/data/webdav_server_repository.dart';
import '../../webdav/presentation/webdav_browser_page.dart';
import '../../webdav/presentation/webdav_settings_page.dart';
import '../../../shared/widgets/app_drawer.dart';
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
    final searching = _searching || filter.chips.isNotEmpty;
    return Scaffold(
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
          const EnrichmentStatusAction(),
          LibraryTaskStatusButton(
            idleTooltip: '导入文件夹',
            idleIcon: const Icon(Icons.create_new_folder_outlined),
            onIdlePressed: _onImportMenu,
          ),
        ],
      ),
      body: worksAsync.when(
        // Filter/sort tweaks rebuild the works stream; keep the previous
        // grid on screen during the reload instead of flashing a spinner.
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (works) => works.isEmpty
            ? _EmptyState(filter: filter)
            : WorksGrid(works: works, onRemove: _onRemoveWork),
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
              ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: const Text('未配置 WebDAV'),
                subtitle: const Text('点此添加服务器'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const WebdavSettingsPage(),
                    ),
                  );
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

    final taskController = ref.read(libraryTaskControllerProvider.notifier);
    final flow = ref.read(importFlowProvider);
    try {
      final summary = await taskController.run<ImportSummary>(
        kind: LibraryTaskKind.import,
        title: '导入本地文件夹',
        initialStage: '扫描文件',
        action: (task) async {
          task.update(stage: '扫描文件', message: folder.displayName);
          final summary = await flow.importFromFolder(
            folder,
            enrich: false,
            skipExisting: true,
          );
          task.update(stage: '写入媒体库', message: '${summary.workIds.length} 个作品');
          return summary;
        },
      );
      if (!mounted) return;
      if (summary.workIds.isEmpty) {
        await ref.read(folderPickerServiceProvider).removeIfEmpty(folder.id);
      }
      unawaited(ref.read(enrichmentQueueProvider.notifier).runPending());
      showAppToast(_importResultText(summary));
    } catch (e) {
      if (!mounted) return;
      unawaited(
        ref
            .read(appEventSinkProvider)
            .log(category: 'import', title: '导入失败', detail: '$e'),
      );
      showAppToast('导入失败：$e');
    }
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

String _importResultText(ImportSummary summary) {
  final incomplete = summary.incompleteWorks.isEmpty
      ? ''
      : '\n${summary.incompleteWorks.length} 个作品扫描失败，已跳过，可稍后重新导入。';
  return '导入完成：新增 ${summary.worksInserted}，'
      '已有 ${summary.worksSkipped} 跳过，共 ${summary.tracksTotal} 音轨。'
      '封面和元数据后台补全中。$incomplete';
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
                hintText: chips.isEmpty ? '搜索 RJ 编号、标题，#标签…' : null,
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
  const _EmptyState({required this.filter});

  final WorkFilter filter;

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
      ),
    );
  }
}
