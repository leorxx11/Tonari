import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves stored image paths against the *current* Documents directory.
///
/// iOS rewrites the sandbox container UUID on reinstall, so any absolute
/// path persisted before the rewrite points at a directory that no longer
/// exists — but the cached file is still on disk under the new container.
/// New writes use relative paths like `images/RJ12345/main.jpg`; legacy rows
/// fall back to scanning for `/images/...` and re-anchoring it.
class LocalImagePath {
  LocalImagePath._();

  static Directory? _documentsDir;

  static Future<void> init() async {
    _documentsDir = await getApplicationDocumentsDirectory();
  }

  static Directory? get documentsDir => _documentsDir;

  /// Returns an absolute path that exists on disk, or null.
  static String? resolve(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    if (p.isAbsolute(stored) && File(stored).existsSync()) return stored;

    const marker = '/images/';
    final idx = stored.indexOf(marker);
    final relative = idx >= 0 ? stored.substring(idx + 1) : stored;
    final docs = _documentsDir;
    if (docs == null) return null;
    final candidate = p.join(docs.path, relative);
    return File(candidate).existsSync() ? candidate : null;
  }

  /// Convert an absolute path under Documents into a relative one for storage.
  static String toRelative(String absolute) {
    final docs = _documentsDir;
    if (docs == null) return absolute;
    return p.relative(absolute, from: docs.path);
  }
}
