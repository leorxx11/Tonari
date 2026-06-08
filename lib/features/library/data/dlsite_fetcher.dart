import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

final dlsiteFetcherProvider = Provider<DlsiteFetcher>((ref) {
  return DlsiteFetcher();
});

class DlsiteGenre {
  const DlsiteGenre({this.id, required this.name});

  final String? id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      other is DlsiteGenre && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'DlsiteGenre($id, $name)';
}

class DlsiteWorkData {
  const DlsiteWorkData({
    required this.productId,
    required this.title,
    this.titleRomaji,
    this.originalProductId,
    this.circleId,
    this.circleName,
    this.releaseDate,
    this.voiceActors = const [],
    this.illustrators = const [],
    this.scenarioWriters = const [],
    this.musicians = const [],
    this.ageRating,
    this.workType,
    this.workTypeName,
    this.fileFormats = const [],
    this.supportedLanguages = const [],
    this.genres = const [],
    this.fileSize,
    this.seriesId,
    this.seriesName,
    this.descriptionHtml,
    required this.mainImageUrl,
    this.sampleImageUrls = const [],
    this.descriptionImageUrls = const [],
  });

  final String productId;
  final String title;
  final String? titleRomaji;

  /// When [productId] is a DLsite translation edition, this is the original
  /// Japanese release's RJ number (extracted from the page's og:image URL,
  /// which always points to the original work's image bucket). Null when the
  /// page represents the original work itself.
  final String? originalProductId;
  final String? circleId;
  final String? circleName;
  final DateTime? releaseDate;
  final List<String> voiceActors;
  final List<String> illustrators;
  final List<String> scenarioWriters;
  final List<String> musicians;
  final String? ageRating;
  final String? workType;
  final String? workTypeName;
  final List<String> fileFormats;
  final List<String> supportedLanguages;
  final List<DlsiteGenre> genres;
  final String? fileSize;
  final String? seriesId;
  final String? seriesName;
  final String? descriptionHtml;
  final String mainImageUrl;
  final List<String> sampleImageUrls;
  final List<String> descriptionImageUrls;
}

class DlsiteAjaxData {
  const DlsiteAjaxData({
    required this.productId,
    this.dlCount,
    this.wishlistCount,
    this.rateAverage,
    this.rateCount,
    this.reviewCount,
    this.price,
    this.officialPrice,
    this.discountRate,
    this.isOnSale,
    this.isDiscount,
    this.rankDay,
    this.rankWeek,
    this.rankMonth,
  });

  final String productId;
  final int? dlCount;
  final int? wishlistCount;
  final double? rateAverage;
  final int? rateCount;
  final int? reviewCount;
  final int? price;
  final int? officialPrice;
  final int? discountRate;
  final bool? isOnSale;
  final bool? isDiscount;
  final int? rankDay;
  final int? rankWeek;
  final int? rankMonth;
}

class DlsiteFetchException implements Exception {
  DlsiteFetchException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'DlsiteFetchException: $message'
      : 'DlsiteFetchException: $message ($cause)';
}

