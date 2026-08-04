import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/features/library/data/work_tree.dart';

void main() {
  late TonariDatabase db;

  setUp(() => db = TonariDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Track makeTrack(
    String workId,
    String relativePath,
    String format, {
    int durationMs = 0,
    int sizeBytes = 0,
  }) {
    final now = DateTime(2026, 5, 26);
    final fileName = relativePath.split('/').last;
    return Track(
      id: '$workId|${relativePath.toLowerCase()}',
      workId: workId,
      filePath: '/scan/$workId/$relativePath',
      relativePath: relativePath,
      fileName: fileName,
      fileFormat: format,
      fileSizeBytes: sizeBytes,
      durationMs: durationMs,
      parentDirName: relativePath.contains('/')
          ? relativePath.substring(0, relativePath.lastIndexOf('/'))
          : workId,
      title: fileName.substring(0, fileName.lastIndexOf('.')),
      alternateQualityPathsJson: '{}',
      lastPositionMs: 0,
      playCount: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  WorkFile makeFile(String workId, String relativePath, String kind) {
    final now = DateTime(2026, 5, 26);
    final fileName = relativePath.split('/').last;
    return WorkFile(
      id: '$workId|${relativePath.toLowerCase()}',
      workId: workId,
      filePath: '/scan/$workId/$relativePath',
      relativePath: relativePath,
      fileName: fileName,
      fileKind: kind,
      fileSizeBytes: 1024,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('two sibling quality folders stay separate in the tree', () {
    final tracks = [
      makeTrack('RJ1', '本編_WAV/01.wav', 'wav'),
      makeTrack('RJ1', '本編_WAV/02.wav', 'wav'),
      makeTrack('RJ1', '本編_MP3/01.mp3', 'mp3'),
      makeTrack('RJ1', '本編_MP3/02.mp3', 'mp3'),
    ];

    final tree = buildWorkTree(tracks);
    expect(tree, hasLength(2));
    expect(tree.whereType<WorkTreeFolder>().map((f) => f.name).toList(), [
      '本編_MP3',
      '本編_WAV',
    ]);

    final wavFolder = tree.whereType<WorkTreeFolder>().firstWhere(
      (f) => f.name == '本編_WAV',
    );
    expect(wavFolder.audioCount, 2);
    expect(
      wavFolder.children.whereType<WorkTreeTrack>().map((t) => t.name).toList(),
      ['01', '02'],
    );
  });

  test('nested bonus folder appears under its parent', () {
    final tracks = [
      makeTrack('RJ2', '【WAV】/①.wav', 'wav'),
      makeTrack('RJ2', '【WAV】/②.wav', 'wav'),
      makeTrack('RJ2', '【WAV】/【おまけ】/extra.wav', 'wav'),
    ];

    final tree = buildWorkTree(tracks);
    expect(tree, hasLength(1));
    final wav = tree.single as WorkTreeFolder;
    expect(wav.audioCount, 3);

    final folderChildren = wav.children.whereType<WorkTreeFolder>().toList();
    final trackChildren = wav.children.whereType<WorkTreeTrack>().toList();
    expect(trackChildren, hasLength(2));
    expect(folderChildren, hasLength(1));
    expect(folderChildren.single.name, '【おまけ】');
    expect(folderChildren.single.audioCount, 1);
  });

  test('root-level tracks (no folder) become top-level entries', () {
    final tracks = [
      makeTrack('RJ3', 'standalone.wav', 'wav'),
      makeTrack('RJ3', '本編/01.wav', 'wav'),
    ];

    final tree = buildWorkTree(tracks);
    expect(tree, hasLength(2));
    // Folders sort before files.
    expect(tree.map((n) => n.name).toList(), ['本編', 'standalone']);
    expect(
      tree.whereType<WorkTreeTrack>().single.track.fileName,
      'standalone.wav',
    );
    expect(tree.whereType<WorkTreeFolder>().single.name, '本編');
  });

  test('flattenForPlayback emits tracks in tree display order', () {
    final tracks = [
      makeTrack('RJ4', 'A/02.wav', 'wav'),
      makeTrack('RJ4', 'A/01.wav', 'wav'),
      makeTrack('RJ4', 'B/01.wav', 'wav'),
      makeTrack('RJ4', 'A/Z/extra.wav', 'wav'),
    ];

    final tree = buildWorkTree(tracks);
    final flat = flattenForPlayback(tree);
    // Inside A the Z folder sorts before the loose tracks.
    expect(flat.map((t) => t.relativePath).toList(), [
      'A/Z/extra.wav',
      'A/01.wav',
      'A/02.wav',
      'B/01.wav',
    ]);
  });

  test(
    'natural sort: 10_xxx comes after 2_xxx (digit run beats separator)',
    () {
      final tracks = [
        makeTrack('RJN', '10_track.mp3', 'mp3'),
        makeTrack('RJN', '1_track.mp3', 'mp3'),
        makeTrack('RJN', '2_track.mp3', 'mp3'),
      ];
      final tree = buildWorkTree(tracks);
      expect(
        tree.whereType<WorkTreeTrack>().map((t) => t.track.fileName).toList(),
        ['1_track.mp3', '2_track.mp3', '10_track.mp3'],
      );
    },
  );

  test('non-audio files appear as WorkTreeFile next to tracks', () {
    final tracks = [makeTrack('RJ5', '音声/01.wav', 'wav')];
    final files = [
      makeFile('RJ5', '特典/cover.jpg', 'image'),
      makeFile('RJ5', 'readme.txt', 'text'),
    ];

    final tree = buildWorkTree(tracks, workFiles: files);
    // Top level: 特典 and 音声 (folders first), then readme.txt.
    expect(tree, hasLength(3));
    expect(tree.map((n) => n.name).toList(), ['特典', '音声', 'readme.txt']);
    expect(tree.whereType<WorkTreeFile>().single.file.fileName, 'readme.txt');

    final tokuten = tree.whereType<WorkTreeFolder>().firstWhere(
      (f) => f.name == '特典',
    );
    expect(tokuten.children.single, isA<WorkTreeFile>());

    final onsei = tree.whereType<WorkTreeFolder>().firstWhere(
      (f) => f.name == '音声',
    );
    expect(onsei.children.single, isA<WorkTreeTrack>());
  });

  test('folder reports itemCount (direct) and totalDurationMs (recursive)', () {
    final tracks = [
      makeTrack('RJ6', '音声/A/01.wav', 'wav', durationMs: 3 * 60 * 1000),
      makeTrack('RJ6', '音声/A/02.wav', 'wav', durationMs: 2 * 60 * 1000),
      makeTrack('RJ6', '音声/B/03.wav', 'wav', durationMs: 90 * 1000),
    ];
    final files = [makeFile('RJ6', '音声/cover.jpg', 'image')];

    final tree = buildWorkTree(tracks, workFiles: files);
    final onsei = tree.whereType<WorkTreeFolder>().single;
    // Direct children: A/, B/, cover.jpg → 3
    expect(onsei.itemCount, 3);
    // Recursive audio duration: 3min + 2min + 90s = 6.5 min = 390000 ms
    expect(onsei.totalDurationMs, 390000);

    final a = onsei.children.whereType<WorkTreeFolder>().firstWhere(
      (f) => f.name == 'A',
    );
    expect(a.itemCount, 2);
    expect(a.totalDurationMs, 5 * 60 * 1000);
  });

  test('flattenForPlayback skips WorkTreeFile entries', () {
    final tracks = [makeTrack('RJ7', '音声/01.wav', 'wav')];
    final files = [makeFile('RJ7', '音声/cover.jpg', 'image')];

    final tree = buildWorkTree(tracks, workFiles: files);
    final flat = flattenForPlayback(tree);
    expect(flat, hasLength(1));
    expect(flat.single.relativePath, '音声/01.wav');
  });

  group('autoPath', () {
    const mb = 1024 * 1024;

    test('descends into the dominant WAV folder over its MP3 sibling', () {
      final tree = buildWorkTree([
        makeTrack('RJ8', '01_WAV/01.wav', 'wav', sizeBytes: 900 * mb),
        makeTrack('RJ8', '02_MP3/01.mp3', 'mp3', sizeBytes: 90 * mb),
      ]);
      expect(autoPath(tree), ['01_WAV']);
    });

    test('WAV vs FLAC at ~2:1 still descends into WAV', () {
      final tree = buildWorkTree([
        makeTrack('RJ9', 'WAV/01.wav', 'wav', sizeBytes: 400 * mb),
        makeTrack('RJ9', 'FLAC/01.flac', 'flac', sizeBytes: 200 * mb),
      ]);
      expect(autoPath(tree), ['WAV']);
    });

    test('equal parallel variants stop at their parent', () {
      final tree = buildWorkTree([
        makeTrack('RJ10', '本編/SEあり/01.wav', 'wav', sizeBytes: 300 * mb),
        makeTrack('RJ10', '本編/SEなし/01.wav', 'wav', sizeBytes: 300 * mb),
      ]);
      expect(autoPath(tree), ['本編']);
    });

    test('walks past a small bonus folder into the nested main audio', () {
      final tree = buildWorkTree([
        makeTrack('RJ11', '本編/WAV/01.wav', 'wav', sizeBytes: 800 * mb),
        makeTrack('RJ11', '本編/MP3/01.mp3', 'mp3', sizeBytes: 80 * mb),
        makeTrack('RJ11', '特典/おまけ.mp3', 'mp3', sizeBytes: 5 * mb),
      ]);
      expect(autoPath(tree), ['本編', 'WAV']);
    });

    test('stays at root when audio already sits there', () {
      final tree = buildWorkTree([
        makeTrack('RJ12', '01.wav', 'wav', sizeBytes: 500 * mb),
        makeTrack('RJ12', '02.wav', 'wav', sizeBytes: 500 * mb),
        makeTrack('RJ12', 'おまけ/宣伝.mp3', 'mp3', sizeBytes: 5 * mb),
      ]);
      expect(autoPath(tree), isEmpty);
    });

    test('ignores folders that only hold non-audio files', () {
      final tree = buildWorkTree(
        [makeTrack('RJ13', '音声/01.wav', 'wav', sizeBytes: 100 * mb)],
        workFiles: [makeFile('RJ13', '画像/cover.jpg', 'image')],
      );
      expect(autoPath(tree), ['音声']);
    });

    test('returns empty when sizes are unknown', () {
      final tree = buildWorkTree([
        makeTrack('RJ14', 'WAV/01.wav', 'wav'),
        makeTrack('RJ14', 'MP3/01.mp3', 'mp3'),
      ]);
      expect(autoPath(tree), isEmpty);
    });
  });
}
