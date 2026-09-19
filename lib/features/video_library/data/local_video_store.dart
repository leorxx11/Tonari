import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class LocalVideoStore {
  static const sourceId = 'video_import';
  static const extensions = ['mp4', 'mkv', 'mov', 'm4v', 'webm', 'ts'];

  Future<File> file(String relativePath) async {
    final docs = await getApplicationDocumentsDirectory();
    return File(p.join(docs.path, relativePath));
  }

  Future<String> adopt(String sourcePath, String name) async {
    final relativePath = p.join('videos', const Uuid().v4(), p.basename(name));
    final target = await file(relativePath);
    await target.parent.create(recursive: true);
    try {
      // The document picker has already copied the original into this app.
      await File(sourcePath).rename(target.path);
    } catch (_) {
      await target.parent.delete(recursive: true);
      rethrow;
    }
    return relativePath;
  }

  Future<void> delete(String relativePath) async {
    final target = await file(relativePath);
    if (await target.parent.exists()) {
      await target.parent.delete(recursive: true);
    }
  }
}

final localVideoStoreProvider = Provider((ref) => LocalVideoStore());
