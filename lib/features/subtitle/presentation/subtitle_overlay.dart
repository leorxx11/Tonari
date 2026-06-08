import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/subtitle_overlay_prefs.dart';
import '../data/subtitle_providers.dart';

/// Always-on overlay that renders the active subtitle cue above every page.
/// Hidden when no track is playing, no subtitle is loaded, the current cue is
/// in a gap, or the user has toggled it off.
class SubtitleOverlay extends ConsumerStatefulWidget {
  const SubtitleOverlay({super.key});

  @override
  ConsumerState<SubtitleOverlay> createState() => _SubtitleOverlayState();
}

class _SubtitleOverlayState extends ConsumerState<SubtitleOverlay> {
  double? _dragDy;

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(subtitleOverlayPrefsProvider);
    if (prefs.mode != SubtitleMode.appLevel) return const SizedBox.shrink();

    final loaded = ref.watch(currentSubtitleProvider).value;
    final lineIdx = ref.watch(currentSubtitleLineProvider).value ?? -1;
    if (loaded == null || lineIdx < 0 || lineIdx >= loaded.cues.length) {
      return const SizedBox.shrink();
    }
    final text = loaded.cues[lineIdx].text;

    final mq = MediaQuery.of(context);
    final size = mq.size;
    // Default: above the mini player + nav bar.
    final defaultDy = size.height - mq.padding.bottom - 200.0;
    final dy = _dragDy ?? prefs.dy ?? defaultDy;

    return Positioned(
      left: 0,
      right: 0,
      top: dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) {
          final newDy = ((_dragDy ?? dy) + d.delta.dy).clamp(
            mq.padding.top + 12.0,
            size.height - 80.0,
          );
          setState(() => _dragDy = newDy);
        },
        onPanEnd: (_) async {
          final newDy = _dragDy;
          if (newDy != null) {
            await ref
                .read(subtitleOverlayPrefsProvider.notifier)
                .setPosition(Offset(0, newDy));
            if (mounted) setState(() => _dragDy = null);
          }
        },
        onLongPress: () => _showMenu(context),
        child: _SubtitleBar(text: text),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context) async {
    final controller = ref.read(subtitleControllerProvider);
    final overlayPrefs = ref.read(subtitleOverlayPrefsProvider.notifier);
    final loaded = ref.read(currentSubtitleProvider).value;
    final offsetMs = loaded?.timeOffsetMs ?? 0;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    '字幕偏移 ${_formatOffset(offsetMs)}',
                    style: Theme.of(sheetCtx).textTheme.titleSmall,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(CupertinoIcons.minus),
                        label: const Text('字幕慢 0.1s'),
                        onPressed: () => controller.adjustOffset(-100),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(CupertinoIcons.add),
                        label: const Text('字幕快 0.1s'),
                        onPressed: () => controller.adjustOffset(100),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: offsetMs == 0
                      ? null
                      : () {
                          controller.resetOffset();
                        },
                  child: const Text('重置偏移'),
                ),
                const Divider(height: 24),
                TextButton.icon(
                  icon: const Icon(CupertinoIcons.location_circle),
                  label: const Text('恢复默认位置'),
                  onPressed: () {
                    overlayPrefs.resetPosition();
                    Navigator.of(sheetCtx).pop();
                  },
                ),
                TextButton.icon(
                  icon: const Icon(CupertinoIcons.eye_slash),
                  label: const Text('关闭悬浮字幕'),
                  onPressed: () {
                    overlayPrefs.setMode(SubtitleMode.off);
                    Navigator.of(sheetCtx).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _formatOffset(int ms) {
    final sign = ms >= 0 ? '+' : '-';
    final absMs = ms.abs();
    final s = (absMs / 1000).toStringAsFixed(1);
    return '$sign${s}s';
  }
}

class _SubtitleBar extends StatelessWidget {
  const _SubtitleBar({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // decoration: none is required because the overlay is rendered
    // outside any Material ancestor (Stack child of MaterialApp.builder),
    // where Flutter falls back to the debug "yellow double underline".
    return ClipRect(
      child: BackdropFilter(
        // sigma ~8 matches iOS .systemUltraThinMaterial — soft enough to add
        // a frosted feel while keeping the page underneath legible.
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF9123A7),
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.35,
              decoration: TextDecoration.none,
              shadows: [
                Shadow(color: Color(0x99FFFFFF), blurRadius: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
