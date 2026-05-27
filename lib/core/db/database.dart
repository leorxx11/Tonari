import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'converters.dart';
import 'tables/imported_folders.dart';
import 'tables/llm_providers.dart';
import 'tables/subtitles.dart';
import 'tables/tracks.dart';
import 'tables/work_files.dart';
import 'tables/works.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Works, Tracks, WorkFiles, Subtitles, ImportedFolders, LlmProviders],
)
class TonariDatabase extends _$TonariDatabase {
  TonariDatabase() : super(_openConnection());

  TonariDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 10;

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
      if (from < 7) {
        await m.createTable(workFiles);
        await m.addColumn(works, works.needsRescan);
        // Mark every existing work so the background rescan on next launch
        // populates work_files (legacy imports never recorded non-audio).
        await customStatement('UPDATE works SET needs_rescan = 1');
      }
      if (from < 8) {
        await m.addColumn(works, works.originalProductId);
        // Clearing scraped_at causes enrichPending (run on app start) to
        // re-fetch metadata for every existing work, picking up the new
        // translation→original fallback and richer image galleries.
        await customStatement('UPDATE works SET scraped_at = NULL');
      }
      if (from < 9) {
        // v8 cleared scraped_at but left local image caches alone. Sample
        // files are saved by position (smp1.jpg, smp2.jpg…), so any user
        // already on v8 ended up with the translation-edition's sparse
        // gallery occupying smp1..smpN while the newly-fetched original-work
        // images filled smpN+1 onwards — visually mixed editions. Nuke the
        // whole image dir and force one more enrichment pass so everything
        // downloads from scratch.
        await _evictAllImageCaches();
        await customStatement('UPDATE works SET scraped_at = NULL');
      }
      if (from < 10) {
        await m.addColumn(works, works.titleZh);
        await m.addColumn(works, works.descriptionHtmlZh);
        await m.createTable(llmProviders);
      }
    },
  );

  static Future<void> _evictAllImageCaches() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${docs.path}/images');
      if (imagesDir.existsSync()) {
        imagesDir.deleteSync(recursive: true);
      }
    } catch (_) {
      // Best-effort: a stale cache is annoying but not fatal.
    }
  }

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
