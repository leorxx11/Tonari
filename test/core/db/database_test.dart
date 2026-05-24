import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/db/database.dart';

void main() {
  late TonariDatabase db;

  setUp(() => db = TonariDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('insert and read back a Work by productId', () async {
    final now = DateTime.now();
    await db.into(db.works).insert(
          WorksCompanion.insert(
            productId: 'RJ01560714',
            title: 'Test Work',
            localImportedAt: now,
            localFolderPath: '/imported/RJ01560714',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final found = await (db.select(db.works)
          ..where((w) => w.productId.equals('RJ01560714')))
        .getSingle();

    expect(found.title, 'Test Work');
    expect(found.isFavorite, false);
    expect(found.voiceActors, isEmpty);
  });

  test('upsert by productId replaces existing row', () async {
    final now = DateTime.now();
    await db.into(db.works).insert(
          WorksCompanion.insert(
            productId: 'RJ123',
            title: 'v1',
            localImportedAt: now,
            localFolderPath: '/a',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.works).insertOnConflictUpdate(
          WorksCompanion.insert(
            productId: 'RJ123',
            title: 'v2',
            localImportedAt: now,
            localFolderPath: '/b',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final found = await (db.select(db.works)
          ..where((w) => w.productId.equals('RJ123')))
        .getSingle();
    expect(found.title, 'v2');
    expect(found.localFolderPath, '/b');
  });

  test('StringListConverter round-trips voiceActors', () async {
    final now = DateTime.now();
    await db.into(db.works).insert(
          WorksCompanion.insert(
            productId: 'RJ_va',
            title: 'VA Test',
            localImportedAt: now,
            localFolderPath: '/va',
            createdAt: now,
            updatedAt: now,
            voiceActors: const Value(['丸井ろん', 'みなみりょう']),
          ),
        );

    final found = await (db.select(db.works)
          ..where((w) => w.productId.equals('RJ_va')))
        .getSingle();
    expect(found.voiceActors, ['丸井ろん', 'みなみりょう']);
  });

  test('Track foreign key references Work', () async {
    final now = DateTime.now();
    await db.into(db.works).insert(
          WorksCompanion.insert(
            productId: 'RJ_fk',
            title: 'FK Test',
            localImportedAt: now,
            localFolderPath: '/fk',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.tracks).insert(
          TracksCompanion.insert(
            id: 'track-1',
            workId: 'RJ_fk',
            filePath: '/fk/track01.mp3',
            fileName: 'track01.mp3',
            fileFormat: 'MP3',
            fileSizeBytes: 1024,
            durationMs: 60000,
            parentDirName: 'fk',
            title: 'Track 1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final tracks = await db.select(db.tracks).get();
    expect(tracks, hasLength(1));
    expect(tracks.first.workId, 'RJ_fk');
  });
}
