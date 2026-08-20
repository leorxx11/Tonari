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

    expect(_recognizerType(tester), LongPressGestureRecognizer);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(UiKitView)),
    );
    await messenger.handlePlatformMessage(
      textChannel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('selectionChanged', true),
      ),
      (ByteData? _) {},
    );
    await tester.pump();
    expect(_recognizerType(tester), LongPressGestureRecognizer);

    await gesture.up();
    await tester.pump();
    expect(_recognizerType(tester), EagerGestureRecognizer);

    await tester.tap(find.byKey(const Key('outside')));
    await tester.pump();
    expect(deactivated, isTrue);
    expect(_recognizerType(tester), LongPressGestureRecognizer);

    messenger.setMockMethodCallHandler(textChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    debugDefaultTargetPlatformOverride = null;
  });
}

Type _recognizerType(WidgetTester tester) {
  final view = tester.widget<UiKitView>(find.byType(UiKitView));
  final recognizer = view.gestureRecognizers!.single.constructor();
  final type = recognizer.runtimeType;
  recognizer.dispose();
  return type;
}
