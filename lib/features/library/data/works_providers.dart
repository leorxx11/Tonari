import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';

enum WorkSortMode {
  importedAtDesc('导入时间 ↓'),
  importedAtAsc('导入时间 ↑'),
  productIdAsc('RJ 编号'),
  lastPlayedAtDesc('最近播放');

  const WorkSortMode(this.label);
  final String label;
}

class WorkSort extends Notifier<WorkSortMode> {
  @override
  WorkSortMode build() => WorkSortMode.importedAtDesc;

  void set(WorkSortMode mode) => state = mode;
}

final workSortProvider = NotifierProvider<WorkSort, WorkSortMode>(
  WorkSort.new,
);

final allWorksProvider = StreamProvider<List<Work>>((ref) {
  final db = ref.watch(databaseProvider);
  final sort = ref.watch(workSortProvider);
  return (db.select(db.works)
        ..where((w) => w.isRemoved.equals(false))
        ..orderBy([(w) => _orderingFor(sort, w)]))
      .watch();
});

OrderingTerm _orderingFor(WorkSortMode mode, $WorksTable w) {
  return switch (mode) {
    WorkSortMode.importedAtDesc => OrderingTerm.desc(w.localImportedAt),
    WorkSortMode.importedAtAsc => OrderingTerm.asc(w.localImportedAt),
    WorkSortMode.productIdAsc => OrderingTerm.asc(w.productId),
    WorkSortMode.lastPlayedAtDesc => OrderingTerm(
        expression: w.lastPlayedAt,
        mode: OrderingMode.desc,
        nulls: NullsOrder.last,
      ),
  };
}

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

/// Resolves a Work to the bookmark stored on its source ImportedFolder.
/// Returns null if the work has no linkage (e.g. imported before C2) or
/// the folder was deleted.
final bookmarkForWorkProvider = FutureProvider.family<String?, String>((
  ref,
  productId,
) async {
  final db = ref.watch(databaseProvider);
  final work = await (db.select(
    db.works,
  )..where((w) => w.productId.equals(productId))).getSingleOrNull();
  final folderId = work?.importedFolderId;
  if (folderId == null) return null;
  final folder = await (db.select(
    db.importedFolders,
  )..where((f) => f.id.equals(folderId))).getSingleOrNull();
  return folder?.bookmarkBase64;
});
