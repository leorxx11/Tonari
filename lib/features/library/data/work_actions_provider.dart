import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';

typedef RemoveWork = Future<void> Function(String productId);
typedef DeleteWorkPermanently = Future<void> Function(String productId);
typedef ToggleFavorite = Future<void> Function(String productId, bool favorite);

final removeWorkProvider = Provider<RemoveWork>((ref) {
  final db = ref.watch(databaseProvider);
  return removeWorkWithDatabase(db);
});

RemoveWork removeWorkWithDatabase(TonariDatabase db) {
  return (productId) async {
    // Remove = drop the snapshot (tracks/files/subtitles) but keep a tombstone
    // works row flagged isRemoved, so a folder re-import won't resurrect it.
    await db.transaction(() async {
      final trackIds =
          await (db.selectOnly(db.tracks)
                ..addColumns([db.tracks.id])
                ..where(db.tracks.workId.equals(productId)))
              .map((row) => row.read(db.tracks.id)!)
              .get();
      if (trackIds.isNotEmpty) {
        await (db.delete(
          db.subtitles,
        )..where((s) => s.trackId.isIn(trackIds))).go();
      }
      await (db.delete(
        db.tracks,
      )..where((t) => t.workId.equals(productId))).go();
      await (db.delete(
        db.workFiles,
      )..where((f) => f.workId.equals(productId))).go();
      await (db.update(
        db.works,
      )..where((w) => w.productId.equals(productId))).write(
        WorksCompanion(
          isRemoved: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  };
}

final deleteWorkPermanentlyProvider = Provider<DeleteWorkPermanently>((ref) {
  final db = ref.watch(databaseProvider);
  return deleteWorkPermanentlyWithDatabase(db);
});

DeleteWorkPermanently deleteWorkPermanentlyWithDatabase(TonariDatabase db) {
  return (productId) async {
    await db.transaction(() async {
      final trackIds =
          await (db.selectOnly(db.tracks)
                ..addColumns([db.tracks.id])
                ..where(db.tracks.workId.equals(productId)))
              .map((row) => row.read(db.tracks.id)!)
              .get();
      if (trackIds.isNotEmpty) {
        await (db.delete(
          db.subtitles,
        )..where((s) => s.trackId.isIn(trackIds))).go();
      }
      await (db.delete(
        db.tracks,
      )..where((t) => t.workId.equals(productId))).go();
      await (db.delete(
        db.workFiles,
      )..where((f) => f.workId.equals(productId))).go();
      await (db.delete(
        db.works,
      )..where((w) => w.productId.equals(productId))).go();
    });
  };
}

final toggleFavoriteProvider = Provider<ToggleFavorite>((ref) {
  final db = ref.watch(databaseProvider);
  return (productId, favorite) async {
    await (db.update(
      db.works,
    )..where((w) => w.productId.equals(productId))).write(
      WorksCompanion(
        isFavorite: Value(favorite),
        updatedAt: Value(DateTime.now()),
      ),
    );
  };
});
