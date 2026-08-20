import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/features/library/presentation/widgets/sample_gallery.dart';

void main() {
  testWidgets('gallery closes only when tapping outside the image', (
    tester,
  ) async {
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
                  samples: [SampleSource(localPath: imageFile.path)],
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

    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tapAt(const Offset(760, 560));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
