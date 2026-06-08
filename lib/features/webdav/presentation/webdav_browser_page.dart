import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/scanner/file_classifier.dart';
import '../../browse/data/remote_models.dart';
import '../../browse/presentation/remote_browser_page.dart';
import '../data/webdav_client.dart';
import '../data/webdav_import_flow.dart';

class WebdavBrowserPage extends ConsumerWidget {
  const WebdavBrowserPage({
    super.key,
    required this.server,
    required this.config,
  });

  final WebdavServer server;
  final WebdavConfig config;

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
      importFolder: (ctx, folder) => _importFolder(ctx, ref, folder),
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
        content: Text('扫描「${folder.name}」下的所有 RJ 作品并导入媒体库？'),
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
    if (!(confirm ?? false) || !context.mounted) return;

    final progress = ValueNotifier<String>('准备扫描…');
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: progress,
                  builder: (_, msg, _) => Text(msg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    try {
      final summary = await ref
          .read(webdavImportFlowProvider)
          .importFolder(
            server: server,
            config: config,
            remotePath: folder.path,
            onProgress: (n, cur) => progress.value = '已扫描 $n 个作品\n$cur',
          );
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '导入完成：${summary.worksInserted} 新增 / ${summary.worksUpdated} 更新，'
            '共 ${summary.tracksTotal} 音轨。封面和元数据后台补全中。',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入失败：$e')));
    } finally {
      progress.dispose();
    }
  }
}
