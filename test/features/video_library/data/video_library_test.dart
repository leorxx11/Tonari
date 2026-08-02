import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/core/db/providers.dart';
import 'package:tonari/features/browse/data/remote_models.dart';
import 'package:tonari/features/library/data/collections_providers.dart';
import 'package:tonari/features/video_library/data/video_library_providers.dart';

PlayableItem _video({String path = 'fid1', String? pickcode = 'pc1'}) {
  return PlayableItem(
    id: '115:$path',
    sourceKind: RemoteSourceKind.p115,
    sourceId: '115',
    sourceName: '115 网盘',
    path: path,
    fileName: 'クリニック.mp4',
    kind: RemoteEntryKind.video,
    size: 123,
    pickcode: pickcode,
    resolve: () async => throw UnimplementedError(),
  );
}

void main() {
  late TonariDatabase db;
  late ProviderContainer container;
  late VideoLibraryRepository repo;

  setUp(() {
    db = TonariDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    repo = container.read(videoLibraryRepositoryProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<T> awaitProvider<T>(ProviderListenable<Future<T>> provider) async {
    final sub = container.listen(provider, (_, _) {});
    try {
      return await sub.read();
    } finally {
      sub.close();
    }
  }

  test('add stores the item once and dedupes by pickcode', () async {
    expect(await repo.add(_video()), isTrue);
    // Same file reached through another entry point: path differs, pickcode
    // matches — must not create a second row.
    expect(await repo.add(_video(path: 'other')), isFalse);

    final rows = await db.select(db.videoItems).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, 'p115:pc1');
    expect(rows.single.fileName, 'クリニック.mp4');
  });

  test('rename trims and clears the custom title', () async {
    await repo.add(_video());
    await repo.rename('p115:pc1', '  新标题  ');
    var row = await db.select(db.videoItems).getSingle();
    expect(row.customTitle, '新标题');
    expect(videoItemTitle(row), '新标题');

    await repo.rename('p115:pc1', '   ');
    row = await db.select(db.videoItems).getSingle();
    expect(row.customTitle, isNull);
    expect(videoItemTitle(row), 'クリニック');
  });

  test('favorite toggle persists', () async {
    await repo.add(_video());
    await repo.setFavorite('p115:pc1', true);
    expect((await db.select(db.videoItems).getSingle()).isFavorite, isTrue);
  });

  test('collection membership joins and remove cleans up', () async {
    await repo.add(_video());
    final collections = container.read(collectionRepositoryProvider);
    final groupId = await collections.create('组');
    await repo.setCollectionMembership('p115:pc1', groupId, member: true);

    final videos = await awaitProvider(collectionVideosProvider(groupId).future);
    expect(videos.map((v) => v.id), ['p115:pc1']);
    expect(
      await awaitProvider(videoCollectionIdsProvider('p115:pc1').future),
      {groupId},
    );

    await repo.remove('p115:pc1');
    expect(await db.select(db.videoItems).get(), isEmpty);
    expect(await db.select(db.collectionVideos).get(), isEmpty);
  });

  test('playableFrom rebuilds identity fields from the row', () async {
    await repo.add(_video());
    await repo.rename('p115:pc1', '自定义');
    final row = await db.select(db.videoItems).getSingle();

    final item = container.read(videoLibraryPlayerProvider).playableFrom(row);
    expect(item.sourceKind, RemoteSourceKind.p115);
    expect(item.pickcode, 'pc1');
    expect(item.title, '自定义');
    expect(item.stableId, 'p115:pc1');
    expect(item.isVideo, isTrue);
  });
}
