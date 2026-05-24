import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'converters.dart';
import 'tables/imported_folders.dart';
import 'tables/subtitles.dart';
import 'tables/tracks.dart';
import 'tables/works.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Works, Tracks, Subtitles, ImportedFolders])
class TonariDatabase extends _$TonariDatabase {
  TonariDatabase() : super(_openConnection());

  TonariDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(works, works.isRemoved);
      }
      if (from < 3) {
        await m.addColumn(works, works.importedFolderId);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'tonari');
  }
}
