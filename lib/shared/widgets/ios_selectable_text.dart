import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IosSelectableText extends StatefulWidget {
  const IosSelectableText(
    this.data, {
    super.key,
    required this.style,
    this.textAlign,
  });

  final String data;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  State<IosSelectableText> createState() => _IosSelectableTextState();
}

class _IosSelectableTextState extends State<IosSelectableText> {
  static const _viewType = 'tonari/ios_selectable_text';
  static const _channelPrefix = 'tonari/ios_selectable_text';
  static const _selectionHandleRadius = 28.0;

  bool _selectionActive = false;
  bool _pointerDown = false;
  bool? _pendingSelectionActive;
  Offset? _selectionStart;
  Offset? _selectionEnd;
  PointerDownEvent? _outsidePointerDown;
  MethodChannel? _channel;
  final _gestureRegionKey = GlobalKey();

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return SelectableText(
        widget.data,
        style: widget.style,
        textAlign: widget.textAlign,
      );
    }

    final defaultTextStyle = DefaultTextStyle.of(context);
    final resolvedStyle = defaultTextStyle.style.merge(widget.style);
    final textScaler = MediaQuery.textScalerOf(context);
    final fontSize = textScaler.scale(resolvedStyle.fontSize!);
    final fontWeight = resolvedStyle.fontWeight ?? FontWeight.normal;
    final color = resolvedStyle.color!;
    final alignment =
        widget.textAlign ?? defaultTextStyle.textAlign ?? TextAlign.start;
    final direction = Directionality.of(context);
    final creationParams = <String, Object?>{
      'text': widget.data,
      'fontSize': fontSize,
      'fontWeight': fontWeight.value,
      'color': color.toARGB32(),
      'lineHeightFactor': resolvedStyle.height,
      'letterSpacing': resolvedStyle.letterSpacing,
      'textAlign': alignment.name,
      'textDirection': direction.name,
    };

    return TapRegion(
      onTapOutside: _selectionActive
          ? (event) => _outsidePointerDown = event
          : null,
      onTapUpOutside: _selectionActive ? _handleTapUpOutside : null,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          ExcludeSemantics(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0,
                child: Text(
                  widget.data,
                  style: widget.style,
                  textAlign: widget.textAlign,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Listener(
              key: _gestureRegionKey,
              onPointerDown: (_) => _pointerDown = true,
              onPointerUp: (_) => _finishPointer(),
              onPointerCancel: (_) => _finishPointer(),
              child: UiKitView(
                key: ValueKey((
                  widget.data,
                  fontSize,
                  fontWeight,
                  color,
                  resolvedStyle.height,
                  resolvedStyle.letterSpacing,
                  alignment,
                  direction,
                )),
                viewType: _viewType,
                layoutDirection: direction,
                creationParams: creationParams,
                creationParamsCodec: const StandardMessageCodec(),
                gestureRecognizers: {
                  if (_selectionActive)
                    Factory<_SelectionHandleGestureRecognizer>(
                      () => _SelectionHandleGestureRecognizer(
                        shouldAccept: _isSelectionHandle,
                      ),
                    )
                  else
                    Factory<LongPressGestureRecognizer>(
                      LongPressGestureRecognizer.new,
                    ),
                },
                onPlatformViewCreated: _onPlatformViewCreated,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onPlatformViewCreated(int viewId) {
    _channel?.setMethodCallHandler(null);
    final channel = MethodChannel('$_channelPrefix/$viewId');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      _selectionChanged(call.arguments as Map<Object?, Object?>);
    });
  }

  void _selectionChanged(Map<Object?, Object?> selection) {
    final active = selection['active']! as bool;
    if (active) {
      _selectionStart = Offset(
        (selection['startX']! as num).toDouble(),
        (selection['startY']! as num).toDouble(),
      );
      _selectionEnd = Offset(
        (selection['endX']! as num).toDouble(),
        (selection['endY']! as num).toDouble(),
      );
    } else {
      _selectionStart = null;
      _selectionEnd = null;
    }
    if (_pointerDown) {
      _pendingSelectionActive = active;
      return;
    }
    if (_selectionActive == active) return;
    setState(() => _selectionActive = active);
  }

  void _finishPointer() {
    _pointerDown = false;
    final active = _pendingSelectionActive;
    _pendingSelectionActive = null;
    if (active != null && _selectionActive != active) {
      setState(() => _selectionActive = active);
    }
  }

  bool _isSelectionHandle(Offset globalPosition) {
    final renderBox =
        _gestureRegionKey.currentContext!.findRenderObject()! as RenderBox;
    final localPosition = renderBox.globalToLocal(globalPosition);
    return (localPosition - _selectionStart!).distance <=
            _selectionHandleRadius ||
        (localPosition - _selectionEnd!).distance <= _selectionHandleRadius;
  }

  void _handleTapUpOutside(PointerUpEvent event) {
    final down = _outsidePointerDown!;
    _outsidePointerDown = null;
    if ((event.position - down.position).distance <= kTouchSlop) {
      _deactivateSelection();
    }
  }

  void _deactivateSelection() {
    _channel!.invokeMethod<void>('deactivate');
    _pendingSelectionActive = null;
    _selectionStart = null;
    _selectionEnd = null;
    setState(() => _selectionActive = false);
  }
}

/// Claims only touches that begin on a native selection handle so vertical
/// drags elsewhere remain available to the enclosing Flutter scroll view.
class _SelectionHandleGestureRecognizer extends OneSequenceGestureRecognizer {
  _SelectionHandleGestureRecognizer({required this.shouldAccept});

  final bool Function(Offset globalPosition) shouldAccept;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    final disposition = shouldAccept(event.position)
        ? GestureDisposition.accepted
        : GestureDisposition.rejected;
    resolvePointer(event.pointer, disposition);
    if (disposition == GestureDisposition.rejected) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    stopTrackingIfPointerNoLongerDown(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'selection handle';
}
