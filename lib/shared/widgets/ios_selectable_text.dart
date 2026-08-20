import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IosSelectableText extends StatelessWidget {
  const IosSelectableText(
    this.data, {
    super.key,
    required this.style,
    this.textAlign,
  });

  static const _viewType = 'tonari/ios_selectable_text';

  final String data;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return SelectableText(data, style: style, textAlign: textAlign);
    }

    final defaultTextStyle = DefaultTextStyle.of(context);
    final resolvedStyle = defaultTextStyle.style.merge(style);
    final textScaler = MediaQuery.textScalerOf(context);
    final fontSize = textScaler.scale(resolvedStyle.fontSize!);
    final fontWeight = resolvedStyle.fontWeight ?? FontWeight.normal;
    final color = resolvedStyle.color!;
    final alignment =
        textAlign ?? defaultTextStyle.textAlign ?? TextAlign.start;
    final direction = Directionality.of(context);
    final creationParams = <String, Object?>{
      'text': data,
      'fontSize': fontSize,
      'fontWeight': fontWeight.value,
      'color': color.toARGB32(),
      'lineHeightFactor': resolvedStyle.height,
      'letterSpacing': resolvedStyle.letterSpacing,
      'textAlign': alignment.name,
      'textDirection': direction.name,
    };

    return Stack(
      fit: StackFit.passthrough,
      children: [
        ExcludeSemantics(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0,
              child: Text(data, style: style, textAlign: textAlign),
            ),
          ),
        ),
        Positioned.fill(
          child: UiKitView(
            key: ValueKey((
              data,
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
          ),
        ),
      ],
    );
  }
}
