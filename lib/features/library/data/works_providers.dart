import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';

final allWorksProvider = StreamProvider<List<Work>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.works)
        ..orderBy([(w) => OrderingTerm.desc(w.localImportedAt)]))
      .watch();
});
