import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/privacy_prefs.dart';

/// iOS snapshots the UI for the app switcher right after the app goes
/// inactive, so the blur must already be on screen at that moment.
class PrivacyBlur extends ConsumerStatefulWidget {
  const PrivacyBlur({super.key});

  @override
  ConsumerState<PrivacyBlur> createState() => _PrivacyBlurState();
}

class _PrivacyBlurState extends ConsumerState<PrivacyBlur> {
  late final AppLifecycleListener _listener;
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onStateChange: (state) =>
          setState(() => _obscured = state != AppLifecycleState.resumed),
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_obscured || !ref.watch(privacyBlurProvider)) {
      return const SizedBox.shrink();
    }
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.4),
      ),
    );
  }
}
