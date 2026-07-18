import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pip_bridge.dart';
import '../data/subtitle_overlay_prefs.dart';
import '../data/subtitle_providers.dart';

/// Text the PiP window should currently show ('' = blank). Only subscribes to
/// the subtitle streams while PiP mode is active.
final _pipSubtitleTextProvider = Provider.autoDispose<String>((ref) {
  final mode = ref.watch(subtitleOverlayPrefsProvider.select((p) => p.mode));
  if (mode != SubtitleMode.pip) return '';
  final loaded = ref.watch(currentSubtitleProvider).value;
  final lineIdx = ref.watch(currentSubtitleLineProvider).value ?? -1;
  if (loaded == null || lineIdx < 0 || lineIdx >= loaded.cues.length) {
    return '';
  }
  return loaded.cues[lineIdx].text;
});

/// Bridges subtitle state into the native PiP plugin. Runs through provider
/// listeners rather than widget rebuilds so cue updates keep flowing while the
/// app is backgrounded: iOS suspends vsync/frames in the background (freezing
/// widget builds), but the provider graph keeps updating off the position
/// stream, which is what PiP mode exists to survive.
final pipSubtitleSyncProvider = Provider.autoDispose<void>((ref) {
  ref.listen<SubtitleMode>(
    subtitleOverlayPrefsProvider.select((p) => p.mode),
    (prev, next) {
      if (prev == next) return;
      if (next == SubtitleMode.pip) {
        PipBridge.start();
      } else if (prev == SubtitleMode.pip) {
        PipBridge.stop();
      }
    },
  );

  ref.listen<String>(_pipSubtitleTextProvider, (prev, next) {
    if (prev == next) return;
    PipBridge.update(next);
  });
});

/// Invisible root-mounted widget whose only job is to keep
/// [pipSubtitleSyncProvider] alive for the app's lifetime.
class PipSync extends ConsumerWidget {
  const PipSync({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pipSubtitleSyncProvider);
    return const SizedBox.shrink();
  }
}
