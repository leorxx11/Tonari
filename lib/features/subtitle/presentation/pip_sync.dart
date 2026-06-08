import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pip_bridge.dart';
import '../data/subtitle_overlay_prefs.dart';
import '../data/subtitle_providers.dart';

/// Invisible widget that bridges Riverpod state into the native PiP plugin:
///   - When the user cycles into [SubtitleMode.pip], start the PiP window.
///   - While in PiP mode, push every subtitle line change down to native.
///   - When the user cycles out, stop the PiP window.
/// Mounted once at the app root (next to SubtitleOverlay).
class PipSync extends ConsumerStatefulWidget {
  const PipSync({super.key});

  @override
  ConsumerState<PipSync> createState() => _PipSyncState();
}

class _PipSyncState extends ConsumerState<PipSync> {
  String _lastPushedText = '';

  @override
  Widget build(BuildContext context) {
    ref.listen(subtitleOverlayPrefsProvider.select((p) => p.mode), (
      prev,
      next,
    ) {
      if (prev == next) return;
      if (next == SubtitleMode.pip) {
        PipBridge.start();
      } else if (prev == SubtitleMode.pip) {
        PipBridge.stop();
        _lastPushedText = '';
      }
    });

    final mode = ref.watch(subtitleOverlayPrefsProvider.select((p) => p.mode));
    if (mode == SubtitleMode.pip) {
      final loaded = ref.watch(currentSubtitleProvider).value;
      final lineIdx = ref.watch(currentSubtitleLineProvider).value ?? -1;
      final text =
          (loaded != null && lineIdx >= 0 && lineIdx < loaded.cues.length)
          ? loaded.cues[lineIdx].text
          : '';
      if (text != _lastPushedText) {
        _lastPushedText = text;
        // Fire-and-forget on the next microtask so we don't trigger a
        // platform-channel call from inside build.
        Future.microtask(() => PipBridge.update(text));
      }
    }

    return const SizedBox.shrink();
  }
}
