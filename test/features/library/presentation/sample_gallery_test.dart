import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view.dart';
import 'package:tonari/features/library/presentation/widgets/sample_gallery.dart';

void main() {
  testWidgets('gallery closes only when tapping outside the image', (
    tester,
  ) async {
    await openGallery(tester);

    await tester.tap(find.byType(RawImage));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tapAt(const Offset(760, 560));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('fit image swipes to the next page', (tester) async {
    await openGallery(tester);
    await tester.dragFrom(const Offset(600, 300), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('double tap zooms and restores the image', (tester) async {
    await openGallery(tester);
    final controller = tester
        .widget<PhotoView>(find.byType(PhotoView))
        .controller!;
    final fit = controller.scale!;
    await doubleTap(tester, const Offset(450, 300));
    expect(controller.scale, closeTo(fit * 2.5, 0.01));
    await tester.tapAt(const Offset(760, 560));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsOneWidget);
    await doubleTap(tester, const Offset(450, 300));
    expect(controller.scale, closeTo(fit, 0.01));
    await tester.dragFrom(const Offset(600, 300), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('pinch zoom and panning never turn the page while enlarged', (
    tester,
  ) async {
    await openGallery(tester);
    final controller = tester
        .widget<PhotoView>(find.byType(PhotoView))
        .controller!;
    final fit = controller.scale!;
    await pinch(tester, 100, 250);
    expect(controller.scale!, greaterThan(fit * 1.5));
    final before = controller.position;
    await tester.dragFrom(const Offset(600, 300), const Offset(-300, -100));
    await tester.pumpAndSettle();
    expect(controller.position.dx, lessThan(before.dx));
    expect(controller.position.dy, lessThan(before.dy));
    for (var i = 0; i < 3; i++) {
      await tester.dragFrom(const Offset(600, 300), const Offset(-450, 0));
      await tester.pumpAndSettle();
    }
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('shrinking keeps pinch ownership until both fingers lift', (
    tester,
  ) async {
    await openGallery(tester);
    final controller = tester
        .widget<PhotoView>(find.byType(PhotoView))
        .controller!;
    final fit = controller.scale!;
    await pinch(tester, 100, 250);
    final left = await tester.startGesture(const Offset(100, 300), pointer: 1);
    final right = await tester.startGesture(const Offset(700, 300), pointer: 2);
    await tester.pump();
    for (var i = 1; i <= 10; i++) {
      await left.moveTo(Offset(100 + i * 28, 300));
      await right.moveTo(Offset(700 - i * 28, 300));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller.scale!, lessThanOrEqualTo(fit));
    await left.up();
    await right.moveBy(const Offset(-300, 0));
    await tester.pump();
    await right.up();
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(controller.scale, closeTo(fit, 0.01));
    await tester.dragFrom(const Offset(600, 300), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
  });
}

Future<void> openGallery(WidgetTester tester) async {
  final tempDirectory = Directory.systemTemp.createTempSync(
    'tonari-gallery-test-',
  );
  addTearDown(() => tempDirectory.deleteSync(recursive: true));
  final imageFile = File('${tempDirectory.path}/sample.png')
    ..writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
        'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => SampleGallery.open(
                context,
                samples: List.generate(
                  2,
                  (_) => SampleSource(localPath: imageFile.path),
                ),
                initialIndex: 0,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(
    () => precacheImage(
      FileImage(imageFile),
      tester.element(find.byType(Scaffold)),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> doubleTap(WidgetTester tester, Offset point) async {
  await tester.pump(const Duration(milliseconds: 350));
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 80));
  await tester.tapAt(point);
  await tester.pumpAndSettle();
}

Future<void> pinch(WidgetTester tester, double start, double end) async {
  final left = await tester.startGesture(Offset(400 - start, 300), pointer: 1);
  final right = await tester.startGesture(Offset(400 + start, 300), pointer: 2);
  await tester.pump();
  for (var i = 1; i <= 10; i++) {
    final distance = start + (end - start) * i / 10;
    await left.moveTo(Offset(400 - distance, 300));
    await right.moveTo(Offset(400 + distance, 300));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await left.up();
  await right.up();
  await tester.pumpAndSettle();
}
