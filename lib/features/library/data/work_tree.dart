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

/// Walks down the tree as long as the per-level filters narrow candidates
/// to exactly one folder, returning the path of folder names traversed.
///
/// Candidates at each level are direct child folders that contain at least
/// one audio descendant. At each level we apply two filters in order:
///
/// 1. **SE preference** (`preferEffectSound`) — each candidate is tagged
///    `has` / `none` / `unknown` by [_seTagOf]. If anything is `has`, keep
///    only `has`. If only `none` and `unknown` are present, drop the `none`
///    ones. Otherwise leave the candidates alone.
/// 2. **Format preference** (`typeOrderEnabled`) — prefer the format token
///    parsed from the folder name (e.g. `本編_WAV`); fall back to a content
///    majority sniff when no candidate has a name-level label.
///
/// Stops when a level can't be narrowed to a single folder, or when
/// [smartPath] is off.
List<String> autoPath(
  List<WorkTreeNode> roots, {
  bool smartPath = true,
  bool preferEffectSound = true,
  bool typeOrderEnabled = true,
  List<String> typeOrder = const ['wav', 'mp3', 'flac', 'opus', 'm4a', 'aac'],
}) {
  if (!smartPath) return const [];
  final path = <String>[];
  var cursor = roots;
  while (true) {
    final candidates = cursor
        .whereType<WorkTreeFolder>()
        .where((f) => f.audioCount > 0)
        .toList();
    if (candidates.isEmpty) break;

    var remaining = candidates;
    if (preferEffectSound && remaining.length > 1) {
      remaining = _filterBySE(remaining);
    }
    if (typeOrderEnabled && remaining.length > 1) {
      remaining = _filterByFormat(remaining, typeOrder);
    }
    if (remaining.length != 1) break;

    final picked = remaining.first;
    path.add(picked.name);
    cursor = picked.children;
  }
  return path;
}

enum _SETag { has, none, unknown }

/// Strips half- and full-width whitespace plus `_` and `-`, then lower-cases.
/// Lets us match keyword variants like `SEなし` / `SE なし` / `SE_なし` /
/// `SE-なし` with a single dictionary lookup.
String _normalize(String s) {
  return s.toLowerCase().replaceAll(RegExp(r'[\s　_\-]+'), '');
}

const _seNegativeKeywords = <String>[
  '効果音なし',
  '効果音ナシ',
  '効果音無し',
  '効果音無',
  '効果音抜き',
  '効果音抜',
  'seなし',
  'seナシ',
  'se無し',
  'se無',
  'se抜き',
  'se抜',
  '無効果音',
  '無se',
  '不含se',
  '不含効果音',
  '不含音效',
  '不含音效版',
  '无音效',
  '無音效',
  '没音效',
  '無音效版',
  'nose',
  'noeffect',
];

const _sePositiveKeywords = <String>[
  '効果音あり',
  '効果音アリ',
  '効果音有り',
  '効果音有',
  '効果音入り',
  '効果音入',
  'seあり',
  'seアリ',
  'se有り',
  'se有',
  'se入り',
  'se入',
  '有効果音',
  '含se',
  '含効果音',
  'withse',
  '含音效',
  '含音效版',
  '有音效',
  '帶音效',
  '带音效',
];

_SETag _seTagOf(String folderName) {
  final norm = _normalize(folderName);
  for (final k in _seNegativeKeywords) {
    if (norm.contains(k)) return _SETag.none;
  }
  for (final k in _sePositiveKeywords) {
    if (norm.contains(k)) return _SETag.has;
  }
  return _SETag.unknown;
}

/// Format token from the folder name, if one sits at a word/symbol
/// boundary. Returns null when the name doesn't visibly advertise a format
/// (e.g. `本編`, `音声`).
String? _formatLabelOf(String folderName, List<String> typeOrder) {
  for (final t in typeOrder) {
    final re = RegExp(
      '(?:^|[^a-z0-9])${RegExp.escape(t)}(?:[^a-z0-9]|\$)',
      caseSensitive: false,
    );
    if (re.hasMatch(folderName)) return t.toLowerCase();
  }
  return null;
}

List<WorkTreeFolder> _filterBySE(List<WorkTreeFolder> folders) {
  final tags = {for (final f in folders) f: _seTagOf(f.name)};
  final has = folders.where((f) => tags[f] == _SETag.has).toList();
  if (has.isNotEmpty) return has;
  final notNone = folders.where((f) => tags[f] != _SETag.none).toList();
  if (notNone.isNotEmpty && notNone.length < folders.length) {
    return notNone;
  }
  return folders;
}

List<WorkTreeFolder> _filterByFormat(
  List<WorkTreeFolder> folders,
  List<String> typeOrder,
) {
  final labels = {
    for (final f in folders) f: _formatLabelOf(f.name, typeOrder),
  };
  final labeled = folders.where((f) => labels[f] != null).toList();
  if (labeled.isNotEmpty) {
    for (final fmt in typeOrder) {
      final lower = fmt.toLowerCase();
      final hits = labeled.where((f) => labels[f] == lower).toList();
      if (hits.isNotEmpty) return hits;
    }
  }
  return _filterByContentFormat(folders, typeOrder);
}

List<WorkTreeFolder> _filterByContentFormat(
  List<WorkTreeFolder> folders,
  List<String> typeOrder,
) {
  String? primaryFormatOf(WorkTreeFolder f) {
    final tallies = <String, int>{};
    void visit(WorkTreeNode n) {
      if (n is WorkTreeTrack) {
        final fmt = n.track.fileFormat.toLowerCase();
        tallies[fmt] = (tallies[fmt] ?? 0) + 1;
      } else if (n is WorkTreeFolder) {
        for (final c in n.children) {
          visit(c);
        }
      }
    }

    for (final c in f.children) {
      visit(c);
    }
    if (tallies.isEmpty) return null;
    return tallies.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  final formats = {for (final f in folders) f: primaryFormatOf(f)};
  for (final fmt in typeOrder) {
    final lower = fmt.toLowerCase();
    final matches = folders.where((f) => formats[f] == lower).toList();
    if (matches.isNotEmpty) return matches;
  }
  return folders;
}
