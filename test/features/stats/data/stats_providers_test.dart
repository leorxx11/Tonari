import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/features/stats/data/stats_providers.dart';

void main() {
  late TonariDatabase db;

  setUp(() => db = TonariDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insertWork(
    String id, {
    String? circleName,
    List<String> voiceActors = const [],
    List<String> genres = const [],
    bool isRemoved = false,
  }) async {
    final now = DateTime.now();
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
            circleName: Value(circleName),
            voiceActors: Value(voiceActors),
            isRemoved: Value(isRemoved),
            genresJson: Value(
              jsonEncode([
                for (final g in genres) {'id': '0', 'name': g},
              ]),
            ),
          ),
        );
  }

  test('counts works per circle, voice actor and genre, ranked', () async {
    await insertWork(
      'RJ1',
      circleName: 'B社',
      voiceActors: ['花澤', '花澤'],
      genres: ['耳舐め', 'バイノーラル'],
    );
    await insertWork(
      'RJ2',
      circleName: 'A社',
      voiceActors: ['花澤', '沢城'],
      genres: ['バイノーラル'],
    );
    await insertWork('RJ3', circleName: 'B社', voiceActors: [' ', '沢城']);
    await insertWork('RJ4', circleName: 'A社', isRemoved: true);

    final stats = computeLibraryStats(
      await (db.select(
        db.works,
      )..where((w) => w.isRemoved.equals(false))).get(),
    );

    expect(stats.circles, [(name: 'B社', count: 2), (name: 'A社', count: 1)]);
    expect(stats.voiceActors, [(name: '沢城', count: 2), (name: '花澤', count: 2)]);
    expect(stats.genres, [(name: 'バイノーラル', count: 2), (name: '耳舐め', count: 1)]);
  });
}
