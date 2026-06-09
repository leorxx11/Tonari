// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../../core/files/local_image_path.dart';
import 'dlsite_fetcher.dart';
import 'work_image_cache.dart';

typedef MetadataProgress =
    void Function(int completed, int total, String current);

class MetadataEnrichmentService {
  MetadataEnrichmentService({
    required TonariDatabase db,
    required DlsiteFetcher fetcher,
    required WorkImageCache imageCache,
    Duration delayBetween = const Duration(milliseconds: 200),
  }) : _db = db,
       _fetcher = fetcher,
       _imageCache = imageCache,
       _delay = delayBetween;

  final TonariDatabase _db;
  final DlsiteFetcher _fetcher;
  final WorkImageCache _imageCache;
  final Duration _delay;

  Future<void> enrichBatch(
    Iterable<String> productIds, {
    MetadataProgress? onProgress,
  }) async {
    final ids = productIds.toList();
    for (var i = 0; i < ids.length; i++) {
      final id = ids[i];
      onProgress?.call(i, ids.length, id);
      if (i > 0) await Future<void>.delayed(_delay);
      try {
        await enrichOne(id);
      } catch (_) {
        // skip; one bad work shouldn't kill the batch
      }
      onProgress?.call(i + 1, ids.length, id);
    }
  }

  Future<void> enrichPending() async {
    final rows = await (_db.select(
      _db.works,
    )..where((r) => r.isRemoved.equals(false))).get();
    await enrichBatch(
      rows
          .where(
            (r) =>
                r.scrapedAt == null ||
                LocalImagePath.resolve(r.mainImageLocalPath) == null,
          )
          .map((r) => r.productId),
    );
  }

