import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../../core/diagnostics/diagnostic_log.dart';
import '../../../core/files/folder_bookmark.dart';
import '../../../core/files/local_image_path.dart';
import '../../../core/ui/app_toast.dart';
import '../../browse/data/remote_models.dart';
import '../../history/data/listen_stats.dart';
import '../../history/data/play_history_repository.dart';
import '../../settings/data/player_prefs.dart';
import '../../video/data/video_controller.dart';
import '../../video/data/video_resume_store.dart';
import '../../p115/data/p115_auth_service.dart';
import '../../p115/data/p115_client.dart';
import '../../p115/data/p115_cookie_store.dart';
import '../../webdav/data/webdav_client.dart';
import '../../library/data/app_events.dart';
import '../../library/data/work_media_source.dart';
import '../../library/data/work_tree.dart';
import 'now_playing_bridge.dart';
import 'sleep_timer.dart';

class PlaybackState {
  const PlaybackState({
    this.work,
    this.tracks = const [],
    this.browseItems = const [],
    this.currentIndex = -1,
    this.bookmarkBase64,
    this.remoteKind,
    this.remoteConfig,
  });

  final Work? work;
  final List<Track> tracks;
  final List<PlayableItem> browseItems;
  final int currentIndex;
  final String? bookmarkBase64;

  /// Non-null when the current work streams from WebDAV; drives how each
  /// track's AudioSource is built (remote URL + auth vs local file).
  final RemoteSourceKind? remoteKind;
  final WebdavConfig? remoteConfig;

  Track? get currentTrack {
    if (currentIndex < 0 || currentIndex >= tracks.length) return null;
    return tracks[currentIndex];
  }

  PlayableItem? get currentBrowseItem {
    if (currentIndex < 0 || currentIndex >= browseItems.length) return null;
    return browseItems[currentIndex];
  }

  bool get isBrowseMode => browseItems.isNotEmpty;
  int get queueLength => isBrowseMode ? browseItems.length : tracks.length;

  bool get hasCurrent => currentTrack != null || currentBrowseItem != null;
  bool get hasPrevious => currentIndex > 0;
  bool get hasNext => currentIndex >= 0 && currentIndex + 1 < queueLength;

  PlaybackState copyWith({
    Work? work,
    List<Track>? tracks,
    List<PlayableItem>? browseItems,
    int? currentIndex,
    String? bookmarkBase64,
    RemoteSourceKind? remoteKind,
    WebdavConfig? remoteConfig,
  }) => PlaybackState(
    work: work ?? this.work,
    tracks: tracks ?? this.tracks,
    browseItems: browseItems ?? this.browseItems,
    currentIndex: currentIndex ?? this.currentIndex,
    bookmarkBase64: bookmarkBase64 ?? this.bookmarkBase64,
    remoteKind: remoteKind ?? this.remoteKind,
    remoteConfig: remoteConfig ?? this.remoteConfig,
  );

  static const empty = PlaybackState();
}

/// A user-facing message for a failed play, plus the remote source's name
/// when the failure belongs to a remote source (so it is worth keeping in the
/// inbox). For WebDAV the server is probed once to tell "unreachable" apart
/// from a problem with the file itself.
Future<(String, String?)> describePlayError(
  Object e, {
  ({Future<String> Function() name, Future<void> Function() probe})? webdav,
}) async {
  if (e is P115AuthExpiredException) return ('115 登录已失效，请重新登录', '115');
  if (e is P115Exception) return (e.message, '115');
  if (webdav == null) return ('无法播放：$e', null);
  final name = await webdav.name();
  try {
    await webdav.probe();
  } catch (_) {
    return ('WebDAV「$name」连不上，请检查网络或服务器是否开机', name);
  }
  return ('无法播放：$e', name);
}

