import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/core/db/providers.dart';
import 'package:tonari/features/library/data/collections_providers.dart';

void main() {
  late TonariDatabase db;
  late ProviderContainer container;
  late CollectionRepository repo;

  setUp(() {
    db = TonariDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    repo = container.read(collectionRepositoryProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // Riverpod 3 pauses providers without listeners, so a bare
  // `container.read(p.future)` never resolves for stream providers.
  Future<T> awaitProvider<T>(ProviderListenable<Future<T>> provider) async {
    final sub = container.listen(provider, (_, _) {});
    try {
      return await sub.read();
    } finally {
      sub.close();
    }
  }

  Future<void> insertWork(String id, {bool removed = false}) async {
    final now = DateTime.now();
    await db
        .into(db.works)
        .insert(
          WorksCompanion.insert(
            productId: id,
            title: 'work $id',
            localImportedAt: now,
            localFolderPath: '/$id',
            createdAt: now,
            updatedAt: now,
            isRemoved: Value(removed),
          ),
        );
  }

  test('create and list collections', () async {
    await repo.create('入眠');
    await repo.create('助兴');

    final collections = await awaitProvider(collectionsProvider.future);
    expect(collections.map((c) => c.name), ['入眠', '助兴']);
  });

  test('rename updates the collection', () async {
    final id = await repo.create('旧名');
    await repo.rename(id, '新名');

    final collections = await awaitProvider(collectionsProvider.future);
    expect(collections.single.name, '新名');
  });

  test('setMembership is idempotent and removable', () async {
    await insertWork('RJ1');
    final id = await repo.create('组');

    await repo.setMembership('RJ1', id, member: true);
    await repo.setMembership('RJ1', id, member: true);
    expect(await db.select(db.collectionWorks).get(), hasLength(1));

    await repo.setMembership('RJ1', id, member: false);
    expect(await db.select(db.collectionWorks).get(), isEmpty);
  });

  test(
    'collectionWorksProvider returns member works excluding removed',
    () async {
      await insertWork('RJ1');
      await insertWork('RJ2', removed: true);
      await insertWork('RJ3');
      final id = await repo.create('组');
      await repo.setMembership('RJ1', id, member: true);
      await repo.setMembership('RJ2', id, member: true);

      final works = await awaitProvider(collectionWorksProvider(id).future);
      expect(works.map((w) => w.productId), ['RJ1']);
    },
  );

  test('workCollectionIdsProvider reflects memberships', () async {
    await insertWork('RJ1');
    final a = await repo.create('A');
    final b = await repo.create('B');
    await repo.setMembership('RJ1', a, member: true);
    await repo.setMembership('RJ1', b, member: true);

    final ids = await awaitProvider(workCollectionIdsProvider('RJ1').future);
    expect(ids, {a, b});
  });

  test('delete cascades to memberships', () async {
    await insertWork('RJ1');
    final id = await repo.create('组');
    await repo.setMembership('RJ1', id, member: true);

    await repo.delete(id);

    expect(await db.select(db.collections).get(), isEmpty);
    expect(await db.select(db.collectionWorks).get(), isEmpty);
  });
}
