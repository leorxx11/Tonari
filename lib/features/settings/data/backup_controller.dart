import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/files/folder_bookmark.dart';
import '../../../core/ui/app_toast.dart';
import '../../library/data/app_events.dart';
import 'backup_service.dart';

typedef BackupRun = ({String stage, int done, int total});

/// Opens a security-scoped session on a picked folder for the duration of
/// [action]. Simulator / in-sandbox folders need no scope, so failures to
/// create one fall back to the raw path.
Future<T> withScopedDir<T>(
  String url,
  Future<T> Function(String dir) action,
) async {
  String? scoped;
  try {
    scoped = (await FolderBookmark.resolve(
      await FolderBookmark.create(url),
    )).url;
  } catch (_) {}
  try {
    return await action(scoped ?? url);
  } finally {
    if (scoped != null) {
      try {
        await FolderBookmark.release(scoped);
      } catch (_) {}
    }
  }
}

/// Runs exports in the background: the app stays usable, the backup page
/// reads progress from here, and the outcome lands in the message inbox.
class BackupController extends Notifier<BackupRun?> {
  @override
  BackupRun? build() => null;

  bool get isRunning => state != null;

  Future<void> export(String pickedUrl, Set<BackupDir> dirs) async {
    if (isRunning) return;
    state = (stage: '准备中', done: 0, total: 0);
    showAppToast('已开始后台备份，完成后会在消息里通知');
    final events = ref.read(appEventSinkProvider);
    try {
      final path = await withScopedDir(
        pickedUrl,
        (dir) => ref
            .read(backupServiceProvider)
            .export(targetDir: dir, dirs: dirs, onProgress: _onProgress),
      );
      final name = p.basename(path);
      await events.log(
        category: 'backup',
        severity: 'info',
        title: '备份完成',
        detail: name,
      );
      showAppToast('备份完成：$name');
    } catch (e) {
      await events.log(category: 'backup', title: '备份失败', detail: '$e');
      showAppToast('备份失败：$e');
    } finally {
      state = null;
    }
  }

  // Image caches are thousands of small files; only repaint per percent.
  void _onProgress(String stage, int done, int total) {
    final current = state;
    if (current != null &&
        current.stage == stage &&
        total > 0 &&
        current.total == total &&
        done * 100 ~/ total == current.done * 100 ~/ total) {
      return;
    }
    state = (stage: stage, done: done, total: total);
  }
}

final backupControllerProvider = NotifierProvider<BackupController, BackupRun?>(
  BackupController.new,
);
