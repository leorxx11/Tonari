import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

final databaseProvider = Provider<TonariDatabase>((ref) {
  final db = TonariDatabase();
  ref.onDispose(db.close);
  return db;
});
