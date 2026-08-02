import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/db/providers.dart';
import '../../../core/diagnostics/diagnostic_log.dart';
import '../../../core/net/media_proxy.dart';
import '../../browse/data/remote_models.dart';
import '../../p115/data/p115_auth_service.dart';
import '../../p115/data/p115_client.dart';
import '../../p115/data/p115_cookie_store.dart';
import '../../player/data/now_playing_bridge.dart';
import '../../player/data/playback_controller.dart';
import '../../player/data/sleep_timer.dart';
import '../../webdav/data/webdav_client.dart';
import '../../webdav/data/webdav_password_store.dart';
import 'video_resume_store.dart';

/// App-lifetime owner of the video player, mirroring [PlaybackController] for
/// audio. Lives outside the video page so minimizing keeps it playing, a mini
/// player can represent it, and the lock screen / Control Center can drive it
/// through the shared [NowPlayingBridge].
class VideoPlaybackState {
  const VideoPlaybackState({
    this.item,
    this.controller,
    this.error,
    this.dormant = false,
  });

  final PlayableItem? item;
  final VideoPlayerController? controller;
  final Object? error;

  /// Remembered video shown in the mini bar but not yet loaded — the link is
  /// resolved only when the user taps play.
  final bool dormant;

  bool get hasVideo => item != null;
  bool get isReady => controller != null && controller!.value.isInitialized;
}

