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

  testWidgets('outside pointer up without a matching down is ignored', (
    tester,
  ) async {
    final harness = await _boot(tester);

    // Selection turns active while a finger is already down outside the text,
    // so TapRegion only ever reports the pointer up.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('outside'))),
    );
    await _sendSelection(
      tester.binding.defaultBinaryMessenger,
      harness.channel,
      start: const Offset(10, 10),
      end: const Offset(80, 10),
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(harness.deactivated, isFalse);
    expect(
      _recognizerFactoryType(tester).toString(),
      '_SelectionHandleGestureRecognizer',
    );

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('extra pointer is ignored while selection coords are stale', (
    tester,
  ) async {
    final harness = await _boot(tester);
    final messenger = tester.binding.defaultBinaryMessenger;

    await _sendSelection(
      messenger,
      harness.channel,
      start: const Offset(10, 10),
      end: const Offset(80, 10),
    );
    await tester.pump();

    final center = tester.getCenter(find.byType(UiKitView));
    final first = await tester.startGesture(center);
    // Coordinates clear immediately, but the state change waits for the
    // pointer to lift, so the handle recognizer is still installed.
    await _sendSelectionCleared(messenger, harness.channel);
    await tester.pump();

    final second = await tester.startGesture(center + const Offset(20, 0));
    await tester.pump();
    await second.up();
    await first.up();
    await tester.pump();

    expect(_recognizerFactoryType(tester), LongPressGestureRecognizer);

    debugDefaultTargetPlatformOverride = null;
  });
}

class _Harness {
  late MethodChannel channel;
  var deactivated = false;
}

Future<_Harness> _boot(WidgetTester tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  final messenger = tester.binding.defaultBinaryMessenger;
  final harness = _Harness();
  late int viewId;

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
              height: 100,
              child: IosSelectableText(
                'Select this text',
                style: TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
            SizedBox(key: Key('outside'), width: 240, height: 200),
          ],
        ),
      ),
    ),
  );
  await tester.pump();

  harness.channel = MethodChannel('tonari/ios_selectable_text/$viewId');
  messenger.setMockMethodCallHandler(harness.channel, (call) async {
    if (call.method == 'deactivate') harness.deactivated = true;
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(harness.channel, null));
  return harness;
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

Future<void> _sendSelectionCleared(
  TestDefaultBinaryMessenger messenger,
  MethodChannel channel,
) {
  return messenger.handlePlatformMessage(
    channel.name,
    const StandardMethodCodec().encodeMethodCall(
      const MethodCall('selectionChanged', {'active': false}),
    ),
    (ByteData? _) {},
  );
}
