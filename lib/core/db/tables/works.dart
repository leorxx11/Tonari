import 'package:drift/drift.dart';

import '../converters.dart';

class Works extends Table {
  TextColumn get productId => text()();
  TextColumn get title => text()();
  TextColumn get titleRomaji => text().nullable()();
  TextColumn get translatedTitle => text().nullable()();

  TextColumn get circleId => text().nullable()();
  TextColumn get circleName => text().nullable()();
  DateTimeColumn get releaseDate => dateTime().nullable()();

  TextColumn get voiceActors => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get illustrators => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get scenarioWriters => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get musicians => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();

  TextColumn get ageRating => text().nullable()();
  TextColumn get workType => text().nullable()();
  TextColumn get workTypeName => text().nullable()();
  TextColumn get fileFormats => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get genresJson => text().withDefault(const Constant('[]'))();
  TextColumn get fileSize => text().nullable()();

  TextColumn get seriesId => text().nullable()();
  TextColumn get seriesName => text().nullable()();
  TextColumn get descriptionHtml => text().nullable()();
  TextColumn get mainImageUrl => text().nullable()();
  TextColumn get sampleImageUrls => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get mainImageLocalPath => text().nullable()();
  TextColumn get sampleImageLocalPaths => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();

  IntColumn get officialPrice => integer().nullable()();
  IntColumn get currentPrice => integer().nullable()();
  IntColumn get discountRate => integer().nullable()();
  RealColumn get rating => real().nullable()();
  IntColumn get ratingCount => integer().nullable()();
  IntColumn get dlCount => integer().nullable()();
  IntColumn get wishlistCount => integer().nullable()();
  IntColumn get reviewCount => integer().nullable()();
  IntColumn get rankDay => integer().nullable()();
  IntColumn get rankWeek => integer().nullable()();
  IntColumn get rankMonth => integer().nullable()();
  TextColumn get supportedLanguages => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();

  DateTimeColumn get scrapedAt => dateTime().nullable()();
  DateTimeColumn get localImportedAt => dateTime()();
  TextColumn get localFolderPath => text()();
  TextColumn get importedFolderId => text().nullable()();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();
  TextColumn get lastPlayedTrackId => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isRemoved => boolean().withDefault(const Constant(false))();
  IntColumn get userRating => integer().nullable()();
  TextColumn get userTags => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {productId};
}
