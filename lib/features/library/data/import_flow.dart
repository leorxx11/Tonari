import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/files/folder_bookmark.dart';
import '../../../core/scanner/folder_scanner.dart';
import 'import_service.dart';

class ImportFlow {
  ImportFlow({required this.importer});
  final ImportService importer;

  /// Resolves the bookmark, scans the folder, and writes the scan results to
  /// the database. Always releases the security-scoped access at the end, even
  /// on error.
  Future<ImportSummary> importFromFolder(ImportedFolder folder) async {
    final resolution = await FolderBookmark.resolve(folder.bookmarkBase64);
    try {
      final path = _urlToPath(resolution.url);
      final scan = await FolderScanner.scan(path);
      return await importer.applyScanResult(scan, sourceFolderId: folder.id);
    } finally {
      await FolderBookmark.release(resolution.url);
    }
  }

  static String _urlToPath(String url) {
    if (!url.startsWith('file://')) return Uri.decodeComponent(url);
    return Uri.parse(url).toFilePath();
  }
}

final importFlowProvider = Provider<ImportFlow>((ref) {
  return ImportFlow(importer: ref.watch(importServiceProvider));
});
