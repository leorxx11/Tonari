import '../../../core/db/database.dart';

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
/// its path. Sorting at each level is natural-order — digit runs compare
/// numerically so `2_xxx` sorts before `10_xxx`, even when the surrounding
/// separator (e.g. `_`) is ASCII-greater than the digit.
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
  final keys = map.keys.toList()..sort(_naturalCompare);
  final out = <WorkTreeNode>[];
  for (final k in keys) {
    final v = map[k];
    if (v is Track) {
      out.add(WorkTreeTrack(v));
    } else if (v is WorkFile) {
      out.add(WorkTreeFile(v));
    } else {
      out.add(
        WorkTreeFolder(
          name: k,
          children: _materialize(v! as Map<String, Object>),
        ),
      );
    }
  }
  return out;
}

int _naturalCompare(String a, String b) {
  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    final aDigit = _isDigit(a.codeUnitAt(i));
    final bDigit = _isDigit(b.codeUnitAt(j));
    if (aDigit && bDigit) {
      var ai = i;
      while (ai < a.length && _isDigit(a.codeUnitAt(ai))) {
        ai++;
      }
      var bj = j;
      while (bj < b.length && _isDigit(b.codeUnitAt(bj))) {
        bj++;
      }
      var aStart = i;
      while (aStart < ai - 1 && a.codeUnitAt(aStart) == 0x30) {
        aStart++;
      }
      var bStart = j;
      while (bStart < bj - 1 && b.codeUnitAt(bStart) == 0x30) {
        bStart++;
      }
      final aLen = ai - aStart;
      final bLen = bj - bStart;
      if (aLen != bLen) return aLen - bLen;
      for (var k = 0; k < aLen; k++) {
        final c = a.codeUnitAt(aStart + k) - b.codeUnitAt(bStart + k);
        if (c != 0) return c;
      }
      i = ai;
      j = bj;
    } else {
      final c = a.codeUnitAt(i) - b.codeUnitAt(j);
      if (c != 0) return c;
      i++;
      j++;
    }
  }
  return (a.length - i) - (b.length - j);
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

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
