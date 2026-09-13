import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One paragraph of a selectable block. Consecutive runs share a single native
/// view so a selection can span them.
class SelectableTextRun {
  const SelectableTextRun(
    this.text, {
    required this.style,
    this.spacingBefore = 0,
    this.spacingAfter = 0,
  });

  final String text;
  final TextStyle style;
  final double spacingBefore;
  final double spacingAfter;
}

class IosSelectableText extends StatefulWidget {
  IosSelectableText(
    String data, {
    super.key,
    required TextStyle style,
    this.textAlign,
  }) : runs = [SelectableTextRun(data, style: style)];

  const IosSelectableText.rich(this.runs, {super.key, this.textAlign});

  final List<SelectableTextRun> runs;
  final TextAlign? textAlign;

  @override
  State<IosSelectableText> createState() => _IosSelectableTextState();
}

class _IosSelectableTextState extends State<IosSelectableText>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => _selectionActive;

  static const _viewType = 'tonari/ios_selectable_text';
  static const _channelPrefix = 'tonari/ios_selectable_text';
  static const _selectionHandleRadius = 28.0;

  bool _selectionActive = false;
  int _pointersDown = 0;
  bool? _pendingSelectionActive;
  Offset? _selectionStart;
  Offset? _selectionEnd;
  PointerDownEvent? _outsidePointerDown;
  double? _measuredHeight;
  String? _measuredSignature;
  String? _signature;
  MethodChannel? _channel;
  final _gestureRegionKey = GlobalKey();

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return _stack(
        (run) => SelectableText(
          run.text,
          style: run.style,
          textAlign: widget.textAlign,
        ),
      );
    }

    final defaultTextStyle = DefaultTextStyle.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final alignment =
        widget.textAlign ?? defaultTextStyle.textAlign ?? TextAlign.start;
    final direction = Directionality.of(context);
    final creationParams = <String, Object?>{
      'runs': [
        for (final run in widget.runs)
          _encodeRun(run, defaultTextStyle.style, textScaler),
      ],
      'textAlign': alignment.name,
      'textDirection': direction.name,
    };
    final signature = creationParams.toString();
    _signature = signature;
    final measuredHeight = _measuredSignature == signature
        ? _measuredHeight
        : null;

    return TapRegion(
      onTapOutside: _selectionActive
          ? (event) => _outsidePointerDown = event
          : null,
      onTapUpOutside: _selectionActive ? _handleTapUpOutside : null,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (measuredHeight != null)
            SizedBox(width: double.infinity, height: measuredHeight)
          else
            ExcludeSemantics(
              child: IgnorePointer(
                child: SizedBox(
                  width: double.infinity,
                  child: Opacity(
                    opacity: 0,
                    child: _stack(
                      (run) => Text(
                        run.text,
                        style: run.style,
                        textAlign: widget.textAlign,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Listener(
              key: _gestureRegionKey,
              onPointerDown: (_) => _pointersDown++,
              onPointerUp: (_) => _finishPointer(),
              onPointerCancel: (_) => _finishPointer(),
              child: UiKitView(
                key: ValueKey(signature),
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

  Widget _stack(Widget Function(SelectableTextRun run) build) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final run in widget.runs)
          Padding(
            padding: EdgeInsets.only(
              top: run.spacingBefore,
              bottom: run.spacingAfter,
            ),
            child: build(run),
          ),
      ],
    );
  }

  Map<String, Object?> _encodeRun(
    SelectableTextRun run,
    TextStyle inherited,
    TextScaler textScaler,
  ) {
    final style = inherited.merge(run.style);
    return {
      'text': run.text,
      'fontSize': textScaler.scale(style.fontSize!),
      'fontWeight': (style.fontWeight ?? FontWeight.normal).value,
      'fontFamily': style.fontFamily,
      'color': style.color!.toARGB32(),
      'lineHeightFactor': style.height,
      'letterSpacing': style.letterSpacing,
      'spacingBefore': run.spacingBefore,
      'spacingAfter': run.spacingAfter,
    };
  }

  void _onPlatformViewCreated(int viewId) {
    _channel?.setMethodCallHandler(null);
    final channel = MethodChannel('$_channelPrefix/$viewId');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      final args = call.arguments as Map<Object?, Object?>;
      switch (call.method) {
        case 'selectionChanged':
          _selectionChanged(args);
        case 'measured':
          _measured((args['height']! as num).toDouble());
      }
    });
  }

  void _measured(double height) {
    if (_measuredHeight == height && _measuredSignature == _signature) return;
    setState(() {
      _measuredHeight = height;
      _measuredSignature = _signature;
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
    if (_pointersDown > 0) {
      _pendingSelectionActive = active;
      return;
    }
    if (_selectionActive == active) return;
    setState(() => _selectionActive = active);
    updateKeepAlive();
  }

  void _finishPointer() {
    if (_pointersDown > 0) _pointersDown--;
    if (_pointersDown > 0) return;
    final active = _pendingSelectionActive;
    _pendingSelectionActive = null;
    if (active != null && _selectionActive != active) {
      setState(() => _selectionActive = active);
      updateKeepAlive();
    }
  }

  bool _isSelectionHandle(Offset globalPosition) {
    final start = _selectionStart;
    final end = _selectionEnd;
    if (start == null || end == null) return false;
    final renderBox =
        _gestureRegionKey.currentContext!.findRenderObject()! as RenderBox;
    final localPosition = renderBox.globalToLocal(globalPosition);
    return (localPosition - start).distance <= _selectionHandleRadius ||
        (localPosition - end).distance <= _selectionHandleRadius;
  }

  void _handleTapUpOutside(PointerUpEvent event) {
    final down = _outsidePointerDown;
    _outsidePointerDown = null;
    if (down == null) return;
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
    updateKeepAlive();
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
