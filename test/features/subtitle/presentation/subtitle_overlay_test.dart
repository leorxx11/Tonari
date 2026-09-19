import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tonari/core/prefs/shared_prefs_provider.dart';
import 'package:tonari/core/subtitle/subtitle_cue.dart';
import 'package:tonari/features/subtitle/data/loaded_subtitle.dart';
import 'package:tonari/features/subtitle/data/subtitle_providers.dart';
import 'package:tonari/features/subtitle/presentation/subtitle_overlay.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('subtitle stays readable and interactive in $brightness', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final navigatorKey = GlobalKey<NavigatorState>();
      const cue = '放松下来，慢慢地深呼吸。\nゆっくり息を吸ってください。';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentSubtitleProvider.overrideWith(
              (ref) => Stream.value(
                const LoadedSubtitle(
                  subtitleId: 'subtitle',
                  trackId: 'track',
                  cues: [SubtitleCue(startMs: 0, endMs: 1000, text: cue)],
                  timeOffsetMs: 0,
                ),
              ),
            ),
            currentSubtitleLineProvider.overrideWith((ref) => Stream.value(0)),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            theme: ThemeData(brightness: brightness),
            home: const Scaffold(),
            builder: (_, child) => Stack(
              children: [
                child!,
                SubtitleOverlay(navigatorKey: navigatorKey),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final text = find.text(cue);
      final style = tester.widget<Text>(text).style!;
      final background = tester
          .widget<ColoredBox>(
            find.ancestor(of: text, matching: find.byType(ColoredBox)).first,
          )
          .color;
      for (final pageColor in [Colors.white, Colors.black]) {
        final blended = Color.alphaBlend(background, pageColor);
        final contrast =
            (style.color!.computeLuminance() + 0.05) /
            (blended.computeLuminance() + 0.05);
        expect(contrast, greaterThanOrEqualTo(7));
      }
      final paragraph = tester.renderObject<RenderParagraph>(text);
      expect(paragraph.didExceedMaxLines, isFalse);
      final originalPosition = tester.getTopLeft(text);
      await tester.drag(text, const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(text).dy, lessThan(originalPosition.dy));
      expect(prefs.getDouble('subtitle.overlay.dy'), isNotNull);
      await tester.longPress(text);
      await tester.pumpAndSettle();
      expect(find.text('恢复默认位置'), findsOneWidget);
      await tester.tap(find.text('关闭悬浮字幕'));
      await tester.pumpAndSettle();
      expect(find.text(cue), findsNothing);
      expect(prefs.getString('subtitle.overlay.mode'), 'off');
      expect(tester.takeException(), isNull);
    });
  }
}
