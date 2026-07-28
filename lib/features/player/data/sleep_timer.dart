import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../video/data/video_controller.dart';
import 'playback_controller.dart';

class SleepTimerState {
  const SleepTimerState({this.remaining, this.stopAfterTrack = false});

  final Duration? remaining;
  final bool stopAfterTrack;

  bool get isActive => remaining != null || stopAfterTrack;
}

/// Counts down and pauses playback, or stops after the current track ends.
/// Tick-decremented rather than wall-clock-anchored on purpose: while audio
/// plays in the background iOS keeps the isolate alive (same as the
/// controller's 5s position timer), and once playback is paused and the app
/// suspends, a sleep timer has nothing left to do.
class SleepTimerController extends Notifier<SleepTimerState> {
  static const presetMinutes = [15, 30, 45, 60, 90];
  static const fadeSeconds = 10;

  Timer? _tick;
  double? _fadeBaseVolume;

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

  void enableStopAfterTrack() {
    _reset();
    state = const SleepTimerState(stopAfterTrack: true);
  }

  void cancel() {
    _reset();
    state = const SleepTimerState();
  }

  /// Consumed by PlaybackController on track completion; true means "stop
  /// now" and clears the flag.
  bool consumeStopAfterTrack() {
    if (!state.stopAfterTrack) return false;
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
    if (next.inSeconds <= fadeSeconds) {
      final player = ref.read(playbackControllerProvider.notifier).player;
      _fadeBaseVolume ??= player.volume;
      player.setVolume(_fadeBaseVolume! * next.inSeconds / fadeSeconds);
    }
  }

  Future<void> _fire() async {
    _tick?.cancel();
    _tick = null;
    state = const SleepTimerState();
    await ref.read(playbackControllerProvider.notifier).pause();
    if (ref.read(videoControllerProvider).hasVideo) {
      await ref.read(videoControllerProvider.notifier).pause();
    }
    _restoreVolume();
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
    ref.read(playbackControllerProvider.notifier).player.setVolume(base);
  }
}

final sleepTimerProvider =
    NotifierProvider<SleepTimerController, SleepTimerState>(
      SleepTimerController.new,
    );
