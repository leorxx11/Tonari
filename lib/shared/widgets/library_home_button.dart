import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/selected_section.dart';

void goToLibraryHome(BuildContext context, WidgetRef ref) {
  ref.read(selectedSectionProvider.notifier).set(AppSection.audioLibrary);
  Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
}

class LibraryHomeButton extends ConsumerWidget {
  const LibraryHomeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: '回到音频媒体库',
      icon: const Icon(CupertinoIcons.house, size: 21),
      onPressed: () => goToLibraryHome(context, ref),
    );
  }
}