/// App-lifetime audio playback owner. Lives outside PlayerPage so that
/// popping back to the detail page (or anywhere) does not stop the audio,
/// and so a mini player at the root can keep showing what's playing.
class PlaybackController extends Notifier<PlaybackState> {
  late final AudioPlayer player;
  StreamSubscription<ProcessingState>? _processingSub;
  Timer? _positionTimer;
  String? _resolvedFolderUrl;
  // P115's signed CDN link expires (tens of minutes to hours for audio), after
  // which `player.play()` hangs on a dead URL. Re-resolve before playing past
  // it; stale also covers a deferred cold-start restore and a stalled play.
  DateTime? _sourceExpiresAt;
  bool _sourceStale = false;
  Timer? _stallWatchdog;
  Future<void>? _refreshing;
  // Position to resume to when a deferred/stale source is (re)resolved. Set by
  // cold-start restore (lastPositionMs); null means "resume at live position".
  int? _resumePositionMs;
  DateTime? _lastListenTick;

  @override
  PlaybackState build() {
    // Hand P115's cookie headers to AVPlayer directly instead of just_audio's
    // loopback proxy, which dies when iOS suspends the app.
    player = AudioPlayer(useProxyForRequestHeaders: false);
    NowPlayingBridge.setCommandHandler(_handleNowPlayingCommand);
    _processingSub = player.processingStateStream.listen(_onProcessingState);
    _positionTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _syncPlaybackTick(),
    );

    ref.onDispose(() {
      _processingSub?.cancel();
      _stallWatchdog?.cancel();
      _positionTimer?.cancel();
      NowPlayingBridge.clearCommandHandler();
      NowPlayingBridge.clear();
      player.dispose();
      _releaseScope();
    });

    Future.microtask(_restoreLastPlayed);

