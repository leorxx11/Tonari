import 'scan_models.dart';

class AudioMerger {
  AudioMerger._();

  /// Format priority — earlier = higher. Picks the primary file when one
  /// logical track has multiple quality variants.
  static const formatPriority = [
    'flac',
    'wav',
    'mp3',
    'opus',
    'aac',
    'm4a',
    'ogg',
  ];

  /// Groups audios within the same parent dir by base filename. Files that
  /// share both the parent dir and the base name collapse into a single
  /// [MergedTrack]; the highest-priority format wins, the rest become
  /// [MergedTrack.alternateQualityPaths].
  ///
  /// Same base name across **different** parent dirs is *not* merged —
  /// likely different chapters that happen to share names (e.g. 本編/track01
  /// vs フリートーク/track01). Cross-dir multi-quality merging is left to
  /// a future heuristic / manual UI.
  static List<MergedTrack> merge(List<DetectedAudio> audios) {
    final groups = <String, List<DetectedAudio>>{};
    for (final a in audios) {
      final base = _baseName(a.fileName).toLowerCase();
      final key = '${a.parentDirName.toLowerCase()}|$base';
      groups.putIfAbsent(key, () => []).add(a);
    }

    final result = <MergedTrack>[];
    for (final group in groups.values) {
      final sorted = [...group]
        ..sort((x, y) => _priority(x.format).compareTo(_priority(y.format)));
      final primary = sorted.first;
      result.add(MergedTrack(
        baseName: _baseName(primary.fileName),
        primaryPath: primary.path,
        primaryFileName: primary.fileName,
        primaryFormat: primary.format,
        primarySizeBytes: primary.sizeBytes,
        parentDirName: primary.parentDirName,
        categoryHint: primary.categoryHint,
        alternateQualityPaths: {
          for (final a in sorted.skip(1)) a.format: a.path,
        },
      ));
    }

    result.sort((a, b) => a.primaryPath.compareTo(b.primaryPath));
    return result;
  }

  static int _priority(String format) {
    final i = formatPriority.indexOf(format.toLowerCase());
    return i < 0 ? formatPriority.length : i;
  }

  static String _baseName(String fileName) {
    final i = fileName.lastIndexOf('.');
    return i < 0 ? fileName : fileName.substring(0, i);
  }
}
