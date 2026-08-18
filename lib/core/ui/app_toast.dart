import 'dart:async';

import 'package:flutter/material.dart';

class _ToastData {
  _ToastData(this.message, this.duration) : seq = ++_seq;
  final String message;
  final Duration duration;
  final int seq;
  static int _seq = 0;
}

final ValueNotifier<_ToastData?> _current = ValueNotifier(null);

/// App-wide notification pill, shown from the top, auto-dismissed, and
/// dismissable early with an upward swipe.
/// Replaces Material SnackBars: never covers the tab bar, matches the app's
/// iOS look, and needs no BuildContext (works from controllers too).
void showAppToast(String message, {Duration? duration}) {
  _current.value = _ToastData(
    message,
    duration ??
        (message.length > 30
            ? const Duration(milliseconds: 4500)
            : const Duration(milliseconds: 2500)),
  );
}

/// Mounted once above the Navigator in the app builder Stack.
class AppToastHost extends StatelessWidget {
  const AppToastHost({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_ToastData?>(
      valueListenable: _current,
      builder: (context, data, _) {
        if (data == null) return const SizedBox.shrink();
        // Keyed by seq so a new toast restarts the animation from the top.
        return _ToastView(key: ValueKey(data.seq), data: data);
      },
    );
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({super.key, required this.data});

  final _ToastData data;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _controller.forward();
    _dismissTimer = Timer(widget.data.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    _dismissTimer = null;
    await _controller.reverse();
    if (_current.value?.seq == widget.data.seq) _current.value = null;
  }

  /// Swipe-up dismissal; the pending auto-dismiss timer doubles as the
  /// "not already dismissing" guard.
  void _dismissEarly() {
    final timer = _dismissTimer;
    if (timer == null) return;
    timer.cancel();
    _dismiss();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    // Only the pill itself is hit-testable; taps elsewhere pass through to
    // the app as before.
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1.6),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) {
                  if (details.delta.dy < 0) _dismissEarly();
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xE61C1C1E),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    child: Text(
                      widget.data.message,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.35,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
