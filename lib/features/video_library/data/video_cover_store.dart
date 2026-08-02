import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/prefs/shared_prefs_provider.dart';

/// Cover image files for video-library entries, stored under
/// `Documents/video_covers/` and referenced by documents-relative path
/// (see LocalImagePath for why relative).
class VideoCoverStore {
  static const _dirName = 'video_covers';

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _dirName));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Video ids contain `:` and `/`, so file names use a digest. The timestamp
  /// suffix makes every save a fresh path — Flutter's image cache keys by
  /// path, so overwriting in place would keep showing the old frame.
  String _fileName(String videoId, String ext) {
    final digest = sha1.convert(videoId.codeUnits).toString().substring(0, 12);
    return '$digest-${DateTime.now().millisecondsSinceEpoch}$ext';
  }

  Future<String> saveBytes(String videoId, Uint8List pngBytes) async {
    final dir = await _dir();
    final file = File(p.join(dir.path, _fileName(videoId, '.png')));
    await file.writeAsBytes(pngBytes);
    return p.join(_dirName, p.basename(file.path));
  }

  /// Copies a user-picked image in (default cover). Returns the relative path.
  Future<String> importFile(String sourcePath) async {
    final dir = await _dir();
    var ext = p.extension(sourcePath).toLowerCase();
    if (ext.isEmpty || ext.length > 5) ext = '.jpg';
    final file = File(
      p.join(dir.path, 'default-${DateTime.now().millisecondsSinceEpoch}$ext'),
    );
    await File(sourcePath).copy(file.path);
    return p.join(_dirName, p.basename(file.path));
  }

  Future<void> delete(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File(p.join(docs.path, relativePath));
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // best effort — an orphaned cover file is harmless
    }
  }
}

final videoCoverStoreProvider = Provider<VideoCoverStore>(
  (ref) => VideoCoverStore(),
);

/// Documents-relative path of the user-chosen default cover, shown for
/// library entries without their own cover.
class DefaultVideoCover extends Notifier<String?> {
  static const _key = 'video.defaultCoverPath';

  @override
  String? build() => ref.watch(sharedPreferencesProvider).getString(_key);

  Future<void> set(String? relativePath) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final old = state;
    if (relativePath == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, relativePath);
    }
    state = relativePath;
    if (old != null && old != relativePath) {
      await ref.read(videoCoverStoreProvider).delete(old);
    }
  }
}

final defaultVideoCoverProvider = NotifierProvider<DefaultVideoCover, String?>(
  DefaultVideoCover.new,
);
