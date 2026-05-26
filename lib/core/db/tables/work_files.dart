import 'package:drift/drift.dart';

import 'works.dart';

class WorkFiles extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().references(Works, #productId)();

  TextColumn get filePath => text()();
  TextColumn get relativePath => text()();
  TextColumn get fileName => text()();

  /// 'image' / 'subtitle' / 'text' / 'other'
  TextColumn get fileKind => text()();
  IntColumn get fileSizeBytes => integer()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
