import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/features/library/data/dlsite_fetcher.dart';
import 'package:tonari/features/library/data/metadata_enrichment.dart';
import 'package:tonari/features/library/data/work_image_cache.dart';

void main() {
  late TonariDatabase db;
  late Directory tmp;

  setUp(() {
    db = TonariDatabase.forTesting(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('tonari_metadata_enrichment_');
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> insertWork(
    String productId, {
    DateTime? scrapedAt,
    String? mainImageLocalPath,
    String? title,
    String? titleZh,
    String? descriptionHtml,
    String? descriptionHtmlZh,
    int? dlCount,
  }) {
    final now = DateTime(2026, 5, 27);
    return db
        .into(db.works)
        .insert(
          WorksCompanion.insert(
            productId: productId,
            title: title ?? productId,
            localFolderPath: '/library/$productId',
            localImportedAt: now,
            createdAt: now,
            updatedAt: now,
            scrapedAt: Value(scrapedAt),
            mainImageLocalPath: Value(mainImageLocalPath),
            titleZh: Value(titleZh),
            descriptionHtml: Value(descriptionHtml),
            descriptionHtmlZh: Value(descriptionHtmlZh),
            dlCount: Value(dlCount),
          ),
        );
  }

  MetadataEnrichmentService buildService({
    required _FakeDlsiteFetcher fetcher,
    required ImageDownloader downloader,
  }) {
    return MetadataEnrichmentService(
      db: db,
      fetcher: fetcher,
      imageCache: WorkImageCache(
        documentsDir: () async => tmp,
        downloader: downloader,
      ),
      delayBetween: Duration.zero,
    );
  }

  test('translation work caches the original work main image', () async {
    await insertWork('RJ_TRANSLATED');
    final downloaded = <String>[];
    final fetcher = _FakeDlsiteFetcher({
      'RJ_TRANSLATED': const DlsiteWorkData(
        productId: 'RJ_TRANSLATED',
        title: '中文标题',
        originalProductId: 'RJ_ORIGINAL',
        mainImageUrl: 'https://example.com/RJ_TRANSLATED_img_main.jpg',
      ),
      'RJ_ORIGINAL': const DlsiteWorkData(
        productId: 'RJ_ORIGINAL',
        title: '日本語タイトル',
        circleName: 'Circle',
        mainImageUrl: 'https://example.com/RJ_ORIGINAL_img_main.jpg',
        sampleImageUrls: ['https://example.com/RJ_ORIGINAL_img_smp1.jpg'],
      ),
    });
    final service = buildService(
      fetcher: fetcher,
      downloader: (url, file) async {
        downloaded.add(url);
        file.writeAsBytesSync([1, 2, 3]);
        return true;
      },
    );

    await service.enrichOne('RJ_TRANSLATED');

    final work = await (db.select(
      db.works,
    )..where((w) => w.productId.equals('RJ_TRANSLATED'))).getSingle();
    expect(downloaded.first, 'https://example.com/RJ_ORIGINAL_img_main.jpg');
    expect(work.title, '中文标题');
    expect(work.originalProductId, 'RJ_ORIGINAL');
    expect(work.circleName, 'Circle');
    expect(work.mainImageUrl, 'https://example.com/RJ_ORIGINAL_img_main.jpg');
    expect(work.mainImageLocalPath, 'images/RJ_TRANSLATED/main.jpg');
    expect(work.sampleImageUrls, [
      'https://example.com/RJ_ORIGINAL_img_smp1.jpg',
    ]);
    expect(work.scrapedAt, isNotNull);
  });

  test('main image cache failure keeps work pending', () async {
    await insertWork('RJ_FAIL');
    final service = buildService(
      fetcher: _FakeDlsiteFetcher({
        'RJ_FAIL': const DlsiteWorkData(
          productId: 'RJ_FAIL',
          title: 'Title',
          mainImageUrl: 'https://example.com/RJ_FAIL_img_main.jpg',
        ),
      }),
      downloader: (url, file) async {
        file.writeAsBytesSync([0]);
        return false;
      },
    );

    await expectLater(
      service.enrichOne('RJ_FAIL'),
      throwsA(isA<DlsiteFetchException>()),
    );

    final work = await (db.select(
      db.works,
    )..where((w) => w.productId.equals('RJ_FAIL'))).getSingle();
    expect(work.scrapedAt, isNull);
    expect(work.mainImageLocalPath, isNull);
  });

  test(
    'pending enrichment retries rows whose local main image is missing',
    () async {
      await insertWork(
        'RJ_STALE',
        scrapedAt: DateTime(2026, 5, 26),
        mainImageLocalPath: '/missing/images/RJ_STALE/main.jpg',
      );
      final downloaded = <String>[];
      final service = buildService(
        fetcher: _FakeDlsiteFetcher({
          'RJ_STALE': const DlsiteWorkData(
            productId: 'RJ_STALE',
            title: 'Refreshed',
            mainImageUrl: 'https://example.com/RJ_STALE_img_main.jpg',
          ),
        }),
        downloader: (url, file) async {
          downloaded.add(url);
          file.writeAsBytesSync([1]);
          return true;
        },
      );

      await service.enrichPending();

      final work = await (db.select(
        db.works,
      )..where((w) => w.productId.equals('RJ_STALE'))).getSingle();
      expect(downloaded, ['https://example.com/RJ_STALE_img_main.jpg']);
      expect(work.title, 'Refreshed');
      expect(work.mainImageLocalPath, 'images/RJ_STALE/main.jpg');
    },
  );

  Future<Work> row(String productId) => (db.select(
    db.works,
  )..where((w) => w.productId.equals(productId))).getSingle();

  String cachedCover() {
    final file = File('${tmp.path}/cover.jpg')..writeAsBytesSync([1]);
    return file.path;
  }

  test('refreshStats updates only the stats columns', () async {
    await insertWork('RJ1', title: 'Old', titleZh: '旧', dlCount: 0);
    final service = buildService(
      fetcher: _FakeDlsiteFetcher(
        const {},
        ajax: {
          'RJ1': const DlsiteAjaxData(
            productId: 'RJ1',
            dlCount: 4714,
            rateAverage: 4.5,
          ),
        },
      ),
      downloader: (url, file) async => fail('no image download expected'),
    );

    await service.refreshStats('RJ1');

    final work = await row('RJ1');
    expect(work.dlCount, 4714);
    expect(work.rating, 4.5);
    expect(work.title, 'Old');
    expect(work.titleZh, '旧');
  });

  test(
    'refreshStats fails instead of wiping stats when DLsite has none',
    () async {
      await insertWork('RJ1', dlCount: 10);
      final service = buildService(
        fetcher: _FakeDlsiteFetcher(const {}),
        downloader: (url, file) async => true,
      );

      await expectLater(
        service.refreshStats('RJ1'),
        throwsA(isA<DlsiteFetchException>()),
      );
      expect((await row('RJ1')).dlCount, 10);
    },
  );

  test('refreshMetadata keeps images and unchanged translations', () async {
    final cover = cachedCover();
    await insertWork(
      'RJ1',
      scrapedAt: DateTime(2026),
      mainImageLocalPath: cover,
      title: 'Same title',
      titleZh: '同样的标题',
      descriptionHtml: '<p>old</p>',
      descriptionHtmlZh: '<p>旧</p>',
    );
    final service = buildService(
      fetcher: _FakeDlsiteFetcher(
        {
          'RJ1': const DlsiteWorkData(
            productId: 'RJ1',
            title: 'Same title',
            circleName: 'New circle',
            descriptionHtml: '<p>new</p>',
            mainImageUrl: 'https://example.com/main.jpg',
          ),
        },
        ajax: {'RJ1': const DlsiteAjaxData(productId: 'RJ1', dlCount: 7)},
      ),
      downloader: (url, file) async => fail('no image download expected'),
    );

    await service.refreshMetadata('RJ1');

    final work = await row('RJ1');
    expect(work.circleName, 'New circle');
    expect(work.dlCount, 7);
    expect(work.mainImageLocalPath, cover);
    expect(work.titleZh, '同样的标题');
    expect(work.descriptionHtml, '<p>new</p>');
    expect(work.descriptionHtmlZh, isNull);
  });

  test('refreshAllStats covers enriched works and counts failures', () async {
    await insertWork('RJ1', scrapedAt: DateTime(2026));
    await insertWork('RJ2', scrapedAt: DateTime(2026));
    await insertWork('RJ_PENDING');
    final service = buildService(
      fetcher: _FakeDlsiteFetcher(
        const {},
        ajax: {'RJ1': const DlsiteAjaxData(productId: 'RJ1', dlCount: 5)},
      ),
      downloader: (url, file) async => true,
    );
    final progress = <(int, int)>[];

    final failed = await service.refreshAllStats(
      onProgress: (done, total, _) => progress.add((done, total)),
    );

    expect(failed, 1);
    expect((await row('RJ1')).dlCount, 5);
    expect(progress.last, (2, 2));
  });
}

class _FakeDlsiteFetcher extends DlsiteFetcher {
  _FakeDlsiteFetcher(this.works, {this.ajax = const {}});

  final Map<String, DlsiteWorkData> works;
  final Map<String, DlsiteAjaxData> ajax;

  @override
  Future<String> fetchHtml(String productId) async => productId;

  @override
  DlsiteWorkData parseHtml(String html, String productId) => works[productId]!;

  @override
  Future<DlsiteAjaxData> fetchAjax(String productId) async {
    return ajax[productId] ?? DlsiteAjaxData(productId: productId);
  }
}