class DlsiteFetcher {
  DlsiteFetcher({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _baseUrl = 'https://www.dlsite.com';
  static const _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15';

  Future<String> fetchHtml(String productId) async {
    final url = '$_baseUrl/maniax/work/=/product_id/$productId.html';
    try {
      final res = await _dio.get<String>(
        url,
        options: Options(
          headers: {
            'User-Agent': _userAgent,
            'Cookie': 'adultchecked=1; locale=zh-cn',
          },
          responseType: ResponseType.plain,
        ),
      );
      final data = res.data;
      if (data == null || data.isEmpty) {
        throw DlsiteFetchException('Empty response for $productId');
      }
      return data;
    } on DioException catch (e) {
      throw DlsiteFetchException('Failed to fetch $productId', e);
    }
  }

  Future<DlsiteWorkData> fetch(String productId) async {
    final html = await fetchHtml(productId);
    return parseHtml(html, productId);
  }

  Future<String> fetchAjaxJson(String productId) async {
    final url = '$_baseUrl/maniax/product/info/ajax?product_id=$productId';
    try {
      final res = await _dio.get<String>(
        url,
        options: Options(
          headers: {
            'User-Agent': _userAgent,
            'Cookie': 'adultchecked=1; locale=zh-cn',
          },
          responseType: ResponseType.plain,
        ),
      );
      final data = res.data;
      if (data == null || data.isEmpty) {
        throw DlsiteFetchException('Empty AJAX response for $productId');
      }
      return data;
    } on DioException catch (e) {
      throw DlsiteFetchException('Failed to fetch AJAX for $productId', e);
    }
  }

  Future<DlsiteAjaxData> fetchAjax(String productId) async {
    final json = await fetchAjaxJson(productId);
    return parseAjaxJson(json, productId);
  }

  DlsiteAjaxData parseAjaxJson(String body, String productId) {
    final Map<String, dynamic> node;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded[productId] is Map) {
        node = Map<String, dynamic>.from(decoded[productId] as Map);
      } else {
        return DlsiteAjaxData(productId: productId);
      }
    } catch (_) {
      return DlsiteAjaxData(productId: productId);
    }

    final price = _tryGet(() => _asInt(node['price']));
    final officialPrice = _tryGet(() => _asInt(node['official_price']));
    final ranks =
        _tryGet(() => _parseRanks(node['rank'])) ?? const <String, int>{};
    return DlsiteAjaxData(
      productId: productId,
      dlCount: _tryGet(
        () => _asInt(node['dl_count_total']) ?? _asInt(node['dl_count']),
      ),
      wishlistCount: _tryGet(() => _asInt(node['wishlist_count'])),
      rateAverage: _tryGet(
        () =>
            _asDouble(node['rate_average_2dp']) ??
            _asDouble(node['rate_average']),
      ),
      rateCount: _tryGet(() => _asInt(node['rate_count'])),
      reviewCount: _tryGet(() => _asInt(node['review_count'])),
      price: price,
      officialPrice: officialPrice,
      discountRate: _tryGet(() => _discountRate(price, officialPrice)),
      isOnSale: _tryGet(() => _asBool(node['on_sale'])),
      isDiscount: _tryGet(() => _asBool(node['is_discount'])),
      rankDay: ranks['day'],
      rankWeek: ranks['week'],
      rankMonth: ranks['month'],
    );
  }

  static Map<String, int> _parseRanks(dynamic raw) {
    if (raw is! List) return const {};
    final out = <String, int>{};
    for (final item in raw) {
      if (item is! Map) continue;
      if (item['category'] != 'all') continue;
      final term = item['term'];
      final rank = _asInt(item['rank']);
      if (term is String && rank != null) out[term] = rank;
    }
    return out;
  }

  static int? _discountRate(int? price, int? officialPrice) {
    if (price == null || officialPrice == null) return null;
    if (officialPrice <= 0 || price >= officialPrice) return 0;
    return ((1 - price / officialPrice) * 100).round();
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static bool? _asBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return null;
  }

