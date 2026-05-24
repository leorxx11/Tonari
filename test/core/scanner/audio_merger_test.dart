import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/scanner/audio_merger.dart';
import 'package:tonari/core/scanner/scan_models.dart';

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
  test('merges same-name same-dir multi-quality into one track', () {
    final merged = AudioMerger.merge([
      _audio(path: '/d/track01.wav', fileName: 'track01.wav', format: 'wav'),
      _audio(path: '/d/track01.mp3', fileName: 'track01.mp3', format: 'mp3'),
    ]);

    expect(merged, hasLength(1));
    expect(merged.first.primaryFormat, 'wav');
    expect(merged.first.alternateQualityPaths, {'mp3': '/d/track01.mp3'});
  });

  test('flac wins over wav wins over mp3', () {
    final merged = AudioMerger.merge([
      _audio(path: '/d/x.mp3', fileName: 'x.mp3', format: 'mp3'),
      _audio(path: '/d/x.flac', fileName: 'x.flac', format: 'flac'),
      _audio(path: '/d/x.wav', fileName: 'x.wav', format: 'wav'),
    ]);

    expect(merged, hasLength(1));
    expect(merged.first.primaryFormat, 'flac');
    expect(merged.first.alternateQualityPaths,
        {'wav': '/d/x.wav', 'mp3': '/d/x.mp3'});
  });

  test('different filenames in same dir stay separate', () {
    final merged = AudioMerger.merge([
      _audio(path: '/d/a.mp3', fileName: 'a.mp3', format: 'mp3'),
      _audio(path: '/d/b.mp3', fileName: 'b.mp3', format: 'mp3'),
    ]);
    expect(merged, hasLength(2));
  });

  test('same base name in different dirs stays separate', () {
    final merged = AudioMerger.merge([
      _audio(
          path: '/main/t.mp3',
          fileName: 't.mp3',
          format: 'mp3',
          parentDir: '本編'),
      _audio(
          path: '/free/t.mp3',
          fileName: 't.mp3',
          format: 'mp3',
          parentDir: 'フリートーク'),
    ]);
    expect(merged, hasLength(2));
  });

  test('preserves categoryHint from primary', () {
    final merged = AudioMerger.merge([
      _audio(
          path: '/main/x.wav',
          fileName: 'x.wav',
          format: 'wav',
          parentDir: '本編',
          categoryHint: 'main'),
      _audio(
          path: '/main/x.mp3',
          fileName: 'x.mp3',
          format: 'mp3',
          parentDir: '本編',
          categoryHint: 'main'),
    ]);
    expect(merged.first.categoryHint, 'main');
  });

  test('unknown format falls to lowest priority', () {
    final merged = AudioMerger.merge([
      _audio(path: '/d/x.weird', fileName: 'x.weird', format: 'weird'),
      _audio(path: '/d/x.mp3', fileName: 'x.mp3', format: 'mp3'),
    ]);
    expect(merged.first.primaryFormat, 'mp3');
    expect(merged.first.alternateQualityPaths, {'weird': '/d/x.weird'});
  });

  test('empty input returns empty list', () {
    expect(AudioMerger.merge([]), isEmpty);
  });

  test('output sorted by primaryPath for stability', () {
    final merged = AudioMerger.merge([
      _audio(
          path: '/d/z.mp3', fileName: 'z.mp3', format: 'mp3', parentDir: 'd'),
      _audio(
          path: '/d/a.mp3', fileName: 'a.mp3', format: 'mp3', parentDir: 'd'),
      _audio(
          path: '/d/m.mp3', fileName: 'm.mp3', format: 'mp3', parentDir: 'd'),
    ]);
    expect(merged.map((m) => m.baseName), ['a', 'm', 'z']);
  });
}
