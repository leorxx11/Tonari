import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/shared_prefs_provider.dart';

enum PlaybackMode {
  sequence,   // 顺序播放：到末尾停
  loopAll,    // 列表循环：到末尾回 0
  loopOne,    // 单曲循环：自动播完后重复本曲
  shuffle,    // 随机播放：自动播完后随机选一首
}

extension PlaybackModeLabel on PlaybackMode {
  String get label => switch (this) {
        PlaybackMode.sequence => '顺序播放',
        PlaybackMode.loopAll => '列表循环',
        PlaybackMode.loopOne => '单曲循环',
        PlaybackMode.shuffle => '随机播放',
      };

  PlaybackMode get nextInCycle {
    const order = PlaybackMode.values;
    return order[(index + 1) % order.length];
  }
}

class PlayerPrefs {
  const PlayerPrefs({
    required this.seekStepSeconds,
    required this.playbackMode,
  });

  final int seekStepSeconds;
  final PlaybackMode playbackMode;

  PlayerPrefs copyWith({
    int? seekStepSeconds,
    PlaybackMode? playbackMode,
  }) {
    return PlayerPrefs(
      seekStepSeconds: seekStepSeconds ?? this.seekStepSeconds,
      playbackMode: playbackMode ?? this.playbackMode,
    );
  }

  static const defaults = PlayerPrefs(
    seekStepSeconds: 15,
    playbackMode: PlaybackMode.sequence,
  );

  /// Tap-to-pick presets shown in settings. Custom values outside this
  /// list are still accepted via [PlayerPrefsNotifier.setSeekStep].
  static const presetSteps = <int>[5, 10, 15, 30, 60];
}

class PlayerPrefsNotifier extends Notifier<PlayerPrefs> {
  static const _kSeekStep = 'player.seekStepSeconds';
  static const _kPlaybackMode = 'player.playbackMode';

  @override
  PlayerPrefs build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return PlayerPrefs(
      seekStepSeconds:
          prefs.getInt(_kSeekStep) ?? PlayerPrefs.defaults.seekStepSeconds,
      playbackMode: _decodeMode(prefs.getString(_kPlaybackMode)),
    );
  }

  Future<void> setSeekStep(int seconds) async {
    final clamped = seconds.clamp(1, 600);
    state = state.copyWith(seekStepSeconds: clamped);
    await ref.read(sharedPreferencesProvider).setInt(_kSeekStep, clamped);
  }

  Future<PlaybackMode> cyclePlaybackMode() async {
    final next = state.playbackMode.nextInCycle;
    state = state.copyWith(playbackMode: next);
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kPlaybackMode, next.name);
    return next;
  }

  static PlaybackMode _decodeMode(String? raw) {
    if (raw == null) return PlayerPrefs.defaults.playbackMode;
    return PlaybackMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => PlayerPrefs.defaults.playbackMode,
    );
  }
}

final playerPrefsProvider = NotifierProvider<PlayerPrefsNotifier, PlayerPrefs>(
  PlayerPrefsNotifier.new,
);
