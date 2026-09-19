import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/shared_prefs_provider.dart';

enum LibraryViewMode { grid, list }

class LibraryViewModeNotifier extends Notifier<LibraryViewMode> {
  LibraryViewModeNotifier(this._key);

  final String _key;

  @override
  LibraryViewMode build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    return raw == LibraryViewMode.list.name
        ? LibraryViewMode.list
        : LibraryViewMode.grid;
  }

  Future<void> toggle() async {
    state = state == LibraryViewMode.grid
        ? LibraryViewMode.list
        : LibraryViewMode.grid;
    await ref.read(sharedPreferencesProvider).setString(_key, state.name);
  }
}

final workViewModeProvider =
    NotifierProvider<LibraryViewModeNotifier, LibraryViewMode>(
      () => LibraryViewModeNotifier('library.view.works'),
    );

final videoViewModeProvider =
    NotifierProvider<LibraryViewModeNotifier, LibraryViewMode>(
      () => LibraryViewModeNotifier('library.view.videos'),
    );
