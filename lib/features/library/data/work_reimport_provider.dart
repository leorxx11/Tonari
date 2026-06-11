import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../p115/data/p115_import_flow.dart';
import '../../webdav/data/webdav_import_flow.dart';
import 'import_flow.dart';
import 'import_service.dart';
import 'library_task_controller.dart';

typedef ReimportWork =
    Future<ImportSummary> Function(Work work, {LibraryTaskReporter? task});

final reimportWorkProvider = Provider<ReimportWork>((ref) {
  return reimportWorkWithSources(
    db: ref.watch(databaseProvider),
    localFlow: ref.watch(importFlowProvider),
    webdavFlow: ref.watch(webdavImportFlowProvider),
    p115Flow: ref.watch(p115ImportFlowProvider),
  );
});

ReimportWork reimportWorkWithSources({
  required TonariDatabase db,
  required ImportFlow localFlow,
  required WebdavImportFlow webdavFlow,
  required P115ImportFlow p115Flow,
}) {
  return (work, {task}) async {
    final folderId = work.importedFolderId;
    if (folderId == null) {
      throw StateError('作品没有原始导入位置，无法重新导入');
    }
    final folder = await (db.select(
      db.importedFolders,
    )..where((f) => f.id.equals(folderId))).getSingleOrNull();
    if (folder == null) {
      throw StateError('原始导入位置已不存在，无法重新导入');
    }

    task?.update(stage: '扫描文件', message: work.productId);
    final ImportSummary? summary;
    switch (folder.type) {
      case 'local':
        summary = await localFlow.reimportWork(work, folder);
      case 'webdav':
        summary = await webdavFlow.reimportWork(work, folder);
      case 'p115':
        summary = await p115Flow.reimportWork(work);
      default:
        throw StateError('未知导入来源：${folder.type}');
    }

    if (summary == null) {
      throw StateError('原始导入位置已不可用，无法重新导入');
    }
    if (summary.incompleteWorks.contains(work.productId)) {
      throw StateError('扫描未完成：${work.productId}');
    }
    if (!summary.workIds.contains(work.productId)) {
      throw StateError('未在原始导入位置找到 ${work.productId}');
    }
    task?.update(stage: '写入媒体库', message: '${summary.tracksTotal} 个音轨');
    return summary;
  };
}
