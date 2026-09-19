import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/library_view_prefs.dart';

class ViewModeButton extends ConsumerWidget {
  const ViewModeButton({super.key, required this.provider});

  final NotifierProvider<LibraryViewModeNotifier, LibraryViewMode> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(provider);
    final (icon, label) = switch (mode) {
      LibraryViewMode.card => (Icons.view_agenda_outlined, '大卡片'),
      LibraryViewMode.grid => (Icons.grid_view, '网格'),
      LibraryViewMode.list => (Icons.view_list, '列表'),
    };
    return IconButton(
      tooltip: '视图：$label',
      icon: Icon(icon),
      onPressed: () => ref.read(provider.notifier).toggle(),
    );
  }
}