    return PlaybackState.empty;
  }

  bool get _isStale =>
      _sourceStale ||
      (_sourceExpiresAt != null &&
          DateTime.now().isAfter(
            _sourceExpiresAt!.subtract(const Duration(minutes: 2)),
          ));

  /// Sets a resolved remote source, remembering when its link expires.
  Future<void> _setRemoteSource(
    ResolvedMediaUrl resolved,
    String via, {
    Duration? at,
  }) async {
    await player.setAudioSource(
      AudioSource.uri(resolved.url, headers: resolved.headers),
      initialPosition: at,
    );
    _sourceExpiresAt = resolved.expiresAt;
    _sourceStale = false;
    DiagnosticLog.write('player', 'source_set', {
      'via': via,
      'urlHost': resolved.url.host,
      'expiresAt': resolved.expiresAt?.toIso8601String(),
    });
  }

  /// Re-resolves a stale P115 source before play. Deduped so the stall
  /// watchdog and a near-simultaneous play tap share one re-resolution.
  Future<void> _ensureFreshSource() {
    if (!_isStale) return Future<void>.value();
    return _refreshing ??= _refreshStaleSource().whenComplete(
      () => _refreshing = null,
    );
  }

  Future<void> _refreshStaleSource() async {
    if (!state.hasCurrent) return;
    final pending = _resumePositionMs;
    final at = pending != null
        ? Duration(milliseconds: pending)
        : player.position;
    final wasPlaying = player.playing;
    ResolvedMediaUrl resolved;
    try {
      final browseItem = state.currentBrowseItem;
      if (browseItem != null) {
        resolved = await browseItem.resolve();
      } else if (state.currentTrack != null &&
          state.remoteKind == RemoteSourceKind.p115) {
        resolved = await _resolveP115(state.currentTrack!.filePath);
      } else {
        return;
      }
    } catch (e) {
      DiagnosticLog.write('player', 'source_refresh_error', {
        'errorType': '${e.runtimeType}',
        'message': '$e',
      });
      return;
    }
    DiagnosticLog.write('player', 'source_refresh', {
      'positionMs': at.inMilliseconds,
      'wasPlaying': wasPlaying,
    });
    try {
      await _setRemoteSource(resolved, 'refresh', at: at);
    } catch (_) {
      return;
    }
    _resumePositionMs = null;
    if (wasPlaying) await player.play();
    await _publishNowPlaying();
  }

  /// On cold start, surface the most-recently-played work into the
  /// MiniPlayer with its audio source preloaded and seeked to where the
  /// user left off — but *not* playing. Tapping play picks up instantly.
  Future<void> _restoreLastPlayed() async {
    if (state.hasCurrent) return;
    final db = ref.read(databaseProvider);
    final work =
        await (db.select(db.works)
              ..where((w) => w.lastPlayedAt.isNotNull())
              ..where((w) => w.isRemoved.equals(false))
              ..orderBy([(w) => OrderingTerm.desc(w.lastPlayedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (work == null || work.lastPlayedTrackId == null) return;

    // If a video was played more recently, let the video mini player restore it
    // instead of showing this audio.
    final videoSlot = ref.read(videoResumeStoreProvider).read();
    if (videoSlot != null &&
        work.lastPlayedAt != null &&
        videoSlot.lastPlayedAt.isAfter(work.lastPlayedAt!)) {
      return;
    }

    // Same order the files page queues from; filePath is a pickcode for 115.
    final tracks = flattenForPlayback(
      buildWorkTree(
        await (db.select(
          db.tracks,
        )..where((t) => t.workId.equals(work.productId))).get(),
      ),
    );
    if (tracks.isEmpty) return;

    final idx = tracks.indexWhere((t) => t.id == work.lastPlayedTrackId);
    if (idx < 0) return;

    final mediaSource = await ref
        .read(workMediaSourceProvider)
        .sourceForWork(work);
    final remoteKind = mediaSource.kind == RemoteSourceKind.local
        ? null
        : mediaSource.kind;
    final remoteConfig = mediaSource.webdavConfig;

    String? bookmark;
    if (remoteConfig == null) {
      final folderId = work.importedFolderId;
      if (folderId != null) {
        final folder = await (db.select(
          db.importedFolders,
        )..where((f) => f.id.equals(folderId))).getSingleOrNull();
        bookmark = folder?.bookmarkBase64;
      }
      if (bookmark != null && bookmark.isNotEmpty) {
        try {
          final r = await FolderBookmark.resolve(bookmark);
          _resolvedFolderUrl = r.url;
        } catch (_) {
          // simulator / sandboxed files don't need an active scope
        }
      }
    }

    state = PlaybackState(
      work: work,
      tracks: tracks,
      currentIndex: idx,
      bookmarkBase64: bookmark,
      remoteConfig: remoteConfig,
      remoteKind: remoteKind,
    );

    final track = tracks[idx];
    // P115 needs a fresh signed link that can't be built offline, so don't
    // preload a bogus file:// source — defer resolution to the first play,
    // like the video mini player's dormant resume.
    if (remoteKind == RemoteSourceKind.p115) {
      _sourceStale = true;
      _resumePositionMs = track.lastPositionMs;
      DiagnosticLog.write('player', 'restore', {
        'remoteKind': remoteKind?.name,
        'deferred': true,
        'positionMs': track.lastPositionMs,
      });
      await _publishNowPlaying();
      return;
    }
    DiagnosticLog.write('player', 'restore', {
      'remoteKind': remoteKind?.name,
      'deferred': false,
      'positionMs': track.lastPositionMs,
    });
    try {
      await player.setAudioSource(_audioSourceFor(track));
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
    WebdavConfig? remoteConfig,
    RemoteSourceKind? remoteKind,
  }) async {
    if (initialIndex < 0 || initialIndex >= tracks.length) return;
    final newTrack = tracks[initialIndex];

    if (state.currentTrack?.id == newTrack.id) {
      if (!player.playing) await play();
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
      browseItems: const [],
      currentIndex: initialIndex,
      bookmarkBase64: bookmarkBase64,
      remoteKind: remoteKind,
      remoteConfig: remoteConfig,
    );
    await _loadAndPlay();
  }

  Future<void> startBrowseQueue({
    required List<PlayableItem> items,
    required int initialIndex,
  }) async {
    if (initialIndex < 0 || initialIndex >= items.length) return;
    final newItem = items[initialIndex];

    if (state.currentBrowseItem?.id == newItem.id) {
      if (!player.playing) await play();
      return;
    }

    await _savePosition();
    await _releaseScope();

    state = PlaybackState(
      tracks: const [],
      browseItems: items,
      currentIndex: initialIndex,
    );
    await _loadAndPlay();
  }

  Future<void> playAt(int index) async {
    if (state.queueLength == 0) return;
    if (index < 0 || index >= state.queueLength) return;
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
    DiagnosticLog.write('player', 'play_requested', {
      'stale': _isStale,
      'playing': player.playing,
      'processingState': player.processingState.name,
    });
    await _ensureFreshSource();
    _watchForStall();
    await player.play();
    await _publishNowPlaying();
  }

  /// A dead 115 link leaves the player "playing" at a frozen position, and
  /// further play/pause taps can't revive it. If the position hasn't moved
  /// shortly after play, re-resolve once.
  void _watchForStall() {
    _stallWatchdog?.cancel();
    if (_sourceExpiresAt == null) return;
    final from = player.position;
    _stallWatchdog = Timer(const Duration(seconds: 8), () {
      if (!player.playing || player.position > from) return;
      DiagnosticLog.write('player', 'play_stalled', {
        'positionMs': from.inMilliseconds,
        'processingState': player.processingState.name,
      });
      _sourceStale = true;
      unawaited(_ensureFreshSource());
    });
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
    _sourceExpiresAt = null;
    _sourceStale = false;
    _resumePositionMs = null;
    await NowPlayingBridge.clear();
    await _releaseScope();
    state = PlaybackState.empty;
  }

  /// Loads the current item and plays. Failures (offline source, expired auth,
  /// unreadable stream) are surfaced as a SnackBar — audio has no in-player
  /// error view like video, and this covers manual taps and auto-advance alike.
  Future<void> _loadAndPlay() async {
    try {
      await _loadAndPlayInner();
    } catch (e) {
      DiagnosticLog.write('player', 'play_error', {
        'errorType': '${e.runtimeType}',
        'message': '$e',
      });
      final (text, sourceName) = await _describePlayError(e);
      showAppToast(text);
      final work = state.work;
      if (sourceName != null) {
        await ref
            .read(appEventSinkProvider)
            .log(
              category: 'network',
              title: text,
              detail: '$e',
              productId: work?.productId,
              workTitle: work?.title,
              sourceName: sourceName,
            );
      }
    }
  }

  Future<(String, String?)> _describePlayError(Object e) {
    final config = state.remoteConfig;
    return describePlayError(
      e,
      webdav: state.remoteKind == RemoteSourceKind.webdav && config != null
          ? (
              name: () async => await _webdavServerName() ?? config.host,
              probe: () =>
                  ref.read(webdavClientProvider).testConnection(config),
            )
          : null,
    );
  }

  Future<String?> _webdavServerName() async {
    final folderId = state.work?.importedFolderId;
    if (folderId == null) return null;
    final db = ref.read(databaseProvider);
    final folder = await (db.select(
      db.importedFolders,
    )..where((f) => f.id.equals(folderId))).getSingleOrNull();
    final serverId = folder?.serverId;
    if (serverId == null) return null;
    final server = await (db.select(
      db.webdavServers,
    )..where((s) => s.id.equals(serverId))).getSingleOrNull();
    return server?.name;
  }

  /// Loads the current track from scratch and starts playing. Per-track
  /// resume is deliberately not done here — the user wants every tap on a
  /// track to start from the beginning. Cold-start MiniPlayer hydration in
  /// [_restoreLastPlayed] is the only place that seeks to `lastPositionMs`.
  Future<void> _loadAndPlayInner() async {
    // A fresh load plays from the beginning, so drop any deferred restore
    // position so it can't leak into a later background-resume refresh.
    _resumePositionMs = null;
    // Only one source plays at a time: stop any video and reclaim the lock
    // screen / Control Center commands for audio.
    final hadVideo = ref.read(videoControllerProvider).hasVideo;
    await ref.read(videoControllerProvider.notifier).stop();
    NowPlayingBridge.setCommandHandler(_handleNowPlayingCommand);
    // fvp releases the iOS audio session asynchronously when it tears down;
    // coming straight from video, give it a beat so just_audio can re-acquire
    // the session — otherwise the source occasionally never finishes loading.
    if (hadVideo) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    final browseItem = state.currentBrowseItem;
    if (browseItem != null) {
      await _setRemoteSource(await browseItem.resolve(), 'load_browse');
      unawaited(ref.read(playHistoryRepositoryProvider).recordItem(browseItem));
      await player.play();
      await _publishNowPlaying();
      return;
    }

    final track = state.currentTrack;
    final work = state.work;
    if (track == null || work == null) return;

    if (state.remoteKind == RemoteSourceKind.p115) {
      await _setRemoteSource(await _resolveP115(track.filePath), 'load_p115');
      await _bumpLastPlayed(trackChanged: true);
      await player.play();
      await _publishNowPlaying();
      return;
    }

    await player.setAudioSource(_audioSourceFor(track));
    _sourceExpiresAt = null;
    _sourceStale = false;
    await _bumpLastPlayed(trackChanged: true);
    await player.play();
    await _publishNowPlaying();
  }

  Future<ResolvedMediaUrl> _resolveP115(String pickcode) async {
    try {
      return await ref.read(p115ClientProvider).resolveAudioUrl(pickcode);
    } on P115AuthExpiredException {
      await ref.read(p115AuthServiceProvider).clearCookie();
      ref.invalidate(p115CookieProvider);
      rethrow;
    }
  }

  AudioSource _audioSourceFor(Track track) {
    final config = state.remoteConfig;
    if (state.remoteKind == RemoteSourceKind.webdav && config != null) {
      final auth = config.authHeader;
      return AudioSource.uri(
        Uri.parse(config.streamUrl(track.filePath)),
        headers: auth == null ? null : {'Authorization': auth},
      );
    }
    return AudioSource.uri(Uri.file(track.filePath));
  }

  Future<void> _onProcessingState(ProcessingState s) async {
    DiagnosticLog.write('player', 'processing_state', {
      'state': s.name,
      'playing': player.playing,
      'positionMs': player.position.inMilliseconds,
    });
    if (s != ProcessingState.completed) return;
    await _bumpPlayCount();
    if (ref.read(sleepTimerProvider.notifier).onTrackCompleted()) {
      await player.pause();
      await player.seek(Duration.zero);
      await _publishNowPlaying();
      return;
    }
    final mode = ref.read(playerPrefsProvider).playbackMode;
    switch (mode) {
      case PlaybackMode.sequence:
        if (state.hasNext) {
          await next();
        } else {
          await player.pause();
          await player.seek(Duration.zero);
          await _publishNowPlaying();
        }
      case PlaybackMode.loopAll:
        if (state.hasNext) {
          await next();
        } else if (state.queueLength > 0) {
          await playAt(0);
        }
      case PlaybackMode.loopOne:
        await playAt(state.currentIndex);
      case PlaybackMode.shuffle:
        if (state.queueLength <= 1) {
          await playAt(state.currentIndex);
        } else {
          final rng = math.Random();
          var idx = rng.nextInt(state.queueLength);
          if (idx == state.currentIndex) {
            idx = (idx + 1) % state.queueLength;
          }
          await playAt(idx);
        }
    }
  }

  Future<void> _syncPlaybackTick() async {
    // Don't touch the now-playing center when audio is idle — otherwise this
    // timer clears it every 5s and fights whatever is actually playing (video).
    if (!state.hasCurrent) return;
    await _logListening();
    await _savePosition();
    await _publishNowPlaying();
  }

  /// Credits the wall time since the previous tick to the current work, but
  /// only when audio was audibly playing at both ticks. Gaps longer than a
  /// few ticks (app suspended, timer starved) are dropped rather than guessed.
  Future<void> _logListening() async {
    final now = DateTime.now();
    final work = state.work;
    final audible =
        work != null &&
        player.playing &&
        player.processingState == ProcessingState.ready;
    final last = _lastListenTick;
    _lastListenTick = audible ? now : null;
    if (!audible || last == null) return;
    final ms = now.difference(last).inMilliseconds;
    if (ms <= 0 || ms > 15000) return;
    await ref.read(listenLogRepositoryProvider).add(work.productId, now, ms);
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
    await (db.update(
      db.works,
    )..where((w) => w.productId.equals(work.productId))).write(
      WorksCompanion(
        lastPlayedAt: Value(now),
        lastPlayedTrackId: trackChanged
            ? Value(track.id)
            : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
    unawaited(ref.read(playHistoryRepositoryProvider).recordWork(work));
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
    final browseItem = state.currentBrowseItem;
    if (browseItem != null) {
      await NowPlayingBridge.update(
        NowPlayingSnapshot(
          title: browseItem.title,
          album: browseItem.sourceName,
          artist: browseItem.sourceName,
          artworkPath: null,
          position: player.position,
          duration: player.duration ?? Duration.zero,
          playing: player.playing,
          speed: player.speed,
          hasPrevious: state.hasPrevious,
          hasNext: state.hasNext,
        ),
      );
      return;
    }

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