class VideoController extends Notifier<VideoPlaybackState>
    with WidgetsBindingObserver {
  Timer? _publishTimer;
  VideoPlayerController? _controller;
  FutureOr<void> Function()? _resolvedRelease;
  bool _lastPlaying = false;
  String? _lastVideoError;
  bool _lastEnded = false;
  var _openSeq = 0;
  Future<void>? _parking;

  @override
  VideoPlaybackState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _publishTimer?.cancel();
      unawaited(_teardown());
    });
    Future.microtask(_maybeRestoreDormant);
    return const VideoPlaybackState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    DiagnosticLog.write('video_player', 'app_lifecycle', {
      'lifecycleState': state.name,
      ..._stateFields(),
      ..._controllerFields(_controller),
    });
    if (state == AppLifecycleState.paused) {
      _parkPausedVideo('lifecycle_paused');
    }
  }

  /// Loads and plays [item], stopping audio so only one source makes sound, and
  /// resuming from the saved position if this is the remembered video.
  Future<void> open(PlayableItem item) async {
    final stableItem = _withControllerResolver(item);
    final attemptId = ++_openSeq;
    DiagnosticLog.write('video_player', 'open_requested', {
      ..._videoItemFields(stableItem),
      'attemptId': attemptId,
      'inputResolverSource': item.resolverSource,
      ..._stateFields(),
      ..._controllerFields(_controller),
    });
    await ref.read(playbackControllerProvider.notifier).stop();
    _publishTimer?.cancel();
    _publishTimer = null;
    await _teardown();
    state = VideoPlaybackState(item: stableItem);
    _lastVideoError = null;
    _lastEnded = false;
    DiagnosticLog.write('video_player', 'open_start', {
      ..._videoItemFields(stableItem),
      'attemptId': attemptId,
    });
    VideoPlayerController? controller;
    FutureOr<void> Function()? release;
    try {
      DiagnosticLog.write('video_player', 'resolve_begin', {
        ..._videoItemFields(stableItem),
        'attemptId': attemptId,
      });
      final resolved = await stableItem.resolve();
      DiagnosticLog.write('video_player', 'resolved', {
        ..._videoItemFields(stableItem),
        'attemptId': attemptId,
        'urlScheme': resolved.url.scheme,
        'urlHost': resolved.url.host,
        'urlPort': resolved.url.hasPort ? resolved.url.port : null,
        'hasHeaders': resolved.headers?.isNotEmpty ?? false,
      });
      release = resolved.release;
      final options = VideoPlayerOptions(allowBackgroundPlayback: true);
      if (resolved.url.isScheme('file')) {
        controller = VideoPlayerController.file(
          File.fromUri(resolved.url),
          videoPlayerOptions: options,
        );
      } else {
        controller = VideoPlayerController.networkUrl(
          resolved.url,
          httpHeaders: resolved.headers ?? const <String, String>{},
          videoPlayerOptions: options,
        );
      }
      final initializeWatch = Stopwatch()..start();
      DiagnosticLog.write('video_player', 'initialize_start', {
        ..._videoItemFields(stableItem),
        'attemptId': attemptId,
        'urlScheme': resolved.url.scheme,
        'urlHost': resolved.url.host,
        'urlPort': resolved.url.hasPort ? resolved.url.port : null,
      });
      await controller.initialize();
      DiagnosticLog.write('video_player', 'initialized', {
        ..._videoItemFields(stableItem),
        'attemptId': attemptId,
        'elapsedMs': initializeWatch.elapsedMilliseconds,
        'durationMs': controller.value.duration.inMilliseconds,
        'width': controller.value.size.width,
        'height': controller.value.size.height,
      });
      _resumeFromSlot(controller, stableItem);
      controller.addListener(_onValue);
      await controller.play();
      DiagnosticLog.write('video_player', 'play_requested', {
        ..._videoItemFields(stableItem),
        'attemptId': attemptId,
        'positionMs': controller.value.position.inMilliseconds,
      });
      _controller = controller;
      _resolvedRelease = release;
      state = VideoPlaybackState(item: stableItem, controller: controller);
      NowPlayingBridge.setCommandHandler(_handleCommand);
      _publish();
      _saveSlot();
      _publishTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _publish();
        _saveSlot();
      });
    } catch (e) {
      DiagnosticLog.write('video_player', 'open_error', {
        ..._videoItemFields(stableItem),
        'attemptId': attemptId,
        'errorType': '${e.runtimeType}',
        'message': '$e',
        ..._controllerFields(controller),
      });
      await controller?.dispose();
      await release?.call();
      state = VideoPlaybackState(item: stableItem, error: e);
    }
  }

  /// Loads the dormant (remembered) video — invoked by the mini bar play button.
  Future<void> resume() async {
    final item = state.item;
    DiagnosticLog.write('video_player', 'resume_requested', {
      'hasItem': item != null,
      ..._stateFields(),
      ..._controllerFields(_controller),
    });
    if (item != null && _controller == null) await open(item);
  }

  Future<void> play() async {
    DiagnosticLog.write('video_player', 'play_existing_start', {
      ..._stateFields(),
      ..._controllerFields(_controller),
    });
    final c = _controller;
    if (c == null) {
      await resume();
      return;
    }
    if (!c.value.isInitialized || c.value.hasError || _isAtEnd(c)) {
      DiagnosticLog.write('video_player', 'play_existing_reopen', {
        ..._stateFields(),
        ..._controllerFields(c),
      });
      await _reopenCurrent('play_existing_invalid');
      return;
    }
    await c.play();
    DiagnosticLog.write('video_player', 'play_existing_done', {
      ..._stateFields(),
      ..._controllerFields(_controller),
    });
    _publish();
    _saveSlot();
  }

  Future<void> pause() async {
    DiagnosticLog.write('video_player', 'pause_requested', {
      ..._stateFields(),
      ..._controllerFields(_controller),
    });
    await _controller?.pause();
    _publish();
    _saveSlot();
  }

  Future<void> seek(Duration position) async {
    DiagnosticLog.write('video_player', 'seek', {
      'positionMs': position.inMilliseconds,
    });
    await _controller?.seekTo(position);
    _publish();
    _saveSlot();
  }

  Future<void> setSpeed(double speed) async {
    await _controller?.setPlaybackSpeed(speed);
    _publish();
  }

  Future<void> stop() async {
    if (_controller == null && state.item == null) return;
    DiagnosticLog.write('video_player', 'stop', {
      ..._stateFields(),
      ..._controllerFields(_controller),
    });
    _publishTimer?.cancel();
    _publishTimer = null;
    _saveSlot();
    await _teardown();
    await NowPlayingBridge.clear();
    await MediaProxy.instance.reset('video_stop');
    state = const VideoPlaybackState();
  }

  void _resumeFromSlot(VideoPlayerController controller, PlayableItem item) {
    final slot = ref.read(videoResumeStoreProvider).read();
    if (slot == null || slot.id != item.id) return;
    final pos = slot.positionMs;
    final dur = controller.value.duration.inMilliseconds;
    if (pos > 3000 && (dur == 0 || pos < dur - 3000)) {
      DiagnosticLog.write('video_player', 'resume_seek', {
        ..._videoItemFields(item),
        'positionMs': pos,
        'durationMs': dur,
      });
      controller.seekTo(Duration(milliseconds: pos));
    }
  }

  void _onValue() {
    final c = _controller;
    if (c == null) return;
    final value = c.value;
    if (value.hasError && value.errorDescription != _lastVideoError) {
      _lastVideoError = value.errorDescription;
      DiagnosticLog.write('video_player', 'player_error', {
        'errorDescription': value.errorDescription,
        'positionMs': value.position.inMilliseconds,
      });
    }
    final playing = value.isPlaying;
    if (playing != _lastPlaying) {
      _lastPlaying = playing;
      DiagnosticLog.write('video_player', 'playing_changed', {
        'isPlaying': playing,
        ..._controllerFields(c),
      });
      _publish();
    }
    final durationMs = value.duration.inMilliseconds;
    final positionMs = value.position.inMilliseconds;
    final ended = durationMs > 0 && positionMs >= durationMs - 500;
    if (ended != _lastEnded) {
      _lastEnded = ended;
      DiagnosticLog.write('video_player', 'ended_changed', {
        'ended': ended,
        ..._controllerFields(c),
      });
      // A finished video already stops on its own; this just clears a pending
      // "finish current track then stop" sleep-timer state.
      if (ended) ref.read(sleepTimerProvider.notifier).onTrackCompleted();
    }
  }

  Future<void> _teardown() async {
    final c = _controller;
    final release = _resolvedRelease;
    _resolvedRelease = null;
    if (c == null) {
      await release?.call();
      return;
    }
    DiagnosticLog.write('video_player', 'teardown_start', {
      ..._controllerFields(c),
    });
    _controller = null;
    c.removeListener(_onValue);
    await c.pause();
    await c.dispose();
    await release?.call();
    _lastVideoError = null;
    _lastEnded = false;
    DiagnosticLog.write('video_player', 'teardown_done');
  }

  void _saveSlot() {
    final item = state.item;
    final c = _controller;
    if (item == null || c == null || !c.value.isInitialized) return;
    unawaited(
      ref
          .read(videoResumeStoreProvider)
          .write(
            _slotFor(
              item,
              positionMs: c.value.position.inMilliseconds,
              lastPlayedAt: DateTime.now(),
            ),
          ),
    );
  }

  void _publish() {
    final c = _controller;
    final item = state.item;
    if (c == null || item == null || !c.value.isInitialized) return;
    final v = c.value;
    NowPlayingBridge.update(
      NowPlayingSnapshot(
        title: item.fileName,
        album: item.sourceName,
        artist: item.sourceName,
        artworkPath: null,
        position: v.position,
        duration: v.duration,
        playing: v.isPlaying,
        speed: v.playbackSpeed,
        hasPrevious: false,
        hasNext: false,
      ),
    );
  }

  Future<void> _handleCommand(NowPlayingCommand command, Object? args) async {
    switch (command) {
      case NowPlayingCommand.play:
        await play();
      case NowPlayingCommand.pause:
        await pause();
      case NowPlayingCommand.seek:
        final map = Map<Object?, Object?>.from(args! as Map);
        await seek(Duration(milliseconds: map['positionMs'] as int));
      case NowPlayingCommand.next:
      case NowPlayingCommand.previous:
        break;
    }
  }

  void _parkPausedVideo(String reason) {
    if (_parking != null) return;
    final c = _controller;
    final item = state.item;
    if (c == null || item == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) return;
    _parking = _parkPausedVideoInner(reason).whenComplete(() {
      _parking = null;
    });
  }

  Future<void> _parkPausedVideoInner(String reason) async {
    final c = _controller;
    final item = state.item;
    if (c == null || item == null || !c.value.isInitialized) return;
    final slot = _slotFor(
      item,
      positionMs: c.value.position.inMilliseconds,
      lastPlayedAt: DateTime.now(),
    );
    DiagnosticLog.write('video_player', 'park_start', {
      'reason': reason,
      ..._videoItemFields(item),
      ..._controllerFields(c),
    });
    final dormant = _rehydrate(slot) ?? _withControllerResolver(item);
    state = VideoPlaybackState(item: dormant, dormant: true);
    await ref.read(videoResumeStoreProvider).write(slot);
    _publishTimer?.cancel();
    _publishTimer = null;
    await _teardown();
    await NowPlayingBridge.clear();
    unawaited(MediaProxy.instance.reset('video_$reason'));
    DiagnosticLog.write('video_player', 'park_done', {
      'reason': reason,
      ..._videoItemFields(dormant),
    });
  }

  Future<void> _reopenCurrent(String reason) async {
    final item = state.item;
    if (item == null) return;
    DiagnosticLog.write('video_player', 'reopen_current', {
      'reason': reason,
      ..._videoItemFields(item),
      ..._stateFields(),
      ..._controllerFields(_controller),
    });
    await open(item);
  }

  bool _isAtEnd(VideoPlayerController controller) {
    final value = controller.value;
    final durationMs = value.duration.inMilliseconds;
    if (durationMs <= 0) return false;
    return value.position.inMilliseconds >= durationMs - 500;
  }

  /// On cold start, surface the last-played video into the mini bar — dormant
  /// (no link resolved) — but only if it was played more recently than the last
  /// library audio (which [PlaybackController] restores otherwise).
  Future<void> _maybeRestoreDormant() async {
    try {
      if (state.hasVideo) return;
      final slot = ref.read(videoResumeStoreProvider).read();
      if (slot == null) return;
      final db = ref.read(databaseProvider);
      final newestWork =
          await (db.select(db.works)
                ..where((w) => w.lastPlayedAt.isNotNull())
                ..where((w) => w.isRemoved.equals(false))
                ..orderBy([(w) => OrderingTerm.desc(w.lastPlayedAt)])
                ..limit(1))
              .getSingleOrNull();
      final audioTime = newestWork?.lastPlayedAt;
      if (audioTime != null && audioTime.isAfter(slot.lastPlayedAt)) return;
      final item = _rehydrate(slot);
      if (item == null || state.hasVideo) return;
      state = VideoPlaybackState(item: item, dormant: true);
    } catch (_) {
      // best effort — no dormant restore
    }
  }

  /// Rebuilds a [PlayableItem] (with a fresh resolver) from a persisted slot.
  PlayableItem? _rehydrate(VideoResumeSlot slot) {
    final RemoteSourceKind kind;
    switch (slot.sourceKind) {
      case 'p115':
        kind = RemoteSourceKind.p115;
      case 'webdav':
        kind = RemoteSourceKind.webdav;
      case 'local':
        kind = RemoteSourceKind.local;
      default:
        return null;
    }
    final resolver = _resolverFor(
      kind: kind,
      sourceId: slot.sourceId,
      path: slot.path,
      pickcode: slot.pickcode,
    );
    return PlayableItem(
      id: slot.id,
      sourceKind: kind,
      sourceId: slot.sourceId,
      sourceName: slot.sourceName,
      path: slot.path,
      fileName: slot.fileName,
      kind: RemoteEntryKind.video,
      size: slot.size,
      pickcode: slot.pickcode,
      resolverSource: 'video_controller_rehydrate',
      resolve: resolver,
    );
  }

  PlayableItem _withControllerResolver(PlayableItem item) {
    final resolver = _resolverFor(
      kind: item.sourceKind,
      sourceId: item.sourceId,
      path: item.path,
      pickcode: item.pickcode,
    );
    return PlayableItem(
      id: item.id,
      sourceKind: item.sourceKind,
      sourceId: item.sourceId,
      sourceName: item.sourceName,
      path: item.path,
      fileName: item.fileName,
      kind: item.kind,
      size: item.size,
      pickcode: item.pickcode,
      resolverSource: item.resolverSource.startsWith('video_controller_')
          ? item.resolverSource
          : 'video_controller_direct',
      title: item.title,
      resolve: resolver,
    );
  }

  PlayableResolver _resolverFor({
    required RemoteSourceKind kind,
    required String sourceId,
    required String path,
    required String? pickcode,
  }) {
    switch (kind) {
      case RemoteSourceKind.p115:
        final pc = pickcode;
        if (pc == null || pc.isEmpty) {
          throw const P115Exception('115 视频缺少 pickcode');
        }
        return () async {
          try {
            return await ref.read(p115ClientProvider).resolveVideoUrl(pc);
          } on P115AuthExpiredException {
            await ref.read(p115AuthServiceProvider).clearCookie();
            ref.invalidate(p115CookieProvider);
            rethrow;
          }
        };
      case RemoteSourceKind.local:
        return () async => ResolvedMediaUrl(url: Uri.file(path));
      case RemoteSourceKind.webdav:
        return () async {
          final config = await _webdavConfigForServer(sourceId);
          if (config == null) throw Exception('WebDAV 服务器配置缺失，无法续播');
          final auth = config.authHeader;
          return ResolvedMediaUrl(
            url: Uri.parse(config.streamUrl(path)),
            headers: auth == null ? null : {'Authorization': auth},
          );
        };
    }
  }

  VideoResumeSlot _slotFor(
    PlayableItem item, {
    required int positionMs,
    required DateTime lastPlayedAt,
  }) {
    return VideoResumeSlot(
      id: item.id,
      sourceKind: item.sourceKind.name,
      sourceId: item.sourceId,
      sourceName: item.sourceName,
      path: item.path,
      fileName: item.fileName,
      size: item.size,
      pickcode: item.pickcode,
      positionMs: positionMs,
      lastPlayedAt: lastPlayedAt,
    );
  }

  Future<WebdavConfig?> _webdavConfigForServer(String serverId) async {
    final db = ref.read(databaseProvider);
    final server = await (db.select(
      db.webdavServers,
    )..where((s) => s.id.equals(serverId))).getSingleOrNull();
    if (server == null) return null;
    final password = await ref
        .read(webdavPasswordStoreProvider)
        .read(server.id);
    return WebdavConfig(
      scheme: server.scheme,
      host: server.host,
      port: server.port,
      basePath: server.basePath,
      username: server.username,
      password: password,
    );
  }

  Map<String, Object?> _stateFields() {
    return {
      'stateHasItem': state.item != null,
      'stateHasController': state.controller != null,
      'stateDormant': state.dormant,
      'stateHasError': state.error != null,
    };
  }
}

