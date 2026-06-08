import 'package:drift/drift.dart' show OrderingTerm;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../db/providers.dart';
import 'folder_bookmark.dart';

class FolderPickerService {
  FolderPickerService(this._db);
  final TonariDatabase _db;
  static const _uuid = Uuid();

  Future<ImportedFolder?> pickAndPersist() async {
    final url = await FilePicker.getDirectoryPath();
    if (url == null) return null;

    final bookmark = await FolderBookmark.create(url);
    final displayName = _lastPathComponent(url);
    final now = DateTime.now();
    final id = _uuid.v4();

    await _db
        .into(_db.importedFolders)
        .insert(
          ImportedFoldersCompanion.insert(
            id: id,
            displayName: displayName,
            bookmarkBase64: bookmark,
            createdAt: now,
            updatedAt: now,
          ),
        );

    return (_db.select(
      _db.importedFolders,
    )..where((f) => f.id.equals(id))).getSingle();
  }

  Stream<List<ImportedFolder>> watchAll() {
    return (_db.select(
      _db.importedFolders,
    )..orderBy([(f) => OrderingTerm.desc(f.createdAt)])).watch();
  }

  Future<void> remove(String id) async {
    await (_db.delete(_db.importedFolders)..where((f) => f.id.equals(id))).go();
  }

  static String _lastPathComponent(String url) {
    final cleaned = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final idx = cleaned.lastIndexOf('/');
    final last = idx >= 0 ? cleaned.substring(idx + 1) : cleaned;
    return Uri.decodeComponent(last);
  }
}

final folderPickerServiceProvider = Provider<FolderPickerService>((ref) {
  return FolderPickerService(ref.watch(databaseProvider));
});

final importedFoldersProvider = StreamProvider<List<ImportedFolder>>((ref) {
  return ref.watch(folderPickerServiceProvider).watchAll();
});
