import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';

/// Reads file-header durations for tracks whose `durationMs` is still 0
/// (because the scanner doesn't probe audio length) and writes them back
/// to the DB. Stream-driven reads upstream will then redraw with the
/// real time shown.
///
/// Designed to be called fire-and-forget from any page that displays
/// tracks — concurrent calls are coalesced so we only ever have one
/// probe loop running at a time across the whole app.
class TrackDurationProbeService {
  TrackDurationProbeService(this._db);

  final TonariDatabase _db;
  bool _running = false;

  Future<void> probe(List<Track> tracks) async {
    if (_running) return;
    final missing = tracks.where((t) => t.durationMs == 0).toList();
    if (missing.isEmpty) return;
    _running = true;
    final player = AudioPlayer();
    try {
      for (final t in missing) {
        try {
          await player.setFilePath(t.filePath);
          final ms = player.duration?.inMilliseconds ?? 0;
          if (ms > 0) {
            await (_db.update(_db.tracks)
                  ..where((row) => row.id.equals(t.id)))
                .write(TracksCompanion(
              durationMs: Value(ms),
              updatedAt: Value(DateTime.now()),
            ));
          }
        } catch (_) {
          // Skip on probe failure (corrupt file, unsupported codec, etc.).
        }
      }
    } finally {
      await player.dispose();
      _running = false;
    }
  }
}

final trackDurationProbeProvider = Provider<TrackDurationProbeService>((ref) {
  return TrackDurationProbeService(ref.watch(databaseProvider));
});
