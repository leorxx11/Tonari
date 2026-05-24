import 'package:drift/drift.dart';

import 'works.dart';

class Tracks extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().references(Works, #productId)();

  TextColumn get filePath => text()();
  TextColumn get fileName => text()();
  TextColumn get fileFormat => text()();
  IntColumn get fileSizeBytes => integer()();
  IntColumn get durationMs => integer()();
  IntColumn get sampleRate => integer().nullable()();
  IntColumn get bitRate => integer().nullable()();

  TextColumn get categoryHint => text().nullable()();
  TextColumn get userCategory => text().nullable()();
  TextColumn get parentDirName => text()();
  IntColumn get trackNumber => integer().nullable()();
  TextColumn get title => text()();
  TextColumn get alternateQualityPathsJson =>
      text().withDefault(const Constant('{}'))();

  IntColumn get lastPositionMs => integer().withDefault(const Constant(0))();
  IntColumn get playCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
