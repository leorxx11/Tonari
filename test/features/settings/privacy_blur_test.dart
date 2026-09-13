import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tonari/core/prefs/shared_prefs_provider.dart';
import 'package:tonari/features/settings/data/privacy_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('privacy is enabled for an unset preference', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    expect(container.read(privacyBlurProvider), isTrue);
  });

  test(
    'privacy toggle persists the key consumed by the iOS scene delegate',
    () async {
      SharedPreferences.setMockInitialValues({
        'flutter.privacy.blurOnBackground': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      expect(container.read(privacyBlurProvider), isFalse);

      for (final enabled in [true, false]) {
        await container.read(privacyBlurProvider.notifier).setEnabled(enabled);
        await prefs.reload();
        expect(prefs.getBool('privacy.blurOnBackground'), enabled);
        final reopened = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        expect(reopened.read(privacyBlurProvider), enabled);
        reopened.dispose();
      }
    },
  );
}
