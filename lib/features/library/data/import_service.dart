import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../../core/scanner/audio_merger.dart';
import '../../../core/scanner/scan_models.dart';

class ImportSummary {
  const ImportSummary({
    required this.worksInserted,
    required this.worksUpdated,
    required this.tracksTotal,
  });

  final int worksInserted;
  final int worksUpdated;
  final int tracksTotal;
}

class ImportService {
  ImportService(this._db);
  final TonariDatabase _db;

  /// Writes a [ScanResult] into the database. Idempotent on re-run with
  /// the same input. Re-scan picks up new tracks, prunes deleted tracks
  /// (per-work scope), and preserves lastPositionMs / playCount on tracks
  /// that are still present.
  Future<ImportSummary> applyScanResult(ScanResult scan) async {
    var worksInserted = 0;
    var worksUpdated = 0;
    var tracksTotal = 0;
    final now = DateTime.now();

    await _db.transaction(() async {
      for (final w in scan.works) {
        final existing = await (_db.select(_db.works)
              ..where((row) => row.productId.equals(w.productId)))
            .getSingleOrNull();

        if (existing == null) {
          await _db.into(_db.works).insert(WorksCompanion.insert(
                productId: w.productId,
                title: w.productId,
                localFolderPath: w.rootPath,
                localImportedAt: now,
                createdAt: now,
                updatedAt: now,
              ));
          worksInserted++;
        } else {
          await (_db.update(_db.works)
                ..where((row) => row.productId.equals(w.productId)))
              .write(WorksCompanion(
            localFolderPath: Value(w.rootPath),
            updatedAt: Value(now),
          ));
          worksUpdated++;
        }

        final merged = AudioMerger.merge(w.audios);
        final scannedIds = <String>{};

        for (final mt in merged) {
          final tid = trackIdFor(w.productId, mt.parentDirName, mt.baseName);
          scannedIds.add(tid);

          final existingTrack = await (_db.select(_db.tracks)
                ..where((row) => row.id.equals(tid)))
              .getSingleOrNull();

          if (existingTrack == null) {
            await _db.into(_db.tracks).insert(TracksCompanion.insert(
                  id: tid,
                  workId: w.productId,
                  filePath: mt.primaryPath,
                  fileName: mt.primaryFileName,
                  fileFormat: mt.primaryFormat,
                  fileSizeBytes: mt.primarySizeBytes,
                  durationMs: 0,
                  parentDirName: mt.parentDirName,
                  title: mt.baseName,
                  alternateQualityPathsJson:
                      Value(jsonEncode(mt.alternateQualityPaths)),
                  categoryHint: Value(mt.categoryHint),
                  createdAt: now,
                  updatedAt: now,
                ));
          } else {
            await (_db.update(_db.tracks)
                  ..where((row) => row.id.equals(tid)))
                .write(TracksCompanion(
              filePath: Value(mt.primaryPath),
              fileName: Value(mt.primaryFileName),
              fileFormat: Value(mt.primaryFormat),
              fileSizeBytes: Value(mt.primarySizeBytes),
              parentDirName: Value(mt.parentDirName),
              title: Value(mt.baseName),
              alternateQualityPathsJson:
                  Value(jsonEncode(mt.alternateQualityPaths)),
              categoryHint: Value(mt.categoryHint),
              updatedAt: Value(now),
            ));
          }
          tracksTotal++;
        }

        if (scannedIds.isEmpty) {
          await (_db.delete(_db.tracks)
                ..where((row) => row.workId.equals(w.productId)))
              .go();
        } else {
          await (_db.delete(_db.tracks)
                ..where((row) =>
                    row.workId.equals(w.productId) &
                    row.id.isNotIn(scannedIds.toList())))
              .go();
        }
      }
    });

    return ImportSummary(
      worksInserted: worksInserted,
      worksUpdated: worksUpdated,
      tracksTotal: tracksTotal,
    );
  }

  /// Stable across re-scans for the same logical track.
  static String trackIdFor(String workId, String parentDir, String baseName) {
    return '$workId|${parentDir.toLowerCase()}|${baseName.toLowerCase()}';
  }
}

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(ref.watch(databaseProvider));
});
