import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/core/db/providers.dart';
import 'package:tonari/core/prefs/shared_prefs_provider.dart';
import 'package:tonari/features/history/data/history_playback.dart';
import 'package:tonari/features/history/data/play_history_repository.dart';
import 'package:tonari/features/library/data/collections_providers.dart';
import 'package:tonari/features/video/data/video_resume_store.dart';
import 'package:tonari/features/video_library/data/local_video_import.dart';
import 'package:tonari/features/video_library/data/local_video_store.dart';
import 'package:tonari/features/video_library/data/video_library_providers.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.documents);
  String documents;
  @override
  Future<String?> getApplicationDocumentsPath() async => documents;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('tonari/video_import');
  late Directory root;
  late _Paths paths;
  late PathProviderPlatform previousPaths;
  late TonariDatabase db;
  late ProviderContainer container;
  late LocalVideoImport importer;
  late VideoLibraryRepository repo;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tonari-video-import-');
    paths = _Paths(p.join(root.path, 'Documents'));
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = paths;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = TonariDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    importer = container.read(localVideoImportProvider);
    repo = container.read(videoLibraryRepositoryProvider);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    container.dispose();
    await db.close();
    PathProviderPlatform.instance = previousPaths;
    await root.delete(recursive: true);
  });

  Future<File> source(String directory, List<int> bytes) async {
    final file = File(p.join(root.path, directory, '同名 video.mp4'));
    await file.parent.create(recursive: true);
    return file.writeAsBytes(bytes);
  }

  Future<String> importOriginal(File original) async {
    final inbox = await source(
      'Inbox/${p.basename(original.parent.path)}',
      await original.readAsBytes(),
    );
    return importer.importFile(inbox.path, p.basename(original.path));
  }

  test(
    'copies namesakes independently and keeps original files intact',
    () async {
      final first = await source('first', [1, 2, 3]);
      final second = await source('second', [4, 5]);
      final id1 = await importOriginal(first);
      final id2 = await importOriginal(second);
      expect(id1, isNot(id2));
      final rows = await db.select(db.videoItems).get();
      expect(rows, hasLength(2));
      final store = container.read(localVideoStoreProvider);
      expect(await (await store.file(rows[0].path)).readAsBytes(), [1, 2, 3]);
      expect(await (await store.file(rows[1].path)).readAsBytes(), [4, 5]);
      expect(rows.map((row) => row.size), [3, 2]);
      expect(rows.every((row) => p.isRelative(row.path)), isTrue);
      expect(await first.exists(), isTrue);
      expect(await second.exists(), isTrue);
    },
  );

  test('library and history resolve the relocated persistent file', () async {
    final original = await source('original', [1, 2, 3]);
    await importOriginal(original);
    final row = await db.select(db.videoItems).getSingle();
    final item = container.read(videoLibraryPlayerProvider).playableFrom(row);
    await container
        .read(playHistoryRepositoryProvider)
        .recordItem(item, positionMs: 1200);
    await original.delete();
    final relocated = p.join(root.path, 'NewDocuments');
    await Directory(paths.documents).rename(relocated);
    paths.documents = relocated;
    final resolved = await item.resolve();
    expect(resolved.url.toFilePath(), p.join(relocated, row.path));
    expect(await File.fromUri(resolved.url).readAsBytes(), [1, 2, 3]);
    final history = await db.select(db.playHistoryEntries).getSingle();
    final replay = container
        .read(historyPlaybackProvider)
        .playableFrom(history)!;
    expect(replay.stableId, row.id);
    expect((await replay.resolve()).url, resolved.url);
    expect(history.positionMs, 1200);
  });

  test(
    'deleting an imported video cleans file, memberships, history and resume',
    () async {
      final original = await source('original', [1]);
      final id = await importOriginal(original);
      final row = await db.select(db.videoItems).getSingle();
      final item = container.read(videoLibraryPlayerProvider).playableFrom(row);
      final collection = await container
          .read(collectionRepositoryProvider)
          .create('组');
      await repo.setCollectionMembership(id, collection, member: true);
      await container.read(playHistoryRepositoryProvider).recordItem(item);
      final resume = container.read(videoResumeStoreProvider);
      await resume.write(
        VideoResumeSlot(
          id: id,
          sourceKind: 'local',
          sourceId: row.sourceId,
          sourceName: row.sourceName,
          path: row.path,
          fileName: row.fileName,
          positionMs: 100,
          lastPlayedAt: DateTime.now(),
        ),
      );
      await repo.remove(id);
      expect(await db.select(db.videoItems).get(), isEmpty);
      expect(await db.select(db.collectionVideos).get(), isEmpty);
      expect(await db.select(db.playHistoryEntries).get(), isEmpty);
      expect(
        await (await container.read(localVideoStoreProvider).file(row.path))
            .exists(),
        isFalse,
      );
      expect(resume.read(), isNull);
      expect(await original.exists(), isTrue);
    },
  );

  test(
    'failed file move leaves neither row nor partial video directory',
    () async {
      await expectLater(
        importer.importFile(p.join(root.path, 'missing.mp4'), 'missing.mp4'),
        throwsA(isA<FileSystemException>()),
      );
      expect(await db.select(db.videoItems).get(), isEmpty);
      expect(
        await Directory(p.join(paths.documents, 'videos')).list().toList(),
        isEmpty,
      );
    },
  );

  test('picker imports every returned Inbox copy with progress', () async {
    final first = await source('Inbox/1', [1]);
    final second = await source('Inbox/2', [2]);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'pick');
          expect(call.arguments, contains('mp4'));
          return [
            for (final file in [first, second])
              {'path': file.path, 'name': p.basename(file.path)},
          ];
        });
    final progress = <(int, int)>[];
    expect(
      await importer.pickAndImport(
        onProgress: (done, total) => progress.add((done, total)),
      ),
      2,
    );
    expect(progress, [(0, 2), (1, 2), (2, 2)]);
    expect(await db.select(db.videoItems).get(), hasLength(2));
    expect(await first.exists(), isFalse);
    expect(await second.exists(), isFalse);
  });

  test(
    'a partial batch keeps successful imports and clears unimported Inbox files',
    () async {
      final first = await source('Inbox/1', [1]);
      final third = await source('Inbox/3', [3]);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => [
              {'path': first.path, 'name': 'first.mp4'},
              {'path': p.join(root.path, 'missing.mp4'), 'name': 'missing.mp4'},
              {'path': third.path, 'name': 'third.mp4'},
            ],
          );
      final progress = <(int, int)>[];
      await expectLater(
        importer.pickAndImport(
          onProgress: (done, total) => progress.add((done, total)),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(progress, [(0, 3), (1, 3)]);
      final row = await db.select(db.videoItems).getSingle();
      expect(row.fileName, 'first.mp4');
      expect(
        await (await container.read(localVideoStoreProvider).file(row.path))
            .readAsBytes(),
        [1],
      );
      expect(await third.exists(), isFalse);
      expect(
        await Directory(p.join(paths.documents, 'videos')).list().toList(),
        hasLength(1),
      );
    },
  );

  test(
    'database insertion failure removes the adopted file and preserves the original',
    () async {
      final original = await source('original', [1]);
      await db.customStatement(
        "CREATE TRIGGER reject_video BEFORE INSERT ON video_items BEGIN SELECT RAISE(FAIL, 'test failure'); END",
      );
      await expectLater(importOriginal(original), throwsException);
      expect(await db.select(db.videoItems).get(), isEmpty);
      expect(
        await Directory(p.join(paths.documents, 'videos')).list().toList(),
        isEmpty,
      );
      expect(await original.readAsBytes(), [1]);
    },
  );

  test('canceling the picker creates no video', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => []);
    expect(await importer.pickAndImport(onProgress: (_, _) {}), 0);
    expect(await db.select(db.videoItems).get(), isEmpty);
  });
}
