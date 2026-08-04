import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import 'work_genres.dart';

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

enum WorkChipKind { genre, voiceActor, series }

typedef WorkChipFilter = ({WorkChipKind kind, String value});

String chipLabel(WorkChipFilter chip) => switch (chip.kind) {
  WorkChipKind.genre => '#${chip.value}',
  WorkChipKind.voiceActor => 'CV：${chip.value}',
  WorkChipKind.series => '系列：${chip.value}',
};

bool workMatchesChip(Work w, WorkChipFilter chip) => switch (chip.kind) {
  WorkChipKind.genre => genreNamesOf(w).contains(chip.value),
  WorkChipKind.voiceActor => w.voiceActors.contains(chip.value),
  WorkChipKind.series => w.seriesName == chip.value,
};

class WorkFilter {
  const WorkFilter({
    this.favoritesOnly = false,
    this.searchQuery = '',
    this.source = SourceFilter.all,
    this.chips = const [],
  });

  final bool favoritesOnly;
  final String searchQuery;
  final SourceFilter source;
  final List<WorkChipFilter> chips;

  WorkFilter copyWith({
    bool? favoritesOnly,
    String? searchQuery,
    SourceFilter? source,
    List<WorkChipFilter>? chips,
  }) {
    return WorkFilter(
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      searchQuery: searchQuery ?? this.searchQuery,
      source: source ?? this.source,
      chips: chips ?? this.chips,
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

  void addChip(WorkChipFilter chip) {
    if (state.chips.contains(chip)) return;
    state = state.copyWith(chips: [...state.chips, chip]);
  }

  void removeChip(WorkChipFilter chip) {
    state = state.copyWith(chips: state.chips.where((c) => c != chip).toList());
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: '', chips: const []);
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
  final tagQuery = query.startsWith('#') ? query.substring(1).trim() : null;
  final textQuery = tagQuery == null ? query : '';

  final stream =
      (db.select(db.works)
            ..where((w) {
              var expr = w.isRemoved.equals(false);
              if (filter.favoritesOnly) {
                expr = expr & w.isFavorite.equals(true);
              }
              if (filter.source != SourceFilter.all) {
                final remoteIds = db.selectOnly(db.importedFolders)
                  ..addColumns([db.importedFolders.id])
                  ..where(db.importedFolders.type.equals('local').not());
                if (filter.source == SourceFilter.remote) {
                  expr = expr & w.importedFolderId.isInQuery(remoteIds);
                } else {
                  expr =
                      expr &
                      (w.importedFolderId.isNull() |
                          w.importedFolderId.isInQuery(remoteIds).not());
                }
              }
              return expr;
            })
            ..orderBy([(w) => _orderingFor(sort, w)]))
          .watch();

  final chips = filter.chips;
  if (chips.isEmpty &&
      (tagQuery == null || tagQuery.isEmpty) &&
      textQuery.isEmpty) {
    return stream;
  }
  return stream.map(
    (rows) => rows
        .where(
          (w) =>
              chips.every((c) => workMatchesChip(w, c)) &&
              (tagQuery == null ||
                  tagQuery.isEmpty ||
                  genreNamesOf(
                    w,
                  ).any((n) => n.toLowerCase().contains(tagQuery))) &&
              (textQuery.isEmpty || workMatchesText(w, textQuery)),
        )
        .toList(),
  );
});

/// Free-text search over every field a work is remembered by: RJ numbers,
/// titles in all editions, circle, series, cast lists, tags and notes.
/// Dart-side (not SQL LIKE) so list fields match on parsed values instead
/// of their JSON encoding.
bool workMatchesText(Work w, String query) {
  bool has(String? s) => s != null && s.toLowerCase().contains(query);
  bool hasAny(List<String> list) =>
      list.any((s) => s.toLowerCase().contains(query));
  return has(w.productId) ||
      has(w.originalProductId) ||
      has(w.title) ||
      has(w.titleRomaji) ||
      has(w.titleZh) ||
      has(w.translatedTitle) ||
      has(w.circleName) ||
      has(w.seriesName) ||
      has(w.notes) ||
      hasAny(w.voiceActors) ||
      hasAny(w.illustrators) ||
      hasAny(w.scenarioWriters) ||
      hasAny(w.musicians) ||
      hasAny(w.userTags) ||
      genreNamesOf(w).any((n) => n.toLowerCase().contains(query));
}

final remoteFolderIdsProvider = StreamProvider<Set<String>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.importedFolders)
        ..where((f) => f.type.equals('local').not()))
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
