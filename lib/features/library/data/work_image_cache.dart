import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'dlsite_fetcher.dart';

class WorkImagePaths {
  const WorkImagePaths({
    this.mainImage,
    this.sampleImages = const [],
    this.descriptionImages = const [],
  });

  final String? mainImage;
  final List<String> sampleImages;
  final List<String> descriptionImages;
}

typedef ImageDownloader = Future<bool> Function(String url, File target);

class WorkImageCache {
  WorkImageCache({
    Dio? dio,
    Future<Directory> Function()? documentsDir,
    ImageDownloader? downloader,
  }) : _documentsDir = documentsDir ?? getApplicationDocumentsDirectory,
       _downloader = downloader ?? _defaultDownloader(dio ?? Dio());

  final Future<Directory> Function() _documentsDir;
  final ImageDownloader _downloader;

  static ImageDownloader _defaultDownloader(Dio dio) {
    return (url, file) async {
      final res = await dio.download(url, file.path);
      return res.statusCode == 200;
    };
  }

  Future<WorkImagePaths> cache({
    required String productId,
    required String mainImageUrl,
    List<String> sampleImageUrls = const [],
    List<String> descriptionImageUrls = const [],
  }) async {
    final docs = await _documentsDir();
    final dir = await _ensureWorkDir(productId);

    final mainPath = await _downloadIfMissing(
      url: mainImageUrl,
      file: File(p.join(dir.path, 'main${_ext(mainImageUrl)}')),
      docsPath: docs.path,
    );

    final samplePaths = <String>[];
    for (var i = 0; i < sampleImageUrls.length; i++) {
      final url = sampleImageUrls[i];
      final path = await _downloadIfMissing(
        url: url,
        file: File(p.join(dir.path, 'smp${i + 1}${_ext(url)}')),
        docsPath: docs.path,
      );
      if (path != null) samplePaths.add(path);
    }

    final descPaths = <String>[];
    for (var i = 0; i < descriptionImageUrls.length; i++) {
      final url = descriptionImageUrls[i];
      final path = await _downloadIfMissing(
        url: url,
        file: File(p.join(dir.path, 'desc${i + 1}${_ext(url)}')),
        docsPath: docs.path,
      );
      // keep slot alignment with input URLs: empty string = download failed
      descPaths.add(path ?? '');
    }

    return WorkImagePaths(
      mainImage: mainPath,
      sampleImages: samplePaths,
      descriptionImages: descPaths,
    );
  }

  Future<void> evict(String productId) async {
    final docs = await _documentsDir();
    final dir = Directory(p.join(docs.path, 'images', productId));
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  Future<Directory> _ensureWorkDir(String productId) async {
    final docs = await _documentsDir();
    final dir = Directory(p.join(docs.path, 'images', productId));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<String?> _downloadIfMissing({
    required String url,
    required File file,
    required String docsPath,
  }) async {
    if (file.existsSync() && file.lengthSync() > 0) {
      return p.relative(file.path, from: docsPath);
    }
    try {
      final ok = await _downloader(url, file);
      if (!ok) {
        if (file.existsSync()) file.deleteSync();
        return null;
      }
      return p.relative(file.path, from: docsPath);
    } catch (_) {
      if (file.existsSync()) file.deleteSync();
      return null;
    }
  }

  static String _ext(String url) {
    final dot = url.lastIndexOf('.');
    final qm = url.indexOf('?', dot);
    if (dot == -1) return '.jpg';
    final raw = qm == -1 ? url.substring(dot) : url.substring(dot, qm);
    return raw.length > 5 ? '.jpg' : raw;
  }
}

final workImageCacheProvider = Provider<WorkImageCache>((ref) {
  return WorkImageCache();
});

final mainImageUrlForProvider = Provider.family<String, String>((
  ref,
  productId,
) {
  return DlsiteFetcher.mainImageUrlFor(productId);
});
