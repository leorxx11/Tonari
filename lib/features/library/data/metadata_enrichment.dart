// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import 'dlsite_fetcher.dart';
import 'work_image_cache.dart';

class MetadataEnrichmentService {
  MetadataEnrichmentService({
    required TonariDatabase db,
    required DlsiteFetcher fetcher,
    required WorkImageCache imageCache,
    Duration delayBetween = const Duration(milliseconds: 200),
  })  : _db = db,
        _fetcher = fetcher,
        _imageCache = imageCache,
        _delay = delayBetween;

  final TonariDatabase _db;
  final DlsiteFetcher _fetcher;
  final WorkImageCache _imageCache;
  final Duration _delay;

  Future<void> enrichBatch(Iterable<String> productIds) async {
    var first = true;
    for (final id in productIds) {
      if (!first) await Future<void>.delayed(_delay);
      first = false;
      try {
        await enrichOne(id);
      } catch (_) {
        // skip; one bad work shouldn't kill the batch
      }
    }
  }

  Future<void> enrichPending() async {
    final rows = await (_db.select(_db.works)
          ..where((r) => r.scrapedAt.isNull() & r.isRemoved.equals(false)))
        .get();
    await enrichBatch(rows.map((r) => r.productId));
  }

  Future<void> enrichOne(String productId, {bool force = false}) async {
    final row = await (_db.select(_db.works)
          ..where((r) => r.productId.equals(productId)))
        .getSingleOrNull();
    if (row == null) return;
    if (!force && row.scrapedAt != null) return;

    final html = await _fetcher.fetchHtml(productId);
    final work = _fetcher.parseHtml(html, productId);
    DlsiteAjaxData? ajax;
    try {
      ajax = await _fetcher.fetchAjax(productId);
    } catch (_) {
      ajax = null;
    }

    WorkImagePaths images = const WorkImagePaths();
    try {
      images = await _imageCache.cache(
        productId: productId,
        mainImageUrl: work.mainImageUrl,
        sampleImageUrls: work.sampleImageUrls,
      );
    } catch (_) {
      // keep URLs even if local caching failed
    }

    final now = DateTime.now();
    await (_db.update(_db.works)..where((r) => r.productId.equals(productId)))
        .write(
      WorksCompanion(
        title: Value(work.title),
        titleRomaji: Value(work.titleRomaji),
        circleId: Value(work.circleId),
        circleName: Value(work.circleName),
        releaseDate: Value(work.releaseDate),
        voiceActors: Value(work.voiceActors),
        illustrators: Value(work.illustrators),
        scenarioWriters: Value(work.scenarioWriters),
        musicians: Value(work.musicians),
        ageRating: Value(work.ageRating),
        workType: Value(work.workType),
        workTypeName: Value(work.workTypeName),
        fileFormats: Value(work.fileFormats),
        genresJson: Value(jsonEncode(work.genres.map((g) => g.toJson()).toList())),
        fileSize: Value(work.fileSize),
        seriesId: Value(work.seriesId),
        seriesName: Value(work.seriesName),
        descriptionHtml: Value(work.descriptionHtml),
        mainImageUrl: Value(work.mainImageUrl),
        sampleImageUrls: Value(work.sampleImageUrls),
        mainImageLocalPath: Value(images.mainImage),
        sampleImageLocalPaths: Value(images.sampleImages),
        rating: Value(ajax?.rateAverage),
        ratingCount: Value(ajax?.rateCount),
        reviewCount: Value(ajax?.reviewCount),
        dlCount: Value(ajax?.dlCount),
        currentPrice: Value(ajax?.price),
        officialPrice: Value(ajax?.officialPrice),
        discountRate: Value(ajax?.discountRate),
        scrapedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }
}

final metadataEnrichmentProvider = Provider<MetadataEnrichmentService>((ref) {
  return MetadataEnrichmentService(
    db: ref.watch(databaseProvider),
    fetcher: ref.watch(dlsiteFetcherProvider),
    imageCache: ref.watch(workImageCacheProvider),
  );
});
