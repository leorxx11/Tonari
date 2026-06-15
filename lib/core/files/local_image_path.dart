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

  /// stored path -> resolved absolute path. Only successful resolutions are
  /// cached: a stored value maps to a fixed on-disk file for the lifetime of
  /// the process, so repeated builds during scroll skip the synchronous stat.
  /// Misses stay uncached so enrichment can still detect a not-yet-downloaded
  /// cover via a fresh `resolve(...) == null` check.
  static final Map<String, String> _cache = {};

  static Future<void> init() async {
    _documentsDir = await getApplicationDocumentsDirectory();
  }

  static Directory? get documentsDir => _documentsDir;

  static void clearCache() {
    _cache.clear();
  }

  /// Returns an absolute path that exists on disk, or null.
  static String? resolve(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    final cached = _cache[stored];
    if (cached != null) return cached;

    String? resolved;
    if (p.isAbsolute(stored) && File(stored).existsSync()) {
      resolved = stored;
    } else {
      const marker = '/images/';
      final idx = stored.indexOf(marker);
      final relative = idx >= 0 ? stored.substring(idx + 1) : stored;
      final docs = _documentsDir;
      if (docs != null) {
        final candidate = p.join(docs.path, relative);
        if (File(candidate).existsSync()) resolved = candidate;
      }
    }

    if (resolved != null) _cache[stored] = resolved;
    return resolved;
  }

  /// Convert an absolute path under Documents into a relative one for storage.
  static String toRelative(String absolute) {
    final docs = _documentsDir;
    if (docs == null) return absolute;
    return p.relative(absolute, from: docs.path);
  }
}
