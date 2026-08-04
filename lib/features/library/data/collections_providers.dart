import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';

final collectionsProvider = StreamProvider<List<Collection>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.collections)..orderBy([
        (c) => OrderingTerm.asc(c.sortOrder),
        (c) => OrderingTerm.asc(c.createdAt),
      ]))
      .watch();
});

final favoriteWorksProvider = StreamProvider<List<Work>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.works)
        ..where((w) => w.isFavorite.equals(true) & w.isRemoved.equals(false))
        ..orderBy([(w) => OrderingTerm.desc(w.localImportedAt)]))
      .watch();
});

final collectionWorksProvider = StreamProvider.family<List<Work>, String>((
  ref,
  collectionId,
) {
  final db = ref.watch(databaseProvider);
  final query =
      db.select(db.works).join([
          innerJoin(
            db.collectionWorks,
            db.collectionWorks.workId.equalsExp(db.works.productId),
          ),
        ])
        ..where(
          db.collectionWorks.collectionId.equals(collectionId) &
              db.works.isRemoved.equals(false),
        )
        ..orderBy([OrderingTerm.desc(db.collectionWorks.addedAt)]);
  return query.watch().map(
    (rows) => rows.map((r) => r.readTable(db.works)).toList(),
  );
});

final workCollectionIdsProvider = StreamProvider.family<Set<String>, String>((
  ref,
  workId,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.collectionWorks)
        ..where((cw) => cw.workId.equals(workId)))
      .watch()
      .map((rows) => rows.map((r) => r.collectionId).toSet());
});

final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  return CollectionRepository(ref.watch(databaseProvider));
});

class CollectionRepository {
  CollectionRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final TonariDatabase _db;
  final Uuid _uuid;

  Future<String> create(String name) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db
        .into(_db.collections)
        .insert(
          CollectionsCompanion.insert(
            id: id,
            name: name,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> rename(String id, String name) async {
    await (_db.update(_db.collections)..where((c) => c.id.equals(id))).write(
      CollectionsCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> delete(String id) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.collectionWorks,
      )..where((cw) => cw.collectionId.equals(id))).go();
      await (_db.delete(
        _db.collectionVideos,
      )..where((cv) => cv.collectionId.equals(id))).go();
      await (_db.delete(_db.collections)..where((c) => c.id.equals(id))).go();
    });
  }

  Future<void> setMembership(
    String workId,
    String collectionId, {
    required bool member,
  }) async {
    if (member) {
      await _db
          .into(_db.collectionWorks)
          .insert(
            CollectionWorksCompanion.insert(
              collectionId: collectionId,
              workId: workId,
              addedAt: DateTime.now(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    } else {
      await (_db.delete(_db.collectionWorks)..where(
            (cw) =>
                cw.collectionId.equals(collectionId) & cw.workId.equals(workId),
          ))
          .go();
    }
  }
}
