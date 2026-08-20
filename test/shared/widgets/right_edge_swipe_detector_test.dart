import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/shared/widgets/right_edge_swipe_detector.dart';

void main() {
  testWidgets('right-edge forward route follows the drag before release', (
    tester,
  ) async {
    var committed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: RightEdgeSwipeDetector(
          pageBuilder: (_) =>
              const Scaffold(body: SizedBox.expand(key: Key('destination'))),
          onNavigationCommitted: () => committed = true,
          child: const Scaffold(body: SizedBox.expand(key: Key('source'))),
        ),
      ),
    );

    final width = tester.getSize(find.byKey(const Key('source'))).width;
    final gesture = await tester.startGesture(Offset(width - 2, 300));
    await gesture.moveBy(Offset(-width * 0.2, 0));
    await tester.pump();
    await gesture.moveBy(Offset(-width * 0.2, 0));
    await tester.pump();

    final destinationX = tester
        .getTopLeft(find.byKey(const Key('destination')))
        .dx;
    expect(destinationX, greaterThan(0));
    expect(destinationX, lessThan(width));
    expect(committed, isFalse);

    await gesture.moveBy(Offset(-width * 0.4, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(committed, isTrue);
    expect(
      tester.getTopLeft(find.byKey(const Key('destination'))).dx,
      closeTo(0, 0.01),
    );
  });

  testWidgets('short right-edge drag returns to the source page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RightEdgeSwipeDetector(
          pageBuilder: (_) =>
              const Scaffold(body: SizedBox.expand(key: Key('destination'))),
          child: const Scaffold(body: SizedBox.expand(key: Key('source'))),
        ),
      ),
    );

    final width = tester.getSize(find.byKey(const Key('source'))).width;
    final gesture = await tester.startGesture(Offset(width - 2, 300));
    await gesture.moveBy(Offset(-width * 0.05, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.moveBy(const Offset(-1, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('source')), findsOneWidget);
    expect(find.byKey(const Key('destination')), findsNothing);
  });
}
