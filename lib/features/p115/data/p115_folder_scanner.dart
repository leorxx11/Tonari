import '../../../core/scanner/file_classifier.dart';
import '../../../core/scanner/rj_id.dart';
import '../../../core/scanner/scan_models.dart';
import '../../browse/data/remote_models.dart';
import 'p115_client.dart';

class P115FolderScanner {
  P115FolderScanner(this._client);

  final P115Client _client;

  Future<ScanResult> scan(
    RemoteEntry root, {
    void Function(int worksFound, String current)? onProgress,
  }) async {
    final works = <DetectedWork>[];
    final unrecognized = <String>[];
    final errors = <String>[];
    var filesScanned = 0;

    Future<DetectedWork> buildWork(
      RemoteEntry workDir,
      String productId,
    ) async {
      final audios = <DetectedAudio>[];
      final images = <DetectedImage>[];
      final subtitles = <DetectedSubtitle>[];
      final videos = <DetectedFile>[];
      final textNotes = <DetectedFile>[];
      final others = <DetectedFile>[];

      Future<void> walk(RemoteEntry dir, String prefix) async {
        final List<RemoteEntry> entries;
        try {
          entries = await _client.list(dir.path);
        } catch (e) {
          errors.add('${dir.path}: $e');
          return;
        }
        for (final entry in entries) {
          if (entry.isFolder) {
            final childPrefix = prefix.isEmpty
                ? entry.name
                : '$prefix/${entry.name}';
            await walk(entry, childPrefix);
            continue;
          }
          filesScanned++;
          final name = entry.name;
          final rel = prefix.isEmpty ? name : '$prefix/$name';
          final parentName = prefix.isEmpty
              ? workDir.name
              : prefix.substring(prefix.lastIndexOf('/') + 1);
          final size = entry.size ?? 0;
          final pickcode = entry.pickcode!;
          switch (FileClassifier.classify(name)) {
            case FileKind.audio:
              audios.add(
                DetectedAudio(
                  path: pickcode,
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
                  path: pickcode,
                  relativePath: rel,
                  fileName: name,
                  sizeBytes: size,
                ),
              );
            case FileKind.subtitle:
              if (FileClassifier.extOf(name) == '.vtt') {
                subtitles.add(
                  DetectedSubtitle(
                    path: pickcode,
                    relativePath: rel,
                    fileName: name,
                    format: 'vtt',
                    sizeBytes: size,
                  ),
                );
              } else {
                others.add(
                  DetectedFile(
                    path: pickcode,
                    relativePath: rel,
                    fileName: name,
                    sizeBytes: size,
                  ),
                );
              }
            case FileKind.video:
              videos.add(
                DetectedFile(
                  path: pickcode,
                  relativePath: rel,
                  fileName: name,
                  sizeBytes: size,
                ),
              );
            case FileKind.text:
              textNotes.add(
                DetectedFile(
                  path: pickcode,
                  relativePath: rel,
                  fileName: name,
                  sizeBytes: size,
                ),
              );
            case FileKind.other:
              others.add(
                DetectedFile(
                  path: pickcode,
                  relativePath: rel,
                  fileName: name,
                  sizeBytes: size,
                ),
              );
          }
        }
      }

      await walk(workDir, '');
      return DetectedWork(
        productId: productId,
        rootPath: workDir.path,
        audios: audios,
        images: images,
        subtitles: subtitles,
        videos: videos,
        textNotes: textNotes,
        others: others,
      );
    }

    final rootRj = RjId.extract(root.name);
    if (rootRj != null) {
      works.add(await buildWork(root, rootRj));
      onProgress?.call(works.length, rootRj);
      return ScanResult(
        rootPath: root.path,
        works: works,
        filesScanned: filesScanned,
        unrecognizedDirs: unrecognized,
        errors: errors,
      );
    }

    final List<RemoteEntry> top;
    try {
      top = await _client.list(root.path);
    } catch (e) {
      return ScanResult(
        rootPath: root.path,
        works: const [],
        filesScanned: 0,
        unrecognizedDirs: const [],
        errors: ['${root.path}: $e'],
      );
    }

    for (final child in top) {
      if (!child.isFolder) continue;
      final childRj = RjId.extract(child.name);
      if (childRj != null) {
        works.add(await buildWork(child, childRj));
        onProgress?.call(works.length, childRj);
        continue;
      }

      var foundGrand = false;
      try {
        for (final grand in await _client.list(child.path)) {
          if (!grand.isFolder) continue;
          final grandRj = RjId.extract(grand.name);
          if (grandRj != null) {
            works.add(await buildWork(grand, grandRj));
            onProgress?.call(works.length, grandRj);
            foundGrand = true;
          }
        }
      } catch (e) {
        errors.add('${child.path}: $e');
      }
      if (!foundGrand) unrecognized.add(child.path);
    }

    return ScanResult(
      rootPath: root.path,
      works: works,
      filesScanned: filesScanned,
      unrecognizedDirs: unrecognized,
      errors: errors,
    );
  }
}

String _ext(String name) {
  final ext = FileClassifier.extOf(name);
  return ext.isEmpty ? '' : ext.substring(1);
}

String? _inferCategory(String parent, String file) {
  final s = '$parent/$file'.toLowerCase();
  if (s.contains('free') || s.contains('フリートーク')) return 'free';
  if (s.contains('bonus') || s.contains('おまけ') || s.contains('特典')) {
    return 'bonus';
  }
  if (s.contains('main') || s.contains('本編') || s.contains('本篇')) {
    return 'main';
  }
  return null;
}