  DlsiteWorkData parseHtml(String html, String productId) {
    final doc = html_parser.parse(html);
    final outline = _collectOutline(doc);
    final description = doc.querySelector('[itemprop="description"]');
    final ogImage = _attr(doc, 'meta[property="og:image"]', 'content');
    final imageRj = _extractImageProductId(ogImage);
    final originalProductId = (imageRj != null && imageRj != productId)
        ? imageRj
        : null;
    final mainImageUrl = (ogImage != null && ogImage.isNotEmpty)
        ? _normalizeUrl(ogImage)
        : mainImageUrlFor(imageRj ?? productId);
    return DlsiteWorkData(
      productId: productId,
      title: _tryGet(() => _textOrNull(doc, '#work_name')) ?? productId,
      titleRomaji: _tryGet(
        () => _attr(doc, 'meta[itemprop="alternateName"]', 'content'),
      ),
      originalProductId: originalProductId,
      circleId: _tryGet(() => _circleId(doc, productId)),
      circleName: _tryGet(() => _textOrNull(doc, '.maker_name')),
      releaseDate: _tryGet(() => _parseReleaseDate(outline['发售日'])),
      voiceActors: _tryGet(() => _anchorTexts(outline['声优'])) ?? const [],
      illustrators: _tryGet(() => _anchorTexts(outline['插画'])) ?? const [],
      scenarioWriters: _tryGet(() => _anchorTexts(outline['剧情'])) ?? const [],
      musicians: _tryGet(() => _anchorTexts(outline['音乐'])) ?? const [],
      ageRating: _tryGet(() => _ageRating(outline['年龄指定'])),
      workType: _tryGet(() => _workType(doc, outline['作品形式'])),
      workTypeName: _tryGet(() => _workTypeName(outline['作品形式'])),
      fileFormats: _tryGet(() => _fileFormats(outline['文件形式'])) ?? const [],
      supportedLanguages:
          _tryGet(() => _supportedLanguages(outline['支持的语言'])) ?? const [],
      genres: _tryGet(() => _genres(outline['分类'])) ?? const [],
      fileSize: _tryGet(() => _fileSize(outline['文件容量'])),
      seriesId: _tryGet(() => _seriesId(outline['系列名'])),
      seriesName: _tryGet(
        () => _textOrNullElem(outline['系列名']?.querySelector('a')),
      ),
      descriptionHtml: _tryGet(() => description?.innerHtml.trim()),
      mainImageUrl: mainImageUrl,
      sampleImageUrls: _tryGet(() => _sampleImages(doc)) ?? const [],
      descriptionImageUrls:
          _tryGet(() => _descriptionImages(description)) ?? const [],
    );
  }

  /// Extracts the work-id segment from a DLsite image CDN URL. URLs look like
  /// `//img.dlsite.jp/modpub/images2/work/doujin/RJ01479000/RJ01478826_img_main.jpg`
  /// — the second RJ is the real underlying work, which differs from the
  /// page's product_id for translation editions.
  static String? _extractImageProductId(String? url) {
    if (url == null || url.isEmpty) return null;
    final m = RegExp(
      r'/work/[^/]+/[A-Za-z]+\d+/([A-Za-z]+\d+)_img_',
    ).firstMatch(url);
    return m?.group(1);
  }

  static String _normalizeUrl(String url) {
    return url.startsWith('//') ? 'https:$url' : url;
  }

  static String mainImageUrlFor(String productId) {
    final bucket = bucketFor(productId);
    return 'https://img.dlsite.jp/modpub/images2/work/doujin/$bucket/${productId}_img_main.jpg';
  }

  static String bucketFor(String productId) {
    final m = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(productId);
    if (m == null) return productId;
    final prefix = m.group(1)!;
    final digits = m.group(2)!;
    final n = int.parse(digits);
    final bucketN = ((n + 999) ~/ 1000) * 1000;
    return '$prefix${bucketN.toString().padLeft(digits.length, '0')}';
  }

  Map<String, dom.Element> _collectOutline(dom.Document doc) {
    final map = <String, dom.Element>{};
    for (final tr in doc.querySelectorAll('#work_outline tr')) {
      final th = tr.querySelector('th')?.text.trim();
      final td = tr.querySelector('td');
      if (th != null && td != null) map[th] = td;
    }
    return map;
  }

  String? _circleId(dom.Document doc, String productId) {
    final ga4 =
        doc.querySelector('.ga4_event_item_$productId') ??
        doc.querySelector('[data-product_id][data-maker_id]');
    return ga4?.attributes['data-maker_id'];
  }

  DateTime? _parseReleaseDate(dom.Element? td) {
    if (td == null) return null;
    final raw = td.querySelector('a')?.text.trim() ?? td.text.trim();
    final m = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日').firstMatch(raw);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  List<String> _anchorTexts(dom.Element? td) {
    if (td == null) return const [];
    final out = <String>[];
    for (final a in td.querySelectorAll('a')) {
      final t = a.text.trim();
      if (t.isNotEmpty) out.add(t);
    }
    return out;
  }

