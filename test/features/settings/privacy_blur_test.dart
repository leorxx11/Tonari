import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tonari/core/prefs/shared_prefs_provider.dart';
import 'package:tonari/shared/widgets/privacy_blur.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, {required bool enabled}) async {
    SharedPreferences.setMockInitialValues({
      'privacy.blurOnBackground': enabled,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          home: Stack(
            fit: StackFit.expand,
            children: [Text('content'), PrivacyBlur()],
          ),
        ),
      ),
    );
  }

  testWidgets('blurs while not resumed, clears on resume', (tester) async {
    await pumpApp(tester, enabled: true);
    expect(find.byType(BackdropFilter), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byType(BackdropFilter), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('stays clear when disabled', (tester) async {
    await pumpApp(tester, enabled: false);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
