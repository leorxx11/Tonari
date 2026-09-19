import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/features/history/data/listen_stats.dart';

void main() {
  late TonariDatabase db;

  setUp(() => db = TonariDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Work> insertWork(
    String id, {
    List<String> voiceActors = const [],
    String? circleName,
  }) async {
    final now = DateTime(2026);
    await db
        .into(db.works)
        .insert(
          WorksCompanion.insert(
            productId: id,
            title: 'work $id',
            localImportedAt: now,
            localFolderPath: '/$id',
            createdAt: now,
            updatedAt: now,
            voiceActors: Value(voiceActors),
            circleName: Value(circleName),
          ),
        );
    return (db.select(
      db.works,
    )..where((w) => w.productId.equals(id))).getSingle();
  }

  test('add accumulates per day and work', () async {
    final repo = ListenLogRepository(db);
    final day1 = DateTime(2026, 9, 19, 23, 59);
    await repo.add('RJ1', day1, 5000);
    await repo.add('RJ1', day1, 4000);
    await repo.add('RJ1', DateTime(2026, 9, 20, 0, 1), 3000);

    final logs = await db.select(db.listenLogs).get();
    expect({for (final l in logs) l.day: l.listenedMs}, {
      '2026-09-19': 9000,
      '2026-09-20': 3000,
    });
  });

  test('totals, week/month windows, daily bars and rankings', () async {
    final a = await insertWork('RJ1', voiceActors: ['花澤'], circleName: 'A社');
    final b = await insertWork(
      'RJ2',
      voiceActors: ['花澤', '沢城'],
      circleName: 'B社',
    );
    const min = 60000;
    ListenLog log(String day, String id, int ms) =>
        ListenLog(day: day, workId: id, listenedMs: ms);
    // 2026-09-19 is a Saturday: the week starts Monday 09-14.
    final stats = computeListenStats(
      [
        log('2026-09-19', 'RJ1', 10 * min),
        log('2026-09-14', 'RJ2', 30 * min),
        log('2026-09-13', 'RJ1', 5 * min),
        log('2026-08-31', 'RJ2', 1 * min),
        log('2026-09-18', 'gone', 7 * min),
      ],
      {a.productId: a, b.productId: b},
      DateTime(2026, 9, 19, 12),
    );

    expect(stats.totalMs, 53 * min);
    expect(stats.weekMs, 47 * min);
    expect(stats.monthMs, 52 * min);
    expect(stats.daily, hasLength(dailyWindow));
    expect(stats.daily.last, (day: DateTime(2026, 9, 19), ms: 10 * min));
    expect(stats.daily.first.day, DateTime(2026, 8, 21));
    expect(stats.daily[stats.daily.length - 2].ms, 7 * min);

    expect([for (final r in stats.topWorks) (r.work.productId, r.ms)], [
      ('RJ2', 31 * min),
      ('RJ1', 15 * min),
    ]);
    expect(stats.topVoiceActors, [
      (name: '花澤', ms: 46 * min),
      (name: '沢城', ms: 31 * min),
    ]);
    expect(stats.topCircles, [
      (name: 'B社', ms: 31 * min),
      (name: 'A社', ms: 15 * min),
    ]);
  });
}
