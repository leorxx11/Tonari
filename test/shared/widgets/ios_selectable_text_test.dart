import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/shared/widgets/ios_selectable_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native text owns handle drags only after selection completes', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final messenger = tester.binding.defaultBinaryMessenger;
    late int viewId;
    var deactivated = false;

    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        viewId = (call.arguments as Map<Object?, Object?>)['id']! as int;
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      debugDefaultTargetPlatformOverride = null;
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                width: 240,
                child: IosSelectableText(
                  'Select this text',
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
              SizedBox(
                width: 240,
                height: 120,
                child: ColoredBox(
                  key: Key('outside'),
                  color: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final textChannel = MethodChannel('tonari/ios_selectable_text/$viewId');
    addTearDown(() => messenger.setMockMethodCallHandler(textChannel, null));
    messenger.setMockMethodCallHandler(textChannel, (call) async {
      if (call.method == 'deactivate') deactivated = true;
      return null;
    });

    expect(_recognizerFactoryType(tester), LongPressGestureRecognizer);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(UiKitView)),
    );
    await _sendSelection(
      messenger,
      textChannel,
      start: const Offset(10, 10),
      end: const Offset(80, 10),
    );
    await tester.pump();
    expect(_recognizerFactoryType(tester), LongPressGestureRecognizer);

    await gesture.up();
    await tester.pump();
    expect(
      _recognizerFactoryType(tester).toString(),
      '_SelectionHandleGestureRecognizer',
    );

    await tester.tap(find.byKey(const Key('outside')));
    await tester.pump();
    expect(deactivated, isTrue);
    expect(_recognizerFactoryType(tester), LongPressGestureRecognizer);

    messenger.setMockMethodCallHandler(textChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('only selection handles block the enclosing scroll view', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final messenger = tester.binding.defaultBinaryMessenger;
    final scrollController = ScrollController();
    late int viewId;
    var deactivated = false;

    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        viewId = (call.arguments as Map<Object?, Object?>)['id']! as int;
      }
      return null;
    });
    addTearDown(() {
      scrollController.dispose();
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      debugDefaultTargetPlatformOverride = null;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: [
                  const SizedBox(
                    width: 240,
                    height: 100,
                    child: IosSelectableText(
                      'Select this text across multiple lines',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                  ),
                  const SizedBox(key: Key('outside'), width: 240, height: 600),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final textChannel = MethodChannel('tonari/ios_selectable_text/$viewId');
    addTearDown(() => messenger.setMockMethodCallHandler(textChannel, null));
    messenger.setMockMethodCallHandler(textChannel, (call) async {
      if (call.method == 'deactivate') deactivated = true;
      return null;
    });
    await _sendSelection(
      messenger,
      textChannel,
      start: const Offset(12, 70),
      end: const Offset(80, 70),
    );
    await tester.pump();

    final textOrigin = tester.getTopLeft(find.byType(UiKitView));
    await tester.dragFrom(
      textOrigin + const Offset(12, 70),
      const Offset(0, -60),
    );
    await tester.pumpAndSettle();
    expect(scrollController.offset, 0);

    await tester.dragFrom(
      textOrigin + const Offset(180, 70),
      const Offset(0, -60),
    );
    await tester.pumpAndSettle();
    expect(scrollController.offset, greaterThan(0));
    expect(deactivated, isFalse);

    final outsideOrigin = tester.getTopLeft(find.byKey(const Key('outside')));
    await tester.dragFrom(
      outsideOrigin + const Offset(40, 40),
      const Offset(0, -60),
    );
    await tester.pumpAndSettle();
    expect(deactivated, isFalse);

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const Key('outside'))) +
          const Offset(40, 40),
    );
    await tester.pump();
    expect(deactivated, isTrue);
    expect(_recognizerFactoryType(tester), LongPressGestureRecognizer);

    messenger.setMockMethodCallHandler(textChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    debugDefaultTargetPlatformOverride = null;
  });
}

Type _recognizerFactoryType(WidgetTester tester) {
  final view = tester.widget<UiKitView>(find.byType(UiKitView));
  return view.gestureRecognizers!.single.type;
}

Future<void> _sendSelection(
  TestDefaultBinaryMessenger messenger,
  MethodChannel channel, {
  required Offset start,
  required Offset end,
}) {
  return messenger.handlePlatformMessage(
    channel.name,
    const StandardMethodCodec().encodeMethodCall(
      MethodCall('selectionChanged', {
        'active': true,
        'startX': start.dx,
        'startY': start.dy,
        'endX': end.dx,
        'endY': end.dy,
      }),
    ),
    (ByteData? _) {},
  );
}
