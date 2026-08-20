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

  bool _selectionActive = false;
  bool _pointerDown = false;
  bool? _pendingSelectionActive;
  MethodChannel? _channel;

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
      onTapOutside: _selectionActive ? (_) => _deactivateSelection() : null,
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
                    Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new)
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
      _selectionChanged(call.arguments as bool);
    });
  }

  void _selectionChanged(bool active) {
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

  void _deactivateSelection() {
    _channel!.invokeMethod<void>('deactivate');
    _pendingSelectionActive = null;
    setState(() => _selectionActive = false);
  }
}
