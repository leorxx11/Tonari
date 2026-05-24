import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/core/scanner/scan_models.dart';
import 'package:tonari/features/library/data/import_service.dart';

DetectedWork _work({
  required String rj,
  required String rootPath,
  List<DetectedAudio> audios = const [],
}) =>
    DetectedWork(
      productId: rj,
      rootPath: rootPath,
      audios: audios,
      images: const [],
      subtitles: const [],
      textNotes: const [],
    );

DetectedAudio _audio({
  required String path,
  required String fileName,
  required String format,
  String parentDir = 'd',
  int size = 100,
  String? categoryHint,
}) =>
    DetectedAudio(
      path: path,
      fileName: fileName,
      format: format,
      sizeBytes: size,
      parentDirName: parentDir,
      categoryHint: categoryHint,
    );

void main() {
  late TonariDatabase db;
  late ImportService service;

  setUp(() {
    db = TonariDatabase.forTesting(NativeDatabase.memory());
    service = ImportService(db);
  });
  tearDown(() => db.close());

  test('inserts works and tracks on first scan', () async {
    final summary = await service.applyScanResult(ScanResult(
      rootPath: '/scan',
      filesScanned: 2,
      unrecognizedDirs: const [],
      works: [
        _work(rj: 'RJ100001', rootPath: '/scan/RJ100001', audios: [
          _audio(
              path: '/scan/RJ100001/d/track01.wav',
              fileName: 'track01.wav',
              format: 'wav'),
          _audio(
              path: '/scan/RJ100001/d/track01.mp3',
              fileName: 'track01.mp3',
              format: 'mp3'),
        ]),
      ],
    ));

    expect(summary.worksInserted, 1);
    expect(summary.worksUpdated, 0);
    expect(summary.tracksTotal, 1);

    final works = await db.select(db.works).get();
    expect(works.single.productId, 'RJ100001');

    final tracks = await db.select(db.tracks).get();
    expect(tracks, hasLength(1));
    expect(tracks.single.fileFormat, 'wav');
    expect(jsonDecode(tracks.single.alternateQualityPathsJson),
        {'mp3': '/scan/RJ100001/d/track01.mp3'});
  });

  test('re-scan updates work and preserves track play state', () async {
    final scan = ScanResult(
      rootPath: '/scan',
      filesScanned: 1,
      unrecognizedDirs: const [],
      works: [
        _work(rj: 'RJ222222', rootPath: '/scan/RJ222222', audios: [
          _audio(
              path: '/scan/RJ222222/d/t.mp3',
              fileName: 't.mp3',
              format: 'mp3'),
        ]),
      ],
    );
    await service.applyScanResult(scan);

    // Simulate playback progress on the existing track.
    final trackId = ImportService.trackIdFor('RJ222222', 'd', 't');
    await db.customStatement(
      'UPDATE tracks SET last_position_ms = ?, play_count = ? WHERE id = ?',
      [5000, 3, trackId],
    );

    // Re-scan with a new path for the same logical track.
    final summary = await service.applyScanResult(ScanResult(
      rootPath: '/scan',
      filesScanned: 1,
      unrecognizedDirs: const [],
      works: [
        _work(rj: 'RJ222222', rootPath: '/scan/RJ222222', audios: [
          _audio(
              path: '/scan/RJ222222/d/t.mp3',
              fileName: 't.mp3',
              format: 'mp3',
              size: 999),
        ]),
      ],
    ));

    expect(summary.worksUpdated, 1);
    expect(summary.worksInserted, 0);

    final track = await (db.select(db.tracks)
          ..where((t) => t.id.equals(trackId)))
        .getSingle();
    expect(track.lastPositionMs, 5000);
    expect(track.playCount, 3);
    expect(track.fileSizeBytes, 999);
  });

  test('orphan tracks for a work get deleted on re-scan', () async {
    await service.applyScanResult(ScanResult(
      rootPath: '/scan',
      filesScanned: 2,
      unrecognizedDirs: const [],
      works: [
        _work(rj: 'RJ333333', rootPath: '/scan/RJ333333', audios: [
          _audio(
              path: '/scan/RJ333333/d/a.mp3',
              fileName: 'a.mp3',
              format: 'mp3'),
          _audio(
              path: '/scan/RJ333333/d/b.mp3',
              fileName: 'b.mp3',
              format: 'mp3'),
        ]),
      ],
    ));
    expect(await db.select(db.tracks).get(), hasLength(2));

    await service.applyScanResult(ScanResult(
      rootPath: '/scan',
      filesScanned: 1,
      unrecognizedDirs: const [],
      works: [
        _work(rj: 'RJ333333', rootPath: '/scan/RJ333333', audios: [
          _audio(
              path: '/scan/RJ333333/d/a.mp3',
              fileName: 'a.mp3',
              format: 'mp3'),
        ]),
      ],
    ));

    final remaining = await db.select(db.tracks).get();
    expect(remaining, hasLength(1));
    expect(remaining.single.title, 'a');
  });

  test('work with no audios deletes all its tracks on re-scan', () async {
    await service.applyScanResult(ScanResult(
      rootPath: '/scan',
      filesScanned: 1,
      unrecognizedDirs: const [],
      works: [
        _work(rj: 'RJ_EMPTY', rootPath: '/x', audios: [
          _audio(path: '/x/a.mp3', fileName: 'a.mp3', format: 'mp3'),
        ]),
      ],
    ));
    expect(await db.select(db.tracks).get(), hasLength(1));

    await service.applyScanResult(ScanResult(
      rootPath: '/scan',
      filesScanned: 0,
      unrecognizedDirs: const [],
      works: [_work(rj: 'RJ_EMPTY', rootPath: '/x')],
    ));

    expect(await db.select(db.tracks).get(), isEmpty);
  });

  test('multiple works in one scan', () async {
    final summary = await service.applyScanResult(ScanResult(
      rootPath: '/scan',
      filesScanned: 2,
      unrecognizedDirs: const [],
      works: [
        _work(rj: 'RJ_A1', rootPath: '/scan/RJ_A1', audios: [
          _audio(
              path: '/scan/RJ_A1/x.mp3',
              fileName: 'x.mp3',
              format: 'mp3'),
        ]),
        _work(rj: 'RJ_B2', rootPath: '/scan/RJ_B2', audios: [
          _audio(
              path: '/scan/RJ_B2/y.wav',
              fileName: 'y.wav',
              format: 'wav'),
        ]),
      ],
    ));
    expect(summary.worksInserted, 2);
    expect(summary.tracksTotal, 2);
  });
}
