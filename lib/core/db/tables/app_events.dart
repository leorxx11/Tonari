import 'package:drift/drift.dart';

class AppEvents extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAt => dateTime()();

  TextColumn get category => text()();
  TextColumn get severity => text()();
  TextColumn get title => text()();
  TextColumn get detail => text().withDefault(const Constant(''))();

  TextColumn get productId => text().nullable()();
  TextColumn get workTitle => text().nullable()();
  TextColumn get sourceName => text().nullable()();
  TextColumn get actionKey => text().nullable()();

  IntColumn get count => integer().withDefault(const Constant(1))();
  BoolColumn get read => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
