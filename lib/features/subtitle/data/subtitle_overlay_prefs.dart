import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/shared_prefs_provider.dart';

/// Three-state cycle the user picks from the captions button. Each step is a
/// distinct rendering target; only one is active at a time.
enum SubtitleMode {
  /// Subtitle hidden.
  off,

  /// In-app floating bar drawn by [SubtitleOverlay].
  appLevel,

  /// iOS-native Picture-in-Picture window driven by the platform plugin.
  pip;

  SubtitleMode get next => switch (this) {
        SubtitleMode.off => SubtitleMode.appLevel,
        SubtitleMode.appLevel => SubtitleMode.pip,
        SubtitleMode.pip => SubtitleMode.off,
      };

  String get label => switch (this) {
        SubtitleMode.off => '字幕关闭',
        SubtitleMode.appLevel => '应用级字幕',
        SubtitleMode.pip => '系统级 PiP 字幕',
      };
}

class SubtitleOverlayPrefs {
  const SubtitleOverlayPrefs({
    required this.mode,
    required this.dx,
    required this.dy,
  });

  final SubtitleMode mode;

  /// Absolute pixel offset from screen top-left of the overlay's top-left.
  /// Null means "use default position" (computed at layout time). Only used
  /// in [SubtitleMode.appLevel].
  final double? dx;
  final double? dy;

  SubtitleOverlayPrefs copyWith({
    SubtitleMode? mode,
    double? dx,
    double? dy,
    bool resetPosition = false,
  }) {
    return SubtitleOverlayPrefs(
      mode: mode ?? this.mode,
      dx: resetPosition ? null : (dx ?? this.dx),
      dy: resetPosition ? null : (dy ?? this.dy),
    );
  }

  static const defaults = SubtitleOverlayPrefs(
    mode: SubtitleMode.appLevel,
    dx: null,
    dy: null,
  );
}

class SubtitleOverlayPrefsNotifier extends Notifier<SubtitleOverlayPrefs> {
  static const _kMode = 'subtitle.overlay.mode';
  static const _kLegacyEnabled = 'subtitle.overlay.enabled';
  static const _kDx = 'subtitle.overlay.dx';
  static const _kDy = 'subtitle.overlay.dy';

  @override
  SubtitleOverlayPrefs build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return SubtitleOverlayPrefs(
      mode: _readMode(prefs.getString(_kMode), prefs.getBool(_kLegacyEnabled)),
      dx: prefs.getDouble(_kDx),
      dy: prefs.getDouble(_kDy),
    );
  }

  static SubtitleMode _readMode(String? raw, bool? legacyEnabled) {
    if (raw != null) {
      for (final m in SubtitleMode.values) {
        if (m.name == raw) return m;
      }
    }
    if (legacyEnabled != null) {
      return legacyEnabled ? SubtitleMode.appLevel : SubtitleMode.off;
    }
    return SubtitleOverlayPrefs.defaults.mode;
  }

  Future<void> setMode(SubtitleMode mode) async {
    state = state.copyWith(mode: mode);
    await ref.read(sharedPreferencesProvider).setString(_kMode, mode.name);
  }

  /// Cycle: off → appLevel → pip → off.
  Future<SubtitleMode> cycle() async {
    final next = state.mode.next;
    await setMode(next);
    return next;
  }

  /// Persists [position] (top-left of the overlay box in screen coords).
  /// Clamping to screen bounds is the widget's responsibility.
  Future<void> setPosition(Offset position) async {
    state = state.copyWith(dx: position.dx, dy: position.dy);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble(_kDx, position.dx);
    await prefs.setDouble(_kDy, position.dy);
  }

  Future<void> resetPosition() async {
    state = state.copyWith(resetPosition: true);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_kDx);
    await prefs.remove(_kDy);
  }
}

final subtitleOverlayPrefsProvider =
    NotifierProvider<SubtitleOverlayPrefsNotifier, SubtitleOverlayPrefs>(
  SubtitleOverlayPrefsNotifier.new,
);
