import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/core/files/folder_picker_service.dart';

void main() {
  late TonariDatabase db;
  late FolderPickerService service;
  final now = DateTime(2026, 6, 13);

  setUp(() {
    db = TonariDatabase.forTesting(NativeDatabase.memory());
    service = FolderPickerService(db);
  });

  tearDown(() => db.close());

  Future<void> insertFolder(String id) {
    return db
        .into(db.importedFolders)
        .insert(
          ImportedFoldersCompanion.insert(
            id: id,
            displayName: id,
            bookmarkBase64: '',
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  test('removeIfEmpty deletes a source with no works', () async {
    await insertFolder('empty');

    await service.removeIfEmpty('empty');

    expect(await db.select(db.importedFolders).get(), isEmpty);
  });

  test('removeIfEmpty keeps a source with removed works', () async {
    await insertFolder('folder');
    await db
        .into(db.works)
        .insert(
          WorksCompanion.insert(
            productId: 'RJ111111',
            title: 'RJ111111',
            localFolderPath: '/library/RJ111111',
            localImportedAt: now,
            importedFolderId: const Value('folder'),
            isRemoved: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await service.removeIfEmpty('folder');

    final folders = await db.select(db.importedFolders).get();
    expect(folders.map((f) => f.id), ['folder']);
  });
}
