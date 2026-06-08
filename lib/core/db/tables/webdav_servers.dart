import 'package:drift/drift.dart';

class WebdavServers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get scheme => text()();
  TextColumn get host => text()();
  IntColumn get port => integer().nullable()();
  TextColumn get basePath => text().nullable()();
  TextColumn get username => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
