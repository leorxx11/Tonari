import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';

/// Number of works bound to each imported folder (keyed by folder id),
/// including tombstoned ones — i.e. exactly what a source delete would remove.
final folderWorkCountsProvider = StreamProvider<Map<String, int>>((ref) {
  final db = ref.watch(databaseProvider);
  final countExpr = db.works.productId.count();
  final query = db.selectOnly(db.works)
    ..addColumns([db.works.importedFolderId, countExpr])
    ..groupBy([db.works.importedFolderId]);
  return query.watch().map((rows) {
    final out = <String, int>{};
    for (final row in rows) {
      final folderId = row.read(db.works.importedFolderId);
      if (folderId != null) out[folderId] = row.read(countExpr) ?? 0;
    }
    return out;
  });
});

typedef DeleteSource = Future<int> Function(String folderId);

/// Deletes an imported folder and every work that came from it (tracks, files,
/// subtitles, works rows) in one transaction, returning how many works were
/// removed. Hard delete, no tombstone: the whole source is gone, so re-adding
/// it later brings the works back fresh.
final deleteSourceProvider = Provider<DeleteSource>((ref) {
  return deleteSourceWithDatabase(ref.watch(databaseProvider));
});

DeleteSource deleteSourceWithDatabase(TonariDatabase db) {
  return (folderId) async {
    var deleted = 0;
    await db.transaction(() async {
      final workIds =
          await (db.selectOnly(db.works)
                ..addColumns([db.works.productId])
                ..where(db.works.importedFolderId.equals(folderId)))
              .map((row) => row.read(db.works.productId)!)
              .get();
      deleted = workIds.length;
      if (workIds.isNotEmpty) {
        final trackIds =
            await (db.selectOnly(db.tracks)
                  ..addColumns([db.tracks.id])
                  ..where(db.tracks.workId.isIn(workIds)))
                .map((row) => row.read(db.tracks.id)!)
                .get();
        if (trackIds.isNotEmpty) {
          await (db.delete(
            db.subtitles,
          )..where((s) => s.trackId.isIn(trackIds))).go();
        }
        await (db.delete(db.tracks)..where((t) => t.workId.isIn(workIds))).go();
        await (db.delete(
          db.workFiles,
        )..where((f) => f.workId.isIn(workIds))).go();
        await (db.delete(
          db.works,
        )..where((w) => w.importedFolderId.equals(folderId))).go();
      }
      await (db.delete(
        db.importedFolders,
      )..where((f) => f.id.equals(folderId))).go();
    });
    return deleted;
  };
}
