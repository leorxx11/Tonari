import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../library/data/work_genres.dart';
import '../../library/data/works_providers.dart';

typedef StatEntry = ({String name, int count});

class LibraryStats {
  const LibraryStats({
    required this.circles,
    required this.voiceActors,
    required this.genres,
  });

  final List<StatEntry> circles;
  final List<StatEntry> voiceActors;
  final List<StatEntry> genres;

  List<StatEntry> of(WorkChipKind kind) => switch (kind) {
    WorkChipKind.circle => circles,
    WorkChipKind.voiceActor => voiceActors,
    WorkChipKind.genre => genres,
    WorkChipKind.series => const [],
  };
}

LibraryStats computeLibraryStats(Iterable<Work> works) {
  final circles = <String, int>{};
  final voiceActors = <String, int>{};
  final genres = <String, int>{};
  void bump(Map<String, int> counts, Iterable<String> names) {
    for (final name in names.map((n) => n.trim()).toSet()) {
      if (name.isNotEmpty) counts[name] = (counts[name] ?? 0) + 1;
    }
  }

  for (final w in works) {
    bump(circles, [?w.circleName]);
    bump(voiceActors, w.voiceActors);
    bump(genres, genreNamesOf(w));
  }
  return LibraryStats(
    circles: _ranked(circles),
    voiceActors: _ranked(voiceActors),
    genres: _ranked(genres),
  );
}

List<StatEntry> _ranked(Map<String, int> counts) {
  final entries = [
    for (final e in counts.entries) (name: e.key, count: e.value),
  ];
  entries.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    return byCount != 0 ? byCount : a.name.compareTo(b.name);
  });
  return entries;
}

final libraryStatsProvider = StreamProvider<LibraryStats>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.works,
  )..where((w) => w.isRemoved.equals(false))).watch().map(computeLibraryStats);
});
