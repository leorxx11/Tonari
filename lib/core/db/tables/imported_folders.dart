import 'package:drift/drift.dart';

class ImportedFolders extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get bookmarkBase64 => text()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
