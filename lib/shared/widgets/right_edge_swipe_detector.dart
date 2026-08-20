import 'package:flutter/material.dart';

class RightEdgeSwipeDetector extends StatefulWidget {
  const RightEdgeSwipeDetector({
    super.key,
    required this.onSwipe,
    required this.child,
  });

  final VoidCallback? onSwipe;
  final Widget child;

  @override
  State<RightEdgeSwipeDetector> createState() => _RightEdgeSwipeDetectorState();
}

class _RightEdgeSwipeDetectorState extends State<RightEdgeSwipeDetector> {
  static const _edgeWidth = 24.0;
  static const _minimumDistance = 72.0;

  final _activePointers = <int>{};
  int? _trackedPointer;
  Offset? _start;

  @override
  Widget build(BuildContext context) {
    if (widget.onSwipe == null) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    if (_activePointers.length > 1) {
      _trackedPointer = null;
      _start = null;
      return;
    }
    final width = MediaQuery.sizeOf(context).width;
    if (event.position.dx >= width - _edgeWidth) {
      _trackedPointer = event.pointer;
      _start = event.position;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final start = event.pointer == _trackedPointer ? _start : null;
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) {
      _trackedPointer = null;
      _start = null;
    }
    if (start == null) return;
    final delta = event.position - start;
    if (delta.dx <= -_minimumDistance &&
        delta.dx.abs() > delta.dy.abs() * 1.5) {
      widget.onSwipe!();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) {
      _trackedPointer = null;
      _start = null;
    }
  }
}
