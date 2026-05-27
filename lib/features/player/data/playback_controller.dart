import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../../core/files/folder_bookmark.dart';
import '../../../core/files/local_image_path.dart';
import 'now_playing_bridge.dart';

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
  }) => PlaybackState(
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
    NowPlayingBridge.setCommandHandler(_handleNowPlayingCommand);
    _processingSub = player.processingStateStream.listen(_onProcessingState);
    _positionTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _syncPlaybackTick(),
    );

    ref.onDispose(() {
      _processingSub?.cancel();
      _positionTimer?.cancel();
      NowPlayingBridge.clearCommandHandler();
      NowPlayingBridge.clear();
      player.dispose();
      _releaseScope();
    });

    Future.microtask(_restoreLastPlayed);

    return PlaybackState.empty;
  }

  /// On cold start, surface the most-recently-played work into the
  /// MiniPlayer with its audio source preloaded and seeked to where the
  /// user left off — but *not* playing. Tapping play picks up instantly.
  Future<void> _restoreLastPlayed() async {
    if (state.hasCurrent) return;
    final db = ref.read(databaseProvider);
    final work = await (db.select(db.works)
          ..where((w) => w.lastPlayedAt.isNotNull())
          ..where((w) => w.isRemoved.equals(false))
          ..orderBy([(w) => OrderingTerm.desc(w.lastPlayedAt)])
          ..limit(1))
        .getSingleOrNull();
    if (work == null || work.lastPlayedTrackId == null) return;

    final tracks = await (db.select(db.tracks)
          ..where((t) => t.workId.equals(work.productId))
          ..orderBy([(t) => OrderingTerm.asc(t.filePath)]))
        .get();
    if (tracks.isEmpty) return;

    final idx = tracks.indexWhere((t) => t.id == work.lastPlayedTrackId);
    if (idx < 0) return;

    String? bookmark;
    final folderId = work.importedFolderId;
    if (folderId != null) {
      final folder = await (db.select(db.importedFolders)
            ..where((f) => f.id.equals(folderId)))
          .getSingleOrNull();
      bookmark = folder?.bookmarkBase64;
    }
    if (bookmark != null) {
      try {
        final r = await FolderBookmark.resolve(bookmark);
        _resolvedFolderUrl = r.url;
      } catch (_) {
        // simulator / sandboxed files don't need an active scope
      }
    }

    state = PlaybackState(
      work: work,
      tracks: tracks,
      currentIndex: idx,
      bookmarkBase64: bookmark,
    );

    final track = tracks[idx];
    try {
      await player.setAudioSource(AudioSource.uri(Uri.file(track.filePath)));
      if (track.lastPositionMs > 0) {
        await player.seek(Duration(milliseconds: track.lastPositionMs));
      }
      await _publishNowPlaying();
    } catch (_) {
      // file moved / permission denied — keep the state so MiniPlayer
      // is visible, but audio playback will surface its own error on tap
    }
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
    await _loadAndPlay();
  }

  Future<void> playAt(int index) async {
    if (state.tracks.isEmpty) return;
    if (index < 0 || index >= state.tracks.length) return;
    await _savePosition();
    state = state.copyWith(currentIndex: index);
    await _loadAndPlay();
  }

  Future<void> next() async {
    if (state.hasNext) {
      await playAt(state.currentIndex + 1);
    } else {
      await _publishNowPlaying();
    }
  }

  Future<void> previous() async {
    if (state.hasPrevious) {
      await playAt(state.currentIndex - 1);
    } else {
      await _publishNowPlaying();
    }
  }

  Future<void> play() async {
    await player.play();
    await _publishNowPlaying();
  }

  Future<void> pause() async {
    await player.pause();
    await _publishNowPlaying();
  }

  Future<void> seek(Duration d) async {
    await player.seek(d);
    await _publishNowPlaying();
  }

  Future<void> setSpeed(double s) async {
    await player.setSpeed(s);
    await _publishNowPlaying();
  }

  Future<void> stop() async {
    await _savePosition();
    await player.stop();
    await NowPlayingBridge.clear();
    await _releaseScope();
    state = PlaybackState.empty;
  }

  /// Loads the current track from scratch and starts playing. Per-track
  /// resume is deliberately not done here — the user wants every tap on a
  /// track to start from the beginning. Cold-start MiniPlayer hydration in
  /// [_restoreLastPlayed] is the only place that seeks to `lastPositionMs`.
  Future<void> _loadAndPlay() async {
    final track = state.currentTrack;
    final work = state.work;
    if (track == null || work == null) return;

    await player.setAudioSource(AudioSource.uri(Uri.file(track.filePath)));
    await _bumpLastPlayed(trackChanged: true);
    await player.play();
    await _publishNowPlaying();
  }

  Future<void> _onProcessingState(ProcessingState s) async {
    if (s != ProcessingState.completed) return;
    await _bumpPlayCount();
    if (state.hasNext) {
      await next();
    } else {
      await player.pause();
      await player.seek(Duration.zero);
      await _publishNowPlaying();
    }
  }

  Future<void> _syncPlaybackTick() async {
    await _savePosition();
    await _publishNowPlaying();
  }

  Future<void> _savePosition() async {
    final track = state.currentTrack;
    if (track == null) return;
    final ms = player.position.inMilliseconds;
    final db = ref.read(databaseProvider);
    await (db.update(db.tracks)..where((t) => t.id.equals(track.id))).write(
      TracksCompanion(lastPositionMs: Value(ms)),
    );
    await _bumpLastPlayed();
  }

  Future<void> _bumpLastPlayed({bool trackChanged = false}) async {
    final work = state.work;
    final track = state.currentTrack;
    if (work == null || track == null) return;
    final now = DateTime.now();
    final db = ref.read(databaseProvider);
    await (db.update(db.works)..where((w) => w.productId.equals(work.productId)))
        .write(
      WorksCompanion(
        lastPlayedAt: Value(now),
        lastPlayedTrackId:
            trackChanged ? Value(track.id) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
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

  Future<void> _publishNowPlaying() async {
    final track = state.currentTrack;
    final work = state.work;
    if (track == null || work == null) {
      await NowPlayingBridge.clear();
      return;
    }

    await NowPlayingBridge.update(
      NowPlayingSnapshot(
        title: track.title,
        album: work.productId,
        artist: work.title,
        artworkPath: LocalImagePath.resolve(work.mainImageLocalPath),
        position: player.position,
        duration: player.duration ?? Duration(milliseconds: track.durationMs),
        playing: player.playing,
        speed: player.speed,
        hasPrevious: state.hasPrevious,
        hasNext: state.hasNext,
      ),
    );
  }

  Future<void> _handleNowPlayingCommand(
    NowPlayingCommand command,
    Object? arguments,
  ) async {
    switch (command) {
      case NowPlayingCommand.play:
        await play();
      case NowPlayingCommand.pause:
        await pause();
      case NowPlayingCommand.next:
        await next();
      case NowPlayingCommand.previous:
        await previous();
      case NowPlayingCommand.seek:
        final map = Map<Object?, Object?>.from(arguments! as Map);
        final positionMs = map['positionMs'] as int;
        await seek(Duration(milliseconds: positionMs));
    }
  }

  Future<void> _releaseScope() async {
    final url = _resolvedFolderUrl;
    if (url == null) return;
    _resolvedFolderUrl = null;
    await FolderBookmark.release(url);
  }
}

final playbackControllerProvider =
    NotifierProvider<PlaybackController, PlaybackState>(PlaybackController.new);
