import 'package:drift/drift.dart';

/// Listening time per local calendar day and work, accumulated by the player
/// while audio is actually playing. No foreign key: totals outlive deleted
/// works.
class ListenLogs extends Table {
  /// Local date as `yyyy-MM-dd`.
  TextColumn get day => text()();
  TextColumn get workId => text()();
  IntColumn get listenedMs => integer()();

  @override
  Set<Column> get primaryKey => {day, workId};
}
