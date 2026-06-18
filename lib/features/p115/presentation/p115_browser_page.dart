import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diagnostic_log.dart';
import '../../../core/ui/root_messenger.dart';
import '../../browse/data/remote_models.dart';
import '../../browse/presentation/remote_browser_page.dart';
import '../../library/data/app_events.dart';
import '../../library/data/enrichment_queue.dart';
import '../../library/data/import_service.dart';
import '../../library/data/library_task_controller.dart';
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
        DiagnosticLog.write('p115_browser', 'resolve_file_start', {
          'entryId': entry.id,
          'extension': _extension(entry.name),
          'hasPickcode': entry.pickcode != null,
          'pickcodeTail': entry.pickcode == null
              ? null
              : _tail(entry.pickcode!),
        });
        try {
          final client = ref.read(p115ClientProvider);
          final resolved = entry.isVideo
              ? await client.resolveVideoUrl(entry.pickcode!)
              : await client.resolveAudioUrl(entry.pickcode!);
          DiagnosticLog.write('p115_browser', 'resolve_file_done', {
            'entryId': entry.id,
            'urlScheme': resolved.url.scheme,
            'urlHost': resolved.url.host,
          });
          return resolved;
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
    final queue = ref.read(enrichmentQueueProvider.notifier);
    final sink = ref.read(appEventSinkProvider);
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('已在后台导入「${folder.name}」…')),
    );
    unawaited(_runImport(taskController, flow, queue, sink, auth, folder));
  }

  Future<void> _runImport(
    LibraryTaskController taskController,
    P115ImportFlow flow,
    EnrichmentQueue queue,
    AppEventSink sink,
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
            skipExisting: true,
            onProgress: (_, current) {
              final stage = current.startsWith('下载字幕') ? '下载字幕' : '扫描文件';
              task.update(stage: stage, message: current);
            },
          );
          task.update(stage: '写入媒体库', message: '${summary.workIds.length} 个作品');
          return summary;
        },
      );
      unawaited(queue.runPending());
      if (summary.incompleteWorks.isNotEmpty) {
        unawaited(
          sink.log(
            category: 'import',
            severity: 'warning',
            title: '${summary.incompleteWorks.length} 个作品扫描失败',
            detail: '疑似 115 风控，已跳过，可稍后重新导入整个文件夹。',
            sourceName: folder.name,
          ),
        );
      }
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            '「${folder.name}」导入完成：新增 ${summary.worksInserted}，'
            '已有 ${summary.worksSkipped} 跳过，共 ${summary.tracksTotal} 音轨。'
            '封面和元数据后台补全中。'
            '${summary.incompleteWorks.isEmpty ? '' : '\n${summary.incompleteWorks.length} 个作品扫描失败（疑似风控），已跳过，可稍后重新导入。'}',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } on P115AuthExpiredException catch (e) {
      await auth.clearCookie();
      unawaited(
        sink.log(
          category: 'auth',
          title: '115 登录已过期',
          detail: '$e',
          sourceName: folder.name,
          actionKey: 'reauth',
        ),
      );
      messenger?.showSnackBar(
        SnackBar(content: Text('$e'), duration: const Duration(seconds: 6)),
      );
    } catch (e) {
      unawaited(
        sink.log(
          category: e is P115BlockedException ? 'network' : 'import',
          title: e is P115BlockedException
              ? '115 风控，导入已中断'
              : '「${folder.name}」导入失败',
          detail: '$e',
          sourceName: folder.name,
        ),
      );
      messenger?.showSnackBar(
        SnackBar(
          content: Text('「${folder.name}」导入失败：$e'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }
}

String _extension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}

String _tail(String value) {
  if (value.length <= 6) return value;
  return value.substring(value.length - 6);
}
