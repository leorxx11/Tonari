import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/core/db/providers.dart';
import 'package:tonari/features/library/data/works_providers.dart';

void main() {
  late TonariDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = TonariDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
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

  Future<void> insertWork(
    String id, {
    String title = '',
    String? titleZh,
    List<String> genres = const [],
    List<String> voiceActors = const [],
    String? seriesName,
    String? circleName,
    List<String> userTags = const [],
  }) async {
    final now = DateTime.now();
    await db
        .into(db.works)
        .insert(
          WorksCompanion.insert(
            productId: id,
            title: title.isEmpty ? 'work $id' : title,
            localImportedAt: now,
            localFolderPath: '/$id',
            createdAt: now,
            updatedAt: now,
            titleZh: Value(titleZh),
            voiceActors: Value(voiceActors),
            seriesName: Value(seriesName),
            circleName: Value(circleName),
            userTags: Value(userTags),
            genresJson: Value(
              jsonEncode([
                for (final g in genres) {'id': '0', 'name': g},
              ]),
            ),
          ),
        );
  }

  Future<List<String>> search(String query) async {
    container.read(workFilterProvider.notifier).setSearchQuery(query);
    final works = await awaitProvider(allWorksProvider.future);
    return works.map((w) => w.productId).toList();
  }

  test('# prefix searches genres with contains matching', () async {
    await insertWork('RJ1', genres: ['耳かき', '囁き']);
    await insertWork('RJ2', genres: ['バイノーラル']);

    expect(await search('#耳かき'), ['RJ1']);
    expect(await search('#耳'), ['RJ1']);
    expect(await search('#バイノ'), ['RJ2']);
  });

  test('# tag search is case-insensitive', () async {
    await insertWork('RJ1', genres: ['ASMR']);

    expect(await search('#asmr'), ['RJ1']);
  });

  test('bare # shows everything', () async {
    await insertWork('RJ1');
    await insertWork('RJ2');

    expect(await search('#'), hasLength(2));
  });

  test('plain query matches Chinese title', () async {
    await insertWork('RJ1', title: '耳かき店', titleZh: '掏耳店');
    await insertWork('RJ2', title: 'ささやき');

    expect(await search('掏耳'), ['RJ1']);
    expect(await search('ささ'), ['RJ2']);
  });

  test('plain query matches CV, circle, series and user tags', () async {
    await insertWork('RJ1', voiceActors: ['花玲', '柚木つばめ']);
    await insertWork('RJ2', circleName: 'シロクマの嫁');
    await insertWork('RJ3', seriesName: '耳元シリーズ');
    await insertWork('RJ4', userTags: ['助眠神作']);

    expect(await search('花玲'), ['RJ1']);
    expect(await search('シロクマ'), ['RJ2']);
    expect(await search('耳元'), ['RJ3']);
    expect(await search('助眠'), ['RJ4']);
  });

  test('plain query matches genre names but not JSON scaffolding', () async {
    await insertWork('RJ1', genres: ['耳かき']);

    expect(await search('耳かき'), ['RJ1']);
    // "name" and "id" only appear in the stored JSON structure, not in any
    // user-facing field — they must not match everything.
    expect(await search('name'), isEmpty);
    expect(await search('id'), isEmpty);
  });

  test('chip filter matches exactly', () async {
    await insertWork('RJ1', genres: ['耳かき'], seriesName: '甘噛み');
    await insertWork('RJ2', genres: ['耳']);

    final notifier = container.read(workFilterProvider.notifier);
    notifier.addChip((kind: WorkChipKind.genre, value: '耳'));
    var works = await awaitProvider(allWorksProvider.future);
    expect(works.map((w) => w.productId), ['RJ2']);

    notifier.clearSearch();
    notifier.addChip((kind: WorkChipKind.series, value: '甘噛み'));
    works = await awaitProvider(allWorksProvider.future);
    expect(works.map((w) => w.productId), ['RJ1']);
  });

  test('multiple chips AND together and are removable', () async {
    await insertWork('RJ1', voiceActors: ['花玲'], genres: ['耳かき']);
    await insertWork('RJ2', voiceActors: ['花玲']);
    await insertWork('RJ3', genres: ['耳かき']);

    final notifier = container.read(workFilterProvider.notifier);
    final cvChip = (kind: WorkChipKind.voiceActor, value: '花玲');
    notifier.addChip(cvChip);
    notifier.addChip(cvChip);
    expect(container.read(workFilterProvider).chips, hasLength(1));

    var ids = (await awaitProvider(
      allWorksProvider.future,
    )).map((w) => w.productId);
    expect(ids, unorderedEquals(['RJ1', 'RJ2']));

    notifier.addChip((kind: WorkChipKind.genre, value: '耳かき'));
    ids = (await awaitProvider(
      allWorksProvider.future,
    )).map((w) => w.productId);
    expect(ids, ['RJ1']);

    notifier.removeChip(cvChip);
    ids = (await awaitProvider(
      allWorksProvider.future,
    )).map((w) => w.productId);
    expect(ids, unorderedEquals(['RJ1', 'RJ3']));
  });
}
