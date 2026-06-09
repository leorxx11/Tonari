import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/db/providers.dart';
import '../../browse/data/remote_models.dart';
import '../../p115/data/p115_client.dart';
import '../../player/data/now_playing_bridge.dart';
import '../../player/data/playback_controller.dart';
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

class VideoController extends Notifier<VideoPlaybackState> {
  Timer? _publishTimer;
  VideoPlayerController? _controller;
  bool _lastPlaying = false;

  @override
  VideoPlaybackState build() {
    ref.onDispose(() {
      _publishTimer?.cancel();
      // Don't read `state` inside onDispose (Riverpod forbids it); use the
      // private handle instead.
      _controller?.removeListener(_onValue);
      _controller?.dispose();
    });
    Future.microtask(_maybeRestoreDormant);
    return const VideoPlaybackState();
  }

  /// Loads and plays [item], stopping audio so only one source makes sound, and
  /// resuming from the saved position if this is the remembered video.
  Future<void> open(PlayableItem item) async {
    await ref.read(playbackControllerProvider.notifier).stop();
    await _teardown();
    state = VideoPlaybackState(item: item);
    try {
      final resolved = await item.resolve();
      final controller = VideoPlayerController.networkUrl(
        resolved.url,
        httpHeaders: resolved.headers ?? const <String, String>{},
        // Without this, video_player installs a lifecycle observer that pauses
        // on backgrounding. We want audio to keep playing in the background.
        videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
      );
      await controller.initialize();
      _resumeFromSlot(controller, item);
      controller.addListener(_onValue);
      await controller.play();
      _controller = controller;
      state = VideoPlaybackState(item: item, controller: controller);
      NowPlayingBridge.setCommandHandler(_handleCommand);
      _publish();
      _saveSlot();
      _publishTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _publish();
        _saveSlot();
      });
    } catch (e) {
      state = VideoPlaybackState(item: item, error: e);
    }
  }

  /// Loads the dormant (remembered) video — invoked by the mini bar play button.
  Future<void> resume() async {
    final item = state.item;
    if (item != null && _controller == null) await open(item);
  }

  Future<void> play() async {
    await _controller?.play();
    _publish();
    _saveSlot();
  }

  Future<void> pause() async {
    await _controller?.pause();
    _publish();
    _saveSlot();
  }

  Future<void> seek(Duration position) async {
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
    _publishTimer?.cancel();
    _publishTimer = null;
    _saveSlot();
    await _teardown();
    await NowPlayingBridge.clear();
    state = const VideoPlaybackState();
  }

  void _resumeFromSlot(VideoPlayerController controller, PlayableItem item) {
    final slot = ref.read(videoResumeStoreProvider).read();
    if (slot == null || slot.id != item.id) return;
    final pos = slot.positionMs;
    final dur = controller.value.duration.inMilliseconds;
    if (pos > 3000 && (dur == 0 || pos < dur - 3000)) {
      controller.seekTo(Duration(milliseconds: pos));
    }
  }

  void _onValue() {
    final playing = _controller?.value.isPlaying ?? false;
    if (playing != _lastPlaying) {
      _lastPlaying = playing;
      _publish();
    }
  }

  Future<void> _teardown() async {
    final c = _controller;
    if (c == null) return;
    _controller = null;
    c.removeListener(_onValue);
    await c.pause();
    await c.dispose();
  }

  void _saveSlot() {
    final item = state.item;
    final c = _controller;
    if (item == null || c == null || !c.value.isInitialized) return;
    unawaited(
      ref
          .read(videoResumeStoreProvider)
          .write(
            VideoResumeSlot(
              id: item.id,
              sourceKind: item.sourceKind.name,
              sourceId: item.sourceId,
              sourceName: item.sourceName,
              path: item.path,
              fileName: item.fileName,
              size: item.size,
              pickcode: item.pickcode,
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
      default:
        return null;
    }
    final PlayableResolver resolver;
    switch (kind) {
      case RemoteSourceKind.p115:
        final pc = slot.pickcode;
        if (pc == null) return null;
        resolver = () => ref.read(p115ClientProvider).resolveDownloadUrl(pc);
      case RemoteSourceKind.webdav:
        resolver = () async {
          final config = await _webdavConfigForServer(slot.sourceId);
          if (config == null) throw Exception('WebDAV 服务器配置缺失，无法续播');
          final auth = config.authHeader;
          return ResolvedMediaUrl(
            url: Uri.parse(config.streamUrl(slot.path)),
            headers: auth == null ? null : {'Authorization': auth},
          );
        };
    }
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
      resolve: resolver,
    );
  }

  Future<WebdavConfig?> _webdavConfigForServer(String serverId) async {
    final db = ref.read(databaseProvider);
    final server = await (db.select(
      db.webdavServers,
    )..where((s) => s.id.equals(serverId))).getSingleOrNull();
    if (server == null) return null;
    final password = await ref.read(webdavPasswordStoreProvider).read(server.id);
    return WebdavConfig(
      scheme: server.scheme,
      host: server.host,
      port: server.port,
      basePath: server.basePath,
      username: server.username,
      password: password,
    );
  }
}

final videoControllerProvider =
    NotifierProvider<VideoController, VideoPlaybackState>(VideoController.new);
