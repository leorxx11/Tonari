import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'converters.dart';
import 'tables/subtitles.dart';
import 'tables/tracks.dart';
import 'tables/works.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Works, Tracks, Subtitles])
class TonariDatabase extends _$TonariDatabase {
  TonariDatabase() : super(_openConnection());

  TonariDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'tonari');
  }
}
