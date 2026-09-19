import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../browse/data/remote_models.dart';
import 'local_video_store.dart';
import 'video_library_providers.dart';

class LocalVideoImport {
  LocalVideoImport(this._store, this._repository);

  final LocalVideoStore _store;
  final VideoLibraryRepository _repository;
  static const _channel = MethodChannel('tonari/video_import');

  Future<int> pickAndImport({
    required void Function(int, int) onProgress,
  }) async {
    final picked = await _channel.invokeListMethod<Object?>(
      'pick',
      LocalVideoStore.extensions,
    );
    var completed = 0;
    final files = picked!
        .map((raw) => Map<String, Object?>.from(raw as Map))
        .toList();
    onProgress(0, files.length);
    try {
      for (final item in files) {
        await importFile(item['path'] as String, item['name'] as String);
        onProgress(++completed, files.length);
      }
    } finally {
      // asCopy: true returns app-owned Inbox copies, never the user's originals.
      for (final item in files) {
        final inboxFile = File(item['path'] as String);
        if (await inboxFile.exists()) await inboxFile.delete();
      }
    }
    return completed;
  }

  Future<String> importFile(String sourcePath, String name) async {
    final relativePath = await _store.adopt(sourcePath, name);
    final file = await _store.file(relativePath);
    final item = PlayableItem(
      id: 'local:${LocalVideoStore.sourceId}:$relativePath',
      sourceKind: RemoteSourceKind.local,
      sourceId: LocalVideoStore.sourceId,
      sourceName: '本地导入',
      path: relativePath,
      fileName: name,
      kind: RemoteEntryKind.video,
      size: await file.length(),
      resolve: () async => ResolvedMediaUrl(url: file.uri),
    );
    try {
      await _repository.add(item);
    } catch (_) {
      await _store.delete(relativePath);
      rethrow;
    }
    return item.stableId;
  }
}

final localVideoImportProvider = Provider(
  (ref) => LocalVideoImport(
    ref.watch(localVideoStoreProvider),
    ref.watch(videoLibraryRepositoryProvider),
  ),
);
