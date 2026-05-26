import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/features/library/data/import_flow.dart';
import 'package:tonari/features/library/data/import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late TonariDatabase db;
  late ImportFlow flow;

  const channel = MethodChannel('tonari/folder_bookmark');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tonari_import_flow_');
    db = TonariDatabase.forTesting(NativeDatabase.memory());
    flow = ImportFlow(importer: ImportService(db));
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  File touch(String relative) {
    final file = File('${tmp.path}/$relative');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('x');
    return file;
  }

  test('resolves bookmark, scans folder, and imports tracks', () async {
    touch('RJ01560714/本編/track01.wav');
    touch('RJ01560714/本編/track01.mp3');

    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'resolve') {
        return {'url': Uri.file(tmp.path).toString(), 'isStale': false};
      }
      if (call.method == 'release') return null;
      throw StateError('Unexpected method ${call.method}');
    });

    final now = DateTime(2026, 5, 24, 14, 30);
    final summary = await flow.importFromFolder(
      ImportedFolder(
        id: 'folder-1',
        displayName: 'fixture',
        bookmarkBase64: 'bookmark',
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(summary.worksInserted, 1);
    expect(summary.tracksTotal, 2);

    final work = await db.select(db.works).getSingle();
    expect(work.productId, 'RJ01560714');

    final tracks = await db.select(db.tracks).get();
    expect(tracks.map((t) => t.fileFormat).toSet(), {'wav', 'mp3'});
    expect(
      tracks.map((t) => t.relativePath).toSet(),
      {'本編/track01.wav', '本編/track01.mp3'},
    );
  });

  test('imports from resolved iOS file provider path with spaces', () async {
    final root = Directory('${tmp.path}/File Provider Storage/Downloads/ASMR');
    final file = File('${root.path}/RJ01560715/track01.mp3');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('x');

    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'resolve') {
        return {'url': root.path, 'isStale': false};
      }
      if (call.method == 'release') return null;
      throw StateError('Unexpected method ${call.method}');
    });

    final now = DateTime(2026, 5, 24, 14, 30);
    final summary = await flow.importFromFolder(
      ImportedFolder(
        id: 'folder-1',
        displayName: 'ASMR',
        bookmarkBase64: 'bookmark',
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(summary.scannedRootPath, root.path);
    expect(summary.worksInserted, 1);
    expect(summary.tracksTotal, 1);

    final work = await db.select(db.works).getSingle();
    expect(work.productId, 'RJ01560715');
  });

  test(
    'imports from percent-encoded resolved iOS file provider path',
    () async {
      final root = Directory(
        '${tmp.path}/File Provider Storage/Downloads/ASMR',
      );
      final file = File('${root.path}/RJ01560716/track01.mp3');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('x');

      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'resolve') {
          return {
            'url': root.path.replaceAll(
              'File Provider Storage',
              'File%20Provider%20Storage',
            ),
            'isStale': false,
          };
        }
        if (call.method == 'release') return null;
        throw StateError('Unexpected method ${call.method}');
      });

      final now = DateTime(2026, 5, 24, 14, 30);
      final summary = await flow.importFromFolder(
        ImportedFolder(
          id: 'folder-1',
          displayName: 'ASMR',
          bookmarkBase64: 'bookmark',
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(summary.scannedRootPath, root.path);
      expect(summary.worksInserted, 1);
      expect(summary.tracksTotal, 1);

      final work = await db.select(db.works).getSingle();
      expect(work.productId, 'RJ01560716');
    },
  );
}
