import 'package:drift/drift.dart';

import 'tracks.dart';

class Subtitles extends Table {
  TextColumn get id => text()();
  TextColumn get trackId => text().references(Tracks, #id)();

  TextColumn get filePath => text()();
  TextColumn get fileFormat => text()();
  TextColumn get fileHash => text()();

  IntColumn get timeOffsetMs => integer().withDefault(const Constant(0))();
  TextColumn get originalLinesJson => text()();
  TextColumn get translatedLinesJson => text().nullable()();
  DateTimeColumn get translatedAt => dateTime().nullable()();
  TextColumn get translatedByModel => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
