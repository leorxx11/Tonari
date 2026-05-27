import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/settings/data/theme_prefs.dart';
import 'features/subtitle/presentation/pip_sync.dart';
import 'features/subtitle/presentation/subtitle_overlay.dart';
import 'shared/widgets/root_tab_view.dart';

class TonariApp extends ConsumerWidget {
  const TonariApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themePrefsProvider);
    return MaterialApp(
      title: 'Tonari',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [
          child ?? const SizedBox.shrink(),
          const PipSync(),
          const SubtitleOverlay(),
        ],
      ),
      home: const RootTabView(),
    );
  }
}