final videoControllerProvider =
    NotifierProvider<VideoController, VideoPlaybackState>(VideoController.new);

Map<String, Object?> _videoItemFields(PlayableItem item) {
  return {
    'itemId': item.id,
    'sourceKind': item.sourceKind.name,
    'sourceId': item.sourceId,
    'extension': _fileExtension(item.fileName),
    'size': item.size,
    'hasPickcode': item.pickcode != null,
    'pickcodeTail': item.pickcode == null ? null : _tail(item.pickcode!),
    'resolverSource': item.resolverSource,
  };
}

Map<String, Object?> _controllerFields(VideoPlayerController? controller) {
  if (controller == null) {
    return const {'hasController': false};
  }
  final value = controller.value;
  return {
    'hasController': true,
    'isInitialized': value.isInitialized,
    'isPlaying': value.isPlaying,
    'isBuffering': value.isBuffering,
    'positionMs': value.position.inMilliseconds,
    'durationMs': value.duration.inMilliseconds,
    'playbackSpeed': value.playbackSpeed,
    'hasError': value.hasError,
    'errorDescription': value.errorDescription,
    'width': value.size.width,
    'height': value.size.height,
  };
}

String _fileExtension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}

String _tail(String value) {
  if (value.length <= 6) return value;
  return value.substring(value.length - 6);
}
