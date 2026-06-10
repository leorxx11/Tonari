import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/scanner/file_classifier.dart';
import '../../../core/ui/root_messenger.dart';
import '../../browse/data/remote_models.dart';
import '../../browse/presentation/remote_browser_page.dart';
import '../../library/data/import_service.dart';
import '../../library/data/library_task_controller.dart';
import '../../library/data/metadata_enrichment.dart';
import '../data/webdav_client.dart';
import '../data/webdav_import_flow.dart';

class WebdavBrowserPage extends ConsumerWidget {
  const WebdavBrowserPage({
    super.key,
    required this.server,
    required this.config,
    this.enableImport = false,
  });

  final WebdavServer server;
  final WebdavConfig config;
  final bool enableImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final root = RemoteEntry(
      id: config.normalizedBasePath,
      path: config.normalizedBasePath,
      name: server.name,
      kind: RemoteEntryKind.folder,
      sourceId: server.id,
    );
    return RemoteBrowserPage(
      sourceKind: RemoteSourceKind.webdav,
      sourceId: server.id,
      sourceName: server.name,
      root: root,
      loadFolder: (folder) async {
        final rows = await ref
            .read(webdavClientProvider)
            .list(config, folder.path);
        return rows.map((entry) {
          return RemoteEntry(
            id: entry.path,
            path: entry.path,
            name: entry.name,
            kind: entry.isDir
                ? RemoteEntryKind.folder
                : remoteEntryKindFromFileKind(
                    FileClassifier.classify(entry.name),
                  ),
            size: entry.size,
            sourceId: server.id,
          );
        }).toList();
      },
      resolveFile: (entry) async {
        final auth = config.authHeader;
        return ResolvedMediaUrl(
          url: Uri.parse(config.streamUrl(entry.path)),
          headers: auth == null ? null : {'Authorization': auth},
        );
      },
      importFolder: enableImport
          ? (ctx, folder) => _importFolder(ctx, ref, folder)
          : null,
    );
  }

  Future<void> _importFolder(
    BuildContext context,
    WidgetRef ref,
    RemoteEntry folder,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入到媒体库'),
        content: Text('扫描「${folder.name}」下的所有 RJ 作品并导入媒体库？\n导入在后台进行，可以继续浏览。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (!(confirm ?? false)) return;

    // Capture the flow before the page can be disposed, then run unawaited so
    // the user can keep browsing. Progress is reported via the app-wide
    // messenger, which outlives this page.
    final flow = ref.read(webdavImportFlowProvider);
    final taskController = ref.read(libraryTaskControllerProvider.notifier);
    final enrichment = ref.read(metadataEnrichmentProvider);
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('已在后台导入「${folder.name}」…')),
    );
    unawaited(_runImport(taskController, flow, enrichment, folder));
  }

  Future<void> _runImport(
    LibraryTaskController taskController,
    WebdavImportFlow flow,
    MetadataEnrichmentService enrichment,
    RemoteEntry folder,
  ) async {
    final messenger = rootScaffoldMessengerKey.currentState;
    try {
      final summary = await taskController.run<ImportSummary>(
        kind: LibraryTaskKind.import,
        title: '导入 WebDAV',
        initialStage: '扫描文件',
        action: (task) async {
          task.update(stage: '扫描文件', message: folder.name);
          final summary = await flow.importFolder(
            server: server,
            config: config,
            remotePath: folder.path,
            enrich: false,
            onProgress: (_, current) {
              final stage = current.startsWith('下载字幕') ? '下载字幕' : '扫描文件';
              task.update(stage: stage, message: current);
            },
          );
          task.update(stage: '写入媒体库', message: '${summary.workIds.length} 个作品');
          await _enrichImportedWorks(enrichment, summary, task);
          return summary;
        },
      );
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            '「${folder.name}」导入完成：${summary.worksInserted} 新增 / '
            '${summary.worksUpdated} 更新，共 ${summary.tracksTotal} 音轨。'
            '封面和元数据后台补全中。',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text('「${folder.name}」导入失败：$e'),
          duration: const Duration(seconds: 6),
        ),
      );
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
}
