import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';

class RightEdgeSwipeDetector extends StatefulWidget {
  const RightEdgeSwipeDetector({
    super.key,
    required this.pageBuilder,
    required this.child,
    this.onNavigationCommitted,
  });

  final WidgetBuilder? pageBuilder;
  final Widget child;
  final VoidCallback? onNavigationCommitted;

  @override
  State<RightEdgeSwipeDetector> createState() => _RightEdgeSwipeDetectorState();
}

class _RightEdgeSwipeDetectorState extends State<RightEdgeSwipeDetector>
    with SingleTickerProviderStateMixin {
  static const _edgeWidth = 24.0;
  static const _minimumCommitDistance = 72.0;
  static const _settleDuration = Duration(milliseconds: 350);

  late final HorizontalDragGestureRecognizer _recognizer;
  late final AnimationController _controller;
  WidgetBuilder? _destinationBuilder;
  bool _settling = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _settleDuration);
    _recognizer = HorizontalDragGestureRecognizer(debugOwner: this)
      ..dragStartBehavior = DragStartBehavior.down
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..onCancel = _handleDragCancel;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pageBuilder == null) return widget.child;
    final dragAreaWidth = MediaQuery.paddingOf(context).right;
    final destination = _destinationBuilder?.call(context);
    return AnimatedBuilder(
      animation: _controller,
      child: destination,
      builder: (context, destination) => Stack(
        fit: StackFit.passthrough,
        children: [
          FractionalTranslation(
            translation: Offset(-_controller.value / 3, 0),
            transformHitTests: false,
            child: widget.child,
          ),
          if (destination != null)
            Positioned.fill(
              child: IgnorePointer(
                child: FractionalTranslation(
                  translation: Offset(1 - _controller.value, 0),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 12,
                          offset: Offset(-3, 0),
                        ),
                      ],
                    ),
                    child: destination,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: dragAreaWidth > _edgeWidth ? dragAreaWidth : _edgeWidth,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                if (!_settling) _recognizer.addPointer(event);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handleDragStart(DragStartDetails details) {
    _controller.value = 0;
    setState(() => _destinationBuilder = widget.pageBuilder!);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _controller.value =
        (_controller.value - details.primaryDelta! / context.size!.width).clamp(
          0.0,
          1.0,
        );
  }

  void _handleDragEnd(DragEndDetails details) {
    _finishDrag(-details.velocity.pixelsPerSecond.dx / context.size!.width);
  }

  void _handleDragCancel() {
    if (_destinationBuilder != null) _finishDrag(0);
  }

  void _finishDrag(double velocity) {
    const minimumFlingVelocity = 1.0;
    final committed = velocity.abs() >= minimumFlingVelocity
        ? velocity > 0
        : _controller.value * context.size!.width >= _minimumCommitDistance;
    _settling = true;
    if (committed) {
      widget.onNavigationCommitted?.call();
      _controller
          .animateTo(
            1,
            duration: _settleDuration,
            curve: Curves.fastEaseInToSlowEaseOut,
          )
          .then((_) {
            final builder = _destinationBuilder!;
            Navigator.of(
              context,
              rootNavigator: true,
            ).push(_CompletedCupertinoPageRoute(builder: builder));
            _clearDestination();
          });
    } else {
      _controller
          .animateBack(
            0,
            duration: _settleDuration,
            curve: Curves.fastEaseInToSlowEaseOut,
          )
          .then((_) => _clearDestination());
    }
  }

  void _clearDestination() {
    _controller.value = 0;
    _settling = false;
    setState(() => _destinationBuilder = null);
  }
}

class _CompletedCupertinoPageRoute extends CupertinoPageRoute<void> {
  _CompletedCupertinoPageRoute({required super.builder});

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 350);
}
