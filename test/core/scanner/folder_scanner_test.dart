import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/scanner/folder_scanner.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('tonari_scan_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File touch(String relative, [String content = 'x']) {
    final f = File('${tmp.path}/$relative');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
    return f;
  }

  test('root dir itself is the work when its name has RJ', () {
    final workDir = Directory('${tmp.path}/RJ01560714')..createSync();
    File('${workDir.path}/track01.mp3').writeAsStringSync('audio');
    File('${workDir.path}/cover.jpg').writeAsStringSync('img');

    final result = FolderScanner.scanSync(workDir.path);

    expect(result.works, hasLength(1));
    expect(result.works.first.productId, 'RJ01560714');
    expect(result.works.first.audios, hasLength(1));
    expect(result.works.first.audios.first.format, 'mp3');
    expect(result.works.first.images, hasLength(1));
  });

  test('classifies audio/image/subtitle/text correctly', () {
    Directory('${tmp.path}/RJ123456').createSync();
    touch('RJ123456/track01.mp3', 'a');
    touch('RJ123456/track01.flac', 'a');
    touch('RJ123456/cover.jpg', 'i');
    touch('RJ123456/sub.srt', 's');
    touch('RJ123456/notes.txt', 't');
    touch('RJ123456/archive.zip', 'o');

    final result = FolderScanner.scanSync(tmp.path);
    expect(result.works, hasLength(1));
    final w = result.works.first;
    expect(w.audios.map((a) => a.fileName).toSet(),
        {'track01.mp3', 'track01.flac'});
    expect(w.images, hasLength(1));
    expect(w.subtitles, hasLength(1));
    expect(w.textNotes, hasLength(1));
    // archive.zip should be silently ignored
    expect(result.filesScanned, 6);
  });

  test('infers categoryHint from parent dir keywords', () {
    Directory('${tmp.path}/RJ000111').createSync();
    touch('RJ000111/本編/main_track.wav');
    touch('RJ000111/フリートーク/ft.wav');
    touch('RJ000111/その他/misc.wav');

    final result = FolderScanner.scanSync(tmp.path);
    final hints = {
      for (final a in result.works.first.audios) a.fileName: a.categoryHint,
    };
    expect(hints['main_track.wav'], 'main');
    expect(hints['ft.wav'], 'free');
    expect(hints['misc.wav'], isNull);
  });

  test('finds multiple sibling RJ subdirs', () {
    touch('RJ000001/a.mp3');
    touch('RJ000002/b.wav');
    touch('not_a_work/c.txt');

    final result = FolderScanner.scanSync(tmp.path);
    expect(
      result.works.map((w) => w.productId).toSet(),
      {'RJ000001', 'RJ000002'},
    );
    expect(
      result.unrecognizedDirs.map((p) => p.split('/').last),
      ['not_a_work'],
    );
  });

  test('finds RJ in grandchild directory (collection layout)', () {
    touch('系列A/RJ555555/track.mp3');

    final result = FolderScanner.scanSync(tmp.path);
    expect(result.works, hasLength(1));
    expect(result.works.first.productId, 'RJ555555');
    expect(result.unrecognizedDirs, isEmpty);
  });

  test('returns error for non-existent root', () {
    final result = FolderScanner.scanSync('/nonexistent/path');
    expect(result.works, isEmpty);
    expect(result.errors, isNotEmpty);
  });

  test('scan() runs on isolate and returns same result', () async {
    Directory('${tmp.path}/RJ888888').createSync();
    touch('RJ888888/track.mp3');

    final result = await FolderScanner.scan(tmp.path);
    expect(result.works, hasLength(1));
    expect(result.works.first.productId, 'RJ888888');
  });
}
