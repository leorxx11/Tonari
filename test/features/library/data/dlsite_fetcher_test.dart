import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/features/library/data/dlsite_fetcher.dart';

void main() {
  group('DlsiteFetcher.bucketFor', () {
    test('rounds 8-digit RJ up to next thousand', () {
      expect(DlsiteFetcher.bucketFor('RJ01560714'), 'RJ01561000');
    });

    test('keeps multiple-of-1000 in same bucket', () {
      expect(DlsiteFetcher.bucketFor('RJ01561000'), 'RJ01561000');
    });

    test('handles legacy 6-digit RJ', () {
      expect(DlsiteFetcher.bucketFor('RJ123456'), 'RJ124000');
    });

    test('handles small numbers', () {
      expect(DlsiteFetcher.bucketFor('RJ000001'), 'RJ001000');
    });
  });

  group('DlsiteFetcher.mainImageUrlFor', () {
    test('builds doujin main image URL', () {
      expect(
        DlsiteFetcher.mainImageUrlFor('RJ01560714'),
        'https://img.dlsite.jp/modpub/images2/work/doujin/RJ01561000/RJ01560714_img_main.jpg',
      );
    });
  });

  group('DlsiteFetcher.parseHtml (RJ01560714 fixture)', () {
    late DlsiteWorkData data;

    setUpAll(() {
      final html = File('test/fixtures/dlsite/RJ01560714.html').readAsStringSync();
      data = DlsiteFetcher().parseHtml(html, 'RJ01560714');
    });

    test('extracts title and romaji', () {
      expect(
        data.title,
        '【ドスケベ淫語連鎖コンボ】低音ドスケベ爆乳ムチムチお姉ちゃんドスケベ淫乱ドスケベえちえちお姉ちゃんライフ【フォーリーサウンド】',
      );
      expect(data.titleRomaji, isNotNull);
      expect(data.titleRomaji, contains('dosukebe'));
    });

    test('extracts circle name and id', () {
      expect(data.circleName, 'Rad.Revel');
      expect(data.circleId, 'RG60242');
    });

    test('parses release date', () {
      expect(data.releaseDate, DateTime(2026, 2, 9));
    });

    test('extracts voice actors / illustrators / scenario writers', () {
      expect(data.voiceActors, ['柚木つばめ']);
      expect(data.illustrators, ['oekakizuki']);
      expect(data.scenarioWriters, ['Rad.Revel']);
      expect(data.musicians, isEmpty);
    });

    test('extracts age rating, work type and type name', () {
      expect(data.ageRating, 'R18');
      expect(data.workType, 'SOU');
      expect(data.workTypeName, 'ボイス・ASMR');
    });

    test('extracts file formats and file size', () {
      expect(data.fileFormats, containsAll(['WAV', 'MP3']));
      expect(data.fileSize, '3.6GB');
    });

    test('extracts genres with ids', () {
      expect(data.genres.length, greaterThanOrEqualTo(8));
      final names = data.genres.map((g) => g.name).toList();
      expect(names, contains('淫語'));
      expect(names, contains('オホ声'));
      final inGo = data.genres.firstWhere((g) => g.name == '淫語');
      expect(inGo.id, '068');
    });

    test('main image URL uses calculated bucket', () {
      expect(
        data.mainImageUrl,
        'https://img.dlsite.jp/modpub/images2/work/doujin/RJ01561000/RJ01560714_img_main.jpg',
      );
    });

    test('extracts sample images and excludes the main one', () {
      expect(data.sampleImageUrls.length, greaterThanOrEqualTo(7));
      expect(
        data.sampleImageUrls.every((u) => !u.contains('_img_main')),
        isTrue,
      );
      expect(
        data.sampleImageUrls.first,
        startsWith('https://img.dlsite.jp/modpub/images2/work/doujin/RJ01561000/RJ01560714_img_smp'),
      );
    });

    test('captures description html (non-empty)', () {
      expect(data.descriptionHtml, isNotNull);
      expect(data.descriptionHtml!.isNotEmpty, isTrue);
    });

    test('series fields null when work has no series', () {
      expect(data.seriesId, isNull);
      expect(data.seriesName, isNull);
    });
  });

  group('DlsiteFetcher.parseAjaxJson (RJ01560714 fixture)', () {
    late DlsiteAjaxData ajax;

    setUpAll(() {
      final json = File('test/fixtures/dlsite/RJ01560714_ajax.json').readAsStringSync();
      ajax = DlsiteFetcher().parseAjaxJson(json, 'RJ01560714');
    });

    test('extracts dl count and wishlist', () {
      expect(ajax.dlCount, 3867);
      expect(ajax.wishlistCount, 5113);
    });

    test('extracts rating average and count', () {
      expect(ajax.rateAverage, 4.85);
      expect(ajax.rateCount, 195);
      expect(ajax.reviewCount, 1);
    });

    test('extracts price and computes discount=0 when not discounted', () {
      expect(ajax.price, 1650);
      expect(ajax.officialPrice, 1650);
      expect(ajax.discountRate, 0);
      expect(ajax.isDiscount, isFalse);
      expect(ajax.isOnSale, isTrue);
    });
  });

  group('DlsiteFetcher.parseAjaxJson edge cases', () {
    test('missing product key returns mostly-null DTO', () {
      const body = '{"RJ999999":{"dl_count":1}}';
      final ajax = DlsiteFetcher().parseAjaxJson(body, 'RJ01560714');
      expect(ajax.productId, 'RJ01560714');
      expect(ajax.dlCount, isNull);
    });

    test('invalid JSON yields empty DTO', () {
      final ajax = DlsiteFetcher().parseAjaxJson('not-json', 'RJ01560714');
      expect(ajax.productId, 'RJ01560714');
      expect(ajax.price, isNull);
    });

    test('discount rate is computed when price < official_price', () {
      const body = '{"RJ01560714":{"price":1100,"official_price":2200,"is_discount":1,"on_sale":1}}';
      final ajax = DlsiteFetcher().parseAjaxJson(body, 'RJ01560714');
      expect(ajax.price, 1100);
      expect(ajax.officialPrice, 2200);
      expect(ajax.discountRate, 50);
      expect(ajax.isDiscount, isTrue);
    });
  });
}
