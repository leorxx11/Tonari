import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/features/library/data/folder_reimport_provider.dart';

void main() {
  late TonariDatabase db;
  final now = DateTime(2026, 6, 11);

  setUp(() => db = TonariDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seed(String folderId, String rj) async {
    await db
        .into(db.importedFolders)
        .insert(
          ImportedFoldersCompanion.insert(
            id: folderId,
            displayName: folderId,
            bookmarkBase64: '',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.works)
        .insert(
          WorksCompanion.insert(
            productId: rj,
            title: rj,
            localFolderPath: '/x/$rj',
            localImportedAt: now,
            createdAt: now,
            updatedAt: now,
            importedFolderId: Value(folderId),
          ),
        );
    final tid = '$rj|t';
    await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            id: tid,
            workId: rj,
            filePath: '/x/$rj/t.wav',
            fileName: 't.wav',
            fileFormat: 'wav',
            fileSizeBytes: 1,
            durationMs: 0,
            parentDirName: rj,
            title: 't',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.subtitles)
        .insert(
          SubtitlesCompanion.insert(
            id: tid,
            trackId: tid,
            filePath: '/x/$rj/t.vtt',
            fileFormat: 'vtt',
            fileHash: 'h',
            originalLinesJson: '[]',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.workFiles)
        .insert(
          WorkFilesCompanion.insert(
            id: '$rj|img',
            workId: rj,
            filePath: '/x/$rj/c.jpg',
            relativePath: 'c.jpg',
            fileName: 'c.jpg',
            fileKind: 'image',
            fileSizeBytes: 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  test('deleteSourceWithDatabase cascades works and spares other sources', () async {
    await seed('f1', 'RJ001');
    await seed('f2', 'RJ002');

    final removed = await deleteSourceWithDatabase(db)('f1');
    expect(removed, 1);

    // f1 and everything bound to it is gone.
    expect(
      await (db.select(db.importedFolders)..where((f) => f.id.equals('f1'))).get(),
      isEmpty,
    );
    expect(
      await (db.select(db.works)..where((w) => w.productId.equals('RJ001'))).get(),
      isEmpty,
    );
    expect(
      await (db.select(db.tracks)..where((t) => t.workId.equals('RJ001'))).get(),
      isEmpty,
    );
    expect(
      await (db.select(db.subtitles)..where((s) => s.id.equals('RJ001|t'))).get(),
      isEmpty,
    );
    expect(
      await (db.select(db.workFiles)..where((f) => f.workId.equals('RJ001'))).get(),
      isEmpty,
    );

    // f2 is untouched.
    expect(
      await (db.select(db.importedFolders)..where((f) => f.id.equals('f2'))).get(),
      isNotEmpty,
    );
    expect(
      await (db.select(db.works)..where((w) => w.productId.equals('RJ002'))).get(),
      isNotEmpty,
    );
    expect(
      await (db.select(db.tracks)..where((t) => t.workId.equals('RJ002'))).get(),
      isNotEmpty,
    );
  });

  test('deleteSourceWithDatabase removes an empty source and returns 0', () async {
    await db
        .into(db.importedFolders)
        .insert(
          ImportedFoldersCompanion.insert(
            id: 'empty',
            displayName: 'empty',
            bookmarkBase64: '',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final removed = await deleteSourceWithDatabase(db)('empty');
    expect(removed, 0);
    expect(
      await (db.select(db.importedFolders)..where((f) => f.id.equals('empty'))).get(),
      isEmpty,
    );
  });
}
