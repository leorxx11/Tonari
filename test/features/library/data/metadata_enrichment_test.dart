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
  }) {
    final now = DateTime(2026, 5, 27);
    return db
        .into(db.works)
        .insert(
          WorksCompanion.insert(
            productId: productId,
            title: productId,
            localFolderPath: '/library/$productId',
            localImportedAt: now,
            createdAt: now,
            updatedAt: now,
            scrapedAt: Value(scrapedAt),
            mainImageLocalPath: Value(mainImageLocalPath),
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
}

class _FakeDlsiteFetcher extends DlsiteFetcher {
  _FakeDlsiteFetcher(this.works);

  final Map<String, DlsiteWorkData> works;

  @override
  Future<String> fetchHtml(String productId) async => productId;

  @override
  DlsiteWorkData parseHtml(String html, String productId) => works[productId]!;

  @override
  Future<DlsiteAjaxData> fetchAjax(String productId) async {
    return DlsiteAjaxData(productId: productId);
  }
}
