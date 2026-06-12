import '../../../core/scanner/file_classifier.dart';
import '../../../core/scanner/rj_id.dart';
import '../../../core/scanner/scan_models.dart';
import 'webdav_client.dart';

/// WebDAV counterpart of [FolderScanner]: walks a remote tree via recursive
/// PROPFIND and produces the same [ScanResult], with every `path` holding the
/// decoded absolute server path (used later to build the streaming URL).
class RemoteFolderScanner {
  RemoteFolderScanner(this._client);

  final WebdavClient _client;

  Future<ScanResult> scan(
    WebdavConfig config,
    String rootPath, {
    void Function(int worksFound, String current)? onProgress,
    Set<String> skipProductIds = const {},
  }) async {
    final works = <DetectedWork>[];
    final unrecognized = <String>[];
    final errors = <String>[];
    var filesScanned = 0;

    Future<DetectedWork> buildWork(String workDir, String productId) async {
      final audios = <DetectedAudio>[];
      final images = <DetectedImage>[];
      final subtitles = <DetectedSubtitle>[];
      final videos = <DetectedFile>[];
      final textNotes = <DetectedFile>[];
      final others = <DetectedFile>[];
      var incomplete = false;
      final rootLen = workDir.endsWith('/')
          ? workDir.length
          : workDir.length + 1;

      String relOf(String full) {
        if (full.length <= rootLen) return _basename(full);
        return full.substring(rootLen);
      }

      Future<void> walk(String dir) async {
        final List<WebdavEntry> entries;
        try {
          entries = await _client.list(config, dir);
        } catch (e) {
          errors.add('$dir: $e');
          incomplete = true;
          return;
        }
        for (final e in entries) {
          if (e.isDir) {
            await walk(e.path);
            continue;
          }
          filesScanned++;
          final name = e.name;
          final rel = relOf(e.path);
          final size = e.size ?? 0;
          final parentName = _basename(_parentOf(e.path));
          switch (FileClassifier.classify(name)) {
            case FileKind.audio:
              audios.add(
                DetectedAudio(
                  path: e.path,
                  relativePath: rel,
                  fileName: name,
                  format: _ext(name),
                  sizeBytes: size,
                  parentDirName: parentName,
                  categoryHint: _inferCategory(parentName, name),
                ),
              );
            case FileKind.image:
              images.add(
                DetectedImage(
                  path: e.path,
                  relativePath: rel,
                  fileName: name,
                  sizeBytes: size,
                ),
              );
            case FileKind.subtitle:
              subtitles.add(
                DetectedSubtitle(
                  path: e.path,
                  relativePath: rel,
                  fileName: name,
                  format: FileClassifier.extOf(name).substring(1),
                  sizeBytes: size,
                ),
              );
            case FileKind.text:
              textNotes.add(
                DetectedFile(
                  path: e.path,
                  relativePath: rel,
                  fileName: name,
                  sizeBytes: size,
                ),
              );
            case FileKind.video:
              videos.add(
                DetectedFile(
                  path: e.path,
                  relativePath: rel,
                  fileName: name,
                  sizeBytes: size,
                ),
              );
            case FileKind.other:
              others.add(
                DetectedFile(
                  path: e.path,
                  relativePath: rel,
                  fileName: name,
                  sizeBytes: size,
                ),
              );
          }
        }
      }

      await walk(workDir);
      return DetectedWork(
        productId: productId,
        rootPath: workDir,
        audios: audios,
        images: images,
        subtitles: subtitles,
        videos: videos,
        textNotes: textNotes,
        others: others,
        incomplete: incomplete,
      );
    }

    final String root = _stripSlash(rootPath);
    final rootRj = RjId.extract(_basename(root));
    if (rootRj != null) {
      works.add(await buildWork(root, rootRj));
      onProgress?.call(works.length, rootRj);
      return ScanResult(
        rootPath: rootPath,
        works: works,
        filesScanned: filesScanned,
        unrecognizedDirs: unrecognized,
        errors: errors,
      );
    }

    final List<WebdavEntry> top;
    try {
      top = await _client.list(config, rootPath);
    } catch (e) {
      return ScanResult(
        rootPath: rootPath,
        works: const [],
        filesScanned: 0,
        unrecognizedDirs: const [],
        errors: ['$rootPath: $e'],
      );
    }

    for (final child in top) {
      if (!child.isDir) continue;
      final childRj = RjId.extract(child.name);
      if (childRj != null) {
        if (skipProductIds.contains(childRj)) continue;
        works.add(await buildWork(child.path, childRj));
        onProgress?.call(works.length, childRj);
        continue;
      }
      // 多一层兜底：合集 → 系列 → RJxxx
      var foundGrand = false;
      try {
        for (final grand in await _client.list(config, child.path)) {
          if (!grand.isDir) continue;
          final grandRj = RjId.extract(grand.name);
          if (grandRj != null) {
            foundGrand = true;
            if (skipProductIds.contains(grandRj)) continue;
            works.add(await buildWork(grand.path, grandRj));
            onProgress?.call(works.length, grandRj);
          }
        }
      } catch (e) {
        errors.add('${child.path}: $e');
      }
      if (!foundGrand) unrecognized.add(child.path);
    }

    return ScanResult(
      rootPath: rootPath,
      works: works,
      filesScanned: filesScanned,
      unrecognizedDirs: unrecognized,
      errors: errors,
    );
  }

  static String _basename(String path) {
    final c = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final i = c.lastIndexOf('/');
    return i < 0 ? c : c.substring(i + 1);
  }

  static String _parentOf(String path) {
    final c = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final i = c.lastIndexOf('/');
    return i < 0 ? '' : c.substring(0, i);
  }

  static String _stripSlash(String s) =>
      (s.length > 1 && s.endsWith('/')) ? s.substring(0, s.length - 1) : s;

  static String _ext(String fileName) {
    final ext = FileClassifier.extOf(fileName);
    return ext.isEmpty ? '' : ext.substring(1);
  }

  static String? _inferCategory(String parentDir, String fileName) {
    for (final s in [parentDir.toLowerCase(), fileName.toLowerCase()]) {
      if (s.contains('本編') || s.contains('本编') || s.contains('main')) {
        return 'main';
      }
      if (s.contains('フリートーク') || s.contains('free') || s.contains('talk')) {
        return 'free';
      }
    }
    return null;
  }
}
