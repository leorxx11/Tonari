import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/core/scanner/scan_models.dart';
import 'package:tonari/features/library/data/import_service.dart';

DetectedWork _work({
  required String rj,
  required String rootPath,
  List<DetectedAudio> audios = const [],
  List<DetectedImage> images = const [],
  List<DetectedSubtitle> subtitles = const [],
  List<DetectedFile> textNotes = const [],
  List<DetectedFile> others = const [],
}) =>
    DetectedWork(
      productId: rj,
      rootPath: rootPath,
      audios: audios,
      images: images,
      subtitles: subtitles,
      textNotes: textNotes,
      others: others,
    );

DetectedAudio _audio({
  required String path,
  required String fileName,
  required String format,
  String parentDir = 'd',
  int size = 100,
  String? categoryHint,
  String? relativePath,
}) =>
    DetectedAudio(
      path: path,
      relativePath: relativePath ?? '$parentDir/$fileName',
      fileName: fileName,
      format: format,
      sizeBytes: size,
      parentDirName: parentDir,
      categoryHint: categoryHint,
    );

DetectedImage _image({
  required String path,
  required String fileName,
  required String relativePath,
  int size = 50,
}) =>
    DetectedImage(
      path: path,
      relativePath: relativePath,
      fileName: fileName,
      sizeBytes: size,
    );

DetectedFile _file({
  required String path,
  required String fileName,
  required String relativePath,
  int size = 30,
}) =>
    DetectedFile(
      path: path,
      relativePath: relativePath,
      fileName: fileName,
      sizeBytes: size,
    );

void main() {
  late TonariDatabase db;
  late ImportService service;

  setUp(() {
    db = TonariDatabase.forTesting(NativeDatabase.memory());
    service = ImportService(db);
  });
  tearDown(() => db.close());

  test('each audio file becomes its own track (no quality merging)', () async {
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
    expect(summary.tracksTotal, 2);

    final works = await db.select(db.works).get();
    expect(works.single.productId, 'RJ100001');

    final tracks = await db.select(db.tracks).get();
    expect(tracks, hasLength(2));
    expect(tracks.map((t) => t.fileFormat).toSet(), {'wav', 'mp3'});
    expect(tracks.map((t) => t.relativePath).toSet(),
        {'d/track01.wav', 'd/track01.mp3'});
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
    final trackId = ImportService.trackIdFor('RJ222222', 'd/t.mp3');
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

  test('persists sourceFolderId on insert and update', () async {
    final scan = ScanResult(
      rootPath: '/scan',
      filesScanned: 1,
      unrecognizedDirs: const [],
      works: [
        _work(rj: 'RJ_SRC', rootPath: '/scan/RJ_SRC', audios: [
          _audio(path: '/scan/RJ_SRC/t.mp3', fileName: 't.mp3', format: 'mp3'),
        ]),
      ],
    );
    await service.applyScanResult(scan, sourceFolderId: 'folder-A');

    var work = await (db.select(db.works)
          ..where((w) => w.productId.equals('RJ_SRC')))
        .getSingle();
    expect(work.importedFolderId, 'folder-A');

    // Re-scan from a different folder should rebind.
    await service.applyScanResult(scan, sourceFolderId: 'folder-B');
    work = await (db.select(db.works)
          ..where((w) => w.productId.equals('RJ_SRC')))
        .getSingle();
    expect(work.importedFolderId, 'folder-B');
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

  test('non-audio files are persisted to work_files', () async {
    await service.applyScanResult(ScanResult(
      rootPath: '/scan',
      filesScanned: 4,
      unrecognizedDirs: const [],
      works: [
        _work(
          rj: 'RJ_FILES',
          rootPath: '/scan/RJ_FILES',
          audios: [
            _audio(
              path: '/scan/RJ_FILES/音声/01.wav',
              fileName: '01.wav',
              format: 'wav',
              relativePath: '音声/01.wav',
            ),
          ],
          images: [
            _image(
              path: '/scan/RJ_FILES/特典/cover.jpg',
              fileName: 'cover.jpg',
              relativePath: '特典/cover.jpg',
            ),
          ],
          textNotes: [
            _file(
              path: '/scan/RJ_FILES/readme.txt',
              fileName: 'readme.txt',
              relativePath: 'readme.txt',
            ),
          ],
          others: [
            _file(
              path: '/scan/RJ_FILES/特典/bonus.zip',
              fileName: 'bonus.zip',
              relativePath: '特典/bonus.zip',
            ),
          ],
        ),
      ],
    ));

    final files = await db.select(db.workFiles).get();
    expect(files, hasLength(3));
    expect(
      {for (final f in files) f.relativePath: f.fileKind},
      {
        '特典/cover.jpg': 'image',
        'readme.txt': 'text',
        '特典/bonus.zip': 'other',
      },
    );
    final tracks = await db.select(db.tracks).get();
    expect(tracks, hasLength(1));
    expect(tracks.single.relativePath, '音声/01.wav');
  });

  test('re-scan prunes orphan work_files', () async {
    final imageA = _image(
      path: '/scan/RJ_PRUNE/a.jpg',
      fileName: 'a.jpg',
      relativePath: 'a.jpg',
    );
    final imageB = _image(
      path: '/scan/RJ_PRUNE/b.jpg',
      fileName: 'b.jpg',
      relativePath: 'b.jpg',
    );
    await service.applyScanResult(ScanResult(
      rootPath: '/scan',
      filesScanned: 2,
      unrecognizedDirs: const [],
      works: [
        _work(rj: 'RJ_PRUNE', rootPath: '/scan/RJ_PRUNE', images: [
          imageA,
          imageB,
        ]),
      ],
    ));
    expect(await db.select(db.workFiles).get(), hasLength(2));

    await service.applyScanResult(ScanResult(
      rootPath: '/scan',
      filesScanned: 1,
      unrecognizedDirs: const [],
      works: [
        _work(rj: 'RJ_PRUNE', rootPath: '/scan/RJ_PRUNE', images: [imageA]),
      ],
    ));
    final remaining = await db.select(db.workFiles).get();
    expect(remaining, hasLength(1));
    expect(remaining.single.fileName, 'a.jpg');
  });

  test('applyScanResult clears needsRescan flag on updated works', () async {
    final now = DateTime(2026, 1, 1);
    await db.into(db.works).insert(WorksCompanion.insert(
          productId: 'RJ_FLAG',
          title: 'flag',
          localFolderPath: '/old',
          localImportedAt: now,
          createdAt: now,
          updatedAt: now,
          needsRescan: const Value(true),
        ));
    expect(
      (await (db.select(db.works)
                ..where((w) => w.productId.equals('RJ_FLAG')))
              .getSingle())
          .needsRescan,
      isTrue,
    );

    await service.applyScanResult(ScanResult(
      rootPath: '/scan',
      filesScanned: 1,
      unrecognizedDirs: const [],
      works: [
        _work(rj: 'RJ_FLAG', rootPath: '/scan/RJ_FLAG', audios: [
          _audio(
              path: '/scan/RJ_FLAG/t.mp3',
              fileName: 't.mp3',
              format: 'mp3'),
        ]),
      ],
    ));

    final flagged = await (db.select(db.works)
          ..where((w) => w.productId.equals('RJ_FLAG')))
        .getSingle();
    expect(flagged.needsRescan, isFalse);
  });
}
