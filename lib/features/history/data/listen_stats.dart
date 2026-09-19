import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';

String listenDayKey(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)}';

String _two(int n) => n.toString().padLeft(2, '0');

class ListenLogRepository {
  ListenLogRepository(this._db);

  final TonariDatabase _db;

  Future<void> add(String workId, DateTime at, int ms) => _db
      .into(_db.listenLogs)
      .insert(
        ListenLogsCompanion.insert(
          day: listenDayKey(at),
          workId: workId,
          listenedMs: ms,
        ),
        onConflict: DoUpdate(
          (old) => ListenLogsCompanion.custom(
            listenedMs: old.listenedMs + Constant(ms),
          ),
        ),
      );
}

final listenLogRepositoryProvider = Provider<ListenLogRepository>(
  (ref) => ListenLogRepository(ref.watch(databaseProvider)),
);

typedef RankedWork = ({Work work, int ms});
typedef RankedName = ({String name, int ms});

class ListenStats {
  const ListenStats({
    required this.totalMs,
    required this.weekMs,
    required this.monthMs,
    required this.daily,
    required this.topWorks,
    required this.topVoiceActors,
    required this.topCircles,
  });

  final int totalMs;
  final int weekMs;
  final int monthMs;

  /// The last 30 days, oldest first, zero-filled.
  final List<({DateTime day, int ms})> daily;
  final List<RankedWork> topWorks;
  final List<RankedName> topVoiceActors;
  final List<RankedName> topCircles;

  bool get isEmpty => totalMs == 0;
}

const _topN = 10;
const dailyWindow = 30;

ListenStats computeListenStats(
  List<ListenLog> logs,
  Map<String, Work> worksById,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = listenDayKey(
    today.subtract(Duration(days: today.weekday - 1)),
  );
  final monthStart = listenDayKey(DateTime(now.year, now.month));
  final byDay = <String, int>{};
  final byWork = <String, int>{};
  var total = 0, week = 0, month = 0;
  for (final log in logs) {
    total += log.listenedMs;
    // yyyy-MM-dd keys compare chronologically as strings.
    if (log.day.compareTo(weekStart) >= 0) week += log.listenedMs;
    if (log.day.compareTo(monthStart) >= 0) month += log.listenedMs;
    byDay[log.day] = (byDay[log.day] ?? 0) + log.listenedMs;
    byWork[log.workId] = (byWork[log.workId] ?? 0) + log.listenedMs;
  }

  final voiceActors = <String, int>{};
  final circles = <String, int>{};
  final works = <RankedWork>[];
  for (final MapEntry(key: id, value: ms) in byWork.entries) {
    final work = worksById[id];
    if (work == null) continue;
    works.add((work: work, ms: ms));
    for (final cv in work.voiceActors.toSet()) {
      voiceActors[cv] = (voiceActors[cv] ?? 0) + ms;
    }
    final circle = work.circleName;
    if (circle != null && circle.isNotEmpty) {
      circles[circle] = (circles[circle] ?? 0) + ms;
    }
  }
  works.sort((a, b) => b.ms.compareTo(a.ms));

  return ListenStats(
    totalMs: total,
    weekMs: week,
    monthMs: month,
    daily: [
      for (var i = dailyWindow - 1; i >= 0; i--)
        () {
          final day = DateTime(today.year, today.month, today.day - i);
          return (day: day, ms: byDay[listenDayKey(day)] ?? 0);
        }(),
    ],
    topWorks: works.take(_topN).toList(),
    topVoiceActors: _top(voiceActors),
    topCircles: _top(circles),
  );
}

List<RankedName> _top(Map<String, int> ms) {
  final entries = [for (final e in ms.entries) (name: e.key, ms: e.value)]
    ..sort((a, b) => b.ms.compareTo(a.ms));
  return entries.take(_topN).toList();
}

final listenStatsProvider = StreamProvider<ListenStats>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.listenLogs).watch().asyncMap((logs) async {
    final ids = logs.map((l) => l.workId).toSet();
    final works = await (db.select(
      db.works,
    )..where((w) => w.productId.isIn(ids))).get();
    return computeListenStats(logs, {
      for (final w in works) w.productId: w,
    }, DateTime.now());
  });
});
