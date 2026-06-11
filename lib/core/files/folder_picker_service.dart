import 'package:drift/drift.dart';
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

    // Dedupe by path: re-picking an already-imported local folder refreshes its
    // (possibly stale) bookmark instead of stacking a duplicate record.
    final existing =
        await (_db.select(_db.importedFolders)..where(
              (f) => f.type.equals('local') & f.remotePath.equals(url),
            ))
            .getSingleOrNull();
    final id = existing?.id ?? _uuid.v4();

    if (existing == null) {
      await _db
          .into(_db.importedFolders)
          .insert(
            ImportedFoldersCompanion.insert(
              id: id,
              displayName: displayName,
              bookmarkBase64: bookmark,
              remotePath: Value(url),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else {
      await (_db.update(
        _db.importedFolders,
      )..where((f) => f.id.equals(id))).write(
        ImportedFoldersCompanion(
          displayName: Value(displayName),
          bookmarkBase64: Value(bookmark),
          updatedAt: Value(now),
        ),
      );
    }

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
