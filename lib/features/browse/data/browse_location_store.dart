import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/prefs/shared_prefs_provider.dart';
import 'remote_models.dart';

/// Persists the last browsed folder stack per source (115, or a WebDAV server
/// id), so reopening a source returns to where the user left off — breadcrumbs
/// included. Stack entries are always folders.
class BrowseLocationStore {
  BrowseLocationStore(this._prefs);

  final SharedPreferences _prefs;

  String _key(String sourceId) => 'browse_stack_$sourceId';

  List<RemoteEntry>? read(String sourceId) {
    final raw = _prefs.getString(_key(sourceId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List;
      final stack = list.map((e) {
        final m = e as Map<String, dynamic>;
        return RemoteEntry(
          id: m['id'] as String,
          path: m['path'] as String,
          name: m['name'] as String,
          kind: RemoteEntryKind.folder,
          sourceId: m['sourceId'] as String,
        );
      }).toList();
      return stack.isEmpty ? null : stack;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String sourceId, List<RemoteEntry> stack) {
    final json = jsonEncode(
      stack
          .map(
            (e) => {
              'id': e.id,
              'path': e.path,
              'name': e.name,
              'sourceId': e.sourceId,
            },
          )
          .toList(),
    );
    return _prefs.setString(_key(sourceId), json);
  }

  Future<void> clear(String sourceId) => _prefs.remove(_key(sourceId));
}

final browseLocationStoreProvider = Provider<BrowseLocationStore>(
  (ref) => BrowseLocationStore(ref.watch(sharedPreferencesProvider)),
);
