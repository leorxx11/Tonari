import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../../core/scanner/scan_models.dart';
import '../../library/data/import_service.dart';
import '../../library/data/metadata_enrichment.dart';
import 'remote_folder_scanner.dart';
import 'webdav_client.dart';
import 'webdav_password_store.dart';

typedef ImportProgress = void Function(int worksFound, String current);

/// Imports a remote WebDAV folder into the library, reusing the existing
/// [ImportService] + [MetadataEnrichmentService] pipeline. Records the source
/// as a `webdav`-typed [ImportedFolder] (serverId + remotePath) so playback
/// can later rebuild the streaming URL.
class WebdavImportFlow {
  WebdavImportFlow({
    required this.db,
    required this.client,
    required this.importer,
    required this.enrichment,
    required this.passwordStore,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final TonariDatabase db;
  final WebdavClient client;
  final ImportService importer;
  final MetadataEnrichmentService enrichment;
  final WebdavPasswordStore passwordStore;
  final Uuid _uuid;

  Future<ImportSummary> importFolder({
    required WebdavServer server,
    required WebdavConfig config,
    required String remotePath,
    ImportProgress? onProgress,
    bool enrich = true,
  }) async {
    final folderId = await _ensureFolder(server, remotePath);
    final scan = await RemoteFolderScanner(
      client,
    ).scan(config, remotePath, onProgress: onProgress);
    final subtitleBytes = await _downloadSubtitles(config, scan, onProgress);
    final summary = await importer.applyScanResult(
      scan,
      sourceFolderId: folderId,
      remoteSubtitleBytes: subtitleBytes,
    );
    if (enrich) {
      // Metadata + cover art run in the background, same as local import.
      unawaited(enrichment.enrichBatch(summary.workIds));
    }
    return summary;
  }

  /// Re-scans an existing webdav folder, rebuilding the server config from the
  /// stored serverId. Returns null if the folder isn't a resolvable webdav
  /// source (e.g. its server was deleted).
  Future<ImportSummary?> rescanFolder(ImportedFolder folder) async {
    if (folder.type != 'webdav' ||
        folder.serverId == null ||
        folder.remotePath == null) {
      return null;
    }
    final server = await (db.select(
      db.webdavServers,
    )..where((s) => s.id.equals(folder.serverId!))).getSingleOrNull();
    if (server == null) return null;
    final password = await passwordStore.read(server.id);
    final config = WebdavConfig(
      scheme: server.scheme,
      host: server.host,
      port: server.port,
      basePath: server.basePath,
      username: server.username,
      password: password,
    );
    return importFolder(
      server: server,
      config: config,
      remotePath: folder.remotePath!,
    );
  }

  /// Downloads subtitle file bytes so [ImportService] can parse them without
  /// touching the (remote) filesystem. Audio is streamed, never downloaded.
  Future<Map<String, List<int>>> _downloadSubtitles(
    WebdavConfig config,
    ScanResult scan,
    ImportProgress? onProgress,
  ) async {
    final out = <String, List<int>>{};
    final total = scan.works.fold<int>(0, (a, w) => a + w.subtitles.length);
    if (total == 0) return out;
    var done = 0;
    for (final w in scan.works) {
      for (final sub in w.subtitles) {
        try {
          out[sub.path] = await client.getBytes(config, sub.path);
        } catch (_) {
          // skip unreadable subtitle; import proceeds without it
        }
        done++;
        onProgress?.call(scan.works.length, '下载字幕 $done/$total');
      }
    }
    return out;
  }

  Future<String> _ensureFolder(WebdavServer server, String remotePath) async {
    final now = DateTime.now();
    final existing =
        await (db.select(db.importedFolders)..where(
              (f) =>
                  f.serverId.equals(server.id) &
                  f.remotePath.equals(remotePath),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await (db.update(db.importedFolders)
            ..where((f) => f.id.equals(existing.id)))
          .write(ImportedFoldersCompanion(updatedAt: Value(now)));
      return existing.id;
    }
    final id = _uuid.v4();
    await db
        .into(db.importedFolders)
        .insert(
          ImportedFoldersCompanion.insert(
            id: id,
            displayName: _displayName(server, remotePath),
            bookmarkBase64: '',
            type: const Value('webdav'),
            serverId: Value(server.id),
            remotePath: Value(remotePath),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  String _displayName(WebdavServer server, String remotePath) {
    final p = remotePath.endsWith('/')
        ? remotePath.substring(0, remotePath.length - 1)
        : remotePath;
    final i = p.lastIndexOf('/');
    final base = i < 0 ? p : p.substring(i + 1);
    return base.isEmpty ? server.name : '${server.name} / $base';
  }
}

final webdavImportFlowProvider = Provider<WebdavImportFlow>((ref) {
  return WebdavImportFlow(
    db: ref.watch(databaseProvider),
    client: ref.watch(webdavClientProvider),
    importer: ref.watch(importServiceProvider),
    enrichment: ref.watch(metadataEnrichmentProvider),
    passwordStore: ref.watch(webdavPasswordStoreProvider),
  );
});
