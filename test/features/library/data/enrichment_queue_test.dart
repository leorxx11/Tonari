import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/core/db/providers.dart';
import 'package:tonari/features/library/data/dlsite_fetcher.dart';
import 'package:tonari/features/library/data/enrichment_queue.dart';
import 'package:tonari/features/library/data/metadata_enrichment.dart';
import 'package:tonari/features/library/data/work_image_cache.dart';

void main() {
  late TonariDatabase db;
  late Directory tmp;
  late File goodImage;

  setUp(() {
    db = TonariDatabase.forTesting(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('tonari_enrich_queue_');
    goodImage = File('${tmp.path}/main.jpg')..writeAsBytesSync([1, 2, 3]);
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> insertWork(String id) {
    final now = DateTime(2026, 6, 1);
    return db
        .into(db.works)
        .insert(
          WorksCompanion.insert(
            productId: id,
            title: id,
            localFolderPath: '/library/$id',
            localImportedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  ProviderContainer makeContainer(MetadataEnrichmentService fake) {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        metadataEnrichmentProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('records a failure only after retries are exhausted', () async {
    await insertWork('RJ_OK');
    await insertWork('RJ_BAD');
    final fake = _FakeEnrichment(db, {'RJ_BAD'}, goodImage.path);
    final container = makeContainer(fake);

    await container.read(enrichmentQueueProvider.notifier).runPending();

    final failures = container.read(enrichmentQueueProvider).failures;
    expect(failures.keys, ['RJ_BAD']);
    expect(failures['RJ_BAD'], contains('boom'));
    // The good work succeeded on the first attempt; the bad one was retried up
    // to the cap before being recorded.
    expect(fake.attempts['RJ_OK'], 1);
    expect(fake.attempts['RJ_BAD'], 2);
  });

  test('reset retries capped works; success clears the failure', () async {
    await insertWork('RJ_BAD');
    final fake = _FakeEnrichment(db, {'RJ_BAD'}, goodImage.path);
    final container = makeContainer(fake);

    await container.read(enrichmentQueueProvider.notifier).runPending();
    expect(container.read(enrichmentQueueProvider).failures.keys, ['RJ_BAD']);

    // Without reset the capped work is skipped entirely (no new attempts).
    final before = fake.attempts['RJ_BAD'];
    await container.read(enrichmentQueueProvider.notifier).runPending();
    expect(fake.attempts['RJ_BAD'], before);
    expect(container.read(enrichmentQueueProvider).failures.keys, ['RJ_BAD']);

    // Now make it succeed and reset: failure is cleared.
    fake.failIds.clear();
    await container
        .read(enrichmentQueueProvider.notifier)
        .runPending(reset: true);
    expect(container.read(enrichmentQueueProvider).failures, isEmpty);
  });

  test('manual success can clear a recorded failure', () async {
    await insertWork('RJ_BAD');
    final fake = _FakeEnrichment(db, {'RJ_BAD'}, goodImage.path);
    final container = makeContainer(fake);

    await container.read(enrichmentQueueProvider.notifier).runPending();
    expect(container.read(enrichmentQueueProvider).failures.keys, ['RJ_BAD']);

    fake.failIds.clear();
    await fake.enrichOne('RJ_BAD');
    container.read(enrichmentQueueProvider.notifier).clearFailure('RJ_BAD');

    expect(container.read(enrichmentQueueProvider).failures, isEmpty);
  });
}

class _FakeEnrichment extends MetadataEnrichmentService {
  _FakeEnrichment(this._db, this.failIds, this._goodImagePath)
    : super(
        db: _db,
        fetcher: DlsiteFetcher(),
        imageCache: WorkImageCache(
          documentsDir: () async => Directory.systemTemp,
          downloader: (_, _) async => true,
        ),
      );

  final TonariDatabase _db;
  final Set<String> failIds;
  final String _goodImagePath;
  final Map<String, int> attempts = {};

  @override
  Future<void> enrichOne(
    String productId, {
    bool force = false,
    ImageCacheProgress? onImageProgress,
  }) async {
    attempts[productId] = (attempts[productId] ?? 0) + 1;
    if (failIds.contains(productId)) {
      throw DlsiteFetchException('boom $productId');
    }
    await (_db.update(
      _db.works,
    )..where((r) => r.productId.equals(productId))).write(
      WorksCompanion(
        scrapedAt: Value(DateTime(2026, 6, 1)),
        mainImageLocalPath: Value(_goodImagePath),
      ),
    );
  }
}
