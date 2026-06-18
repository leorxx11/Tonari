import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';

/// Persistent, user-facing problem inbox. Background failures (import,
/// subtitle download, metadata, auth) are logged here so they survive past a
/// transient SnackBar and across restarts. Only error/warning — never success.
class AppEventSink {
  AppEventSink(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final TonariDatabase _db;
  final Uuid _uuid;

  static const _retain = 200;

  Future<void> log({
    required String category,
    String severity = 'error',
    required String title,
    String detail = '',
    String? productId,
    String? workTitle,
    String? sourceName,
    String? actionKey,
  }) async {
    final now = DateTime.now();
    // Dedup: same (category, productId, title) bumps count instead of spamming
    // a new row — 115 rate limiting fires the same error in bursts.
    final existing =
        await (_db.select(_db.appEvents)
              ..where(
                (e) =>
                    e.category.equals(category) &
                    e.title.equals(title) &
                    (productId == null
                        ? e.productId.isNull()
                        : e.productId.equals(productId)),
              )
              ..orderBy([(e) => OrderingTerm.desc(e.lastAt)])
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) {
      await (_db.update(_db.appEvents)..where((e) => e.id.equals(existing.id)))
          .write(
            AppEventsCompanion(
              detail: Value(detail),
              lastAt: Value(now),
              count: Value(existing.count + 1),
              read: const Value(false),
            ),
          );
      return;
    }
    await _db
        .into(_db.appEvents)
        .insert(
          AppEventsCompanion.insert(
            id: _uuid.v4(),
            createdAt: now,
            lastAt: now,
            category: category,
            severity: severity,
            title: title,
            detail: Value(detail),
            productId: Value(productId),
            workTitle: Value(workTitle),
            sourceName: Value(sourceName),
            actionKey: Value(actionKey),
          ),
        );
    await _trim();
  }

  Future<void> markAllRead() async {
    await (_db.update(_db.appEvents)..where((e) => e.read.equals(false))).write(
      const AppEventsCompanion(read: Value(true)),
    );
  }

  Future<void> dismiss(String id) async {
    await (_db.delete(_db.appEvents)..where((e) => e.id.equals(id))).go();
  }

  Future<void> clear() async {
    await _db.delete(_db.appEvents).go();
  }

  Future<void> _trim() async {
    final keep = _db.selectOnly(_db.appEvents)
      ..addColumns([_db.appEvents.id])
      ..orderBy([OrderingTerm.desc(_db.appEvents.lastAt)])
      ..limit(_retain);
    await (_db.delete(
      _db.appEvents,
    )..where((e) => e.id.isNotInQuery(keep))).go();
  }
}

final appEventSinkProvider = Provider<AppEventSink>((ref) {
  return AppEventSink(ref.watch(databaseProvider));
});

final appEventsProvider = StreamProvider<List<AppEvent>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.appEvents)
        ..orderBy([(e) => OrderingTerm.desc(e.lastAt)]))
      .watch();
});

final unreadEventCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.selectOnly(db.appEvents)
    ..addColumns([db.appEvents.id.count()])
    ..where(db.appEvents.read.equals(false));
  return query.watchSingle().map(
    (row) => row.read(db.appEvents.id.count()) ?? 0,
  );
});
