import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../p115/data/p115_import_flow.dart';
import '../../webdav/data/webdav_import_flow.dart';
import 'import_flow.dart';
import 'import_service.dart';
import 'library_task_controller.dart';

typedef ReimportFolder =
    Future<ImportSummary?> Function(
      ImportedFolder folder, {
      LibraryTaskReporter? task,
    });

final reimportFolderProvider = Provider<ReimportFolder>((ref) {
  return reimportFolderWithSources(
    localFlow: ref.watch(importFlowProvider),
    webdavFlow: ref.watch(webdavImportFlowProvider),
    p115Flow: ref.watch(p115ImportFlowProvider),
  );
});

ReimportFolder reimportFolderWithSources({
  required ImportFlow localFlow,
  required WebdavImportFlow webdavFlow,
  required P115ImportFlow p115Flow,
}) {
  // A manual folder rescan only picks up works not already in the library
  // (skipExisting); refreshing an existing work's files is done per-work via
  // the detail-page rescan.
  return (folder, {task}) async {
    task?.update(stage: '扫描文件', message: folder.displayName);
    switch (folder.type) {
      case 'webdav':
        return webdavFlow.rescanFolder(folder, skipExisting: true);
      case 'p115':
        return p115Flow.rescanFolder(folder, skipExisting: true);
      case 'local':
        return localFlow.importFromFolder(folder, skipExisting: true);
      default:
        return null;
    }
  };
}
