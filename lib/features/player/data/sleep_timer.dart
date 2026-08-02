import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/player_prefs.dart';
import '../../video/data/video_controller.dart';
import 'playback_controller.dart';

class SleepTimerState {
  const SleepTimerState({
    this.remaining,
    this.remainingTracks,
    this.waitingTrackEnd = false,
  });

  /// Countdown left in timed mode.
  final Duration? remaining;

  /// Track-count mode: stop once this many tracks finish (1 = current track).
  final int? remainingTracks;

  /// Countdown hit zero but "finish current track" is on — playback keeps
  /// going until the track ends.
  final bool waitingTrackEnd;

  bool get isActive =>
      remaining != null || remainingTracks != null || waitingTrackEnd;
}

/// Counts down and pauses playback, or stops after N tracks finish.
/// Tick-decremented rather than wall-clock-anchored on purpose: while audio
/// plays in the background iOS keeps the isolate alive (same as the
/// controller's 5s position timer), and once playback is paused and the app
/// suspends, a sleep timer has nothing left to do.
class SleepTimerController extends Notifier<SleepTimerState> {
  static const presetMinutes = [15, 30, 45, 60, 90];
  static const presetTrackCounts = [1, 2, 3, 5];
  static const fadeSeconds = 10;

  Timer? _tick;
  double? _fadeBaseVolume;
  bool _fadeOnVideo = false;

  @override
  SleepTimerState build() {
    ref.onDispose(() => _tick?.cancel());
    return const SleepTimerState();
  }

  void start(Duration duration) {
    _reset();
    state = SleepTimerState(remaining: duration);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void stopAfterTracks(int count) {
    _reset();
    state = SleepTimerState(remainingTracks: count);
  }

  void cancel() {
    _reset();
    state = const SleepTimerState();
  }

  /// Called by the players when a track/video finishes; true means "stop
  /// now". In track-count mode intermediate completions just decrement.
  bool onTrackCompleted() {
    if (state.waitingTrackEnd) {
      state = const SleepTimerState();
      return true;
    }
    final tracks = state.remainingTracks;
    if (tracks == null) return false;
    if (tracks > 1) {
      state = SleepTimerState(remainingTracks: tracks - 1);
      return false;
    }
    state = const SleepTimerState();
    return true;
  }

  void _onTick() {
    final remaining = state.remaining;
    if (remaining == null) return;
    final next = remaining - const Duration(seconds: 1);
    if (next <= Duration.zero) {
      unawaited(_fire());
      return;
    }
    state = SleepTimerState(remaining: next);
    // No fade when the track is allowed to finish — nothing gets cut off.
    if (next.inSeconds <= fadeSeconds &&
        !ref.read(playerPrefsProvider).sleepFinishCurrentTrack) {
      final video = ref.read(videoControllerProvider).controller;
      if (_fadeBaseVolume == null) {
        _fadeOnVideo = video != null;
        _fadeBaseVolume = _fadeOnVideo
            ? video!.value.volume
            : ref.read(playbackControllerProvider.notifier).player.volume;
      }
      final volume = _fadeBaseVolume! * next.inSeconds / fadeSeconds;
      if (_fadeOnVideo) {
        video?.setVolume(volume);
      } else {
        ref.read(playbackControllerProvider.notifier).player.setVolume(volume);
      }
    }
  }

  Future<void> _fire() async {
    _tick?.cancel();
    _tick = null;
    if (ref.read(playerPrefsProvider).sleepFinishCurrentTrack && _isPlaying()) {
      state = const SleepTimerState(waitingTrackEnd: true);
      return;
    }
    state = const SleepTimerState();
    await ref.read(playbackControllerProvider.notifier).pause();
    if (ref.read(videoControllerProvider).hasVideo) {
      await ref.read(videoControllerProvider.notifier).pause();
    }
    _restoreVolume();
  }

  bool _isPlaying() {
    final video = ref.read(videoControllerProvider).controller;
    if (video != null) return video.value.isPlaying;
    return ref.read(playbackControllerProvider.notifier).player.playing;
  }

  void _reset() {
    _tick?.cancel();
    _tick = null;
    _restoreVolume();
  }

  void _restoreVolume() {
    final base = _fadeBaseVolume;
    _fadeBaseVolume = null;
    if (base == null) return;
    if (_fadeOnVideo) {
      ref.read(videoControllerProvider).controller?.setVolume(base);
    } else {
      ref.read(playbackControllerProvider.notifier).player.setVolume(base);
    }
  }
}

final sleepTimerProvider =
    NotifierProvider<SleepTimerController, SleepTimerState>(
      SleepTimerController.new,
    );
