import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';

final allWorksProvider = StreamProvider<List<Work>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.works)
        ..where((w) => w.isRemoved.equals(false))
        ..orderBy([(w) => OrderingTerm.desc(w.localImportedAt)]))
      .watch();
});

final removedWorksProvider = StreamProvider<List<Work>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.works)
        ..where((w) => w.isRemoved.equals(true))
        ..orderBy([(w) => OrderingTerm.desc(w.updatedAt)]))
      .watch();
});

final tracksByWorkProvider = StreamProvider.family<List<Track>, String>((
  ref,
  workId,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.tracks)
        ..where((t) => t.workId.equals(workId))
        ..orderBy([(t) => OrderingTerm.asc(t.filePath)]))
      .watch();
});
