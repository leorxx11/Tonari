import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../../core/scanner/scan_models.dart';
import '../../browse/data/remote_models.dart';
import '../../library/data/import_service.dart';
import '../../library/data/metadata_enrichment.dart';
import 'p115_client.dart';
import 'p115_folder_scanner.dart';

typedef P115ImportProgress = void Function(int worksFound, String current);

class P115ImportFlow {
  P115ImportFlow({
    required this.db,
    required this.client,
    required this.importer,
    required this.enrichment,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final TonariDatabase db;
  final P115Client client;
  final ImportService importer;
  final MetadataEnrichmentService enrichment;
  final Uuid _uuid;

  Future<ImportSummary> importFolder({
    required RemoteEntry folder,
    P115ImportProgress? onProgress,
    bool enrich = true,
    bool skipExisting = false,
  }) async {
    final folderId = await _ensureFolder(folder);
    final skip = skipExisting
        ? await importer.allActiveWorkIds()
        : const <String>{};
    final scan = await P115FolderScanner(
      client,
    ).scan(folder, onProgress: onProgress, skipProductIds: skip);
    final subtitleBytes = await _downloadSubtitles(scan, onProgress, skip: skip);
    final summary = await importer.applyScanResult(
      scan,
      sourceFolderId: folderId,
      remoteSubtitleBytes: subtitleBytes,
      skipExisting: skipExisting,
    );
    if (enrich) unawaited(enrichment.enrichBatch(summary.workIds));
    return summary;
  }

  /// Re-scans a single work in place: scans only its own 115 folder (cid stored
  /// as localFolderPath) and writes back under the work's existing folderId,
  /// reviving the tombstone if it was removed. No new ImportedFolder is created.
  Future<ImportSummary> reimportWork(Work work) async {
    final entry = RemoteEntry(
      id: work.localFolderPath,
      path: work.localFolderPath,
      name: work.productId,
      kind: RemoteEntryKind.folder,
      sourceId: P115Client.sourceId,
    );
    final scan = await P115FolderScanner(client).scan(entry);
    final subtitleBytes = await _downloadSubtitles(scan, null);
    final summary = await importer.applyScanResult(
      scan,
      sourceFolderId: work.importedFolderId,
      remoteSubtitleBytes: subtitleBytes,
      reviveTombstoned: true,
    );
    unawaited(enrichment.enrichBatch(summary.workIds));
    return summary;
  }

  Future<Map<String, List<int>>> _downloadSubtitles(
    ScanResult scan,
    P115ImportProgress? onProgress, {
    Set<String> skip = const {},
  }) async {
    final out = <String, List<int>>{};
    final total = scan.works
        .where((w) => !w.incomplete && !skip.contains(w.productId))
        .fold<int>(0, (a, w) => a + w.subtitles.length);
    if (total == 0) return out;
    var done = 0;
    for (final work in scan.works) {
      if (work.incomplete || skip.contains(work.productId)) continue;
      for (final sub in work.subtitles) {
        try {
          out[sub.path] = await client.getBytesByPickcode(sub.path);
        } on P115AuthExpiredException {
          rethrow;
        } catch (_) {
          // skip unreadable subtitle; import proceeds without it
        }
        done++;
        onProgress?.call(scan.works.length, '下载字幕 $done/$total');
      }
    }
    return out;
  }

  Future<String> _ensureFolder(RemoteEntry folder) async {
    final now = DateTime.now();
    final existing =
        await (db.select(db.importedFolders)..where(
              (f) =>
                  f.type.equals('p115') &
                  f.serverId.equals(P115Client.sourceId) &
                  f.remotePath.equals(folder.path),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await (db.update(
        db.importedFolders,
      )..where((f) => f.id.equals(existing.id))).write(
        ImportedFoldersCompanion(
          displayName: Value(_displayName(folder)),
          updatedAt: Value(now),
        ),
      );
      return existing.id;
    }

    final id = _uuid.v4();
    await db
        .into(db.importedFolders)
        .insert(
          ImportedFoldersCompanion.insert(
            id: id,
            displayName: _displayName(folder),
            bookmarkBase64: '',
            type: const Value('p115'),
            serverId: const Value(P115Client.sourceId),
            remotePath: Value(folder.path),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  String _displayName(RemoteEntry folder) {
    return folder.path == '0'
        ? P115Client.sourceName
        : '${P115Client.sourceName} / ${folder.name}';
  }
}

final p115ImportFlowProvider = Provider<P115ImportFlow>((ref) {
  return P115ImportFlow(
    db: ref.watch(databaseProvider),
    client: ref.watch(p115ClientProvider),
    importer: ref.watch(importServiceProvider),
    enrichment: ref.watch(metadataEnrichmentProvider),
  );
});
