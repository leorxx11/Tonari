import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/shared_prefs_provider.dart';

class PrivacyBlurNotifier extends Notifier<bool> {
  static const _key = 'privacy.blurOnBackground';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  Future<void> setEnabled(bool on) async {
    state = on;
    await ref.read(sharedPreferencesProvider).setBool(_key, on);
  }
}

final privacyBlurProvider = NotifierProvider<PrivacyBlurNotifier, bool>(
  PrivacyBlurNotifier.new,
);
