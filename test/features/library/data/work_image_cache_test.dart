import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tonari/features/library/data/work_image_cache.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tonari_img_cache_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  WorkImageCache build({required ImageDownloader downloader}) {
    return WorkImageCache(
      documentsDir: () async => tmp,
      downloader: downloader,
    );
  }

  test('writes main + sample images under images/<productId>/', () async {
    final downloaded = <String>[];
    final cache = build(downloader: (url, file) async {
      downloaded.add(url);
      file.writeAsBytesSync([1, 2, 3]);
      return true;
    });

    final paths = await cache.cache(
      productId: 'RJ01560714',
      mainImageUrl: 'https://example.com/RJ01560714_img_main.jpg',
      sampleImageUrls: [
        'https://example.com/RJ01560714_img_smp1.jpg',
        'https://example.com/RJ01560714_img_smp2.jpg',
      ],
    );

    expect(downloaded.length, 3);
    final workDir = Directory(p.join(tmp.path, 'images', 'RJ01560714'));
    expect(workDir.existsSync(), isTrue);
    expect(File(p.join(workDir.path, 'main.jpg')).existsSync(), isTrue);
    expect(File(p.join(workDir.path, 'smp1.jpg')).existsSync(), isTrue);
    expect(File(p.join(workDir.path, 'smp2.jpg')).existsSync(), isTrue);

    expect(paths.mainImage, endsWith('main.jpg'));
    expect(paths.sampleImages.length, 2);
  });

  test('skips re-download when file already exists with content', () async {
    var calls = 0;
    final cache = build(downloader: (url, file) async {
      calls++;
      file.writeAsBytesSync([1]);
      return true;
    });

    await cache.cache(
      productId: 'RJ123456',
      mainImageUrl: 'https://example.com/RJ123456_img_main.jpg',
    );
    await cache.cache(
      productId: 'RJ123456',
      mainImageUrl: 'https://example.com/RJ123456_img_main.jpg',
    );

    expect(calls, 1);
  });

  test('deletes partial file when download returns false', () async {
    final cache = build(downloader: (url, file) async {
      file.writeAsBytesSync([0]);
      return false;
    });

    final paths = await cache.cache(
      productId: 'RJ222222',
      mainImageUrl: 'https://example.com/RJ222222_img_main.jpg',
    );

    expect(paths.mainImage, isNull);
    final f = File(p.join(tmp.path, 'images', 'RJ222222', 'main.jpg'));
    expect(f.existsSync(), isFalse);
  });

  test('swallows downloader exceptions per-image', () async {
    final cache = build(downloader: (url, file) async {
      if (url.contains('smp2')) throw const SocketException('boom');
      file.writeAsBytesSync([1]);
      return true;
    });

    final paths = await cache.cache(
      productId: 'RJ333333',
      mainImageUrl: 'https://example.com/RJ333333_img_main.jpg',
      sampleImageUrls: [
        'https://example.com/RJ333333_img_smp1.jpg',
        'https://example.com/RJ333333_img_smp2.jpg',
        'https://example.com/RJ333333_img_smp3.jpg',
      ],
    );

    expect(paths.mainImage, isNotNull);
    expect(paths.sampleImages.length, 2);
  });
}
