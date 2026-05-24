import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'shared/widgets/root_tab_view.dart';

class TonariApp extends StatelessWidget {
  const TonariApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tonari',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const RootTabView(),
    );
  }
}
