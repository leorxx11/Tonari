import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'converters.dart';
import 'tables/imported_folders.dart';
import 'tables/subtitles.dart';
import 'tables/tracks.dart';
import 'tables/works.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Works, Tracks, Subtitles, ImportedFolders])
class TonariDatabase extends _$TonariDatabase {
  TonariDatabase() : super(_openConnection());

  TonariDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(works, works.isRemoved);
      }
      if (from < 3) {
        await m.addColumn(works, works.importedFolderId);
      }
      if (from < 4) {
        await m.addColumn(works, works.wishlistCount);
        await m.addColumn(works, works.rankDay);
        await m.addColumn(works, works.rankWeek);
        await m.addColumn(works, works.rankMonth);
        await m.addColumn(works, works.supportedLanguages);
      }
      if (from < 5) {
        await m.addColumn(works, works.descriptionImageLocalPaths);
      }
      if (from < 6) {
        await m.addColumn(tracks, tracks.relativePath);
        await _backfillRelativePath();
      }
    },
  );

  /// Compute [tracks.relativePath] for rows imported before schema v6 and
  /// rewrite their ID to the new `workId|relativePath` scheme. Done in-place
  /// so existing [lastPositionMs] / [playCount] survive the upgrade.
  Future<void> _backfillRelativePath() async {
    final rows = await select(tracks).get();
    for (final t in rows) {
      final work = await (select(works)
            ..where((w) => w.productId.equals(t.workId)))
          .getSingleOrNull();
      if (work == null) continue;
      final rel = _relativize(work.localFolderPath, t.filePath);
      final newId = '${t.workId}|${rel.toLowerCase()}';
      if (newId == t.id) {
        await (update(tracks)..where((row) => row.id.equals(t.id)))
            .write(TracksCompanion(relativePath: Value(rel)));
        continue;
      }
      // Rename the row; ON CONFLICT IGNORE absorbs the rare case where a
      // sibling row already has the target id (shouldn't happen since the
      // old scheme was at least as unique, but be safe).
      await customStatement(
        'UPDATE OR IGNORE tracks SET id = ?, relative_path = ? WHERE id = ?',
        [newId, rel, t.id],
      );
      await customStatement(
        'UPDATE works SET last_played_track_id = ? '
        'WHERE last_played_track_id = ?',
        [newId, t.id],
      );
    }
  }

  static String _relativize(String root, String full) {
    if (!full.startsWith(root)) return full;
    var rel = full.substring(root.length);
    while (rel.startsWith('/')) {
      rel = rel.substring(1);
    }
    return rel;
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'tonari');
  }
}
