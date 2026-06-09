import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/prefs/shared_prefs_provider.dart';

/// The single "last played video" slot — enough to rebuild the [PlayableItem]'s
/// resolver lazily (on play) plus where the user left off. Library audio keeps
/// its own per-track resume in the DB.
class VideoResumeSlot {
  const VideoResumeSlot({
    required this.id,
    required this.sourceKind,
    required this.sourceId,
    required this.sourceName,
    required this.path,
    required this.fileName,
    required this.positionMs,
    required this.lastPlayedAt,
    this.size,
    this.pickcode,
  });

  final String id;
  final String sourceKind; // RemoteSourceKind.name: local | webdav | p115
  final String sourceId;
  final String sourceName;
  final String path;
  final String fileName;
  final int positionMs;
  final DateTime lastPlayedAt;
  final int? size;
  final String? pickcode;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceKind': sourceKind,
    'sourceId': sourceId,
    'sourceName': sourceName,
    'path': path,
    'fileName': fileName,
    'positionMs': positionMs,
    'lastPlayedAt': lastPlayedAt.millisecondsSinceEpoch,
    'size': size,
    'pickcode': pickcode,
  };

  static VideoResumeSlot? fromJson(Map<String, dynamic> json) {
    try {
      return VideoResumeSlot(
        id: json['id'] as String,
        sourceKind: json['sourceKind'] as String,
        sourceId: json['sourceId'] as String,
        sourceName: json['sourceName'] as String,
        path: json['path'] as String,
        fileName: json['fileName'] as String,
        positionMs: json['positionMs'] as int,
        lastPlayedAt: DateTime.fromMillisecondsSinceEpoch(
          json['lastPlayedAt'] as int,
        ),
        size: json['size'] as int?,
        pickcode: json['pickcode'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

class VideoResumeStore {
  VideoResumeStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'video_resume_slot';

  VideoResumeSlot? read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return VideoResumeSlot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(VideoResumeSlot slot) =>
      _prefs.setString(_key, jsonEncode(slot.toJson()));

  Future<void> clear() => _prefs.remove(_key);
}

final videoResumeStoreProvider = Provider<VideoResumeStore>(
  (ref) => VideoResumeStore(ref.watch(sharedPreferencesProvider)),
);
