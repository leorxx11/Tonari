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
    expect(summary.tracksTotal, 1);

    final work = await db.select(db.works).getSingle();
    expect(work.productId, 'RJ01560714');

    final track = await db.select(db.tracks).getSingle();
    expect(track.title, 'track01');
    expect(track.fileFormat, 'wav');
    expect(
      track.alternateQualityPathsJson,
      '{"mp3":"${tmp.path}/RJ01560714/本編/track01.mp3"}',
    );
  });
}
