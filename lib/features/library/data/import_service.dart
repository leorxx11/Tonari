import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../../core/scanner/scan_models.dart';
import '../../../core/subtitle/subtitle_parser.dart';

class ImportSummary {
  const ImportSummary({
    required this.worksInserted,
    required this.worksUpdated,
    required this.tracksTotal,
    this.workIds = const {},
    this.trackIds = const {},
    this.scannedRootPath = '',
    this.filesScanned = 0,
    this.unrecognizedDirs = const [],
    this.scanErrors = const [],
  });

  final int worksInserted;
  final int worksUpdated;
  final int tracksTotal;
  final Set<String> workIds;
  final Set<String> trackIds;

  // Debug fields — surfaced in the import-complete dialog so we can see
  // why a scan returned zero works on device.
  final String scannedRootPath;
  final int filesScanned;
  final List<String> unrecognizedDirs;
  final List<String> scanErrors;
}

class ImportService {
  ImportService(this._db);
  final TonariDatabase _db;

  /// Writes a [ScanResult] into the database. Idempotent on re-run with
  /// the same input. Re-scan picks up new tracks, prunes deleted tracks
  /// (per-work scope), and preserves lastPositionMs / playCount on tracks
  /// that are still present.
  ///
  /// [sourceFolderId] links each Work to the [ImportedFolder] it came from
  /// so the player can resolve the corresponding security-scoped bookmark
  /// later.
  Future<ImportSummary> applyScanResult(
    ScanResult scan, {
    String? sourceFolderId,
    Map<String, List<int>> remoteSubtitleBytes = const {},
  }) async {
    var worksInserted = 0;
    var worksUpdated = 0;
    var tracksTotal = 0;
    final workIds = <String>{};
    final trackIds = <String>{};
    final now = DateTime.now();

    // Read + parse subtitles outside the DB transaction — file I/O can be slow
    // and we don't want to hold the SQLite write lock while doing it.
    final parsedSubs = _readAndParseSubtitles(scan, remoteSubtitleBytes);

    await _db.transaction(() async {
      for (final w in scan.works) {
        workIds.add(w.productId);
        final existing = await (_db.select(
          _db.works,
        )..where((row) => row.productId.equals(w.productId))).getSingleOrNull();

        if (existing == null) {
          await _db
              .into(_db.works)
              .insert(
                WorksCompanion.insert(
                  productId: w.productId,
                  title: w.productId,
                  localFolderPath: w.rootPath,
                  localImportedAt: now,
                  createdAt: now,
                  updatedAt: now,
                  importedFolderId: Value(sourceFolderId),
                ),
              );
          worksInserted++;
        } else {
          await (_db.update(
            _db.works,
          )..where((row) => row.productId.equals(w.productId))).write(
            WorksCompanion(
              localFolderPath: Value(w.rootPath),
              updatedAt: Value(now),
              importedFolderId: Value(sourceFolderId),
              needsRescan: const Value(false),
            ),
          );
          worksUpdated++;
        }

        final scannedIds = <String>{};

        for (final a in w.audios) {
          final baseName = _stripExt(a.fileName);
          final tid = trackIdFor(w.productId, a.relativePath);
          scannedIds.add(tid);
          trackIds.add(tid);

          final existingTrack = await (_db.select(
            _db.tracks,
          )..where((row) => row.id.equals(tid))).getSingleOrNull();

          if (existingTrack == null) {
            await _db
                .into(_db.tracks)
                .insert(
                  TracksCompanion.insert(
                    id: tid,
                    workId: w.productId,
                    filePath: a.path,
                    relativePath: Value(a.relativePath),
                    fileName: a.fileName,
                    fileFormat: a.format,
                    fileSizeBytes: a.sizeBytes,
                    durationMs: 0,
                    parentDirName: a.parentDirName,
                    title: baseName,
                    categoryHint: Value(a.categoryHint),
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
          } else {
            await (_db.update(
              _db.tracks,
            )..where((row) => row.id.equals(tid))).write(
              TracksCompanion(
                filePath: Value(a.path),
                relativePath: Value(a.relativePath),
                fileName: Value(a.fileName),
                fileFormat: Value(a.format),
                fileSizeBytes: Value(a.sizeBytes),
                parentDirName: Value(a.parentDirName),
                title: Value(baseName),
                categoryHint: Value(a.categoryHint),
                updatedAt: Value(now),
              ),
            );
          }
          tracksTotal++;
        }

        if (scannedIds.isEmpty) {
          await (_db.delete(
            _db.tracks,
          )..where((row) => row.workId.equals(w.productId))).go();
        } else {
          await (_db.delete(_db.tracks)..where(
                (row) =>
                    row.workId.equals(w.productId) &
                    row.id.isNotIn(scannedIds.toList()),
              ))
              .go();
        }

        // Subtitles for tracks of this work — id == trackId (one-to-one). Upsert
        // preserves timeOffsetMs and any prior translation cache on a rescan.
        final subsForWork = parsedSubs.where((p) => p.workId == w.productId);
        final subtitleIds = <String>{};
        for (final p in subsForWork) {
          final tid = trackIdFor(w.productId, p.audioRelativePath);
          if (!scannedIds.contains(tid)) continue;
          subtitleIds.add(tid);
          final existing = await (_db.select(_db.subtitles)
                ..where((row) => row.id.equals(tid)))
              .getSingleOrNull();
          if (existing == null) {
            await _db.into(_db.subtitles).insert(
                  SubtitlesCompanion.insert(
                    id: tid,
                    trackId: tid,
                    filePath: p.path,
                    fileFormat: p.format,
                    fileHash: p.hash,
                    originalLinesJson: p.cuesJson,
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
          } else {
            await (_db.update(_db.subtitles)
                  ..where((row) => row.id.equals(tid)))
                .write(
              SubtitlesCompanion(
                filePath: Value(p.path),
                fileFormat: Value(p.format),
                fileHash: Value(p.hash),
                originalLinesJson: Value(p.cuesJson),
                updatedAt: Value(now),
              ),
            );
          }
        }
        // Drop subtitle rows whose audio is gone or whose file disappeared.
        if (subtitleIds.isEmpty) {
          if (scannedIds.isNotEmpty) {
            await (_db.delete(_db.subtitles)..where(
                  (row) => row.trackId.isIn(scannedIds.toList()),
                ))
                .go();
          }
        } else {
          await (_db.delete(_db.subtitles)..where(
                (row) =>
                    row.trackId.isIn(scannedIds.toList()) &
                    row.id.isNotIn(subtitleIds.toList()),
              ))
              .go();
        }

        // Non-audio files (image / subtitle / text / other) live in their own
        // table so the on-disk tree can be rendered without intermixing them
        // with playable tracks.
        final fileIds = <String>{};
        Future<void> upsertFile({
          required String relativePath,
          required String filePath,
          required String fileName,
          required String kind,
          required int sizeBytes,
        }) async {
          final fid = workFileIdFor(w.productId, relativePath);
          fileIds.add(fid);
          final existingFile = await (_db.select(
            _db.workFiles,
          )..where((row) => row.id.equals(fid))).getSingleOrNull();
          if (existingFile == null) {
            await _db.into(_db.workFiles).insert(
                  WorkFilesCompanion.insert(
                    id: fid,
                    workId: w.productId,
                    filePath: filePath,
                    relativePath: relativePath,
                    fileName: fileName,
                    fileKind: kind,
                    fileSizeBytes: sizeBytes,
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
          } else {
            await (_db.update(
              _db.workFiles,
            )..where((row) => row.id.equals(fid))).write(
              WorkFilesCompanion(
                filePath: Value(filePath),
                fileName: Value(fileName),
                fileKind: Value(kind),
                fileSizeBytes: Value(sizeBytes),
                updatedAt: Value(now),
              ),
            );
          }
        }

        for (final f in w.images) {
          await upsertFile(
            relativePath: f.relativePath,
            filePath: f.path,
            fileName: f.fileName,
            kind: 'image',
            sizeBytes: f.sizeBytes,
          );
        }
        for (final f in w.subtitles) {
          await upsertFile(
            relativePath: f.relativePath,
            filePath: f.path,
            fileName: f.fileName,
            kind: 'subtitle',
            sizeBytes: f.sizeBytes,
          );
        }
        for (final f in w.textNotes) {
          await upsertFile(
            relativePath: f.relativePath,
            filePath: f.path,
            fileName: f.fileName,
            kind: 'text',
            sizeBytes: f.sizeBytes,
          );
        }
        for (final f in w.others) {
          await upsertFile(
            relativePath: f.relativePath,
            filePath: f.path,
            fileName: f.fileName,
            kind: 'other',
            sizeBytes: f.sizeBytes,
          );
        }

        if (fileIds.isEmpty) {
          await (_db.delete(
            _db.workFiles,
          )..where((row) => row.workId.equals(w.productId))).go();
        } else {
          await (_db.delete(_db.workFiles)..where(
                (row) =>
                    row.workId.equals(w.productId) &
                    row.id.isNotIn(fileIds.toList()),
              ))
              .go();
        }
      }
    });

    return ImportSummary(
      worksInserted: worksInserted,
      worksUpdated: worksUpdated,
      tracksTotal: tracksTotal,
      workIds: workIds,
      trackIds: trackIds,
      scannedRootPath: scan.rootPath,
      filesScanned: scan.filesScanned,
      unrecognizedDirs: scan.unrecognizedDirs,
      scanErrors: scan.errors,
    );
  }

  /// Stable across re-scans for the same logical track.
  static String trackIdFor(String workId, String relativePath) {
    return '$workId|${relativePath.toLowerCase()}';
  }

  /// Stable across re-scans for the same logical non-audio file.
  static String workFileIdFor(String workId, String relativePath) {
    return '$workId|${relativePath.toLowerCase()}';
  }

  static String _stripExt(String fileName) {
    final i = fileName.lastIndexOf('.');
    return i < 0 ? fileName : fileName.substring(0, i);
  }

  /// Returns parsed-and-hashed subtitles for every work in [scan], matched
  /// to their corresponding audio. Two naming conventions are accepted:
  ///   - `track.wav.vtt` (DLsite style — subtitle name minus one ext == audio name)
  ///   - `track.srt`     (generic style — both files share a stem)
  /// First match wins. Unreadable or empty subtitles are silently skipped.
  List<_ParsedSubtitle> _readAndParseSubtitles(
    ScanResult scan, [
    Map<String, List<int>> remoteBytes = const {},
  ]) {
    final out = <_ParsedSubtitle>[];
    for (final w in scan.works) {
      if (w.subtitles.isEmpty || w.audios.isEmpty) continue;
      for (final sub in w.subtitles) {
        final stem = _stripExt(sub.fileName);
        final match = w.audios.firstWhere(
          (a) => a.fileName == stem || _stripExt(a.fileName) == stem,
          orElse: () => _noAudio,
        );
        if (identical(match, _noAudio)) continue;

        try {
          final bytes = remoteBytes[sub.path] ?? File(sub.path).readAsBytesSync();
          if (bytes.isEmpty) continue;
          final hash = sha256.convert(bytes).toString();
          final content = utf8.decode(_stripBom(bytes), allowMalformed: true);
          final cues = SubtitleParser.parse(content, sub.format);
          if (cues.isEmpty) continue;
          out.add(_ParsedSubtitle(
            workId: w.productId,
            audioRelativePath: match.relativePath,
            path: sub.path,
            format: sub.format,
            hash: hash,
            cuesJson:
                jsonEncode([for (final c in cues) c.toJson()]),
          ));
        } catch (_) {
          // unreadable / unparseable subtitle — skip, don't abort import
        }
      }
    }
    return out;
  }

  static List<int> _stripBom(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return bytes.sublist(3);
    }
    return bytes;
  }

  static const _noAudio = DetectedAudio(
    path: '',
    relativePath: '',
    fileName: '',
    format: '',
    sizeBytes: 0,
    parentDirName: '',
  );
}

class _ParsedSubtitle {
  const _ParsedSubtitle({
    required this.workId,
    required this.audioRelativePath,
    required this.path,
    required this.format,
    required this.hash,
    required this.cuesJson,
  });

  final String workId;
  final String audioRelativePath;
  final String path;
  final String format;
  final String hash;
  final String cuesJson;
}

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(ref.watch(databaseProvider));
});
