import 'dart:io';

import 'file_classifier.dart';
import 'rj_id.dart';
import 'scan_models.dart';

class FolderScanner {
  FolderScanner._();

  /// Scans [rootPath] for RJ-id works, recursively. Runs on the main
  /// isolate because iOS security-scoped bookmark access is bound to the
  /// NSURL object held by the main isolate and does not propagate to a
  /// spawned isolate. (Simulator doesn't strictly enforce sandbox so the
  /// isolate version "worked" there, masking the issue on device.)
  /// Accepts either a filesystem path or a `file://` URL.
  static Future<ScanResult> scan(String rootPath) async {
    final cleanPath = rootPath.startsWith('file://')
        ? Uri.parse(rootPath).toFilePath()
        : rootPath;
    return scanSync(cleanPath);
  }

  /// Same as [scan] but runs on the current isolate. Exposed for tests.
  static ScanResult scanSync(String rootPath) {
    final root = Directory(rootPath);
    if (!root.existsSync()) {
      return ScanResult(
        rootPath: rootPath,
        works: const [],
        filesScanned: 0,
        unrecognizedDirs: const [],
        errors: ['Root not found: $rootPath'],
      );
    }

    final works = <DetectedWork>[];
    final unrecognized = <String>[];
    final errors = <String>[];
    var filesScanned = 0;

    DetectedWork buildWork(Directory workDir, String productId) {
      final audios = <DetectedAudio>[];
      final images = <DetectedImage>[];
      final subtitles = <DetectedSubtitle>[];
      final textNotes = <DetectedFile>[];
      final rootLen = workDir.path.endsWith('/')
          ? workDir.path.length
          : workDir.path.length + 1;

      String relOf(String full) {
        if (full.length <= rootLen) return _basename(full);
        return full.substring(rootLen);
      }

      try {
        for (final e in workDir.listSync(recursive: true, followLinks: false)) {
          if (e is! File) continue;
          filesScanned++;
          final name = _basename(e.path);
          final kind = FileClassifier.classify(name);
          final parentName = _basename(e.parent.path);

          if (kind == FileKind.audio) {
            audios.add(DetectedAudio(
              path: e.path,
              relativePath: relOf(e.path),
              fileName: name,
              format: _audioFormat(name),
              sizeBytes: e.lengthSync(),
              parentDirName: parentName,
              categoryHint: _inferCategory(parentName, name),
            ));
          } else if (kind == FileKind.image) {
            images.add(DetectedImage(
              path: e.path,
              fileName: name,
              sizeBytes: e.lengthSync(),
            ));
          } else if (kind == FileKind.subtitle) {
            subtitles.add(DetectedSubtitle(
              path: e.path,
              fileName: name,
              format: FileClassifier.extOf(name).substring(1),
            ));
          } else if (kind == FileKind.text) {
            textNotes.add(DetectedFile(path: e.path, fileName: name));
          }
        }
      } catch (err) {
        errors.add('${workDir.path}: $err');
      }

      return DetectedWork(
        productId: productId,
        rootPath: workDir.path,
        audios: audios,
        images: images,
        subtitles: subtitles,
        textNotes: textNotes,
      );
    }

    final rootRj = RjId.extract(_basename(root.path));
    if (rootRj != null) {
      works.add(buildWork(root, rootRj));
    } else {
      try {
        for (final child in root.listSync(followLinks: false)) {
          if (child is! Directory) continue;
          final childRj = RjId.extract(_basename(child.path));
          if (childRj != null) {
            works.add(buildWork(child, childRj));
            continue;
          }
          // 多一层兜底：用户导入了"合集 → 系列 → RJxxx" 这种二层结构时也能识别
          var foundGrandchild = false;
          try {
            for (final grand in child.listSync(followLinks: false)) {
              if (grand is! Directory) continue;
              final grandRj = RjId.extract(_basename(grand.path));
              if (grandRj != null) {
                works.add(buildWork(grand, grandRj));
                foundGrandchild = true;
              }
            }
          } catch (err) {
            errors.add('${child.path}: $err');
          }
          if (!foundGrandchild) unrecognized.add(child.path);
        }
      } catch (err) {
        errors.add('${root.path}: $err');
      }
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
    final cleaned = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final i = cleaned.lastIndexOf('/');
    return i < 0 ? cleaned : cleaned.substring(i + 1);
  }

  static String _audioFormat(String fileName) {
    final ext = FileClassifier.extOf(fileName);
    return ext.isEmpty ? '' : ext.substring(1);
  }

  static String? _inferCategory(String parentDir, String fileName) {
    for (final s in [parentDir.toLowerCase(), fileName.toLowerCase()]) {
      if (s.contains('本編') || s.contains('本编') || s.contains('main')) {
        return 'main';
      }
      if (s.contains('フリートーク') ||
          s.contains('free') ||
          s.contains('talk')) {
        return 'free';
      }
    }
    return null;
  }
}
