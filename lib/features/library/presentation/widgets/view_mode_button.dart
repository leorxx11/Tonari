import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/library_view_prefs.dart';

class ViewModeButton extends ConsumerWidget {
  const ViewModeButton({super.key, required this.provider});

  final NotifierProvider<LibraryViewModeNotifier, LibraryViewMode> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(provider) == LibraryViewMode.list;
    return IconButton(
      tooltip: list ? '网格视图' : '列表视图',
      icon: Icon(list ? Icons.grid_view : Icons.view_list),
      onPressed: () => ref.read(provider.notifier).toggle(),
    );
  }
}
