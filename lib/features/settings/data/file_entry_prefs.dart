import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/shared_prefs_provider.dart';

enum FileEntryPosition { bottomLeft, bottomRight }

class FileEntryPositionNotifier extends Notifier<FileEntryPosition> {
  static const _key = 'appearance.fileEntryPosition';

  @override
  FileEntryPosition build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    return switch (raw) {
      'bottomLeft' => FileEntryPosition.bottomLeft,
      _ => FileEntryPosition.bottomRight,
    };
  }

  Future<void> set(FileEntryPosition position) async {
    state = position;
    await ref.read(sharedPreferencesProvider).setString(_key, position.name);
  }
}

final fileEntryPositionProvider =
    NotifierProvider<FileEntryPositionNotifier, FileEntryPosition>(
      FileEntryPositionNotifier.new,
    );
