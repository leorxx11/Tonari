import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import 'import_flow.dart';

/// Background pass triggered on app start: for every Work flagged with
/// `needsRescan` (e.g. set by a schema migration that introduced new file
/// kinds), re-import its source folder so the new tables are populated.
///
/// Failures (bookmark stale, folder gone, scan throws) are silently
/// skipped — the flag stays set and we'll retry next launch. Cleared on
/// success by [ImportService.applyScanResult].
class RescanService {
  RescanService({required this.db, required this.flow});
  final TonariDatabase db;
  final ImportFlow flow;

  Future<void> runPending() async {
    try {
      final pendingWorks = await (db.select(db.works)
            ..where((w) => w.needsRescan.equals(true)))
          .get();
      if (pendingWorks.isEmpty) return;

      final folderIds = <String>{
        for (final w in pendingWorks)
          if (w.importedFolderId != null) w.importedFolderId!,
      };
      if (folderIds.isEmpty) {
        // Legacy works with no bound folder: nothing we can do; clear the
        // flag so we stop retrying them every launch.
        await (db.update(db.works)
              ..where((w) =>
                  w.needsRescan.equals(true) & w.importedFolderId.isNull()))
            .write(const WorksCompanion(needsRescan: Value(false)));
        return;
      }

      final folders = await (db.select(db.importedFolders)
            ..where((f) => f.id.isIn(folderIds.toList())))
          .get();

      for (final folder in folders) {
        if (folder.type == 'webdav') continue; // remote rescan: 阶段3
        try {
          await flow.importFromFolder(folder);
        } catch (_) {
          // Skip and retry next launch.
        }
      }
    } catch (_) {
      // Background best-effort: any failure (db not ready in tests, schema
      // upgrade in flight, etc.) is silently ignored.
    }
  }
}

final rescanServiceProvider = Provider<RescanService>((ref) {
  return RescanService(
    db: ref.watch(databaseProvider),
    flow: ref.watch(importFlowProvider),
  );
});
