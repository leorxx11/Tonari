import 'package:drift/drift.dart';

/// Hand-picked video library entries. `id` follows the same stable-identity
/// scheme as play history (`p115:<pickcode>` / `<kind>:<sourceId>:<path>`),
/// so history rows, library rows and resume positions all line up.
class VideoItems extends Table {
  TextColumn get id => text()();
  TextColumn get sourceKind => text()();
  TextColumn get sourceId => text()();
  TextColumn get sourceName => text()();
  TextColumn get path => text()();
  TextColumn get fileName => text()();
  TextColumn get pickcode => text().nullable()();
  IntColumn get size => integer().nullable()();
  TextColumn get customTitle => text().nullable()();

  /// Cover image path relative to the documents directory.
  TextColumn get coverPath => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CollectionVideos extends Table {
  TextColumn get collectionId => text()();
  TextColumn get videoId => text()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {collectionId, videoId};
}
