import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../browse/data/remote_models.dart';

class PlayHistoryRepository {
  PlayHistoryRepository(this._db);

  final TonariDatabase _db;
  static const maxEntries = 200;

  Future<void> recordWork(Work work) {
    return _record(
      PlayHistoryEntriesCompanion.insert(
        id: 'work:${work.productId}',
        kind: 'work',
        title: work.title,
        workId: Value(work.productId),
        playedAt: DateTime.now(),
      ),
    );
  }

  Future<void> recordItem(
    PlayableItem item, {
    int positionMs = 0,
    int? durationMs,
  }) {
    return _record(
      PlayHistoryEntriesCompanion.insert(
        id: item.stableId,
        kind: item.isVideo ? 'video' : 'audio',
        title: item.title,
        sourceKind: Value(item.sourceKind.name),
        sourceId: Value(item.sourceId),
        sourceName: Value(item.sourceName),
        path: Value(item.path),
        fileName: Value(item.fileName),
        pickcode: Value(item.pickcode),
        size: Value(item.size),
        positionMs: Value(positionMs),
        durationMs: Value(durationMs),
        playedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _record(PlayHistoryEntriesCompanion entry) async {
    await _db.into(_db.playHistoryEntries).insertOnConflictUpdate(entry);
    await _db.customStatement(
      'DELETE FROM play_history_entries WHERE id NOT IN '
      '(SELECT id FROM play_history_entries ORDER BY played_at DESC LIMIT ?)',
      [maxEntries],
    );
  }

  Future<int?> positionMsOf(String id) async {
    final row = await (_db.select(
      _db.playHistoryEntries,
    )..where((e) => e.id.equals(id))).getSingleOrNull();
    return row?.positionMs;
  }

  Future<void> remove(String id) async {
    await (_db.delete(
      _db.playHistoryEntries,
    )..where((e) => e.id.equals(id))).go();
  }

  Future<void> clear() async {
    await _db.delete(_db.playHistoryEntries).go();
  }
}

final playHistoryRepositoryProvider = Provider<PlayHistoryRepository>((ref) {
  return PlayHistoryRepository(ref.watch(databaseProvider));
});

final playHistoryProvider = StreamProvider<List<PlayHistoryEntry>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.playHistoryEntries,
  )..orderBy([(e) => OrderingTerm.desc(e.playedAt)])).watch();
});
