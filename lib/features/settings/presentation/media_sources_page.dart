import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/files/folder_picker_service.dart';
import '../../library/data/folder_reimport_provider.dart';
import '../../library/data/import_flow.dart';
import '../../library/data/import_service.dart';
import '../../library/data/library_task_controller.dart';
import '../../library/data/metadata_enrichment.dart';
import '../../p115/data/p115_cookie_store.dart';
import '../../p115/presentation/p115_browser_page.dart';
import '../../p115/presentation/p115_login_page.dart';
import '../../webdav/data/webdav_client.dart';
import '../../webdav/data/webdav_server_repository.dart';
import '../../webdav/presentation/webdav_browser_page.dart';

class MediaSourcesPage extends ConsumerStatefulWidget {
  const MediaSourcesPage({super.key});

  @override
  ConsumerState<MediaSourcesPage> createState() => _MediaSourcesPageState();
}

class _MediaSourcesPageState extends ConsumerState<MediaSourcesPage> {
  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(importedFoldersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('媒体来源'),
        actions: [
          IconButton(
            tooltip: '添加来源',
            icon: const Icon(Icons.add),
            onPressed: _addSource,
          ),
        ],
      ),
      body: foldersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (folders) {
          if (folders.isEmpty) return _EmptyState(onAdd: _addSource);
          return ListView.separated(
            itemCount: folders.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _SourceTile(folder: folders[index]),
          );
        },
      ),
    );
  }

  // ---------- Add a new source ----------

  Future<void> _addSource() async {
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
          final summary = await flow.importFromFolder(
            folder,
            enrich: false,
            skipExisting: true,
          );
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
            '扫描失败跳过: ${s.incompleteWorks.length}\n'
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
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('还没有任何媒体来源'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('添加来源'),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends ConsumerWidget {
  const _SourceTile({required this.folder});

  final ImportedFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      workTaskControllerProvider.select(
        (tasks) => tasks[folder.id]?.active ?? false,
      ),
    );
    // Also block while a global import (adding any source) runs — that flow
    // writes works.importedFolderId for this folder and would orphan them if
    // the source were deleted mid-import.
    final globalBusy = ref.watch(
      libraryTaskControllerProvider.select((s) => s.active),
    );
    final busy = active || globalBusy;
    final count = ref.watch(
      folderWorkCountsProvider.select(
        (counts) => counts.value?[folder.id] ?? 0,
      ),
    );
    return ListTile(
      leading: Icon(_iconFor(folder.type)),
      title: Text(folder.displayName),
      subtitle: Text('${_sourceLabel(folder.type)} · $count 个作品'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: busy ? null : () => _rescan(context, ref),
            child: Text(active ? '扫描中' : '刷新'),
          ),
          IconButton(
            tooltip: '删除来源',
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: busy ? null : () => _confirmDelete(context, ref, count),
          ),
        ],
      ),
    );
  }

  Future<void> _rescan(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(workTaskControllerProvider.notifier);
    final reimport = ref.read(reimportFolderProvider);
    try {
      final summary = await controller.run<ImportSummary?>(
        productId: folder.id,
        kind: LibraryTaskKind.import,
        title: '刷新来源',
        initialStage: '扫描文件',
        action: (task) => reimport(folder, task: task),
      );
      if (!context.mounted) return;
      if (summary == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('来源不可用，无法刷新')));
        return;
      }
      final n = summary.workIds.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(n > 0 ? '新增 $n 个作品' : '没有发现新作品')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刷新失败：$e')));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除来源'),
        content: Text(
          count > 0
              ? '将移除来源「${folder.displayName}」及其下 $count 个作品（含播放记录、收藏），不可恢复。确定？'
              : '将移除来源「${folder.displayName}」。确定？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final removed = await ref.read(deleteSourceProvider)(folder.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed > 0
              ? '已删除来源「${folder.displayName}」及 $removed 个作品'
              : '已删除来源「${folder.displayName}」',
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'webdav':
        return Icons.cloud_outlined;
      case 'p115':
        return Icons.folder_special_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  String _sourceLabel(String type) {
    switch (type) {
      case 'webdav':
        return 'WebDAV';
      case 'p115':
        return '115 网盘';
      default:
        return '本地';
    }
  }
}
