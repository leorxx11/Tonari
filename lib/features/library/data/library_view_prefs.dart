import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/shared_prefs_provider.dart';

enum LibraryViewMode { card, grid, list }

class LibraryViewModeNotifier extends Notifier<LibraryViewMode> {
  LibraryViewModeNotifier(this._key, this.modes);

  final String _key;

  /// Modes this library offers, in toggle order; the first is the default.
  final List<LibraryViewMode> modes;

  @override
  LibraryViewMode build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    return modes.firstWhere((m) => m.name == raw, orElse: () => modes.first);
  }

  Future<void> toggle() async {
    state = modes[(modes.indexOf(state) + 1) % modes.length];
    await ref.read(sharedPreferencesProvider).setString(_key, state.name);
  }
}

final workViewModeProvider =
    NotifierProvider<LibraryViewModeNotifier, LibraryViewMode>(
      () =>
          LibraryViewModeNotifier('library.view.works', LibraryViewMode.values),
    );

final videoViewModeProvider =
    NotifierProvider<LibraryViewModeNotifier, LibraryViewMode>(
      () => LibraryViewModeNotifier(
        'library.view.videos',
        LibraryViewMode.values,
      ),
    );

/// Favorites and groups mix works and videos; one mode drives both sections.
final collectionViewModeProvider =
    NotifierProvider<LibraryViewModeNotifier, LibraryViewMode>(
      () => LibraryViewModeNotifier(
        'library.view.collections',
        LibraryViewMode.values,
      ),
    );
