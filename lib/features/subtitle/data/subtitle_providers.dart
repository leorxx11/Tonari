import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../../core/subtitle/subtitle_cue.dart';
import '../../player/data/playback_controller.dart';
import 'loaded_subtitle.dart';

/// Subtitle for the currently-playing track (null when no track or no subtitle
/// matched). Watches the DB row so [adjustOffset] re-emits automatically.
final currentSubtitleProvider =
    StreamProvider.autoDispose<LoadedSubtitle?>((ref) {
  final trackId = ref.watch(
    playbackControllerProvider.select((s) => s.currentTrack?.id),
  );
  if (trackId == null) return Stream.value(null);

  final db = ref.watch(databaseProvider);
  return (db.select(db.subtitles)..where((s) => s.id.equals(trackId)))
      .watchSingleOrNull()
      .map((row) {
    if (row == null) return null;
    final raw = jsonDecode(row.originalLinesJson) as List<dynamic>;
    final cues = <SubtitleCue>[
      for (final item in raw)
        SubtitleCue.fromJson(item as Map<String, dynamic>),
    ];
    return LoadedSubtitle(
      subtitleId: row.id,
      trackId: row.trackId,
      cues: cues,
      timeOffsetMs: row.timeOffsetMs,
    );
  });
});

/// Index of the cue to display at the current position, or -1 before the first
/// cue / when there's no subtitle. During a gap between cues, returns the last
/// cue that played — keeps the overlay stable (Apple Music / 网易云歌词 style)
/// instead of flickering on every silence.
final currentSubtitleLineProvider = StreamProvider.autoDispose<int>((ref) {
  final loaded = ref.watch(currentSubtitleProvider).value;
  if (loaded == null || loaded.cues.isEmpty) {
    return Stream.value(-1);
  }
  final cues = loaded.cues;
  final offsetMs = loaded.timeOffsetMs;
  final player = ref.watch(playbackControllerProvider.notifier).player;
  return player.positionStream
      .map((pos) => _findDisplayCue(cues, pos.inMilliseconds - offsetMs))
      .distinct();
});

/// Binary search for the last cue whose start <= [positionMs]. Returns -1
/// only when [positionMs] is before the first cue. Inside a gap (past a
/// cue's endMs but before the next cue's startMs), returns the previous cue.
int _findDisplayCue(List<SubtitleCue> cues, int positionMs) {
  if (cues.isEmpty) return -1;
  var lo = 0;
  var hi = cues.length - 1;
  var best = -1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (cues[mid].startMs <= positionMs) {
      best = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return best;
}

/// Writes / mutates subtitle-related state. Kept thin — provider tree owns
/// state, this just brokers DB updates.
class SubtitleController {
  SubtitleController(this._ref);
  final Ref _ref;

  /// Adds [deltaMs] (can be negative) to the subtitle's stored offset.
  /// No-op when no subtitle is loaded.
  Future<void> adjustOffset(int deltaMs) async {
    final loaded = _ref.read(currentSubtitleProvider).value;
    if (loaded == null) return;
    final db = _ref.read(databaseProvider);
    final newOffset = loaded.timeOffsetMs + deltaMs;
    await (db.update(db.subtitles)
          ..where((s) => s.id.equals(loaded.subtitleId)))
        .write(
      SubtitlesCompanion(
        timeOffsetMs: Value(newOffset),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> resetOffset() async {
    final loaded = _ref.read(currentSubtitleProvider).value;
    if (loaded == null) return;
    final db = _ref.read(databaseProvider);
    await (db.update(db.subtitles)
          ..where((s) => s.id.equals(loaded.subtitleId)))
        .write(
      SubtitlesCompanion(
        timeOffsetMs: const Value(0),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

final subtitleControllerProvider = Provider<SubtitleController>(
  SubtitleController.new,
);