  Future<void> enrichOne(
    String productId, {
    bool force = false,
    ImageCacheProgress? onImageProgress,
  }) async {
    final row = await (_db.select(
      _db.works,
    )..where((r) => r.productId.equals(productId))).getSingleOrNull();
    if (row == null) return;
    if (!force &&
        row.scrapedAt != null &&
        LocalImagePath.resolve(row.mainImageLocalPath) != null) {
      return;
    }

    if (force) {
      await _imageCache.evict(productId);
    }

    final translated = _fetcher.parseHtml(
      await _fetcher.fetchHtml(productId),
      productId,
    );

    // DLsite translation editions (e.g. "大家一起来翻译") get their own
    // RJ but the page is sparse: no product-slider sample gallery, and
    // upstream credits/runtime fields can be missing. The og:image URL still
    // points at the original work's image bucket, which is how we discover
    // the original RJ. When present, fetch the original page and merge.
    DlsiteWorkData? original;
    if (translated.originalProductId != null) {
      try {
        original = _fetcher.parseHtml(
          await _fetcher.fetchHtml(translated.originalProductId!),
          translated.originalProductId!,
        );
      } catch (_) {
        original = null;
      }
    }
    final work = _merge(translated, original);

    DlsiteAjaxData? ajax;
    try {
      ajax = await _fetcher.fetchAjax(productId);
    } catch (_) {
      ajax = null;
    }

    final images = await _imageCache.cache(
      productId: productId,
      mainImageUrl: work.mainImageUrl,
      sampleImageUrls: work.sampleImageUrls,
      descriptionImageUrls: work.descriptionImageUrls,
      onProgress: onImageProgress,
    );
    if (images.mainImage == null) {
      throw DlsiteFetchException('Failed to cache main image for $productId');
    }

    final now = DateTime.now();
    await (_db.update(
      _db.works,
    )..where((r) => r.productId.equals(productId))).write(
      WorksCompanion(
        title: Value(work.title),
        titleRomaji: Value(work.titleRomaji),
        originalProductId: Value(work.originalProductId),
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
        supportedLanguages: Value(work.supportedLanguages),
        genresJson: Value(
          jsonEncode(work.genres.map((g) => g.toJson()).toList()),
        ),
        fileSize: Value(work.fileSize),
        seriesId: Value(work.seriesId),
        seriesName: Value(work.seriesName),
        descriptionHtml: Value(work.descriptionHtml),
        titleZh: force ? const Value(null) : const Value.absent(),
        descriptionHtmlZh: force ? const Value(null) : const Value.absent(),
        mainImageUrl: Value(work.mainImageUrl),
        sampleImageUrls: Value(work.sampleImageUrls),
        mainImageLocalPath: Value(images.mainImage),
        sampleImageLocalPaths: Value(images.sampleImages),
        descriptionImageLocalPaths: Value(images.descriptionImages),
        rating: Value(ajax?.rateAverage),
        ratingCount: Value(ajax?.rateCount),
        reviewCount: Value(ajax?.reviewCount),
        dlCount: Value(ajax?.dlCount),
        wishlistCount: Value(ajax?.wishlistCount),
        rankDay: Value(ajax?.rankDay),
        rankWeek: Value(ajax?.rankWeek),
        rankMonth: Value(ajax?.rankMonth),
        currentPrice: Value(ajax?.price),
        officialPrice: Value(ajax?.officialPrice),
        discountRate: Value(ajax?.discountRate),
        scrapedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Re-downloads only the work's images, leaving every other column —
  /// including the cached translation — untouched. Use when the user
  /// wants to refresh artwork without paying the LLM cost again or losing
  /// already-translated copy.
  Future<void> refreshImages(
    String productId, {
    ImageCacheProgress? onImageProgress,
  }) async {
    final row = await (_db.select(
      _db.works,
    )..where((r) => r.productId.equals(productId))).getSingleOrNull();
    if (row == null) return;
    final mainUrl = row.mainImageUrl;
    if (mainUrl == null || mainUrl.isEmpty) {
      throw DlsiteFetchException(
        'Cannot refresh images: $productId has no mainImageUrl yet',
      );
    }
    // Description image URLs aren't persisted as a separate column; we
    // re-extract them from the cached descriptionHtml (always the original,
    // not the LLM-translated copy in descriptionHtmlZh).
    final descUrls = _extractDescriptionImageUrls(row.descriptionHtml);
    await _imageCache.evict(productId);
    final images = await _imageCache.cache(
      productId: productId,
      mainImageUrl: mainUrl,
      sampleImageUrls: row.sampleImageUrls,
      descriptionImageUrls: descUrls,
      onProgress: onImageProgress,
    );
    if (images.mainImage == null) {
      throw DlsiteFetchException('Failed to cache main image for $productId');
    }
    await (_db.update(
      _db.works,
    )..where((r) => r.productId.equals(productId))).write(
      WorksCompanion(
        mainImageLocalPath: Value(images.mainImage),
        sampleImageLocalPaths: Value(images.sampleImages),
        descriptionImageLocalPaths: Value(images.descriptionImages),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  static List<String> _extractDescriptionImageUrls(String? html) {
    if (html == null || html.isEmpty) return const [];
    final out = <String>[];
    for (final m in RegExp(
      r'''<img\s[^>]*?(?:src|data-src)\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).allMatches(html)) {
      var src = m.group(1)!;
      if (src.startsWith('//')) src = 'https:$src';
      out.add(src);
    }
    return out;
  }

  /// Combines a translation-edition page with its original Japanese page.
  /// Translation page wins for user-facing localized fields (title, desc,
  /// language list); the original wins for upstream catalog data that the
  /// translation page tends to omit (sample gallery, cast, runtime, genres).
  /// Stats and pricing come from neither — those are fetched per-edition via
  /// the ajax endpoint by the caller.
  DlsiteWorkData _merge(DlsiteWorkData t, DlsiteWorkData? o) {
    if (o == null) return t;
    return DlsiteWorkData(
      productId: t.productId,
      title: t.title,
      titleRomaji: t.titleRomaji ?? o.titleRomaji,
      originalProductId: t.originalProductId,
      circleId: t.circleId ?? o.circleId,
      circleName: t.circleName ?? o.circleName,
      releaseDate: o.releaseDate ?? t.releaseDate,
      voiceActors: o.voiceActors.isNotEmpty ? o.voiceActors : t.voiceActors,
      illustrators: o.illustrators.isNotEmpty ? o.illustrators : t.illustrators,
      scenarioWriters: o.scenarioWriters.isNotEmpty
          ? o.scenarioWriters
          : t.scenarioWriters,
      musicians: o.musicians.isNotEmpty ? o.musicians : t.musicians,
      ageRating: t.ageRating ?? o.ageRating,
      workType: t.workType ?? o.workType,
      workTypeName: t.workTypeName ?? o.workTypeName,
      fileFormats: t.fileFormats.isNotEmpty ? t.fileFormats : o.fileFormats,
      supportedLanguages: t.supportedLanguages.isNotEmpty
          ? t.supportedLanguages
          : o.supportedLanguages,
      genres: o.genres.isNotEmpty ? o.genres : t.genres,
      fileSize: o.fileSize ?? t.fileSize,
      seriesId: t.seriesId ?? o.seriesId,
      seriesName: t.seriesName ?? o.seriesName,
      descriptionHtml: t.descriptionHtml ?? o.descriptionHtml,
      mainImageUrl: o.mainImageUrl,
      sampleImageUrls: o.sampleImageUrls.isNotEmpty
          ? o.sampleImageUrls
          : t.sampleImageUrls,
      descriptionImageUrls: t.descriptionImageUrls.isNotEmpty
          ? t.descriptionImageUrls
          : o.descriptionImageUrls,
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
