import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/core/db/providers.dart';
import 'package:tonari/features/browse/data/remote_models.dart';
import 'package:tonari/features/history/data/play_history_repository.dart';

PlayableItem _item({
  RemoteSourceKind sourceKind = RemoteSourceKind.p115,
  String sourceId = '115',
  String path = 'fid1',
  String fileName = 'a.mp4',
  String? pickcode = 'pc1',
  RemoteEntryKind kind = RemoteEntryKind.video,
}) {
  return PlayableItem(
    id: 'queue:$path',
    sourceKind: sourceKind,
    sourceId: sourceId,
    sourceName: '115 网盘',
    path: path,
    fileName: fileName,
    kind: kind,
    pickcode: pickcode,
    resolve: () async => throw UnimplementedError(),
  );
}

void main() {
  late TonariDatabase db;
  late ProviderContainer container;
  late PlayHistoryRepository repo;

  setUp(() {
    db = TonariDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    repo = container.read(playHistoryRepositoryProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('stableId keys p115 items by pickcode across entry points', () {
    final fromBrowser = _item(path: 'fid1', pickcode: 'pc1');
    final fromWorkFiles = _item(path: 'pc1', pickcode: 'pc1');
    expect(fromBrowser.stableId, 'p115:pc1');
    expect(fromBrowser.stableId, fromWorkFiles.stableId);

    final webdav = _item(
      sourceKind: RemoteSourceKind.webdav,
      sourceId: 'srv1',
      path: '/v/a.mp4',
      pickcode: null,
    );
    expect(webdav.stableId, 'webdav:srv1:/v/a.mp4');
  });

  test('recordItem upserts on replay instead of duplicating', () async {
    await repo.recordItem(_item(), positionMs: 1000, durationMs: 60000);
    await repo.recordItem(_item(path: 'renamed'), positionMs: 5000);

    final rows = await db.select(db.playHistoryEntries).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, 'p115:pc1');
    expect(rows.single.positionMs, 5000);
  });

  test('recordWork and positionMsOf round-trip', () async {
    final now = DateTime.now();
    await db
        .into(db.works)
        .insert(
          WorksCompanion.insert(
            productId: 'RJ1',
            title: '作品',
            localImportedAt: now,
            localFolderPath: '/RJ1',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final work = await db.select(db.works).getSingle();
    await repo.recordWork(work);
    await repo.recordItem(_item(), positionMs: 4321);

    expect(await repo.positionMsOf('work:RJ1'), 0);
    expect(await repo.positionMsOf('p115:pc1'), 4321);
    expect(await repo.positionMsOf('missing'), isNull);
  });

  test('keeps only the most recent maxEntries rows', () async {
    for (var i = 0; i < PlayHistoryRepository.maxEntries + 5; i++) {
      await db
          .into(db.playHistoryEntries)
          .insert(
            PlayHistoryEntriesCompanion.insert(
              id: 'old:$i',
              kind: 'audio',
              title: 'old $i',
              playedAt: DateTime(2020).add(Duration(minutes: i)),
            ),
          );
    }
    await repo.recordItem(_item());

    final rows = await db.select(db.playHistoryEntries).get();
    expect(rows, hasLength(PlayHistoryRepository.maxEntries));
    expect(rows.any((r) => r.id == 'p115:pc1'), isTrue);
    expect(rows.any((r) => r.id == 'old:0'), isFalse);
  });

  test('remove and clear', () async {
    await repo.recordItem(_item());
    await repo.recordItem(
      _item(sourceKind: RemoteSourceKind.webdav, pickcode: null),
    );

    await repo.remove('p115:pc1');
    expect(await db.select(db.playHistoryEntries).get(), hasLength(1));

    await repo.clear();
    expect(await db.select(db.playHistoryEntries).get(), isEmpty);
  });
}