  String? _ageRating(dom.Element? td) {
    if (td == null) return null;
    final span = td.querySelector('span[title]');
    return span?.attributes['title'] ?? span?.text.trim();
  }

  String? _workType(dom.Document doc, dom.Element? td) {
    final ga4 = doc.querySelector('[data-product_id][data-work_type]');
    final ga4Type = ga4?.attributes['data-work_type'];
    if (ga4Type != null && ga4Type.isNotEmpty) return ga4Type;
    final span = td?.querySelector('span[class^="icon_"]');
    final cls = span?.classes.firstWhere(
      (c) => c.startsWith('icon_'),
      orElse: () => '',
    );
    if (cls != null && cls.isNotEmpty) return cls.substring('icon_'.length);
    return null;
  }

  String? _workTypeName(dom.Element? td) {
    if (td == null) return null;
    final span = td.querySelector('span[title]');
    return span?.attributes['title'] ?? span?.text.trim();
  }

  List<String> _fileFormats(dom.Element? td) {
    if (td == null) return const [];
    final out = <String>[];
    for (final span in td.querySelectorAll('span[title]')) {
      final t = span.attributes['title']?.trim();
      if (t != null && t.isNotEmpty) out.add(t);
    }
    for (final extra in td.querySelectorAll('.additional_info')) {
      for (final part in extra.text.split('/')) {
        final s = part.trim();
        if (s.isNotEmpty) out.add(s);
      }
    }
    return out;
  }

  List<String> _supportedLanguages(dom.Element? td) {
    if (td == null) return const [];
    final out = <String>[];
    for (final span in td.querySelectorAll('span[title]')) {
      final t = span.attributes['title']?.trim();
      if (t != null && t.isNotEmpty) out.add(t);
    }
    if (out.isEmpty) {
      for (final a in td.querySelectorAll('a')) {
        final t = a.text.trim();
        if (t.isNotEmpty) out.add(t);
      }
    }
    return out;
  }

  List<DlsiteGenre> _genres(dom.Element? td) {
    if (td == null) return const [];
    final out = <DlsiteGenre>[];
    for (final a in td.querySelectorAll('a')) {
      final name = a.text.trim();
      if (name.isEmpty) continue;
      final href = a.attributes['href'] ?? '';
      final m = RegExp(r'/genre/(\d+)').firstMatch(href);
      out.add(DlsiteGenre(id: m?.group(1), name: name));
    }
    return out;
  }

  String? _fileSize(dom.Element? td) {
    if (td == null) return null;
    final t = td.text.trim();
    return t.isEmpty ? null : t;
  }

  String? _seriesId(dom.Element? td) {
    final a = td?.querySelector('a');
    final href = a?.attributes['href'] ?? '';
    final m = RegExp(r'/title/=/title_id/(\w+)').firstMatch(href);
    return m?.group(1);
  }

  List<String> _sampleImages(dom.Document doc) {
    final out = <String>[];
    for (final div in doc.querySelectorAll(
      '.product-slider-data div[data-src]',
    )) {
      final src = div.attributes['data-src'];
      if (src == null || src.isEmpty) continue;
      if (src.contains('_img_main')) continue;
      out.add(src.startsWith('//') ? 'https:$src' : src);
    }
    return out;
  }

  List<String> _descriptionImages(dom.Element? description) {
    if (description == null) return const [];
    final out = <String>[];
    for (final img in description.querySelectorAll('img')) {
      var src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
      if (src.isEmpty) continue;
      if (src.startsWith('//')) src = 'https:$src';
      out.add(src);
    }
    return out;
  }

  String? _textOrNull(dom.Document doc, String selector) {
    final el = doc.querySelector(selector);
    return _textOrNullElem(el);
  }

  String? _textOrNullElem(dom.Element? el) {
    if (el == null) return null;
    final t = el.text.trim();
    return t.isEmpty ? null : t;
  }

  String? _attr(dom.Document doc, String selector, String name) {
    return doc.querySelector(selector)?.attributes[name];
  }

  T? _tryGet<T>(T? Function() fn) {
    try {
      return fn();
    } catch (_) {
      return null;
    }
  }
}
