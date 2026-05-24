import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../../core/files/folder_bookmark.dart';

class PlaybackState {
  const PlaybackState({
    this.work,
    this.tracks = const [],
    this.currentIndex = -1,
    this.bookmarkBase64,
  });

  final Work? work;
  final List<Track> tracks;
  final int currentIndex;
  final String? bookmarkBase64;

  Track? get currentTrack {
    if (currentIndex < 0 || currentIndex >= tracks.length) return null;
    return tracks[currentIndex];
  }

  bool get hasCurrent => currentTrack != null;
  bool get hasPrevious => currentIndex > 0;
  bool get hasNext => currentIndex >= 0 && currentIndex + 1 < tracks.length;

  PlaybackState copyWith({
    Work? work,
    List<Track>? tracks,
    int? currentIndex,
    String? bookmarkBase64,
  }) =>
      PlaybackState(
        work: work ?? this.work,
        tracks: tracks ?? this.tracks,
        currentIndex: currentIndex ?? this.currentIndex,
        bookmarkBase64: bookmarkBase64 ?? this.bookmarkBase64,
      );

  static const empty = PlaybackState();
}

/// App-lifetime audio playback owner. Lives outside PlayerPage so that
/// popping back to the detail page (or anywhere) does not stop the audio,
/// and so a mini player at the root can keep showing what's playing.
class PlaybackController extends Notifier<PlaybackState> {
  late final AudioPlayer player;
  StreamSubscription<ProcessingState>? _processingSub;
  Timer? _positionTimer;
  String? _resolvedFolderUrl;

  @override
  PlaybackState build() {
    player = AudioPlayer();
    _processingSub = player.processingStateStream.listen(_onProcessingState);
    _positionTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _savePosition(),
    );

    ref.onDispose(() {
      _processingSub?.cancel();
      _positionTimer?.cancel();
      player.dispose();
      _releaseScope();
    });

    return PlaybackState.empty;
  }

  /// Begin playing [tracks] of [work] starting at [initialIndex]. Idempotent
  /// when the requested track is already the current one (just resumes if
  /// paused). Switching works releases the previous bookmark scope and
  /// acquires a new one.
  Future<void> startWork({
    required Work work,
    required List<Track> tracks,
    required int initialIndex,
    required String? bookmarkBase64,
  }) async {
    if (initialIndex < 0 || initialIndex >= tracks.length) return;
    final newTrack = tracks[initialIndex];

    if (state.currentTrack?.id == newTrack.id) {
      if (!player.playing) await player.play();
      return;
    }

    await _savePosition();

    if (state.work?.productId != work.productId) {
      await _releaseScope();
      if (bookmarkBase64 != null) {
        try {
          final r = await FolderBookmark.resolve(bookmarkBase64);
          _resolvedFolderUrl = r.url;
        } catch (_) {
          // Best effort: simulator / in-sandbox files don't need scope.
        }
      }
    }

    state = PlaybackState(
      work: work,
      tracks: tracks,
      currentIndex: initialIndex,
      bookmarkBase64: bookmarkBase64,
    );
    await _loadAndPlay(resume: true);
  }

  Future<void> playAt(int index) async {
    if (state.tracks.isEmpty) return;
    if (index < 0 || index >= state.tracks.length) return;
    await _savePosition();
    state = state.copyWith(currentIndex: index);
    await _loadAndPlay(resume: true);
  }

  Future<void> next() async {
    if (state.hasNext) await playAt(state.currentIndex + 1);
  }

  Future<void> previous() async {
    if (state.hasPrevious) await playAt(state.currentIndex - 1);
  }

  Future<void> play() => player.play();
  Future<void> pause() => player.pause();
  Future<void> seek(Duration d) => player.seek(d);
  Future<void> setSpeed(double s) => player.setSpeed(s);

  Future<void> stop() async {
    await _savePosition();
    await player.stop();
    await _releaseScope();
    state = PlaybackState.empty;
  }

  Future<void> _loadAndPlay({bool resume = false}) async {
    final track = state.currentTrack;
    final work = state.work;
    if (track == null || work == null) return;

    await player.setAudioSource(
      AudioSource.uri(
        Uri.file(track.filePath),
        tag: MediaItem(
          id: track.id,
          title: track.title,
          artist: work.title,
          album: work.productId,
        ),
      ),
    );
    if (resume && track.lastPositionMs > 0) {
      await player.seek(Duration(milliseconds: track.lastPositionMs));
    }
    await player.play();
  }

  Future<void> _onProcessingState(ProcessingState s) async {
    if (s != ProcessingState.completed) return;
    await _bumpPlayCount();
    if (state.hasNext) {
      await next();
    } else {
      await player.pause();
      await player.seek(Duration.zero);
    }
  }

  Future<void> _savePosition() async {
    final track = state.currentTrack;
    if (track == null) return;
    final ms = player.position.inMilliseconds;
    final db = ref.read(databaseProvider);
    await (db.update(db.tracks)..where((t) => t.id.equals(track.id)))
        .write(TracksCompanion(lastPositionMs: Value(ms)));
  }

  Future<void> _bumpPlayCount() async {
    final track = state.currentTrack;
    if (track == null) return;
    final db = ref.read(databaseProvider);
    await db.customStatement(
      'UPDATE tracks SET play_count = play_count + 1 WHERE id = ?',
      [track.id],
    );
  }

  Future<void> _releaseScope() async {
    final url = _resolvedFolderUrl;
    if (url == null) return;
    _resolvedFolderUrl = null;
    await FolderBookmark.release(url);
  }
}

final playbackControllerProvider =
    NotifierProvider<PlaybackController, PlaybackState>(
  PlaybackController.new,
);
