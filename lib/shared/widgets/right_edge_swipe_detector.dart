import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// UIKit owns the edge gesture because pushing a Flutter route cancels active
/// Flutter pointers. The destination is a single route throughout the gesture.
class ForwardNavigationObserver extends NavigatorObserver {
  ForwardNavigationObserver() {
    _channel.setMethodCallHandler(_handleGesture);
  }

  static const _channel = MethodChannel('tonari/forward_navigation');
  final _pages = <ModalRoute<dynamic>, _RightEdgeSwipeDetectorState>{};
  Route<dynamic>? _topRoute;
  _InteractiveForwardRoute? _interactiveRoute;
  VoidCallback? _onCommitted;
  bool _settling = false;

  void dispose() {
    _channel.setMethodCallHandler(null);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _channel.invokeMethod<void>('setEnabled', false);
    }
  }

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    _topRoute = topRoute;
    _syncEnabled();
  }

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    _syncEnabled();
  }

  @override
  void didStopUserGesture() {
    _syncEnabled();
  }

  void _syncEnabled() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _channel.invokeMethod<void>('setEnabled', _canBegin);
    }
  }

  bool get _canBegin =>
      _interactiveRoute == null &&
      !(navigator?.userGestureInProgress ?? false) &&
      _topRoute is PageRoute &&
      !_topRoute!.willHandlePopInternally &&
      (_topRoute! as PageRoute).animation!.isCompleted &&
      _pages[_topRoute]?.widget.pageBuilder != null;

  Future<void> _handleGesture(MethodCall call) async {
    final args = call.arguments as Map<Object?, Object?>;
    switch (call.method) {
      case 'began':
        if (!_canBegin) return;
        final page = _pages[_topRoute]!;
        final route = _InteractiveForwardRoute(
          builder: page.widget.pageBuilder!,
        );
        _interactiveRoute = route;
        _onCommitted = page.widget.onNavigationCommitted;
        navigator!.didStartUserGesture();
        navigator!.push(route);
        route.progress = (args['progress']! as num).toDouble();
        _syncEnabled();
      case 'changed':
        if (_interactiveRoute == null || _settling) return;
        _interactiveRoute!.progress = (args['progress']! as num).toDouble();
      case 'ended':
      case 'cancelled':
        if (_interactiveRoute == null || _settling) return;
        final route = _interactiveRoute!;
        route.progress = (args['progress']! as num).toDouble();
        final velocity = (args['velocity']! as num).toDouble();
        final distance = (args['distance']! as num).toDouble();
        final committed =
            call.method == 'ended' &&
            (velocity.abs() >= 1 ? velocity > 0 : distance >= 72);
        _settling = true;
        if (committed) _onCommitted?.call();
        final owner = navigator!;
        if (!committed) owner.pop();
        await route.settle(committed);
        if (!owner.mounted) return;
        owner.didStopUserGesture();
        _interactiveRoute = null;
        _onCommitted = null;
        _settling = false;
        _syncEnabled();
    }
  }
}

class ForwardNavigationScope extends InheritedWidget {
  const ForwardNavigationScope({
    super.key,
    required this.observer,
    required super.child,
  });

  final ForwardNavigationObserver observer;

  @override
  bool updateShouldNotify(ForwardNavigationScope oldWidget) =>
      observer != oldWidget.observer;
}

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

class _RightEdgeSwipeDetectorState extends State<RightEdgeSwipeDetector> {
  late ForwardNavigationObserver _observer;
  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route?.animation!.removeStatusListener(_animationChanged);
    _observer = context
        .dependOnInheritedWidgetOfExactType<ForwardNavigationScope>()!
        .observer;
    _route = ModalRoute.of(context)!;
    _observer._pages[_route!] = this;
    _observer._syncEnabled();
    _route!.animation!.addStatusListener(_animationChanged);
  }

  void _animationChanged(AnimationStatus status) => _observer._syncEnabled();

  @override
  void didUpdateWidget(RightEdgeSwipeDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    _observer._syncEnabled();
  }

  @override
  void dispose() {
    _route!.animation!.removeStatusListener(_animationChanged);
    _observer._pages.remove(_route);
    _observer._syncEnabled();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _InteractiveForwardRoute extends MaterialPageRoute<void> {
  _InteractiveForwardRoute({required super.builder});

  @override
  TickerFuture didPush() {
    final ticker = super.didPush();
    controller!.stop(canceled: false);
    return ticker;
  }

  set progress(double value) => controller!.value = value.clamp(0.0, 1.0);

  Future<void> settle(bool committed) {
    final remaining = committed ? 1 - controller!.value : controller!.value;
    final duration = Duration(milliseconds: (350 * remaining).round());
    return committed
        ? controller!.animateTo(1, duration: duration, curve: Curves.easeOut)
        : controller!.animateBack(0, duration: duration, curve: Curves.easeOut);
  }
}
