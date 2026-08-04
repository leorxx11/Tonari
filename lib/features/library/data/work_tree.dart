import '../../../core/db/database.dart';
import '../../../core/files/natural_compare.dart';

sealed class WorkTreeNode {
  String get name;
}

class WorkTreeFolder extends WorkTreeNode {
  WorkTreeFolder({required this.name, required this.children});

  @override
  final String name;
  final List<WorkTreeNode> children;

  /// Direct child count (folders + files, not recursive). Matches the
  /// "N 项" reading in DLsite's own folder UI.
  int get itemCount => children.length;

  int get audioCount {
    var n = 0;
    for (final c in children) {
      if (c is WorkTreeTrack) {
        n++;
      } else if (c is WorkTreeFolder) {
        n += c.audioCount;
      }
    }
    return n;
  }

  /// Sum of durationMs across every descendant audio track.
  int get totalDurationMs {
    var n = 0;
    for (final c in children) {
      if (c is WorkTreeTrack) {
        n += c.track.durationMs;
      } else if (c is WorkTreeFolder) {
        n += c.totalDurationMs;
      }
    }
    return n;
  }

  /// Sum of fileSizeBytes across every descendant audio track.
  int get totalAudioBytes {
    var n = 0;
    for (final c in children) {
      if (c is WorkTreeTrack) {
        n += c.track.fileSizeBytes;
      } else if (c is WorkTreeFolder) {
        n += c.totalAudioBytes;
      }
    }
    return n;
  }
}

class WorkTreeTrack extends WorkTreeNode {
  WorkTreeTrack(this.track);
  final Track track;

  @override
  String get name => track.title;
}

class WorkTreeFile extends WorkTreeNode {
  WorkTreeFile(this.file);
  final WorkFile file;

  @override
  String get name => file.fileName;
}

/// Builds a folder-mirrored tree from [tracks] + [workFiles], splitting on
/// `/` in their relative paths. Intermediate folders (e.g. `音声/`,
/// `特典/`) appear automatically whenever any descendant file has them in
/// its path. At each level folders sort before files; within each group the
/// order is natural — digit runs compare numerically so `2_xxx` sorts
/// before `10_xxx`.
List<WorkTreeNode> buildWorkTree(
  List<Track> tracks, {
  List<WorkFile> workFiles = const [],
}) {
  final root = <String, Object>{};

  void insert(List<String> parts, Object leaf) {
    Map<String, Object> cursor = root;
    for (var i = 0; i < parts.length - 1; i++) {
      final next = cursor.putIfAbsent(parts[i], () => <String, Object>{});
      cursor = next as Map<String, Object>;
    }
    cursor[parts.last] = leaf;
  }

  for (final t in tracks) {
    final parts = t.relativePath.isEmpty
        ? [t.fileName]
        : t.relativePath.split('/');
    insert(parts, t);
  }
  for (final f in workFiles) {
    final parts = f.relativePath.isEmpty
        ? [f.fileName]
        : f.relativePath.split('/');
    insert(parts, f);
  }
  return _materialize(root);
}

List<WorkTreeNode> _materialize(Map<String, Object> map) {
  final keys = map.keys.toList()..sort(naturalCompare);
  final folders = <WorkTreeNode>[];
  final leaves = <WorkTreeNode>[];
  for (final k in keys) {
    final v = map[k];
    if (v is Track) {
      leaves.add(WorkTreeTrack(v));
    } else if (v is WorkFile) {
      leaves.add(WorkTreeFile(v));
    } else {
      folders.add(
        WorkTreeFolder(
          name: k,
          children: _materialize(v! as Map<String, Object>),
        ),
      );
    }
  }
  return [...folders, ...leaves];
}

/// Audio tracks in tree display order. Used as the playback queue so
/// tapping a track plays it within the sequence the user is reading.
/// Non-audio nodes ([WorkTreeFile]) are skipped.
List<Track> flattenForPlayback(List<WorkTreeNode> nodes) {
  final out = <Track>[];
  void visit(WorkTreeNode n) {
    if (n is WorkTreeTrack) {
      out.add(n.track);
    } else if (n is WorkTreeFolder) {
      for (final c in n.children) {
        visit(c);
      }
    }
  }

  for (final n in nodes) {
    visit(n);
  }
  return out;
}

/// Initial folder path for the resource browser: descend while one child
/// folder's subtree holds >60% of this level's audio bytes.
///
/// Bytes encode both "long" (本編 vs 特典 bonus clips) and "lossless"
/// (WAV ≈ 10× MP3, ≈ 2× FLAC — hence 60%, so a WAV/FLAC pair at ~67%
/// still descends into WAV). Parallel equal variants (SEあり/なし,
/// Disc1/Disc2) split ~50/50 and stop the walk at their parent so the
/// user picks by hand.
List<String> autoPath(List<WorkTreeNode> nodes) {
  final path = <String>[];
  var cursor = nodes;
  while (true) {
    var total = 0;
    WorkTreeFolder? best;
    var bestBytes = 0;
    for (final n in cursor) {
      final bytes = switch (n) {
        WorkTreeTrack(:final track) => track.fileSizeBytes,
        WorkTreeFolder() => n.totalAudioBytes,
        WorkTreeFile() => 0,
      };
      total += bytes;
      if (n is WorkTreeFolder && bytes > bestBytes) {
        best = n;
        bestBytes = bytes;
      }
    }
    if (best == null || bestBytes * 10 <= total * 6) break;
    path.add(best.name);
    cursor = best.children;
  }
  return path;
}
