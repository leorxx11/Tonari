import 'package:drift/drift.dart';

/// One row per played thing, upserted on replay so the list stays deduped.
/// `id` is a stable identity that survives entry points and (for 115) renames:
/// works use `work:<productId>`, 115 files `p115:<pickcode>`, webdav/local
/// files `<sourceKind>:<sourceId>:<path>`.
@DataClassName('PlayHistoryEntry')
class PlayHistoryEntries extends Table {
  TextColumn get id => text()();

  /// 'work' | 'audio' | 'video'
  TextColumn get kind => text()();
  TextColumn get title => text()();
  TextColumn get workId => text().nullable()();
  TextColumn get sourceKind => text().nullable()();
  TextColumn get sourceId => text().nullable()();
  TextColumn get sourceName => text().nullable()();
  TextColumn get path => text().nullable()();
  TextColumn get fileName => text().nullable()();
  TextColumn get pickcode => text().nullable()();
  IntColumn get size => integer().nullable()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().nullable()();
  DateTimeColumn get playedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
