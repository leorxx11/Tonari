import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/shared_prefs_provider.dart';

class PathPrefs {
  const PathPrefs({
    required this.smartPath,
    required this.preferEffectSound,
    required this.typeOrderEnabled,
    required this.typeOrder,
  });

  final bool smartPath;
  final bool preferEffectSound;
  final bool typeOrderEnabled;
  final List<String> typeOrder;

  static const defaultTypeOrder = <String>[
    'wav',
    'mp3',
    'flac',
    'opus',
    'm4a',
    'aac',
  ];

  static const defaults = PathPrefs(
    smartPath: true,
    preferEffectSound: true,
    typeOrderEnabled: true,
    typeOrder: defaultTypeOrder,
  );

  PathPrefs copyWith({
    bool? smartPath,
    bool? preferEffectSound,
    bool? typeOrderEnabled,
    List<String>? typeOrder,
  }) {
    return PathPrefs(
      smartPath: smartPath ?? this.smartPath,
      preferEffectSound: preferEffectSound ?? this.preferEffectSound,
      typeOrderEnabled: typeOrderEnabled ?? this.typeOrderEnabled,
      typeOrder: typeOrder ?? this.typeOrder,
    );
  }
}

class PathPrefsNotifier extends Notifier<PathPrefs> {
  static const _kSmartPath = 'path.smartPath';
  static const _kPreferEffectSound = 'path.preferEffectSound';
  static const _kTypeOrderEnabled = 'path.typeOrderEnabled';
  static const _kTypeOrder = 'path.typeOrder';

  @override
  PathPrefs build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getStringList(_kTypeOrder);
    final order = stored == null || stored.isEmpty
        ? PathPrefs.defaultTypeOrder
        : _mergeWithDefaults(stored);
    return PathPrefs(
      smartPath: prefs.getBool(_kSmartPath) ?? true,
      preferEffectSound: prefs.getBool(_kPreferEffectSound) ?? true,
      typeOrderEnabled: prefs.getBool(_kTypeOrderEnabled) ?? true,
      typeOrder: order,
    );
  }

  // Merges stored order with defaults so new formats added in a future
  // version still appear (appended at the end).
  static List<String> _mergeWithDefaults(List<String> stored) {
    final seen = <String>{...stored};
    return [
      ...stored,
      ...PathPrefs.defaultTypeOrder.where((f) => !seen.contains(f)),
    ];
  }

  Future<void> setSmartPath(bool value) async {
    state = state.copyWith(smartPath: value);
    await ref.read(sharedPreferencesProvider).setBool(_kSmartPath, value);
  }

  Future<void> setPreferEffectSound(bool value) async {
    state = state.copyWith(preferEffectSound: value);
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kPreferEffectSound, value);
  }

  Future<void> setTypeOrderEnabled(bool value) async {
    state = state.copyWith(typeOrderEnabled: value);
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kTypeOrderEnabled, value);
  }

  Future<void> reorderType(int oldIndex, int newIndex) async {
    final list = [...state.typeOrder];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(typeOrder: list);
    await ref.read(sharedPreferencesProvider).setStringList(_kTypeOrder, list);
  }
}

final pathPrefsProvider = NotifierProvider<PathPrefsNotifier, PathPrefs>(
  PathPrefsNotifier.new,
);
