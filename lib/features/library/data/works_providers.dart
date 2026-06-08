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

final workSortProvider = NotifierProvider<WorkSort, WorkSortMode>(WorkSort.new);

enum SourceFilter { all, local, remote }

class WorkFilter {
  const WorkFilter({
    this.favoritesOnly = false,
    this.searchQuery = '',
    this.source = SourceFilter.all,
  });

  final bool favoritesOnly;
  final String searchQuery;
  final SourceFilter source;

  WorkFilter copyWith({
    bool? favoritesOnly,
    String? searchQuery,
    SourceFilter? source,
  }) {
    return WorkFilter(
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      searchQuery: searchQuery ?? this.searchQuery,
      source: source ?? this.source,
    );
  }
}

class WorkFilterNotifier extends Notifier<WorkFilter> {
  @override
  WorkFilter build() => const WorkFilter();

  void toggleFavoritesOnly() {
    state = state.copyWith(favoritesOnly: !state.favoritesOnly);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSource(SourceFilter source) {
    state = state.copyWith(source: source);
  }
}

final workFilterProvider = NotifierProvider<WorkFilterNotifier, WorkFilter>(
  WorkFilterNotifier.new,
);

final allWorksProvider = StreamProvider<List<Work>>((ref) {
  final db = ref.watch(databaseProvider);
  final sort = ref.watch(workSortProvider);
  final filter = ref.watch(workFilterProvider);
  final query = filter.searchQuery.trim().toLowerCase();

  return (db.select(db.works)
        ..where((w) {
          var expr = w.isRemoved.equals(false);
          if (filter.favoritesOnly) {
            expr = expr & w.isFavorite.equals(true);
          }
          if (query.isNotEmpty) {
            final like = '%$query%';
            expr =
                expr &
                (w.productId.lower().like(like) | w.title.lower().like(like));
          }
          if (filter.source != SourceFilter.all) {
            final webdavIds = db.selectOnly(db.importedFolders)
              ..addColumns([db.importedFolders.id])
              ..where(db.importedFolders.type.equals('webdav'));
            if (filter.source == SourceFilter.remote) {
              expr = expr & w.importedFolderId.isInQuery(webdavIds);
            } else {
              expr =
                  expr &
                  (w.importedFolderId.isNull() |
                      w.importedFolderId.isInQuery(webdavIds).not());
            }
          }
          return expr;
        })
        ..orderBy([(w) => _orderingFor(sort, w)]))
      .watch();
});

final remoteFolderIdsProvider = StreamProvider<Set<String>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.importedFolders)..where((f) => f.type.equals('webdav')))
      .watch()
      .map((rows) => rows.map((f) => f.id).toSet());
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

final workFilesByWorkProvider = StreamProvider.family<List<WorkFile>, String>((
  ref,
  workId,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.workFiles)
        ..where((f) => f.workId.equals(workId))
        ..orderBy([(f) => OrderingTerm.asc(f.relativePath)]))
      .watch();
});

final workByIdProvider = StreamProvider.family<Work?, String>((ref, productId) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.works,
  )..where((w) => w.productId.equals(productId))).watchSingleOrNull();
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
