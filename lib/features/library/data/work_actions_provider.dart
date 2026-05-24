import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';

typedef RemoveWork = Future<void> Function(String productId);
typedef RestoreWork = Future<void> Function(String productId);

final removeWorkProvider = Provider<RemoveWork>((ref) {
  final db = ref.watch(databaseProvider);
  return removeWorkWithDatabase(db);
});

final restoreWorkProvider = Provider<RestoreWork>((ref) {
  final db = ref.watch(databaseProvider);
  return (productId) async {
    await (db.update(
      db.works,
    )..where((w) => w.productId.equals(productId))).write(
      WorksCompanion(
        isRemoved: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  };
});

RemoveWork removeWorkWithDatabase(TonariDatabase db) {
  return (productId) async {
    await (db.update(
      db.works,
    )..where((w) => w.productId.equals(productId))).write(
      WorksCompanion(
        isRemoved: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  };
}
