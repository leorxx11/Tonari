import 'package:drift/drift.dart';

class ImportedFolders extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get bookmarkBase64 => text()();

  TextColumn get type => text().withDefault(const Constant('local'))();
  TextColumn get serverId => text().nullable()();
  TextColumn get remotePath => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
