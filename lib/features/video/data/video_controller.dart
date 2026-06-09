import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../browse/data/remote_models.dart';
import '../../player/data/now_playing_bridge.dart';
import '../../player/data/playback_controller.dart';

/// App-lifetime owner of the video player, mirroring [PlaybackController] for
/// audio. Lives outside the video page so minimizing (popping the page) keeps
/// the video playing, a mini player can represent it, and the lock screen /
/// Control Center can drive it through the shared [NowPlayingBridge].
class VideoPlaybackState {
  const VideoPlaybackState({this.item, this.controller, this.error});

  final PlayableItem? item;
  final VideoPlayerController? controller;
  final Object? error;

  bool get hasVideo => item != null;
  bool get isReady => controller != null && controller!.value.isInitialized;
}

class VideoController extends Notifier<VideoPlaybackState> {
  Timer? _publishTimer;
  VideoPlayerController? _controller;

  @override
  VideoPlaybackState build() {
    ref.onDispose(() {
      _publishTimer?.cancel();
      // Don't read `state` inside onDispose (Riverpod forbids it); use the
      // private handle instead.
      _controller?.removeListener(_onValue);
      _controller?.dispose();
    });
    return const VideoPlaybackState();
  }

  /// Loads and plays [item], tearing down any previous video and stopping audio
  /// so only one source ever makes sound.
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
        // on backgrounding (and we'd have to tap to resume). We want audio to
        // keep playing in the background like the audio player does.
        videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
      );
      await controller.initialize();
      controller.addListener(_onValue);
      await controller.play();
      _controller = controller;
      state = VideoPlaybackState(item: item, controller: controller);
      NowPlayingBridge.setCommandHandler(_handleCommand);
      _publish();
      _publishTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _publish(),
      );
    } catch (e) {
      state = VideoPlaybackState(item: item, error: e);
    }
  }

  Future<void> play() async {
    await state.controller?.play();
    _publish();
  }

  Future<void> pause() async {
    await state.controller?.pause();
    _publish();
  }

  Future<void> seek(Duration position) async {
    await state.controller?.seekTo(position);
    _publish();
  }

  Future<void> setSpeed(double speed) async {
    await state.controller?.setPlaybackSpeed(speed);
    _publish();
  }

  Future<void> stop() async {
    if (state.controller == null && state.item == null) return;
    _publishTimer?.cancel();
    _publishTimer = null;
    await _teardown();
    await NowPlayingBridge.clear();
    state = const VideoPlaybackState();
  }

  bool _lastPlaying = false;

  void _onValue() {
    final playing = state.controller?.value.isPlaying ?? false;
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

  void _publish() {
    final c = state.controller;
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
}

final videoControllerProvider =
    NotifierProvider<VideoController, VideoPlaybackState>(VideoController.new);
