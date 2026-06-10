import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/root_messenger.dart';
import '../../browse/data/remote_models.dart';
import '../../browse/presentation/remote_browser_page.dart';
import '../../library/data/import_service.dart';
import '../../library/data/library_task_controller.dart';
import '../../library/data/metadata_enrichment.dart';
import '../data/p115_auth_service.dart';
import '../data/p115_client.dart';
import '../data/p115_cookie_store.dart';
import '../data/p115_import_flow.dart';

class P115BrowserPage extends ConsumerWidget {
  const P115BrowserPage({super.key, this.enableImport = false});

  final bool enableImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const root = RemoteEntry(
      id: '0',
      path: '0',
      name: P115Client.sourceName,
      kind: RemoteEntryKind.folder,
      sourceId: P115Client.sourceId,
    );
    return RemoteBrowserPage(
      sourceKind: RemoteSourceKind.p115,
      sourceId: P115Client.sourceId,
      sourceName: P115Client.sourceName,
      root: root,
      loadFolder: (folder) async {
        try {
          return await ref.read(p115ClientProvider).list(folder.path);
        } on P115AuthExpiredException {
          await ref.read(p115AuthServiceProvider).clearCookie();
          ref.invalidate(p115CookieProvider);
          if (context.mounted) Navigator.of(context).maybePop();
          rethrow;
        }
      },
      resolveFile: (entry) async {
        try {
          return await ref
              .read(p115ClientProvider)
              .resolveDownloadUrl(entry.pickcode!);
        } on P115AuthExpiredException {
          await ref.read(p115AuthServiceProvider).clearCookie();
          ref.invalidate(p115CookieProvider);
          if (context.mounted) Navigator.of(context).maybePop();
          rethrow;
        }
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

    final flow = ref.read(p115ImportFlowProvider);
    final auth = ref.read(p115AuthServiceProvider);
    final taskController = ref.read(libraryTaskControllerProvider.notifier);
    final enrichment = ref.read(metadataEnrichmentProvider);
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('已在后台导入「${folder.name}」…')),
    );
    unawaited(_runImport(taskController, flow, enrichment, auth, folder));
  }

  Future<void> _runImport(
    LibraryTaskController taskController,
    P115ImportFlow flow,
    MetadataEnrichmentService enrichment,
    P115AuthService auth,
    RemoteEntry folder,
  ) async {
    final messenger = rootScaffoldMessengerKey.currentState;
    try {
      final summary = await taskController.run<ImportSummary>(
        kind: LibraryTaskKind.import,
        title: '导入 115 网盘',
        initialStage: '扫描文件',
        action: (task) async {
          task.update(stage: '扫描文件', message: folder.name);
          final summary = await flow.importFolder(
            folder: folder,
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
            '封面和元数据后台补全中。'
            '${summary.incompleteWorks.isEmpty ? '' : '\n${summary.incompleteWorks.length} 个作品扫描失败（疑似风控），已跳过，可稍后重新导入。'}',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } on P115AuthExpiredException catch (e) {
      await auth.clearCookie();
      messenger?.showSnackBar(
        SnackBar(content: Text('$e'), duration: const Duration(seconds: 6)),
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
