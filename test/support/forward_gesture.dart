import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> sendForwardGesture(
  WidgetTester tester,
  String phase, {
  required double progress,
  double velocity = 0,
}) async {
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'tonari/forward_navigation',
    const StandardMethodCodec().encodeMethodCall(
      MethodCall(phase, {
        'progress': progress,
        'distance': progress * width,
        'velocity': velocity,
      }),
    ),
    (reply) => const StandardMethodCodec().decodeEnvelope(reply!),
  );
  await tester.pump();
}
