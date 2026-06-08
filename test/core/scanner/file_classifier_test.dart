import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/scanner/file_classifier.dart';

void main() {
  group('FileClassifier.classify', () {
    test('mp3 is audio', () {
      expect(FileClassifier.classify('track01.mp3'), FileKind.audio);
    });

    test('uppercase WAV is audio', () {
      expect(FileClassifier.classify('TRACK.WAV'), FileKind.audio);
    });

    test('flac, opus, ogg, m4a all audio', () {
      for (final f in ['a.flac', 'a.opus', 'a.ogg', 'a.m4a', 'a.aac']) {
        expect(FileClassifier.classify(f), FileKind.audio, reason: f);
      }
    });

    test('jpg/png/webp are image', () {
      for (final f in ['cover.jpg', 'sample.PNG', 'foo.webp']) {
        expect(FileClassifier.classify(f), FileKind.image, reason: f);
      }
    });

    test('mp4/mkv/mov/m4v/webm/ts are video', () {
      for (final f in ['a.mp4', 'a.mkv', 'a.mov', 'a.m4v', 'a.webm', 'a.ts']) {
        expect(FileClassifier.classify(f), FileKind.video, reason: f);
      }
    });

    test('srt/lrc/vtt/ass are subtitle', () {
      for (final f in ['a.srt', 'a.lrc', 'a.vtt', 'a.ass']) {
        expect(FileClassifier.classify(f), FileKind.subtitle, reason: f);
      }
    });

    test('txt/md are text', () {
      expect(FileClassifier.classify('readme.txt'), FileKind.text);
      expect(FileClassifier.classify('notes.md'), FileKind.text);
    });

    test('unknown extension is other', () {
      expect(FileClassifier.classify('archive.zip'), FileKind.other);
      expect(FileClassifier.classify('noext'), FileKind.other);
    });
  });

  group('FileClassifier.extOf', () {
    test('returns lowercased extension with dot', () {
      expect(FileClassifier.extOf('foo.MP3'), '.mp3');
    });

    test('returns empty for no extension', () {
      expect(FileClassifier.extOf('noext'), '');
    });

    test('returns last extension when multiple dots', () {
      expect(FileClassifier.extOf('archive.tar.gz'), '.gz');
    });
  });
}
