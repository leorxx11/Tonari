import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/files/folder_picker_service.dart';
import '../../../core/ui/app_toast.dart';
import '../../p115/data/p115_cookie_store.dart';
import '../../p115/presentation/p115_browser_page.dart';
import '../../p115/presentation/p115_login_page.dart';
import '../../webdav/data/webdav_client.dart';
import '../../webdav/data/webdav_server_repository.dart';
import '../../webdav/presentation/webdav_browser_page.dart';
import '../../webdav/presentation/webdav_settings_page.dart';
import '../data/app_events.dart';
import '../data/enrichment_queue.dart';
import '../data/import_flow.dart';
import '../data/import_service.dart';
import '../data/library_task_controller.dart';

/// Bottom sheet listing every import source (local folder / 115 / WebDAV).
/// Shared by the library empty state and 设置 → 数据管理.
Future<void> showImportSourcesSheet(BuildContext context, WidgetRef ref) async {
  final servers = await ref.read(webdavServerRepositoryProvider).listAll();
  final p115Cookie = await ref.read(p115CookieProvider.future);
  if (!context.mounted) return;
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
              _importLocalFolder(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_queue_outlined),
            title: const Text('115 网盘'),
            subtitle: Text(p115Cookie == null ? '未登录，先登录' : '已登录'),
            onTap: () {
              Navigator.of(ctx).pop();
              _openP115Browser(context, loginRequired: p115Cookie == null);
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
                _openWebdavBrowser(context, ref, s);
              },
            ),
        ],
      ),
    ),
  );
}

Future<void> _openP115Browser(
  BuildContext context, {
  required bool loginRequired,
}) async {
  if (loginRequired) {
    final loggedIn = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const P115LoginPage()));
    if (loggedIn != true || !context.mounted) return;
  }
  Navigator.of(context, rootNavigator: true).push(
    CupertinoSheetRoute<void>(
      scrollableBuilder: (_, _) => const P115BrowserPage(enableImport: true),
      showDragHandle: true,
    ),
  );
}

Future<void> _openWebdavBrowser(
  BuildContext context,
  WidgetRef ref,
  WebdavServer server,
) async {
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
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).push(
    CupertinoSheetRoute<void>(
      scrollableBuilder: (_, _) =>
          WebdavBrowserPage(server: server, config: config, enableImport: true),
      showDragHandle: true,
    ),
  );
}

Future<void> _importLocalFolder(BuildContext context, WidgetRef ref) async {
  final folder = await ref.read(folderPickerServiceProvider).pickAndPersist();
  if (folder == null || !context.mounted) return;

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
    if (!context.mounted) return;
    if (summary.workIds.isEmpty) {
      await ref.read(folderPickerServiceProvider).removeIfEmpty(folder.id);
    }
    unawaited(ref.read(enrichmentQueueProvider.notifier).runPending());
    showAppToast(_importResultText(summary));
  } catch (e) {
    if (!context.mounted) return;
    unawaited(
      ref
          .read(appEventSinkProvider)
          .log(category: 'import', title: '导入失败', detail: '$e'),
    );
    showAppToast('导入失败：$e');
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
