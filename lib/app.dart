import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/ui/app_toast.dart';
import 'features/settings/data/theme_prefs.dart';
import 'features/subtitle/presentation/pip_sync.dart';
import 'features/subtitle/presentation/subtitle_overlay.dart';
import 'shared/widgets/privacy_blur.dart';
import 'shared/widgets/right_edge_swipe_detector.dart';
import 'shared/widgets/root_tab_view.dart';

class TonariApp extends ConsumerStatefulWidget {
  const TonariApp({super.key});

  @override
  ConsumerState<TonariApp> createState() => _TonariAppState();
}

class _TonariAppState extends ConsumerState<TonariApp> {
  late final _forwardNavigation = ForwardNavigationObserver();

  @override
  void dispose() {
    _forwardNavigation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themePrefsProvider);
    return MaterialApp(
      title: 'Tonari',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      navigatorObservers: [_forwardNavigation],
      builder: (context, child) => ForwardNavigationScope(
        observer: _forwardNavigation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child ?? const SizedBox.shrink(),
            const PipSync(),
            const SubtitleOverlay(),
            const AppToastHost(),
            const PrivacyBlur(),
          ],
        ),
      ),
      home: const RootTabView(),
    );
  }
}
