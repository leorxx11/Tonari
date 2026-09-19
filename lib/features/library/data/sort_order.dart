import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/shared_prefs_provider.dart';

abstract interface class SortField implements Enum {
  String get label;

  /// Direction a field starts in when picked, e.g. newest / highest first.
  bool get defaultDescending;
}

typedef SortOrder<F extends SortField> = ({F field, bool descending});

/// Persisted sort choice. Picking the current field flips its direction;
/// picking another field switches to it in that field's natural direction.
class SortOrderNotifier<F extends SortField> extends Notifier<SortOrder<F>> {
  SortOrderNotifier(this._key, this.fields);

  final String _key;

  /// Menu order; the first field is the default.
  final List<F> fields;

  @override
  SortOrder<F> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    final parts = (raw ?? '').split(':');
    final field = fields.where((f) => f.name == parts.first).firstOrNull;
    if (field == null) {
      return (field: fields.first, descending: fields.first.defaultDescending);
    }
    return (field: field, descending: parts.last == 'desc');
  }

  Future<void> select(F field) async {
    state = field == state.field
        ? (field: field, descending: !state.descending)
        : (field: field, descending: field.defaultDescending);
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, '${field.name}:${state.descending ? 'desc' : 'asc'}');
  }
}
