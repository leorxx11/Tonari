import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/features/settings/data/backup_service.dart';

class _FakeDocs extends PathProviderPlatform {
  _FakeDocs(this.path);
  String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late _FakeDocs fakeDocs;
  late TonariDatabase db;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tonari_backup_test');
    fakeDocs = _FakeDocs(
      (Directory(p.join(tmp.path, 'docsA'))..createSync()).path,
    );
    PathProviderPlatform.instance = fakeDocs;
    SharedPreferences.setMockInitialValues({});
    db = TonariDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('prefs encode/apply round trip preserves types', () async {
    SharedPreferences.setMockInitialValues({
      'aString': 'hello',
      'aBool': true,
      'anInt': 42,
      'aDouble': 1.5,
      'aList': ['x', 'y'],
    });
    final source = await SharedPreferences.getInstance();
    final encoded = jsonDecode(jsonEncode(encodePrefs(source)));

    SharedPreferences.setMockInitialValues({});
    final target = await SharedPreferences.getInstance();
    await applyPrefs(target, encoded as Map<String, Object?>);

    expect(target.getString('aString'), 'hello');
    expect(target.getBool('aBool'), true);
    expect(target.getInt('anInt'), 42);
    expect(target.getDouble('aDouble'), 1.5);
    expect(target.getStringList('aList'), ['x', 'y']);
  });

  test('inspect rejects missing and too-new manifests', () async {
    final service = BackupService(db, readSecrets: () async => {});
    final backupDir = Directory(p.join(tmp.path, 'nomanifest'))..createSync();
    expect(
      () => service.inspect(backupDir.path),
      throwsA(isA<BackupInvalid>()),
    );

    File(p.join(backupDir.path, BackupService.manifestName)).writeAsStringSync(
      jsonEncode(
        BackupManifest(
          formatVersion: BackupManifest.currentFormat,
          schemaVersion: db.schemaVersion + 1,
          createdAt: DateTime(2026, 8, 4),
          dirs: const {},
          includesSecrets: true,
        ).toJson(),
      ),
    );
    expect(
      () => service.inspect(backupDir.path),
      throwsA(isA<BackupIncompatible>()),
    );
  });

  test('export → stage → apply restores db, images, prefs, secrets', () async {
    // Source device state.
    final docsA = Directory(fakeDocs.path);
    File(p.join(docsA.path, 'images', 'RJ1', 'main.jpg'))
      ..createSync(recursive: true)
      ..writeAsStringSync('cover-bytes');
    File(p.join(docsA.path, 'video_covers', 'v.png'))
      ..createSync(recursive: true)
      ..writeAsStringSync('video-cover');
    SharedPreferences.setMockInitialValues({'player.speed': 1.5});

    final service = BackupService(
      db,
      readSecrets: () async => {
        'p115_cookie': 'UID=1',
        'llm_provider_key:d': 'sk',
      },
    );
    final exportTarget = Directory(p.join(tmp.path, 'exported'))..createSync();
    final backupPath = await service.export(
      targetDir: exportTarget.path,
      dirs: {...BackupDir.values},
    );

    expect(
      File(p.join(backupPath, 'tonari.sqlite')).lengthSync(),
      greaterThan(0),
    );
    expect(
      File(p.join(backupPath, 'images', 'RJ1', 'main.jpg')).readAsStringSync(),
      'cover-bytes',
    );

    // "New device": switch docs, stage, then apply.
    final docsB = Directory(p.join(tmp.path, 'docsB'))..createSync();
    fakeDocs.path = docsB.path;
    SharedPreferences.setMockInitialValues({});
    File(p.join(docsB.path, 'tonari.sqlite-wal')).writeAsStringSync('stale');

    await service.stageRestore(backupPath);
    final captured = <String, String>{};
    await BackupService.applyPendingRestoreIn(
      docsB,
      applySecrets: (s) async => captured.addAll(s),
    );

    expect(File(p.join(docsB.path, 'tonari.sqlite')).existsSync(), true);
    expect(File(p.join(docsB.path, 'tonari.sqlite-wal')).existsSync(), false);
    expect(
      File(p.join(docsB.path, 'images', 'RJ1', 'main.jpg')).readAsStringSync(),
      'cover-bytes',
    );
    expect(
      File(p.join(docsB.path, 'video_covers', 'v.png')).readAsStringSync(),
      'video-cover',
    );
    expect(captured, {'p115_cookie': 'UID=1', 'llm_provider_key:d': 'sk'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('player.speed'), 1.5);
    expect(
      Directory(p.join(docsB.path, 'restore_pending')).existsSync(),
      false,
    );
  });

  test('a directory left out of the backup keeps its live copy', () async {
    final service = BackupService(db, readSecrets: () async => {});
    final exportTarget = Directory(p.join(tmp.path, 'exported'))..createSync();
    final backupPath = await service.export(
      targetDir: exportTarget.path,
      dirs: {BackupDir.images},
    );
    expect(Directory(p.join(backupPath, 'video_covers')).existsSync(), false);

    final docs = Directory(fakeDocs.path);
    File(p.join(docs.path, 'video_covers', 'v.png'))
      ..createSync(recursive: true)
      ..writeAsStringSync('keep-me');
    await service.stageRestore(backupPath);
    await BackupService.applyPendingRestoreIn(docs, applySecrets: (_) async {});

    expect(
      File(p.join(docs.path, 'video_covers', 'v.png')).readAsStringSync(),
      'keep-me',
    );
  });

  test('format 1 manifests map includesImages onto dirs', () {
    BackupManifest parse(bool includesImages) => BackupManifest.fromJson({
      'formatVersion': 1,
      'schemaVersion': 1,
      'createdAt': '2026-08-04T00:00:00.000',
      'includesImages': includesImages,
      'includesSecrets': true,
    });
    expect(parse(true).dirs, {BackupDir.images});
    expect(parse(false).dirs, isEmpty);
  });

  test('applyPendingRestoreIn is a no-op without a staged backup', () async {
    final docs = Directory(p.join(tmp.path, 'empty'))..createSync();
    await BackupService.applyPendingRestoreIn(
      docs,
      applySecrets: (_) async => fail('should not apply secrets'),
    );
  });
}
