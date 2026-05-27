// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $WorksTable extends Works with TableInfo<$WorksTable, Work> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleRomajiMeta = const VerificationMeta(
    'titleRomaji',
  );
  @override
  late final GeneratedColumn<String> titleRomaji = GeneratedColumn<String>(
    'title_romaji',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _translatedTitleMeta = const VerificationMeta(
    'translatedTitle',
  );
  @override
  late final GeneratedColumn<String> translatedTitle = GeneratedColumn<String>(
    'translated_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalProductIdMeta = const VerificationMeta(
    'originalProductId',
  );
  @override
  late final GeneratedColumn<String> originalProductId =
      GeneratedColumn<String>(
        'original_product_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _circleIdMeta = const VerificationMeta(
    'circleId',
  );
  @override
  late final GeneratedColumn<String> circleId = GeneratedColumn<String>(
    'circle_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _circleNameMeta = const VerificationMeta(
    'circleName',
  );
  @override
  late final GeneratedColumn<String> circleName = GeneratedColumn<String>(
    'circle_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _releaseDateMeta = const VerificationMeta(
    'releaseDate',
  );
  @override
  late final GeneratedColumn<DateTime> releaseDate = GeneratedColumn<DateTime>(
    'release_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  voiceActors = GeneratedColumn<String>(
    'voice_actors',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($WorksTable.$convertervoiceActors);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  illustrators = GeneratedColumn<String>(
    'illustrators',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($WorksTable.$converterillustrators);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  scenarioWriters = GeneratedColumn<String>(
    'scenario_writers',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($WorksTable.$converterscenarioWriters);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> musicians =
      GeneratedColumn<String>(
        'musicians',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($WorksTable.$convertermusicians);
  static const VerificationMeta _ageRatingMeta = const VerificationMeta(
    'ageRating',
  );
  @override
  late final GeneratedColumn<String> ageRating = GeneratedColumn<String>(
    'age_rating',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workTypeMeta = const VerificationMeta(
    'workType',
  );
  @override
  late final GeneratedColumn<String> workType = GeneratedColumn<String>(
    'work_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workTypeNameMeta = const VerificationMeta(
    'workTypeName',
  );
  @override
  late final GeneratedColumn<String> workTypeName = GeneratedColumn<String>(
    'work_type_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  fileFormats = GeneratedColumn<String>(
    'file_formats',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($WorksTable.$converterfileFormats);
  static const VerificationMeta _genresJsonMeta = const VerificationMeta(
    'genresJson',
  );
  @override
  late final GeneratedColumn<String> genresJson = GeneratedColumn<String>(
    'genres_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<String> fileSize = GeneratedColumn<String>(
    'file_size',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
    'series_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seriesNameMeta = const VerificationMeta(
    'seriesName',
  );
  @override
  late final GeneratedColumn<String> seriesName = GeneratedColumn<String>(
    'series_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionHtmlMeta = const VerificationMeta(
    'descriptionHtml',
  );
  @override
  late final GeneratedColumn<String> descriptionHtml = GeneratedColumn<String>(
    'description_html',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleZhMeta = const VerificationMeta(
    'titleZh',
  );
  @override
  late final GeneratedColumn<String> titleZh = GeneratedColumn<String>(
    'title_zh',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionHtmlZhMeta = const VerificationMeta(
    'descriptionHtmlZh',
  );
  @override
  late final GeneratedColumn<String> descriptionHtmlZh =
      GeneratedColumn<String>(
        'description_html_zh',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _mainImageUrlMeta = const VerificationMeta(
    'mainImageUrl',
  );
  @override
  late final GeneratedColumn<String> mainImageUrl = GeneratedColumn<String>(
    'main_image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  sampleImageUrls = GeneratedColumn<String>(
    'sample_image_urls',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($WorksTable.$convertersampleImageUrls);
  static const VerificationMeta _mainImageLocalPathMeta =
      const VerificationMeta('mainImageLocalPath');
  @override
  late final GeneratedColumn<String> mainImageLocalPath =
      GeneratedColumn<String>(
        'main_image_local_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  sampleImageLocalPaths = GeneratedColumn<String>(
    'sample_image_local_paths',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($WorksTable.$convertersampleImageLocalPaths);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  descriptionImageLocalPaths =
      GeneratedColumn<String>(
        'description_image_local_paths',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>(
        $WorksTable.$converterdescriptionImageLocalPaths,
      );
  static const VerificationMeta _officialPriceMeta = const VerificationMeta(
    'officialPrice',
  );
  @override
  late final GeneratedColumn<int> officialPrice = GeneratedColumn<int>(
    'official_price',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentPriceMeta = const VerificationMeta(
    'currentPrice',
  );
  @override
  late final GeneratedColumn<int> currentPrice = GeneratedColumn<int>(
    'current_price',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discountRateMeta = const VerificationMeta(
    'discountRate',
  );
  @override
  late final GeneratedColumn<int> discountRate = GeneratedColumn<int>(
    'discount_rate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingCountMeta = const VerificationMeta(
    'ratingCount',
  );
  @override
  late final GeneratedColumn<int> ratingCount = GeneratedColumn<int>(
    'rating_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dlCountMeta = const VerificationMeta(
    'dlCount',
  );
  @override
  late final GeneratedColumn<int> dlCount = GeneratedColumn<int>(
    'dl_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wishlistCountMeta = const VerificationMeta(
    'wishlistCount',
  );
  @override
  late final GeneratedColumn<int> wishlistCount = GeneratedColumn<int>(
    'wishlist_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reviewCountMeta = const VerificationMeta(
    'reviewCount',
  );
  @override
  late final GeneratedColumn<int> reviewCount = GeneratedColumn<int>(
    'review_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rankDayMeta = const VerificationMeta(
    'rankDay',
  );
  @override
  late final GeneratedColumn<int> rankDay = GeneratedColumn<int>(
    'rank_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rankWeekMeta = const VerificationMeta(
    'rankWeek',
  );
  @override
  late final GeneratedColumn<int> rankWeek = GeneratedColumn<int>(
    'rank_week',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rankMonthMeta = const VerificationMeta(
    'rankMonth',
  );
  @override
  late final GeneratedColumn<int> rankMonth = GeneratedColumn<int>(
    'rank_month',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  supportedLanguages = GeneratedColumn<String>(
    'supported_languages',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($WorksTable.$convertersupportedLanguages);
  static const VerificationMeta _scrapedAtMeta = const VerificationMeta(
    'scrapedAt',
  );
  @override
  late final GeneratedColumn<DateTime> scrapedAt = GeneratedColumn<DateTime>(
    'scraped_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localImportedAtMeta = const VerificationMeta(
    'localImportedAt',
  );
  @override
  late final GeneratedColumn<DateTime> localImportedAt =
      GeneratedColumn<DateTime>(
        'local_imported_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _localFolderPathMeta = const VerificationMeta(
    'localFolderPath',
  );
  @override
  late final GeneratedColumn<String> localFolderPath = GeneratedColumn<String>(
    'local_folder_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedFolderIdMeta = const VerificationMeta(
    'importedFolderId',
  );
  @override
  late final GeneratedColumn<String> importedFolderId = GeneratedColumn<String>(
    'imported_folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPlayedAt = GeneratedColumn<DateTime>(
    'last_played_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastPlayedTrackIdMeta = const VerificationMeta(
    'lastPlayedTrackId',
  );
  @override
  late final GeneratedColumn<String> lastPlayedTrackId =
      GeneratedColumn<String>(
        'last_played_track_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isRemovedMeta = const VerificationMeta(
    'isRemoved',
  );
  @override
  late final GeneratedColumn<bool> isRemoved = GeneratedColumn<bool>(
    'is_removed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_removed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _needsRescanMeta = const VerificationMeta(
    'needsRescan',
  );
  @override
  late final GeneratedColumn<bool> needsRescan = GeneratedColumn<bool>(
    'needs_rescan',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_rescan" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _userRatingMeta = const VerificationMeta(
    'userRating',
  );
  @override
  late final GeneratedColumn<int> userRating = GeneratedColumn<int>(
    'user_rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> userTags =
      GeneratedColumn<String>(
        'user_tags',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($WorksTable.$converteruserTags);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    productId,
    title,
    titleRomaji,
    translatedTitle,
    originalProductId,
    circleId,
    circleName,
    releaseDate,
    voiceActors,
    illustrators,
    scenarioWriters,
    musicians,
    ageRating,
    workType,
    workTypeName,
    fileFormats,
    genresJson,
    fileSize,
    seriesId,
    seriesName,
    descriptionHtml,
    titleZh,
    descriptionHtmlZh,
    mainImageUrl,
    sampleImageUrls,
    mainImageLocalPath,
    sampleImageLocalPaths,
    descriptionImageLocalPaths,
    officialPrice,
    currentPrice,
    discountRate,
    rating,
    ratingCount,
    dlCount,
    wishlistCount,
    reviewCount,
    rankDay,
    rankWeek,
    rankMonth,
    supportedLanguages,
    scrapedAt,
    localImportedAt,
    localFolderPath,
    importedFolderId,
    lastPlayedAt,
    lastPlayedTrackId,
    isFavorite,
    isRemoved,
    needsRescan,
    userRating,
    userTags,
    notes,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'works';
  @override
  VerificationContext validateIntegrity(
    Insertable<Work> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('title_romaji')) {
      context.handle(
        _titleRomajiMeta,
        titleRomaji.isAcceptableOrUnknown(
          data['title_romaji']!,
          _titleRomajiMeta,
        ),
      );
    }
    if (data.containsKey('translated_title')) {
      context.handle(
        _translatedTitleMeta,
        translatedTitle.isAcceptableOrUnknown(
          data['translated_title']!,
          _translatedTitleMeta,
        ),
      );
    }
    if (data.containsKey('original_product_id')) {
      context.handle(
        _originalProductIdMeta,
        originalProductId.isAcceptableOrUnknown(
          data['original_product_id']!,
          _originalProductIdMeta,
        ),
      );
    }
    if (data.containsKey('circle_id')) {
      context.handle(
        _circleIdMeta,
        circleId.isAcceptableOrUnknown(data['circle_id']!, _circleIdMeta),
      );
    }
    if (data.containsKey('circle_name')) {
      context.handle(
        _circleNameMeta,
        circleName.isAcceptableOrUnknown(data['circle_name']!, _circleNameMeta),
      );
    }
    if (data.containsKey('release_date')) {
      context.handle(
        _releaseDateMeta,
        releaseDate.isAcceptableOrUnknown(
          data['release_date']!,
          _releaseDateMeta,
        ),
      );
    }
    if (data.containsKey('age_rating')) {
      context.handle(
        _ageRatingMeta,
        ageRating.isAcceptableOrUnknown(data['age_rating']!, _ageRatingMeta),
      );
    }
    if (data.containsKey('work_type')) {
      context.handle(
        _workTypeMeta,
        workType.isAcceptableOrUnknown(data['work_type']!, _workTypeMeta),
      );
    }
    if (data.containsKey('work_type_name')) {
      context.handle(
        _workTypeNameMeta,
        workTypeName.isAcceptableOrUnknown(
          data['work_type_name']!,
          _workTypeNameMeta,
        ),
      );
    }
    if (data.containsKey('genres_json')) {
      context.handle(
        _genresJsonMeta,
        genresJson.isAcceptableOrUnknown(data['genres_json']!, _genresJsonMeta),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    }
    if (data.containsKey('series_name')) {
      context.handle(
        _seriesNameMeta,
        seriesName.isAcceptableOrUnknown(data['series_name']!, _seriesNameMeta),
      );
    }
    if (data.containsKey('description_html')) {
      context.handle(
        _descriptionHtmlMeta,
        descriptionHtml.isAcceptableOrUnknown(
          data['description_html']!,
          _descriptionHtmlMeta,
        ),
      );
    }
    if (data.containsKey('title_zh')) {
      context.handle(
        _titleZhMeta,
        titleZh.isAcceptableOrUnknown(data['title_zh']!, _titleZhMeta),
      );
    }
    if (data.containsKey('description_html_zh')) {
      context.handle(
        _descriptionHtmlZhMeta,
        descriptionHtmlZh.isAcceptableOrUnknown(
          data['description_html_zh']!,
          _descriptionHtmlZhMeta,
        ),
      );
    }
    if (data.containsKey('main_image_url')) {
      context.handle(
        _mainImageUrlMeta,
        mainImageUrl.isAcceptableOrUnknown(
          data['main_image_url']!,
          _mainImageUrlMeta,
        ),
      );
    }
    if (data.containsKey('main_image_local_path')) {
      context.handle(
        _mainImageLocalPathMeta,
        mainImageLocalPath.isAcceptableOrUnknown(
          data['main_image_local_path']!,
          _mainImageLocalPathMeta,
        ),
      );
    }
    if (data.containsKey('official_price')) {
      context.handle(
        _officialPriceMeta,
        officialPrice.isAcceptableOrUnknown(
          data['official_price']!,
          _officialPriceMeta,
        ),
      );
    }
    if (data.containsKey('current_price')) {
      context.handle(
        _currentPriceMeta,
        currentPrice.isAcceptableOrUnknown(
          data['current_price']!,
          _currentPriceMeta,
        ),
      );
    }
    if (data.containsKey('discount_rate')) {
      context.handle(
        _discountRateMeta,
        discountRate.isAcceptableOrUnknown(
          data['discount_rate']!,
          _discountRateMeta,
        ),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('rating_count')) {
      context.handle(
        _ratingCountMeta,
        ratingCount.isAcceptableOrUnknown(
          data['rating_count']!,
          _ratingCountMeta,
        ),
      );
    }
    if (data.containsKey('dl_count')) {
      context.handle(
        _dlCountMeta,
        dlCount.isAcceptableOrUnknown(data['dl_count']!, _dlCountMeta),
      );
    }
    if (data.containsKey('wishlist_count')) {
      context.handle(
        _wishlistCountMeta,
        wishlistCount.isAcceptableOrUnknown(
          data['wishlist_count']!,
          _wishlistCountMeta,
        ),
      );
    }
    if (data.containsKey('review_count')) {
      context.handle(
        _reviewCountMeta,
        reviewCount.isAcceptableOrUnknown(
          data['review_count']!,
          _reviewCountMeta,
        ),
      );
    }
    if (data.containsKey('rank_day')) {
      context.handle(
        _rankDayMeta,
        rankDay.isAcceptableOrUnknown(data['rank_day']!, _rankDayMeta),
      );
    }
    if (data.containsKey('rank_week')) {
      context.handle(
        _rankWeekMeta,
        rankWeek.isAcceptableOrUnknown(data['rank_week']!, _rankWeekMeta),
      );
    }
    if (data.containsKey('rank_month')) {
      context.handle(
        _rankMonthMeta,
        rankMonth.isAcceptableOrUnknown(data['rank_month']!, _rankMonthMeta),
      );
    }
    if (data.containsKey('scraped_at')) {
      context.handle(
        _scrapedAtMeta,
        scrapedAt.isAcceptableOrUnknown(data['scraped_at']!, _scrapedAtMeta),
      );
    }
    if (data.containsKey('local_imported_at')) {
      context.handle(
        _localImportedAtMeta,
        localImportedAt.isAcceptableOrUnknown(
          data['local_imported_at']!,
          _localImportedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localImportedAtMeta);
    }
    if (data.containsKey('local_folder_path')) {
      context.handle(
        _localFolderPathMeta,
        localFolderPath.isAcceptableOrUnknown(
          data['local_folder_path']!,
          _localFolderPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localFolderPathMeta);
    }
    if (data.containsKey('imported_folder_id')) {
      context.handle(
        _importedFolderIdMeta,
        importedFolderId.isAcceptableOrUnknown(
          data['imported_folder_id']!,
          _importedFolderIdMeta,
        ),
      );
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_played_track_id')) {
      context.handle(
        _lastPlayedTrackIdMeta,
        lastPlayedTrackId.isAcceptableOrUnknown(
          data['last_played_track_id']!,
          _lastPlayedTrackIdMeta,
        ),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('is_removed')) {
      context.handle(
        _isRemovedMeta,
        isRemoved.isAcceptableOrUnknown(data['is_removed']!, _isRemovedMeta),
      );
    }
    if (data.containsKey('needs_rescan')) {
      context.handle(
        _needsRescanMeta,
        needsRescan.isAcceptableOrUnknown(
          data['needs_rescan']!,
          _needsRescanMeta,
        ),
      );
    }
    if (data.containsKey('user_rating')) {
      context.handle(
        _userRatingMeta,
        userRating.isAcceptableOrUnknown(data['user_rating']!, _userRatingMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {productId};
  @override
  Work map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Work(
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      titleRomaji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_romaji'],
      ),
      translatedTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translated_title'],
      ),
      originalProductId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_product_id'],
      ),
      circleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}circle_id'],
      ),
      circleName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}circle_name'],
      ),
      releaseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}release_date'],
      ),
      voiceActors: $WorksTable.$convertervoiceActors.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}voice_actors'],
        )!,
      ),
      illustrators: $WorksTable.$converterillustrators.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}illustrators'],
        )!,
      ),
      scenarioWriters: $WorksTable.$converterscenarioWriters.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}scenario_writers'],
        )!,
      ),
      musicians: $WorksTable.$convertermusicians.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}musicians'],
        )!,
      ),
      ageRating: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}age_rating'],
      ),
      workType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_type'],
      ),
      workTypeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_type_name'],
      ),
      fileFormats: $WorksTable.$converterfileFormats.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}file_formats'],
        )!,
      ),
      genresJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genres_json'],
      )!,
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_size'],
      ),
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_id'],
      ),
      seriesName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_name'],
      ),
      descriptionHtml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description_html'],
      ),
      titleZh: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_zh'],
      ),
      descriptionHtmlZh: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description_html_zh'],
      ),
      mainImageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}main_image_url'],
      ),
      sampleImageUrls: $WorksTable.$convertersampleImageUrls.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sample_image_urls'],
        )!,
      ),
      mainImageLocalPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}main_image_local_path'],
      ),
      sampleImageLocalPaths: $WorksTable.$convertersampleImageLocalPaths
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}sample_image_local_paths'],
            )!,
          ),
      descriptionImageLocalPaths: $WorksTable
          .$converterdescriptionImageLocalPaths
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}description_image_local_paths'],
            )!,
          ),
      officialPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}official_price'],
      ),
      currentPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_price'],
      ),
      discountRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discount_rate'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rating'],
      ),
      ratingCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating_count'],
      ),
      dlCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dl_count'],
      ),
      wishlistCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wishlist_count'],
      ),
      reviewCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}review_count'],
      ),
      rankDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rank_day'],
      ),
      rankWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rank_week'],
      ),
      rankMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rank_month'],
      ),
      supportedLanguages: $WorksTable.$convertersupportedLanguages.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}supported_languages'],
        )!,
      ),
      scrapedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scraped_at'],
      ),
      localImportedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}local_imported_at'],
      )!,
      localFolderPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_folder_path'],
      )!,
      importedFolderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imported_folder_id'],
      ),
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_played_at'],
      ),
      lastPlayedTrackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_played_track_id'],
      ),
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      isRemoved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_removed'],
      )!,
      needsRescan: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_rescan'],
      )!,
      userRating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_rating'],
      ),
      userTags: $WorksTable.$converteruserTags.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}user_tags'],
        )!,
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $WorksTable createAlias(String alias) {
    return $WorksTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $convertervoiceActors =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterillustrators =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterscenarioWriters =
      const StringListConverter();
  static TypeConverter<List<String>, String> $convertermusicians =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterfileFormats =
      const StringListConverter();
  static TypeConverter<List<String>, String> $convertersampleImageUrls =
      const StringListConverter();
  static TypeConverter<List<String>, String> $convertersampleImageLocalPaths =
      const StringListConverter();
  static TypeConverter<List<String>, String>
  $converterdescriptionImageLocalPaths = const StringListConverter();
  static TypeConverter<List<String>, String> $convertersupportedLanguages =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converteruserTags =
      const StringListConverter();
}

class Work extends DataClass implements Insertable<Work> {
  final String productId;
  final String title;
  final String? titleRomaji;
  final String? translatedTitle;

  /// When this row is a DLsite translation edition (e.g. "大家一起来翻译"),
  /// the original Japanese release's RJ number. Lets enrichment fall back to
  /// the original work's image gallery / cast / runtime when the translated
  /// page is sparse. Null for non-translated works.
  final String? originalProductId;
  final String? circleId;
  final String? circleName;
  final DateTime? releaseDate;
  final List<String> voiceActors;
  final List<String> illustrators;
  final List<String> scenarioWriters;
  final List<String> musicians;
  final String? ageRating;
  final String? workType;
  final String? workTypeName;
  final List<String> fileFormats;
  final String genresJson;
  final String? fileSize;
  final String? seriesId;
  final String? seriesName;
  final String? descriptionHtml;
  final String? titleZh;
  final String? descriptionHtmlZh;
  final String? mainImageUrl;
  final List<String> sampleImageUrls;
  final String? mainImageLocalPath;
  final List<String> sampleImageLocalPaths;
  final List<String> descriptionImageLocalPaths;
  final int? officialPrice;
  final int? currentPrice;
  final int? discountRate;
  final double? rating;
  final int? ratingCount;
  final int? dlCount;
  final int? wishlistCount;
  final int? reviewCount;
  final int? rankDay;
  final int? rankWeek;
  final int? rankMonth;
  final List<String> supportedLanguages;
  final DateTime? scrapedAt;
  final DateTime localImportedAt;
  final String localFolderPath;
  final String? importedFolderId;
  final DateTime? lastPlayedAt;
  final String? lastPlayedTrackId;
  final bool isFavorite;
  final bool isRemoved;
  final bool needsRescan;
  final int? userRating;
  final List<String> userTags;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Work({
    required this.productId,
    required this.title,
    this.titleRomaji,
    this.translatedTitle,
    this.originalProductId,
    this.circleId,
    this.circleName,
    this.releaseDate,
    required this.voiceActors,
    required this.illustrators,
    required this.scenarioWriters,
    required this.musicians,
    this.ageRating,
    this.workType,
    this.workTypeName,
    required this.fileFormats,
    required this.genresJson,
    this.fileSize,
    this.seriesId,
    this.seriesName,
    this.descriptionHtml,
    this.titleZh,
    this.descriptionHtmlZh,
    this.mainImageUrl,
    required this.sampleImageUrls,
    this.mainImageLocalPath,
    required this.sampleImageLocalPaths,
    required this.descriptionImageLocalPaths,
    this.officialPrice,
    this.currentPrice,
    this.discountRate,
    this.rating,
    this.ratingCount,
    this.dlCount,
    this.wishlistCount,
    this.reviewCount,
    this.rankDay,
    this.rankWeek,
    this.rankMonth,
    required this.supportedLanguages,
    this.scrapedAt,
    required this.localImportedAt,
    required this.localFolderPath,
    this.importedFolderId,
    this.lastPlayedAt,
    this.lastPlayedTrackId,
    required this.isFavorite,
    required this.isRemoved,
    required this.needsRescan,
    this.userRating,
    required this.userTags,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['product_id'] = Variable<String>(productId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || titleRomaji != null) {
      map['title_romaji'] = Variable<String>(titleRomaji);
    }
    if (!nullToAbsent || translatedTitle != null) {
      map['translated_title'] = Variable<String>(translatedTitle);
    }
    if (!nullToAbsent || originalProductId != null) {
      map['original_product_id'] = Variable<String>(originalProductId);
    }
    if (!nullToAbsent || circleId != null) {
      map['circle_id'] = Variable<String>(circleId);
    }
    if (!nullToAbsent || circleName != null) {
      map['circle_name'] = Variable<String>(circleName);
    }
    if (!nullToAbsent || releaseDate != null) {
      map['release_date'] = Variable<DateTime>(releaseDate);
    }
    {
      map['voice_actors'] = Variable<String>(
        $WorksTable.$convertervoiceActors.toSql(voiceActors),
      );
    }
    {
      map['illustrators'] = Variable<String>(
        $WorksTable.$converterillustrators.toSql(illustrators),
      );
    }
    {
      map['scenario_writers'] = Variable<String>(
        $WorksTable.$converterscenarioWriters.toSql(scenarioWriters),
      );
    }
    {
      map['musicians'] = Variable<String>(
        $WorksTable.$convertermusicians.toSql(musicians),
      );
    }
    if (!nullToAbsent || ageRating != null) {
      map['age_rating'] = Variable<String>(ageRating);
    }
    if (!nullToAbsent || workType != null) {
      map['work_type'] = Variable<String>(workType);
    }
    if (!nullToAbsent || workTypeName != null) {
      map['work_type_name'] = Variable<String>(workTypeName);
    }
    {
      map['file_formats'] = Variable<String>(
        $WorksTable.$converterfileFormats.toSql(fileFormats),
      );
    }
    map['genres_json'] = Variable<String>(genresJson);
    if (!nullToAbsent || fileSize != null) {
      map['file_size'] = Variable<String>(fileSize);
    }
    if (!nullToAbsent || seriesId != null) {
      map['series_id'] = Variable<String>(seriesId);
    }
    if (!nullToAbsent || seriesName != null) {
      map['series_name'] = Variable<String>(seriesName);
    }
    if (!nullToAbsent || descriptionHtml != null) {
      map['description_html'] = Variable<String>(descriptionHtml);
    }
    if (!nullToAbsent || titleZh != null) {
      map['title_zh'] = Variable<String>(titleZh);
    }
    if (!nullToAbsent || descriptionHtmlZh != null) {
      map['description_html_zh'] = Variable<String>(descriptionHtmlZh);
    }
    if (!nullToAbsent || mainImageUrl != null) {
      map['main_image_url'] = Variable<String>(mainImageUrl);
    }
    {
      map['sample_image_urls'] = Variable<String>(
        $WorksTable.$convertersampleImageUrls.toSql(sampleImageUrls),
      );
    }
    if (!nullToAbsent || mainImageLocalPath != null) {
      map['main_image_local_path'] = Variable<String>(mainImageLocalPath);
    }
    {
      map['sample_image_local_paths'] = Variable<String>(
        $WorksTable.$convertersampleImageLocalPaths.toSql(
          sampleImageLocalPaths,
        ),
      );
    }
    {
      map['description_image_local_paths'] = Variable<String>(
        $WorksTable.$converterdescriptionImageLocalPaths.toSql(
          descriptionImageLocalPaths,
        ),
      );
    }
    if (!nullToAbsent || officialPrice != null) {
      map['official_price'] = Variable<int>(officialPrice);
    }
    if (!nullToAbsent || currentPrice != null) {
      map['current_price'] = Variable<int>(currentPrice);
    }
    if (!nullToAbsent || discountRate != null) {
      map['discount_rate'] = Variable<int>(discountRate);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<double>(rating);
    }
    if (!nullToAbsent || ratingCount != null) {
      map['rating_count'] = Variable<int>(ratingCount);
    }
    if (!nullToAbsent || dlCount != null) {
      map['dl_count'] = Variable<int>(dlCount);
    }
    if (!nullToAbsent || wishlistCount != null) {
      map['wishlist_count'] = Variable<int>(wishlistCount);
    }
    if (!nullToAbsent || reviewCount != null) {
      map['review_count'] = Variable<int>(reviewCount);
    }
    if (!nullToAbsent || rankDay != null) {
      map['rank_day'] = Variable<int>(rankDay);
    }
    if (!nullToAbsent || rankWeek != null) {
      map['rank_week'] = Variable<int>(rankWeek);
    }
    if (!nullToAbsent || rankMonth != null) {
      map['rank_month'] = Variable<int>(rankMonth);
    }
    {
      map['supported_languages'] = Variable<String>(
        $WorksTable.$convertersupportedLanguages.toSql(supportedLanguages),
      );
    }
    if (!nullToAbsent || scrapedAt != null) {
      map['scraped_at'] = Variable<DateTime>(scrapedAt);
    }
    map['local_imported_at'] = Variable<DateTime>(localImportedAt);
    map['local_folder_path'] = Variable<String>(localFolderPath);
    if (!nullToAbsent || importedFolderId != null) {
      map['imported_folder_id'] = Variable<String>(importedFolderId);
    }
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt);
    }
    if (!nullToAbsent || lastPlayedTrackId != null) {
      map['last_played_track_id'] = Variable<String>(lastPlayedTrackId);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['is_removed'] = Variable<bool>(isRemoved);
    map['needs_rescan'] = Variable<bool>(needsRescan);
    if (!nullToAbsent || userRating != null) {
      map['user_rating'] = Variable<int>(userRating);
    }
    {
      map['user_tags'] = Variable<String>(
        $WorksTable.$converteruserTags.toSql(userTags),
      );
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WorksCompanion toCompanion(bool nullToAbsent) {
    return WorksCompanion(
      productId: Value(productId),
      title: Value(title),
      titleRomaji: titleRomaji == null && nullToAbsent
          ? const Value.absent()
          : Value(titleRomaji),
      translatedTitle: translatedTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(translatedTitle),
      originalProductId: originalProductId == null && nullToAbsent
          ? const Value.absent()
          : Value(originalProductId),
      circleId: circleId == null && nullToAbsent
          ? const Value.absent()
          : Value(circleId),
      circleName: circleName == null && nullToAbsent
          ? const Value.absent()
          : Value(circleName),
      releaseDate: releaseDate == null && nullToAbsent
          ? const Value.absent()
          : Value(releaseDate),
      voiceActors: Value(voiceActors),
      illustrators: Value(illustrators),
      scenarioWriters: Value(scenarioWriters),
      musicians: Value(musicians),
      ageRating: ageRating == null && nullToAbsent
          ? const Value.absent()
          : Value(ageRating),
      workType: workType == null && nullToAbsent
          ? const Value.absent()
          : Value(workType),
      workTypeName: workTypeName == null && nullToAbsent
          ? const Value.absent()
          : Value(workTypeName),
      fileFormats: Value(fileFormats),
      genresJson: Value(genresJson),
      fileSize: fileSize == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSize),
      seriesId: seriesId == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesId),
      seriesName: seriesName == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesName),
      descriptionHtml: descriptionHtml == null && nullToAbsent
          ? const Value.absent()
          : Value(descriptionHtml),
      titleZh: titleZh == null && nullToAbsent
          ? const Value.absent()
          : Value(titleZh),
      descriptionHtmlZh: descriptionHtmlZh == null && nullToAbsent
          ? const Value.absent()
          : Value(descriptionHtmlZh),
      mainImageUrl: mainImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(mainImageUrl),
      sampleImageUrls: Value(sampleImageUrls),
      mainImageLocalPath: mainImageLocalPath == null && nullToAbsent
          ? const Value.absent()
          : Value(mainImageLocalPath),
      sampleImageLocalPaths: Value(sampleImageLocalPaths),
      descriptionImageLocalPaths: Value(descriptionImageLocalPaths),
      officialPrice: officialPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(officialPrice),
      currentPrice: currentPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(currentPrice),
      discountRate: discountRate == null && nullToAbsent
          ? const Value.absent()
          : Value(discountRate),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      ratingCount: ratingCount == null && nullToAbsent
          ? const Value.absent()
          : Value(ratingCount),
      dlCount: dlCount == null && nullToAbsent
          ? const Value.absent()
          : Value(dlCount),
      wishlistCount: wishlistCount == null && nullToAbsent
          ? const Value.absent()
          : Value(wishlistCount),
      reviewCount: reviewCount == null && nullToAbsent
          ? const Value.absent()
          : Value(reviewCount),
      rankDay: rankDay == null && nullToAbsent
          ? const Value.absent()
          : Value(rankDay),
      rankWeek: rankWeek == null && nullToAbsent
          ? const Value.absent()
          : Value(rankWeek),
      rankMonth: rankMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(rankMonth),
      supportedLanguages: Value(supportedLanguages),
      scrapedAt: scrapedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(scrapedAt),
      localImportedAt: Value(localImportedAt),
      localFolderPath: Value(localFolderPath),
      importedFolderId: importedFolderId == null && nullToAbsent
          ? const Value.absent()
          : Value(importedFolderId),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
      lastPlayedTrackId: lastPlayedTrackId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedTrackId),
      isFavorite: Value(isFavorite),
      isRemoved: Value(isRemoved),
      needsRescan: Value(needsRescan),
      userRating: userRating == null && nullToAbsent
          ? const Value.absent()
          : Value(userRating),
      userTags: Value(userTags),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Work.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Work(
      productId: serializer.fromJson<String>(json['productId']),
      title: serializer.fromJson<String>(json['title']),
      titleRomaji: serializer.fromJson<String?>(json['titleRomaji']),
      translatedTitle: serializer.fromJson<String?>(json['translatedTitle']),
      originalProductId: serializer.fromJson<String?>(
        json['originalProductId'],
      ),
      circleId: serializer.fromJson<String?>(json['circleId']),
      circleName: serializer.fromJson<String?>(json['circleName']),
      releaseDate: serializer.fromJson<DateTime?>(json['releaseDate']),
      voiceActors: serializer.fromJson<List<String>>(json['voiceActors']),
      illustrators: serializer.fromJson<List<String>>(json['illustrators']),
      scenarioWriters: serializer.fromJson<List<String>>(
        json['scenarioWriters'],
      ),
      musicians: serializer.fromJson<List<String>>(json['musicians']),
      ageRating: serializer.fromJson<String?>(json['ageRating']),
      workType: serializer.fromJson<String?>(json['workType']),
      workTypeName: serializer.fromJson<String?>(json['workTypeName']),
      fileFormats: serializer.fromJson<List<String>>(json['fileFormats']),
      genresJson: serializer.fromJson<String>(json['genresJson']),
      fileSize: serializer.fromJson<String?>(json['fileSize']),
      seriesId: serializer.fromJson<String?>(json['seriesId']),
      seriesName: serializer.fromJson<String?>(json['seriesName']),
      descriptionHtml: serializer.fromJson<String?>(json['descriptionHtml']),
      titleZh: serializer.fromJson<String?>(json['titleZh']),
      descriptionHtmlZh: serializer.fromJson<String?>(
        json['descriptionHtmlZh'],
      ),
      mainImageUrl: serializer.fromJson<String?>(json['mainImageUrl']),
      sampleImageUrls: serializer.fromJson<List<String>>(
        json['sampleImageUrls'],
      ),
      mainImageLocalPath: serializer.fromJson<String?>(
        json['mainImageLocalPath'],
      ),
      sampleImageLocalPaths: serializer.fromJson<List<String>>(
        json['sampleImageLocalPaths'],
      ),
      descriptionImageLocalPaths: serializer.fromJson<List<String>>(
        json['descriptionImageLocalPaths'],
      ),
      officialPrice: serializer.fromJson<int?>(json['officialPrice']),
      currentPrice: serializer.fromJson<int?>(json['currentPrice']),
      discountRate: serializer.fromJson<int?>(json['discountRate']),
      rating: serializer.fromJson<double?>(json['rating']),
      ratingCount: serializer.fromJson<int?>(json['ratingCount']),
      dlCount: serializer.fromJson<int?>(json['dlCount']),
      wishlistCount: serializer.fromJson<int?>(json['wishlistCount']),
      reviewCount: serializer.fromJson<int?>(json['reviewCount']),
      rankDay: serializer.fromJson<int?>(json['rankDay']),
      rankWeek: serializer.fromJson<int?>(json['rankWeek']),
      rankMonth: serializer.fromJson<int?>(json['rankMonth']),
      supportedLanguages: serializer.fromJson<List<String>>(
        json['supportedLanguages'],
      ),
      scrapedAt: serializer.fromJson<DateTime?>(json['scrapedAt']),
      localImportedAt: serializer.fromJson<DateTime>(json['localImportedAt']),
      localFolderPath: serializer.fromJson<String>(json['localFolderPath']),
      importedFolderId: serializer.fromJson<String?>(json['importedFolderId']),
      lastPlayedAt: serializer.fromJson<DateTime?>(json['lastPlayedAt']),
      lastPlayedTrackId: serializer.fromJson<String?>(
        json['lastPlayedTrackId'],
      ),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      isRemoved: serializer.fromJson<bool>(json['isRemoved']),
      needsRescan: serializer.fromJson<bool>(json['needsRescan']),
      userRating: serializer.fromJson<int?>(json['userRating']),
      userTags: serializer.fromJson<List<String>>(json['userTags']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'productId': serializer.toJson<String>(productId),
      'title': serializer.toJson<String>(title),
      'titleRomaji': serializer.toJson<String?>(titleRomaji),
      'translatedTitle': serializer.toJson<String?>(translatedTitle),
      'originalProductId': serializer.toJson<String?>(originalProductId),
      'circleId': serializer.toJson<String?>(circleId),
      'circleName': serializer.toJson<String?>(circleName),
      'releaseDate': serializer.toJson<DateTime?>(releaseDate),
      'voiceActors': serializer.toJson<List<String>>(voiceActors),
      'illustrators': serializer.toJson<List<String>>(illustrators),
      'scenarioWriters': serializer.toJson<List<String>>(scenarioWriters),
      'musicians': serializer.toJson<List<String>>(musicians),
      'ageRating': serializer.toJson<String?>(ageRating),
      'workType': serializer.toJson<String?>(workType),
      'workTypeName': serializer.toJson<String?>(workTypeName),
      'fileFormats': serializer.toJson<List<String>>(fileFormats),
      'genresJson': serializer.toJson<String>(genresJson),
      'fileSize': serializer.toJson<String?>(fileSize),
      'seriesId': serializer.toJson<String?>(seriesId),
      'seriesName': serializer.toJson<String?>(seriesName),
      'descriptionHtml': serializer.toJson<String?>(descriptionHtml),
      'titleZh': serializer.toJson<String?>(titleZh),
      'descriptionHtmlZh': serializer.toJson<String?>(descriptionHtmlZh),
      'mainImageUrl': serializer.toJson<String?>(mainImageUrl),
      'sampleImageUrls': serializer.toJson<List<String>>(sampleImageUrls),
      'mainImageLocalPath': serializer.toJson<String?>(mainImageLocalPath),
      'sampleImageLocalPaths': serializer.toJson<List<String>>(
        sampleImageLocalPaths,
      ),
      'descriptionImageLocalPaths': serializer.toJson<List<String>>(
        descriptionImageLocalPaths,
      ),
      'officialPrice': serializer.toJson<int?>(officialPrice),
      'currentPrice': serializer.toJson<int?>(currentPrice),
      'discountRate': serializer.toJson<int?>(discountRate),
      'rating': serializer.toJson<double?>(rating),
      'ratingCount': serializer.toJson<int?>(ratingCount),
      'dlCount': serializer.toJson<int?>(dlCount),
      'wishlistCount': serializer.toJson<int?>(wishlistCount),
      'reviewCount': serializer.toJson<int?>(reviewCount),
      'rankDay': serializer.toJson<int?>(rankDay),
      'rankWeek': serializer.toJson<int?>(rankWeek),
      'rankMonth': serializer.toJson<int?>(rankMonth),
      'supportedLanguages': serializer.toJson<List<String>>(supportedLanguages),
      'scrapedAt': serializer.toJson<DateTime?>(scrapedAt),
      'localImportedAt': serializer.toJson<DateTime>(localImportedAt),
      'localFolderPath': serializer.toJson<String>(localFolderPath),
      'importedFolderId': serializer.toJson<String?>(importedFolderId),
      'lastPlayedAt': serializer.toJson<DateTime?>(lastPlayedAt),
      'lastPlayedTrackId': serializer.toJson<String?>(lastPlayedTrackId),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'isRemoved': serializer.toJson<bool>(isRemoved),
      'needsRescan': serializer.toJson<bool>(needsRescan),
      'userRating': serializer.toJson<int?>(userRating),
      'userTags': serializer.toJson<List<String>>(userTags),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Work copyWith({
    String? productId,
    String? title,
    Value<String?> titleRomaji = const Value.absent(),
    Value<String?> translatedTitle = const Value.absent(),
    Value<String?> originalProductId = const Value.absent(),
    Value<String?> circleId = const Value.absent(),
    Value<String?> circleName = const Value.absent(),
    Value<DateTime?> releaseDate = const Value.absent(),
    List<String>? voiceActors,
    List<String>? illustrators,
    List<String>? scenarioWriters,
    List<String>? musicians,
    Value<String?> ageRating = const Value.absent(),
    Value<String?> workType = const Value.absent(),
    Value<String?> workTypeName = const Value.absent(),
    List<String>? fileFormats,
    String? genresJson,
    Value<String?> fileSize = const Value.absent(),
    Value<String?> seriesId = const Value.absent(),
    Value<String?> seriesName = const Value.absent(),
    Value<String?> descriptionHtml = const Value.absent(),
    Value<String?> titleZh = const Value.absent(),
    Value<String?> descriptionHtmlZh = const Value.absent(),
    Value<String?> mainImageUrl = const Value.absent(),
    List<String>? sampleImageUrls,
    Value<String?> mainImageLocalPath = const Value.absent(),
    List<String>? sampleImageLocalPaths,
    List<String>? descriptionImageLocalPaths,
    Value<int?> officialPrice = const Value.absent(),
    Value<int?> currentPrice = const Value.absent(),
    Value<int?> discountRate = const Value.absent(),
    Value<double?> rating = const Value.absent(),
    Value<int?> ratingCount = const Value.absent(),
    Value<int?> dlCount = const Value.absent(),
    Value<int?> wishlistCount = const Value.absent(),
    Value<int?> reviewCount = const Value.absent(),
    Value<int?> rankDay = const Value.absent(),
    Value<int?> rankWeek = const Value.absent(),
    Value<int?> rankMonth = const Value.absent(),
    List<String>? supportedLanguages,
    Value<DateTime?> scrapedAt = const Value.absent(),
    DateTime? localImportedAt,
    String? localFolderPath,
    Value<String?> importedFolderId = const Value.absent(),
    Value<DateTime?> lastPlayedAt = const Value.absent(),
    Value<String?> lastPlayedTrackId = const Value.absent(),
    bool? isFavorite,
    bool? isRemoved,
    bool? needsRescan,
    Value<int?> userRating = const Value.absent(),
    List<String>? userTags,
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Work(
    productId: productId ?? this.productId,
    title: title ?? this.title,
    titleRomaji: titleRomaji.present ? titleRomaji.value : this.titleRomaji,
    translatedTitle: translatedTitle.present
        ? translatedTitle.value
        : this.translatedTitle,
    originalProductId: originalProductId.present
        ? originalProductId.value
        : this.originalProductId,
    circleId: circleId.present ? circleId.value : this.circleId,
    circleName: circleName.present ? circleName.value : this.circleName,
    releaseDate: releaseDate.present ? releaseDate.value : this.releaseDate,
    voiceActors: voiceActors ?? this.voiceActors,
    illustrators: illustrators ?? this.illustrators,
    scenarioWriters: scenarioWriters ?? this.scenarioWriters,
    musicians: musicians ?? this.musicians,
    ageRating: ageRating.present ? ageRating.value : this.ageRating,
    workType: workType.present ? workType.value : this.workType,
    workTypeName: workTypeName.present ? workTypeName.value : this.workTypeName,
    fileFormats: fileFormats ?? this.fileFormats,
    genresJson: genresJson ?? this.genresJson,
    fileSize: fileSize.present ? fileSize.value : this.fileSize,
    seriesId: seriesId.present ? seriesId.value : this.seriesId,
    seriesName: seriesName.present ? seriesName.value : this.seriesName,
    descriptionHtml: descriptionHtml.present
        ? descriptionHtml.value
        : this.descriptionHtml,
    titleZh: titleZh.present ? titleZh.value : this.titleZh,
    descriptionHtmlZh: descriptionHtmlZh.present
        ? descriptionHtmlZh.value
        : this.descriptionHtmlZh,
    mainImageUrl: mainImageUrl.present ? mainImageUrl.value : this.mainImageUrl,
    sampleImageUrls: sampleImageUrls ?? this.sampleImageUrls,
    mainImageLocalPath: mainImageLocalPath.present
        ? mainImageLocalPath.value
        : this.mainImageLocalPath,
    sampleImageLocalPaths: sampleImageLocalPaths ?? this.sampleImageLocalPaths,
    descriptionImageLocalPaths:
        descriptionImageLocalPaths ?? this.descriptionImageLocalPaths,
    officialPrice: officialPrice.present
        ? officialPrice.value
        : this.officialPrice,
    currentPrice: currentPrice.present ? currentPrice.value : this.currentPrice,
    discountRate: discountRate.present ? discountRate.value : this.discountRate,
    rating: rating.present ? rating.value : this.rating,
    ratingCount: ratingCount.present ? ratingCount.value : this.ratingCount,
    dlCount: dlCount.present ? dlCount.value : this.dlCount,
    wishlistCount: wishlistCount.present
        ? wishlistCount.value
        : this.wishlistCount,
    reviewCount: reviewCount.present ? reviewCount.value : this.reviewCount,
    rankDay: rankDay.present ? rankDay.value : this.rankDay,
    rankWeek: rankWeek.present ? rankWeek.value : this.rankWeek,
    rankMonth: rankMonth.present ? rankMonth.value : this.rankMonth,
    supportedLanguages: supportedLanguages ?? this.supportedLanguages,
    scrapedAt: scrapedAt.present ? scrapedAt.value : this.scrapedAt,
    localImportedAt: localImportedAt ?? this.localImportedAt,
    localFolderPath: localFolderPath ?? this.localFolderPath,
    importedFolderId: importedFolderId.present
        ? importedFolderId.value
        : this.importedFolderId,
    lastPlayedAt: lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
    lastPlayedTrackId: lastPlayedTrackId.present
        ? lastPlayedTrackId.value
        : this.lastPlayedTrackId,
    isFavorite: isFavorite ?? this.isFavorite,
    isRemoved: isRemoved ?? this.isRemoved,
    needsRescan: needsRescan ?? this.needsRescan,
    userRating: userRating.present ? userRating.value : this.userRating,
    userTags: userTags ?? this.userTags,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Work copyWithCompanion(WorksCompanion data) {
    return Work(
      productId: data.productId.present ? data.productId.value : this.productId,
      title: data.title.present ? data.title.value : this.title,
      titleRomaji: data.titleRomaji.present
          ? data.titleRomaji.value
          : this.titleRomaji,
      translatedTitle: data.translatedTitle.present
          ? data.translatedTitle.value
          : this.translatedTitle,
      originalProductId: data.originalProductId.present
          ? data.originalProductId.value
          : this.originalProductId,
      circleId: data.circleId.present ? data.circleId.value : this.circleId,
      circleName: data.circleName.present
          ? data.circleName.value
          : this.circleName,
      releaseDate: data.releaseDate.present
          ? data.releaseDate.value
          : this.releaseDate,
      voiceActors: data.voiceActors.present
          ? data.voiceActors.value
          : this.voiceActors,
      illustrators: data.illustrators.present
          ? data.illustrators.value
          : this.illustrators,
      scenarioWriters: data.scenarioWriters.present
          ? data.scenarioWriters.value
          : this.scenarioWriters,
      musicians: data.musicians.present ? data.musicians.value : this.musicians,
      ageRating: data.ageRating.present ? data.ageRating.value : this.ageRating,
      workType: data.workType.present ? data.workType.value : this.workType,
      workTypeName: data.workTypeName.present
          ? data.workTypeName.value
          : this.workTypeName,
      fileFormats: data.fileFormats.present
          ? data.fileFormats.value
          : this.fileFormats,
      genresJson: data.genresJson.present
          ? data.genresJson.value
          : this.genresJson,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      seriesName: data.seriesName.present
          ? data.seriesName.value
          : this.seriesName,
      descriptionHtml: data.descriptionHtml.present
          ? data.descriptionHtml.value
          : this.descriptionHtml,
      titleZh: data.titleZh.present ? data.titleZh.value : this.titleZh,
      descriptionHtmlZh: data.descriptionHtmlZh.present
          ? data.descriptionHtmlZh.value
          : this.descriptionHtmlZh,
      mainImageUrl: data.mainImageUrl.present
          ? data.mainImageUrl.value
          : this.mainImageUrl,
      sampleImageUrls: data.sampleImageUrls.present
          ? data.sampleImageUrls.value
          : this.sampleImageUrls,
      mainImageLocalPath: data.mainImageLocalPath.present
          ? data.mainImageLocalPath.value
          : this.mainImageLocalPath,
      sampleImageLocalPaths: data.sampleImageLocalPaths.present
          ? data.sampleImageLocalPaths.value
          : this.sampleImageLocalPaths,
      descriptionImageLocalPaths: data.descriptionImageLocalPaths.present
          ? data.descriptionImageLocalPaths.value
          : this.descriptionImageLocalPaths,
      officialPrice: data.officialPrice.present
          ? data.officialPrice.value
          : this.officialPrice,
      currentPrice: data.currentPrice.present
          ? data.currentPrice.value
          : this.currentPrice,
      discountRate: data.discountRate.present
          ? data.discountRate.value
          : this.discountRate,
      rating: data.rating.present ? data.rating.value : this.rating,
      ratingCount: data.ratingCount.present
          ? data.ratingCount.value
          : this.ratingCount,
      dlCount: data.dlCount.present ? data.dlCount.value : this.dlCount,
      wishlistCount: data.wishlistCount.present
          ? data.wishlistCount.value
          : this.wishlistCount,
      reviewCount: data.reviewCount.present
          ? data.reviewCount.value
          : this.reviewCount,
      rankDay: data.rankDay.present ? data.rankDay.value : this.rankDay,
      rankWeek: data.rankWeek.present ? data.rankWeek.value : this.rankWeek,
      rankMonth: data.rankMonth.present ? data.rankMonth.value : this.rankMonth,
      supportedLanguages: data.supportedLanguages.present
          ? data.supportedLanguages.value
          : this.supportedLanguages,
      scrapedAt: data.scrapedAt.present ? data.scrapedAt.value : this.scrapedAt,
      localImportedAt: data.localImportedAt.present
          ? data.localImportedAt.value
          : this.localImportedAt,
      localFolderPath: data.localFolderPath.present
          ? data.localFolderPath.value
          : this.localFolderPath,
      importedFolderId: data.importedFolderId.present
          ? data.importedFolderId.value
          : this.importedFolderId,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
      lastPlayedTrackId: data.lastPlayedTrackId.present
          ? data.lastPlayedTrackId.value
          : this.lastPlayedTrackId,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      isRemoved: data.isRemoved.present ? data.isRemoved.value : this.isRemoved,
      needsRescan: data.needsRescan.present
          ? data.needsRescan.value
          : this.needsRescan,
      userRating: data.userRating.present
          ? data.userRating.value
          : this.userRating,
      userTags: data.userTags.present ? data.userTags.value : this.userTags,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Work(')
          ..write('productId: $productId, ')
          ..write('title: $title, ')
          ..write('titleRomaji: $titleRomaji, ')
          ..write('translatedTitle: $translatedTitle, ')
          ..write('originalProductId: $originalProductId, ')
          ..write('circleId: $circleId, ')
          ..write('circleName: $circleName, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('voiceActors: $voiceActors, ')
          ..write('illustrators: $illustrators, ')
          ..write('scenarioWriters: $scenarioWriters, ')
          ..write('musicians: $musicians, ')
          ..write('ageRating: $ageRating, ')
          ..write('workType: $workType, ')
          ..write('workTypeName: $workTypeName, ')
          ..write('fileFormats: $fileFormats, ')
          ..write('genresJson: $genresJson, ')
          ..write('fileSize: $fileSize, ')
          ..write('seriesId: $seriesId, ')
          ..write('seriesName: $seriesName, ')
          ..write('descriptionHtml: $descriptionHtml, ')
          ..write('titleZh: $titleZh, ')
          ..write('descriptionHtmlZh: $descriptionHtmlZh, ')
          ..write('mainImageUrl: $mainImageUrl, ')
          ..write('sampleImageUrls: $sampleImageUrls, ')
          ..write('mainImageLocalPath: $mainImageLocalPath, ')
          ..write('sampleImageLocalPaths: $sampleImageLocalPaths, ')
          ..write('descriptionImageLocalPaths: $descriptionImageLocalPaths, ')
          ..write('officialPrice: $officialPrice, ')
          ..write('currentPrice: $currentPrice, ')
          ..write('discountRate: $discountRate, ')
          ..write('rating: $rating, ')
          ..write('ratingCount: $ratingCount, ')
          ..write('dlCount: $dlCount, ')
          ..write('wishlistCount: $wishlistCount, ')
          ..write('reviewCount: $reviewCount, ')
          ..write('rankDay: $rankDay, ')
          ..write('rankWeek: $rankWeek, ')
          ..write('rankMonth: $rankMonth, ')
          ..write('supportedLanguages: $supportedLanguages, ')
          ..write('scrapedAt: $scrapedAt, ')
          ..write('localImportedAt: $localImportedAt, ')
          ..write('localFolderPath: $localFolderPath, ')
          ..write('importedFolderId: $importedFolderId, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('lastPlayedTrackId: $lastPlayedTrackId, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isRemoved: $isRemoved, ')
          ..write('needsRescan: $needsRescan, ')
          ..write('userRating: $userRating, ')
          ..write('userTags: $userTags, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    productId,
    title,
    titleRomaji,
    translatedTitle,
    originalProductId,
    circleId,
    circleName,
    releaseDate,
    voiceActors,
    illustrators,
    scenarioWriters,
    musicians,
    ageRating,
    workType,
    workTypeName,
    fileFormats,
    genresJson,
    fileSize,
    seriesId,
    seriesName,
    descriptionHtml,
    titleZh,
    descriptionHtmlZh,
    mainImageUrl,
    sampleImageUrls,
    mainImageLocalPath,
    sampleImageLocalPaths,
    descriptionImageLocalPaths,
    officialPrice,
    currentPrice,
    discountRate,
    rating,
    ratingCount,
    dlCount,
    wishlistCount,
    reviewCount,
    rankDay,
    rankWeek,
    rankMonth,
    supportedLanguages,
    scrapedAt,
    localImportedAt,
    localFolderPath,
    importedFolderId,
    lastPlayedAt,
    lastPlayedTrackId,
    isFavorite,
    isRemoved,
    needsRescan,
    userRating,
    userTags,
    notes,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Work &&
          other.productId == this.productId &&
          other.title == this.title &&
          other.titleRomaji == this.titleRomaji &&
          other.translatedTitle == this.translatedTitle &&
          other.originalProductId == this.originalProductId &&
          other.circleId == this.circleId &&
          other.circleName == this.circleName &&
          other.releaseDate == this.releaseDate &&
          other.voiceActors == this.voiceActors &&
          other.illustrators == this.illustrators &&
          other.scenarioWriters == this.scenarioWriters &&
          other.musicians == this.musicians &&
          other.ageRating == this.ageRating &&
          other.workType == this.workType &&
          other.workTypeName == this.workTypeName &&
          other.fileFormats == this.fileFormats &&
          other.genresJson == this.genresJson &&
          other.fileSize == this.fileSize &&
          other.seriesId == this.seriesId &&
          other.seriesName == this.seriesName &&
          other.descriptionHtml == this.descriptionHtml &&
          other.titleZh == this.titleZh &&
          other.descriptionHtmlZh == this.descriptionHtmlZh &&
          other.mainImageUrl == this.mainImageUrl &&
          other.sampleImageUrls == this.sampleImageUrls &&
          other.mainImageLocalPath == this.mainImageLocalPath &&
          other.sampleImageLocalPaths == this.sampleImageLocalPaths &&
          other.descriptionImageLocalPaths == this.descriptionImageLocalPaths &&
          other.officialPrice == this.officialPrice &&
          other.currentPrice == this.currentPrice &&
          other.discountRate == this.discountRate &&
          other.rating == this.rating &&
          other.ratingCount == this.ratingCount &&
          other.dlCount == this.dlCount &&
          other.wishlistCount == this.wishlistCount &&
          other.reviewCount == this.reviewCount &&
          other.rankDay == this.rankDay &&
          other.rankWeek == this.rankWeek &&
          other.rankMonth == this.rankMonth &&
          other.supportedLanguages == this.supportedLanguages &&
          other.scrapedAt == this.scrapedAt &&
          other.localImportedAt == this.localImportedAt &&
          other.localFolderPath == this.localFolderPath &&
          other.importedFolderId == this.importedFolderId &&
          other.lastPlayedAt == this.lastPlayedAt &&
          other.lastPlayedTrackId == this.lastPlayedTrackId &&
          other.isFavorite == this.isFavorite &&
          other.isRemoved == this.isRemoved &&
          other.needsRescan == this.needsRescan &&
          other.userRating == this.userRating &&
          other.userTags == this.userTags &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WorksCompanion extends UpdateCompanion<Work> {
  final Value<String> productId;
  final Value<String> title;
  final Value<String?> titleRomaji;
  final Value<String?> translatedTitle;
  final Value<String?> originalProductId;
  final Value<String?> circleId;
  final Value<String?> circleName;
  final Value<DateTime?> releaseDate;
  final Value<List<String>> voiceActors;
  final Value<List<String>> illustrators;
  final Value<List<String>> scenarioWriters;
  final Value<List<String>> musicians;
  final Value<String?> ageRating;
  final Value<String?> workType;
  final Value<String?> workTypeName;
  final Value<List<String>> fileFormats;
  final Value<String> genresJson;
  final Value<String?> fileSize;
  final Value<String?> seriesId;
  final Value<String?> seriesName;
  final Value<String?> descriptionHtml;
  final Value<String?> titleZh;
  final Value<String?> descriptionHtmlZh;
  final Value<String?> mainImageUrl;
  final Value<List<String>> sampleImageUrls;
  final Value<String?> mainImageLocalPath;
  final Value<List<String>> sampleImageLocalPaths;
  final Value<List<String>> descriptionImageLocalPaths;
  final Value<int?> officialPrice;
  final Value<int?> currentPrice;
  final Value<int?> discountRate;
  final Value<double?> rating;
  final Value<int?> ratingCount;
  final Value<int?> dlCount;
  final Value<int?> wishlistCount;
  final Value<int?> reviewCount;
  final Value<int?> rankDay;
  final Value<int?> rankWeek;
  final Value<int?> rankMonth;
  final Value<List<String>> supportedLanguages;
  final Value<DateTime?> scrapedAt;
  final Value<DateTime> localImportedAt;
  final Value<String> localFolderPath;
  final Value<String?> importedFolderId;
  final Value<DateTime?> lastPlayedAt;
  final Value<String?> lastPlayedTrackId;
  final Value<bool> isFavorite;
  final Value<bool> isRemoved;
  final Value<bool> needsRescan;
  final Value<int?> userRating;
  final Value<List<String>> userTags;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WorksCompanion({
    this.productId = const Value.absent(),
    this.title = const Value.absent(),
    this.titleRomaji = const Value.absent(),
    this.translatedTitle = const Value.absent(),
    this.originalProductId = const Value.absent(),
    this.circleId = const Value.absent(),
    this.circleName = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.voiceActors = const Value.absent(),
    this.illustrators = const Value.absent(),
    this.scenarioWriters = const Value.absent(),
    this.musicians = const Value.absent(),
    this.ageRating = const Value.absent(),
    this.workType = const Value.absent(),
    this.workTypeName = const Value.absent(),
    this.fileFormats = const Value.absent(),
    this.genresJson = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.seriesName = const Value.absent(),
    this.descriptionHtml = const Value.absent(),
    this.titleZh = const Value.absent(),
    this.descriptionHtmlZh = const Value.absent(),
    this.mainImageUrl = const Value.absent(),
    this.sampleImageUrls = const Value.absent(),
    this.mainImageLocalPath = const Value.absent(),
    this.sampleImageLocalPaths = const Value.absent(),
    this.descriptionImageLocalPaths = const Value.absent(),
    this.officialPrice = const Value.absent(),
    this.currentPrice = const Value.absent(),
    this.discountRate = const Value.absent(),
    this.rating = const Value.absent(),
    this.ratingCount = const Value.absent(),
    this.dlCount = const Value.absent(),
    this.wishlistCount = const Value.absent(),
    this.reviewCount = const Value.absent(),
    this.rankDay = const Value.absent(),
    this.rankWeek = const Value.absent(),
    this.rankMonth = const Value.absent(),
    this.supportedLanguages = const Value.absent(),
    this.scrapedAt = const Value.absent(),
    this.localImportedAt = const Value.absent(),
    this.localFolderPath = const Value.absent(),
    this.importedFolderId = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.lastPlayedTrackId = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isRemoved = const Value.absent(),
    this.needsRescan = const Value.absent(),
    this.userRating = const Value.absent(),
    this.userTags = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorksCompanion.insert({
    required String productId,
    required String title,
    this.titleRomaji = const Value.absent(),
    this.translatedTitle = const Value.absent(),
    this.originalProductId = const Value.absent(),
    this.circleId = const Value.absent(),
    this.circleName = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.voiceActors = const Value.absent(),
    this.illustrators = const Value.absent(),
    this.scenarioWriters = const Value.absent(),
    this.musicians = const Value.absent(),
    this.ageRating = const Value.absent(),
    this.workType = const Value.absent(),
    this.workTypeName = const Value.absent(),
    this.fileFormats = const Value.absent(),
    this.genresJson = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.seriesName = const Value.absent(),
    this.descriptionHtml = const Value.absent(),
    this.titleZh = const Value.absent(),
    this.descriptionHtmlZh = const Value.absent(),
    this.mainImageUrl = const Value.absent(),
    this.sampleImageUrls = const Value.absent(),
    this.mainImageLocalPath = const Value.absent(),
    this.sampleImageLocalPaths = const Value.absent(),
    this.descriptionImageLocalPaths = const Value.absent(),
    this.officialPrice = const Value.absent(),
    this.currentPrice = const Value.absent(),
    this.discountRate = const Value.absent(),
    this.rating = const Value.absent(),
    this.ratingCount = const Value.absent(),
    this.dlCount = const Value.absent(),
    this.wishlistCount = const Value.absent(),
    this.reviewCount = const Value.absent(),
    this.rankDay = const Value.absent(),
    this.rankWeek = const Value.absent(),
    this.rankMonth = const Value.absent(),
    this.supportedLanguages = const Value.absent(),
    this.scrapedAt = const Value.absent(),
    required DateTime localImportedAt,
    required String localFolderPath,
    this.importedFolderId = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.lastPlayedTrackId = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isRemoved = const Value.absent(),
    this.needsRescan = const Value.absent(),
    this.userRating = const Value.absent(),
    this.userTags = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : productId = Value(productId),
       title = Value(title),
       localImportedAt = Value(localImportedAt),
       localFolderPath = Value(localFolderPath),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Work> custom({
    Expression<String>? productId,
    Expression<String>? title,
    Expression<String>? titleRomaji,
    Expression<String>? translatedTitle,
    Expression<String>? originalProductId,
    Expression<String>? circleId,
    Expression<String>? circleName,
    Expression<DateTime>? releaseDate,
    Expression<String>? voiceActors,
    Expression<String>? illustrators,
    Expression<String>? scenarioWriters,
    Expression<String>? musicians,
    Expression<String>? ageRating,
    Expression<String>? workType,
    Expression<String>? workTypeName,
    Expression<String>? fileFormats,
    Expression<String>? genresJson,
    Expression<String>? fileSize,
    Expression<String>? seriesId,
    Expression<String>? seriesName,
    Expression<String>? descriptionHtml,
    Expression<String>? titleZh,
    Expression<String>? descriptionHtmlZh,
    Expression<String>? mainImageUrl,
    Expression<String>? sampleImageUrls,
    Expression<String>? mainImageLocalPath,
    Expression<String>? sampleImageLocalPaths,
    Expression<String>? descriptionImageLocalPaths,
    Expression<int>? officialPrice,
    Expression<int>? currentPrice,
    Expression<int>? discountRate,
    Expression<double>? rating,
    Expression<int>? ratingCount,
    Expression<int>? dlCount,
    Expression<int>? wishlistCount,
    Expression<int>? reviewCount,
    Expression<int>? rankDay,
    Expression<int>? rankWeek,
    Expression<int>? rankMonth,
    Expression<String>? supportedLanguages,
    Expression<DateTime>? scrapedAt,
    Expression<DateTime>? localImportedAt,
    Expression<String>? localFolderPath,
    Expression<String>? importedFolderId,
    Expression<DateTime>? lastPlayedAt,
    Expression<String>? lastPlayedTrackId,
    Expression<bool>? isFavorite,
    Expression<bool>? isRemoved,
    Expression<bool>? needsRescan,
    Expression<int>? userRating,
    Expression<String>? userTags,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (productId != null) 'product_id': productId,
      if (title != null) 'title': title,
      if (titleRomaji != null) 'title_romaji': titleRomaji,
      if (translatedTitle != null) 'translated_title': translatedTitle,
      if (originalProductId != null) 'original_product_id': originalProductId,
      if (circleId != null) 'circle_id': circleId,
      if (circleName != null) 'circle_name': circleName,
      if (releaseDate != null) 'release_date': releaseDate,
      if (voiceActors != null) 'voice_actors': voiceActors,
      if (illustrators != null) 'illustrators': illustrators,
      if (scenarioWriters != null) 'scenario_writers': scenarioWriters,
      if (musicians != null) 'musicians': musicians,
      if (ageRating != null) 'age_rating': ageRating,
      if (workType != null) 'work_type': workType,
      if (workTypeName != null) 'work_type_name': workTypeName,
      if (fileFormats != null) 'file_formats': fileFormats,
      if (genresJson != null) 'genres_json': genresJson,
      if (fileSize != null) 'file_size': fileSize,
      if (seriesId != null) 'series_id': seriesId,
      if (seriesName != null) 'series_name': seriesName,
      if (descriptionHtml != null) 'description_html': descriptionHtml,
      if (titleZh != null) 'title_zh': titleZh,
      if (descriptionHtmlZh != null) 'description_html_zh': descriptionHtmlZh,
      if (mainImageUrl != null) 'main_image_url': mainImageUrl,
      if (sampleImageUrls != null) 'sample_image_urls': sampleImageUrls,
      if (mainImageLocalPath != null)
        'main_image_local_path': mainImageLocalPath,
      if (sampleImageLocalPaths != null)
        'sample_image_local_paths': sampleImageLocalPaths,
      if (descriptionImageLocalPaths != null)
        'description_image_local_paths': descriptionImageLocalPaths,
      if (officialPrice != null) 'official_price': officialPrice,
      if (currentPrice != null) 'current_price': currentPrice,
      if (discountRate != null) 'discount_rate': discountRate,
      if (rating != null) 'rating': rating,
      if (ratingCount != null) 'rating_count': ratingCount,
      if (dlCount != null) 'dl_count': dlCount,
      if (wishlistCount != null) 'wishlist_count': wishlistCount,
      if (reviewCount != null) 'review_count': reviewCount,
      if (rankDay != null) 'rank_day': rankDay,
      if (rankWeek != null) 'rank_week': rankWeek,
      if (rankMonth != null) 'rank_month': rankMonth,
      if (supportedLanguages != null) 'supported_languages': supportedLanguages,
      if (scrapedAt != null) 'scraped_at': scrapedAt,
      if (localImportedAt != null) 'local_imported_at': localImportedAt,
      if (localFolderPath != null) 'local_folder_path': localFolderPath,
      if (importedFolderId != null) 'imported_folder_id': importedFolderId,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (lastPlayedTrackId != null) 'last_played_track_id': lastPlayedTrackId,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (isRemoved != null) 'is_removed': isRemoved,
      if (needsRescan != null) 'needs_rescan': needsRescan,
      if (userRating != null) 'user_rating': userRating,
      if (userTags != null) 'user_tags': userTags,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorksCompanion copyWith({
    Value<String>? productId,
    Value<String>? title,
    Value<String?>? titleRomaji,
    Value<String?>? translatedTitle,
    Value<String?>? originalProductId,
    Value<String?>? circleId,
    Value<String?>? circleName,
    Value<DateTime?>? releaseDate,
    Value<List<String>>? voiceActors,
    Value<List<String>>? illustrators,
    Value<List<String>>? scenarioWriters,
    Value<List<String>>? musicians,
    Value<String?>? ageRating,
    Value<String?>? workType,
    Value<String?>? workTypeName,
    Value<List<String>>? fileFormats,
    Value<String>? genresJson,
    Value<String?>? fileSize,
    Value<String?>? seriesId,
    Value<String?>? seriesName,
    Value<String?>? descriptionHtml,
    Value<String?>? titleZh,
    Value<String?>? descriptionHtmlZh,
    Value<String?>? mainImageUrl,
    Value<List<String>>? sampleImageUrls,
    Value<String?>? mainImageLocalPath,
    Value<List<String>>? sampleImageLocalPaths,
    Value<List<String>>? descriptionImageLocalPaths,
    Value<int?>? officialPrice,
    Value<int?>? currentPrice,
    Value<int?>? discountRate,
    Value<double?>? rating,
    Value<int?>? ratingCount,
    Value<int?>? dlCount,
    Value<int?>? wishlistCount,
    Value<int?>? reviewCount,
    Value<int?>? rankDay,
    Value<int?>? rankWeek,
    Value<int?>? rankMonth,
    Value<List<String>>? supportedLanguages,
    Value<DateTime?>? scrapedAt,
    Value<DateTime>? localImportedAt,
    Value<String>? localFolderPath,
    Value<String?>? importedFolderId,
    Value<DateTime?>? lastPlayedAt,
    Value<String?>? lastPlayedTrackId,
    Value<bool>? isFavorite,
    Value<bool>? isRemoved,
    Value<bool>? needsRescan,
    Value<int?>? userRating,
    Value<List<String>>? userTags,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return WorksCompanion(
      productId: productId ?? this.productId,
      title: title ?? this.title,
      titleRomaji: titleRomaji ?? this.titleRomaji,
      translatedTitle: translatedTitle ?? this.translatedTitle,
      originalProductId: originalProductId ?? this.originalProductId,
      circleId: circleId ?? this.circleId,
      circleName: circleName ?? this.circleName,
      releaseDate: releaseDate ?? this.releaseDate,
      voiceActors: voiceActors ?? this.voiceActors,
      illustrators: illustrators ?? this.illustrators,
      scenarioWriters: scenarioWriters ?? this.scenarioWriters,
      musicians: musicians ?? this.musicians,
      ageRating: ageRating ?? this.ageRating,
      workType: workType ?? this.workType,
      workTypeName: workTypeName ?? this.workTypeName,
      fileFormats: fileFormats ?? this.fileFormats,
      genresJson: genresJson ?? this.genresJson,
      fileSize: fileSize ?? this.fileSize,
      seriesId: seriesId ?? this.seriesId,
      seriesName: seriesName ?? this.seriesName,
      descriptionHtml: descriptionHtml ?? this.descriptionHtml,
      titleZh: titleZh ?? this.titleZh,
      descriptionHtmlZh: descriptionHtmlZh ?? this.descriptionHtmlZh,
      mainImageUrl: mainImageUrl ?? this.mainImageUrl,
      sampleImageUrls: sampleImageUrls ?? this.sampleImageUrls,
      mainImageLocalPath: mainImageLocalPath ?? this.mainImageLocalPath,
      sampleImageLocalPaths:
          sampleImageLocalPaths ?? this.sampleImageLocalPaths,
      descriptionImageLocalPaths:
          descriptionImageLocalPaths ?? this.descriptionImageLocalPaths,
      officialPrice: officialPrice ?? this.officialPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      discountRate: discountRate ?? this.discountRate,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      dlCount: dlCount ?? this.dlCount,
      wishlistCount: wishlistCount ?? this.wishlistCount,
      reviewCount: reviewCount ?? this.reviewCount,
      rankDay: rankDay ?? this.rankDay,
      rankWeek: rankWeek ?? this.rankWeek,
      rankMonth: rankMonth ?? this.rankMonth,
      supportedLanguages: supportedLanguages ?? this.supportedLanguages,
      scrapedAt: scrapedAt ?? this.scrapedAt,
      localImportedAt: localImportedAt ?? this.localImportedAt,
      localFolderPath: localFolderPath ?? this.localFolderPath,
      importedFolderId: importedFolderId ?? this.importedFolderId,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      lastPlayedTrackId: lastPlayedTrackId ?? this.lastPlayedTrackId,
      isFavorite: isFavorite ?? this.isFavorite,
      isRemoved: isRemoved ?? this.isRemoved,
      needsRescan: needsRescan ?? this.needsRescan,
      userRating: userRating ?? this.userRating,
      userTags: userTags ?? this.userTags,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (titleRomaji.present) {
      map['title_romaji'] = Variable<String>(titleRomaji.value);
    }
    if (translatedTitle.present) {
      map['translated_title'] = Variable<String>(translatedTitle.value);
    }
    if (originalProductId.present) {
      map['original_product_id'] = Variable<String>(originalProductId.value);
    }
    if (circleId.present) {
      map['circle_id'] = Variable<String>(circleId.value);
    }
    if (circleName.present) {
      map['circle_name'] = Variable<String>(circleName.value);
    }
    if (releaseDate.present) {
      map['release_date'] = Variable<DateTime>(releaseDate.value);
    }
    if (voiceActors.present) {
      map['voice_actors'] = Variable<String>(
        $WorksTable.$convertervoiceActors.toSql(voiceActors.value),
      );
    }
    if (illustrators.present) {
      map['illustrators'] = Variable<String>(
        $WorksTable.$converterillustrators.toSql(illustrators.value),
      );
    }
    if (scenarioWriters.present) {
      map['scenario_writers'] = Variable<String>(
        $WorksTable.$converterscenarioWriters.toSql(scenarioWriters.value),
      );
    }
    if (musicians.present) {
      map['musicians'] = Variable<String>(
        $WorksTable.$convertermusicians.toSql(musicians.value),
      );
    }
    if (ageRating.present) {
      map['age_rating'] = Variable<String>(ageRating.value);
    }
    if (workType.present) {
      map['work_type'] = Variable<String>(workType.value);
    }
    if (workTypeName.present) {
      map['work_type_name'] = Variable<String>(workTypeName.value);
    }
    if (fileFormats.present) {
      map['file_formats'] = Variable<String>(
        $WorksTable.$converterfileFormats.toSql(fileFormats.value),
      );
    }
    if (genresJson.present) {
      map['genres_json'] = Variable<String>(genresJson.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<String>(fileSize.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (seriesName.present) {
      map['series_name'] = Variable<String>(seriesName.value);
    }
    if (descriptionHtml.present) {
      map['description_html'] = Variable<String>(descriptionHtml.value);
    }
    if (titleZh.present) {
      map['title_zh'] = Variable<String>(titleZh.value);
    }
    if (descriptionHtmlZh.present) {
      map['description_html_zh'] = Variable<String>(descriptionHtmlZh.value);
    }
    if (mainImageUrl.present) {
      map['main_image_url'] = Variable<String>(mainImageUrl.value);
    }
    if (sampleImageUrls.present) {
      map['sample_image_urls'] = Variable<String>(
        $WorksTable.$convertersampleImageUrls.toSql(sampleImageUrls.value),
      );
    }
    if (mainImageLocalPath.present) {
      map['main_image_local_path'] = Variable<String>(mainImageLocalPath.value);
    }
    if (sampleImageLocalPaths.present) {
      map['sample_image_local_paths'] = Variable<String>(
        $WorksTable.$convertersampleImageLocalPaths.toSql(
          sampleImageLocalPaths.value,
        ),
      );
    }
    if (descriptionImageLocalPaths.present) {
      map['description_image_local_paths'] = Variable<String>(
        $WorksTable.$converterdescriptionImageLocalPaths.toSql(
          descriptionImageLocalPaths.value,
        ),
      );
    }
    if (officialPrice.present) {
      map['official_price'] = Variable<int>(officialPrice.value);
    }
    if (currentPrice.present) {
      map['current_price'] = Variable<int>(currentPrice.value);
    }
    if (discountRate.present) {
      map['discount_rate'] = Variable<int>(discountRate.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (ratingCount.present) {
      map['rating_count'] = Variable<int>(ratingCount.value);
    }
    if (dlCount.present) {
      map['dl_count'] = Variable<int>(dlCount.value);
    }
    if (wishlistCount.present) {
      map['wishlist_count'] = Variable<int>(wishlistCount.value);
    }
    if (reviewCount.present) {
      map['review_count'] = Variable<int>(reviewCount.value);
    }
    if (rankDay.present) {
      map['rank_day'] = Variable<int>(rankDay.value);
    }
    if (rankWeek.present) {
      map['rank_week'] = Variable<int>(rankWeek.value);
    }
    if (rankMonth.present) {
      map['rank_month'] = Variable<int>(rankMonth.value);
    }
    if (supportedLanguages.present) {
      map['supported_languages'] = Variable<String>(
        $WorksTable.$convertersupportedLanguages.toSql(
          supportedLanguages.value,
        ),
      );
    }
    if (scrapedAt.present) {
      map['scraped_at'] = Variable<DateTime>(scrapedAt.value);
    }
    if (localImportedAt.present) {
      map['local_imported_at'] = Variable<DateTime>(localImportedAt.value);
    }
    if (localFolderPath.present) {
      map['local_folder_path'] = Variable<String>(localFolderPath.value);
    }
    if (importedFolderId.present) {
      map['imported_folder_id'] = Variable<String>(importedFolderId.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt.value);
    }
    if (lastPlayedTrackId.present) {
      map['last_played_track_id'] = Variable<String>(lastPlayedTrackId.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (isRemoved.present) {
      map['is_removed'] = Variable<bool>(isRemoved.value);
    }
    if (needsRescan.present) {
      map['needs_rescan'] = Variable<bool>(needsRescan.value);
    }
    if (userRating.present) {
      map['user_rating'] = Variable<int>(userRating.value);
    }
    if (userTags.present) {
      map['user_tags'] = Variable<String>(
        $WorksTable.$converteruserTags.toSql(userTags.value),
      );
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorksCompanion(')
          ..write('productId: $productId, ')
          ..write('title: $title, ')
          ..write('titleRomaji: $titleRomaji, ')
          ..write('translatedTitle: $translatedTitle, ')
          ..write('originalProductId: $originalProductId, ')
          ..write('circleId: $circleId, ')
          ..write('circleName: $circleName, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('voiceActors: $voiceActors, ')
          ..write('illustrators: $illustrators, ')
          ..write('scenarioWriters: $scenarioWriters, ')
          ..write('musicians: $musicians, ')
          ..write('ageRating: $ageRating, ')
          ..write('workType: $workType, ')
          ..write('workTypeName: $workTypeName, ')
          ..write('fileFormats: $fileFormats, ')
          ..write('genresJson: $genresJson, ')
          ..write('fileSize: $fileSize, ')
          ..write('seriesId: $seriesId, ')
          ..write('seriesName: $seriesName, ')
          ..write('descriptionHtml: $descriptionHtml, ')
          ..write('titleZh: $titleZh, ')
          ..write('descriptionHtmlZh: $descriptionHtmlZh, ')
          ..write('mainImageUrl: $mainImageUrl, ')
          ..write('sampleImageUrls: $sampleImageUrls, ')
          ..write('mainImageLocalPath: $mainImageLocalPath, ')
          ..write('sampleImageLocalPaths: $sampleImageLocalPaths, ')
          ..write('descriptionImageLocalPaths: $descriptionImageLocalPaths, ')
          ..write('officialPrice: $officialPrice, ')
          ..write('currentPrice: $currentPrice, ')
          ..write('discountRate: $discountRate, ')
          ..write('rating: $rating, ')
          ..write('ratingCount: $ratingCount, ')
          ..write('dlCount: $dlCount, ')
          ..write('wishlistCount: $wishlistCount, ')
          ..write('reviewCount: $reviewCount, ')
          ..write('rankDay: $rankDay, ')
          ..write('rankWeek: $rankWeek, ')
          ..write('rankMonth: $rankMonth, ')
          ..write('supportedLanguages: $supportedLanguages, ')
          ..write('scrapedAt: $scrapedAt, ')
          ..write('localImportedAt: $localImportedAt, ')
          ..write('localFolderPath: $localFolderPath, ')
          ..write('importedFolderId: $importedFolderId, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('lastPlayedTrackId: $lastPlayedTrackId, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isRemoved: $isRemoved, ')
          ..write('needsRescan: $needsRescan, ')
          ..write('userRating: $userRating, ')
          ..write('userTags: $userTags, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TracksTable extends Tracks with TableInfo<$TracksTable, Track> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workIdMeta = const VerificationMeta('workId');
  @override
  late final GeneratedColumn<String> workId = GeneratedColumn<String>(
    'work_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES works (product_id)',
    ),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileFormatMeta = const VerificationMeta(
    'fileFormat',
  );
  @override
  late final GeneratedColumn<String> fileFormat = GeneratedColumn<String>(
    'file_format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileSizeBytesMeta = const VerificationMeta(
    'fileSizeBytes',
  );
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
    'file_size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sampleRateMeta = const VerificationMeta(
    'sampleRate',
  );
  @override
  late final GeneratedColumn<int> sampleRate = GeneratedColumn<int>(
    'sample_rate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bitRateMeta = const VerificationMeta(
    'bitRate',
  );
  @override
  late final GeneratedColumn<int> bitRate = GeneratedColumn<int>(
    'bit_rate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryHintMeta = const VerificationMeta(
    'categoryHint',
  );
  @override
  late final GeneratedColumn<String> categoryHint = GeneratedColumn<String>(
    'category_hint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userCategoryMeta = const VerificationMeta(
    'userCategory',
  );
  @override
  late final GeneratedColumn<String> userCategory = GeneratedColumn<String>(
    'user_category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentDirNameMeta = const VerificationMeta(
    'parentDirName',
  );
  @override
  late final GeneratedColumn<String> parentDirName = GeneratedColumn<String>(
    'parent_dir_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackNumberMeta = const VerificationMeta(
    'trackNumber',
  );
  @override
  late final GeneratedColumn<int> trackNumber = GeneratedColumn<int>(
    'track_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _alternateQualityPathsJsonMeta =
      const VerificationMeta('alternateQualityPathsJson');
  @override
  late final GeneratedColumn<String> alternateQualityPathsJson =
      GeneratedColumn<String>(
        'alternate_quality_paths_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      );
  static const VerificationMeta _lastPositionMsMeta = const VerificationMeta(
    'lastPositionMs',
  );
  @override
  late final GeneratedColumn<int> lastPositionMs = GeneratedColumn<int>(
    'last_position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _playCountMeta = const VerificationMeta(
    'playCount',
  );
  @override
  late final GeneratedColumn<int> playCount = GeneratedColumn<int>(
    'play_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workId,
    filePath,
    relativePath,
    fileName,
    fileFormat,
    fileSizeBytes,
    durationMs,
    sampleRate,
    bitRate,
    categoryHint,
    userCategory,
    parentDirName,
    trackNumber,
    title,
    alternateQualityPathsJson,
    lastPositionMs,
    playCount,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Track> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('work_id')) {
      context.handle(
        _workIdMeta,
        workId.isAcceptableOrUnknown(data['work_id']!, _workIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workIdMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('file_format')) {
      context.handle(
        _fileFormatMeta,
        fileFormat.isAcceptableOrUnknown(data['file_format']!, _fileFormatMeta),
      );
    } else if (isInserting) {
      context.missing(_fileFormatMeta);
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(
        _fileSizeBytesMeta,
        fileSizeBytes.isAcceptableOrUnknown(
          data['file_size_bytes']!,
          _fileSizeBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fileSizeBytesMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('sample_rate')) {
      context.handle(
        _sampleRateMeta,
        sampleRate.isAcceptableOrUnknown(data['sample_rate']!, _sampleRateMeta),
      );
    }
    if (data.containsKey('bit_rate')) {
      context.handle(
        _bitRateMeta,
        bitRate.isAcceptableOrUnknown(data['bit_rate']!, _bitRateMeta),
      );
    }
    if (data.containsKey('category_hint')) {
      context.handle(
        _categoryHintMeta,
        categoryHint.isAcceptableOrUnknown(
          data['category_hint']!,
          _categoryHintMeta,
        ),
      );
    }
    if (data.containsKey('user_category')) {
      context.handle(
        _userCategoryMeta,
        userCategory.isAcceptableOrUnknown(
          data['user_category']!,
          _userCategoryMeta,
        ),
      );
    }
    if (data.containsKey('parent_dir_name')) {
      context.handle(
        _parentDirNameMeta,
        parentDirName.isAcceptableOrUnknown(
          data['parent_dir_name']!,
          _parentDirNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parentDirNameMeta);
    }
    if (data.containsKey('track_number')) {
      context.handle(
        _trackNumberMeta,
        trackNumber.isAcceptableOrUnknown(
          data['track_number']!,
          _trackNumberMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('alternate_quality_paths_json')) {
      context.handle(
        _alternateQualityPathsJsonMeta,
        alternateQualityPathsJson.isAcceptableOrUnknown(
          data['alternate_quality_paths_json']!,
          _alternateQualityPathsJsonMeta,
        ),
      );
    }
    if (data.containsKey('last_position_ms')) {
      context.handle(
        _lastPositionMsMeta,
        lastPositionMs.isAcceptableOrUnknown(
          data['last_position_ms']!,
          _lastPositionMsMeta,
        ),
      );
    }
    if (data.containsKey('play_count')) {
      context.handle(
        _playCountMeta,
        playCount.isAcceptableOrUnknown(data['play_count']!, _playCountMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Track map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Track(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      workId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_id'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      fileFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_format'],
      )!,
      fileSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size_bytes'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      sampleRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_rate'],
      ),
      bitRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bit_rate'],
      ),
      categoryHint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_hint'],
      ),
      userCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_category'],
      ),
      parentDirName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_dir_name'],
      )!,
      trackNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_number'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      alternateQualityPathsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alternate_quality_paths_json'],
      )!,
      lastPositionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_position_ms'],
      )!,
      playCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}play_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TracksTable createAlias(String alias) {
    return $TracksTable(attachedDatabase, alias);
  }
}

class Track extends DataClass implements Insertable<Track> {
  final String id;
  final String workId;
  final String filePath;
  final String relativePath;
  final String fileName;
  final String fileFormat;
  final int fileSizeBytes;
  final int durationMs;
  final int? sampleRate;
  final int? bitRate;
  final String? categoryHint;
  final String? userCategory;
  final String parentDirName;
  final int? trackNumber;
  final String title;
  final String alternateQualityPathsJson;
  final int lastPositionMs;
  final int playCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Track({
    required this.id,
    required this.workId,
    required this.filePath,
    required this.relativePath,
    required this.fileName,
    required this.fileFormat,
    required this.fileSizeBytes,
    required this.durationMs,
    this.sampleRate,
    this.bitRate,
    this.categoryHint,
    this.userCategory,
    required this.parentDirName,
    this.trackNumber,
    required this.title,
    required this.alternateQualityPathsJson,
    required this.lastPositionMs,
    required this.playCount,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['work_id'] = Variable<String>(workId);
    map['file_path'] = Variable<String>(filePath);
    map['relative_path'] = Variable<String>(relativePath);
    map['file_name'] = Variable<String>(fileName);
    map['file_format'] = Variable<String>(fileFormat);
    map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    map['duration_ms'] = Variable<int>(durationMs);
    if (!nullToAbsent || sampleRate != null) {
      map['sample_rate'] = Variable<int>(sampleRate);
    }
    if (!nullToAbsent || bitRate != null) {
      map['bit_rate'] = Variable<int>(bitRate);
    }
    if (!nullToAbsent || categoryHint != null) {
      map['category_hint'] = Variable<String>(categoryHint);
    }
    if (!nullToAbsent || userCategory != null) {
      map['user_category'] = Variable<String>(userCategory);
    }
    map['parent_dir_name'] = Variable<String>(parentDirName);
    if (!nullToAbsent || trackNumber != null) {
      map['track_number'] = Variable<int>(trackNumber);
    }
    map['title'] = Variable<String>(title);
    map['alternate_quality_paths_json'] = Variable<String>(
      alternateQualityPathsJson,
    );
    map['last_position_ms'] = Variable<int>(lastPositionMs);
    map['play_count'] = Variable<int>(playCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TracksCompanion toCompanion(bool nullToAbsent) {
    return TracksCompanion(
      id: Value(id),
      workId: Value(workId),
      filePath: Value(filePath),
      relativePath: Value(relativePath),
      fileName: Value(fileName),
      fileFormat: Value(fileFormat),
      fileSizeBytes: Value(fileSizeBytes),
      durationMs: Value(durationMs),
      sampleRate: sampleRate == null && nullToAbsent
          ? const Value.absent()
          : Value(sampleRate),
      bitRate: bitRate == null && nullToAbsent
          ? const Value.absent()
          : Value(bitRate),
      categoryHint: categoryHint == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryHint),
      userCategory: userCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(userCategory),
      parentDirName: Value(parentDirName),
      trackNumber: trackNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(trackNumber),
      title: Value(title),
      alternateQualityPathsJson: Value(alternateQualityPathsJson),
      lastPositionMs: Value(lastPositionMs),
      playCount: Value(playCount),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Track.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Track(
      id: serializer.fromJson<String>(json['id']),
      workId: serializer.fromJson<String>(json['workId']),
      filePath: serializer.fromJson<String>(json['filePath']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      fileName: serializer.fromJson<String>(json['fileName']),
      fileFormat: serializer.fromJson<String>(json['fileFormat']),
      fileSizeBytes: serializer.fromJson<int>(json['fileSizeBytes']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      sampleRate: serializer.fromJson<int?>(json['sampleRate']),
      bitRate: serializer.fromJson<int?>(json['bitRate']),
      categoryHint: serializer.fromJson<String?>(json['categoryHint']),
      userCategory: serializer.fromJson<String?>(json['userCategory']),
      parentDirName: serializer.fromJson<String>(json['parentDirName']),
      trackNumber: serializer.fromJson<int?>(json['trackNumber']),
      title: serializer.fromJson<String>(json['title']),
      alternateQualityPathsJson: serializer.fromJson<String>(
        json['alternateQualityPathsJson'],
      ),
      lastPositionMs: serializer.fromJson<int>(json['lastPositionMs']),
      playCount: serializer.fromJson<int>(json['playCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workId': serializer.toJson<String>(workId),
      'filePath': serializer.toJson<String>(filePath),
      'relativePath': serializer.toJson<String>(relativePath),
      'fileName': serializer.toJson<String>(fileName),
      'fileFormat': serializer.toJson<String>(fileFormat),
      'fileSizeBytes': serializer.toJson<int>(fileSizeBytes),
      'durationMs': serializer.toJson<int>(durationMs),
      'sampleRate': serializer.toJson<int?>(sampleRate),
      'bitRate': serializer.toJson<int?>(bitRate),
      'categoryHint': serializer.toJson<String?>(categoryHint),
      'userCategory': serializer.toJson<String?>(userCategory),
      'parentDirName': serializer.toJson<String>(parentDirName),
      'trackNumber': serializer.toJson<int?>(trackNumber),
      'title': serializer.toJson<String>(title),
      'alternateQualityPathsJson': serializer.toJson<String>(
        alternateQualityPathsJson,
      ),
      'lastPositionMs': serializer.toJson<int>(lastPositionMs),
      'playCount': serializer.toJson<int>(playCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Track copyWith({
    String? id,
    String? workId,
    String? filePath,
    String? relativePath,
    String? fileName,
    String? fileFormat,
    int? fileSizeBytes,
    int? durationMs,
    Value<int?> sampleRate = const Value.absent(),
    Value<int?> bitRate = const Value.absent(),
    Value<String?> categoryHint = const Value.absent(),
    Value<String?> userCategory = const Value.absent(),
    String? parentDirName,
    Value<int?> trackNumber = const Value.absent(),
    String? title,
    String? alternateQualityPathsJson,
    int? lastPositionMs,
    int? playCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Track(
    id: id ?? this.id,
    workId: workId ?? this.workId,
    filePath: filePath ?? this.filePath,
    relativePath: relativePath ?? this.relativePath,
    fileName: fileName ?? this.fileName,
    fileFormat: fileFormat ?? this.fileFormat,
    fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    durationMs: durationMs ?? this.durationMs,
    sampleRate: sampleRate.present ? sampleRate.value : this.sampleRate,
    bitRate: bitRate.present ? bitRate.value : this.bitRate,
    categoryHint: categoryHint.present ? categoryHint.value : this.categoryHint,
    userCategory: userCategory.present ? userCategory.value : this.userCategory,
    parentDirName: parentDirName ?? this.parentDirName,
    trackNumber: trackNumber.present ? trackNumber.value : this.trackNumber,
    title: title ?? this.title,
    alternateQualityPathsJson:
        alternateQualityPathsJson ?? this.alternateQualityPathsJson,
    lastPositionMs: lastPositionMs ?? this.lastPositionMs,
    playCount: playCount ?? this.playCount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Track copyWithCompanion(TracksCompanion data) {
    return Track(
      id: data.id.present ? data.id.value : this.id,
      workId: data.workId.present ? data.workId.value : this.workId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      fileFormat: data.fileFormat.present
          ? data.fileFormat.value
          : this.fileFormat,
      fileSizeBytes: data.fileSizeBytes.present
          ? data.fileSizeBytes.value
          : this.fileSizeBytes,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      sampleRate: data.sampleRate.present
          ? data.sampleRate.value
          : this.sampleRate,
      bitRate: data.bitRate.present ? data.bitRate.value : this.bitRate,
      categoryHint: data.categoryHint.present
          ? data.categoryHint.value
          : this.categoryHint,
      userCategory: data.userCategory.present
          ? data.userCategory.value
          : this.userCategory,
      parentDirName: data.parentDirName.present
          ? data.parentDirName.value
          : this.parentDirName,
      trackNumber: data.trackNumber.present
          ? data.trackNumber.value
          : this.trackNumber,
      title: data.title.present ? data.title.value : this.title,
      alternateQualityPathsJson: data.alternateQualityPathsJson.present
          ? data.alternateQualityPathsJson.value
          : this.alternateQualityPathsJson,
      lastPositionMs: data.lastPositionMs.present
          ? data.lastPositionMs.value
          : this.lastPositionMs,
      playCount: data.playCount.present ? data.playCount.value : this.playCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Track(')
          ..write('id: $id, ')
          ..write('workId: $workId, ')
          ..write('filePath: $filePath, ')
          ..write('relativePath: $relativePath, ')
          ..write('fileName: $fileName, ')
          ..write('fileFormat: $fileFormat, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('durationMs: $durationMs, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('bitRate: $bitRate, ')
          ..write('categoryHint: $categoryHint, ')
          ..write('userCategory: $userCategory, ')
          ..write('parentDirName: $parentDirName, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('title: $title, ')
          ..write('alternateQualityPathsJson: $alternateQualityPathsJson, ')
          ..write('lastPositionMs: $lastPositionMs, ')
          ..write('playCount: $playCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    workId,
    filePath,
    relativePath,
    fileName,
    fileFormat,
    fileSizeBytes,
    durationMs,
    sampleRate,
    bitRate,
    categoryHint,
    userCategory,
    parentDirName,
    trackNumber,
    title,
    alternateQualityPathsJson,
    lastPositionMs,
    playCount,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Track &&
          other.id == this.id &&
          other.workId == this.workId &&
          other.filePath == this.filePath &&
          other.relativePath == this.relativePath &&
          other.fileName == this.fileName &&
          other.fileFormat == this.fileFormat &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.durationMs == this.durationMs &&
          other.sampleRate == this.sampleRate &&
          other.bitRate == this.bitRate &&
          other.categoryHint == this.categoryHint &&
          other.userCategory == this.userCategory &&
          other.parentDirName == this.parentDirName &&
          other.trackNumber == this.trackNumber &&
          other.title == this.title &&
          other.alternateQualityPathsJson == this.alternateQualityPathsJson &&
          other.lastPositionMs == this.lastPositionMs &&
          other.playCount == this.playCount &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TracksCompanion extends UpdateCompanion<Track> {
  final Value<String> id;
  final Value<String> workId;
  final Value<String> filePath;
  final Value<String> relativePath;
  final Value<String> fileName;
  final Value<String> fileFormat;
  final Value<int> fileSizeBytes;
  final Value<int> durationMs;
  final Value<int?> sampleRate;
  final Value<int?> bitRate;
  final Value<String?> categoryHint;
  final Value<String?> userCategory;
  final Value<String> parentDirName;
  final Value<int?> trackNumber;
  final Value<String> title;
  final Value<String> alternateQualityPathsJson;
  final Value<int> lastPositionMs;
  final Value<int> playCount;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TracksCompanion({
    this.id = const Value.absent(),
    this.workId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.fileName = const Value.absent(),
    this.fileFormat = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.bitRate = const Value.absent(),
    this.categoryHint = const Value.absent(),
    this.userCategory = const Value.absent(),
    this.parentDirName = const Value.absent(),
    this.trackNumber = const Value.absent(),
    this.title = const Value.absent(),
    this.alternateQualityPathsJson = const Value.absent(),
    this.lastPositionMs = const Value.absent(),
    this.playCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TracksCompanion.insert({
    required String id,
    required String workId,
    required String filePath,
    this.relativePath = const Value.absent(),
    required String fileName,
    required String fileFormat,
    required int fileSizeBytes,
    required int durationMs,
    this.sampleRate = const Value.absent(),
    this.bitRate = const Value.absent(),
    this.categoryHint = const Value.absent(),
    this.userCategory = const Value.absent(),
    required String parentDirName,
    this.trackNumber = const Value.absent(),
    required String title,
    this.alternateQualityPathsJson = const Value.absent(),
    this.lastPositionMs = const Value.absent(),
    this.playCount = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       workId = Value(workId),
       filePath = Value(filePath),
       fileName = Value(fileName),
       fileFormat = Value(fileFormat),
       fileSizeBytes = Value(fileSizeBytes),
       durationMs = Value(durationMs),
       parentDirName = Value(parentDirName),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Track> custom({
    Expression<String>? id,
    Expression<String>? workId,
    Expression<String>? filePath,
    Expression<String>? relativePath,
    Expression<String>? fileName,
    Expression<String>? fileFormat,
    Expression<int>? fileSizeBytes,
    Expression<int>? durationMs,
    Expression<int>? sampleRate,
    Expression<int>? bitRate,
    Expression<String>? categoryHint,
    Expression<String>? userCategory,
    Expression<String>? parentDirName,
    Expression<int>? trackNumber,
    Expression<String>? title,
    Expression<String>? alternateQualityPathsJson,
    Expression<int>? lastPositionMs,
    Expression<int>? playCount,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workId != null) 'work_id': workId,
      if (filePath != null) 'file_path': filePath,
      if (relativePath != null) 'relative_path': relativePath,
      if (fileName != null) 'file_name': fileName,
      if (fileFormat != null) 'file_format': fileFormat,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (durationMs != null) 'duration_ms': durationMs,
      if (sampleRate != null) 'sample_rate': sampleRate,
      if (bitRate != null) 'bit_rate': bitRate,
      if (categoryHint != null) 'category_hint': categoryHint,
      if (userCategory != null) 'user_category': userCategory,
      if (parentDirName != null) 'parent_dir_name': parentDirName,
      if (trackNumber != null) 'track_number': trackNumber,
      if (title != null) 'title': title,
      if (alternateQualityPathsJson != null)
        'alternate_quality_paths_json': alternateQualityPathsJson,
      if (lastPositionMs != null) 'last_position_ms': lastPositionMs,
      if (playCount != null) 'play_count': playCount,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TracksCompanion copyWith({
    Value<String>? id,
    Value<String>? workId,
    Value<String>? filePath,
    Value<String>? relativePath,
    Value<String>? fileName,
    Value<String>? fileFormat,
    Value<int>? fileSizeBytes,
    Value<int>? durationMs,
    Value<int?>? sampleRate,
    Value<int?>? bitRate,
    Value<String?>? categoryHint,
    Value<String?>? userCategory,
    Value<String>? parentDirName,
    Value<int?>? trackNumber,
    Value<String>? title,
    Value<String>? alternateQualityPathsJson,
    Value<int>? lastPositionMs,
    Value<int>? playCount,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TracksCompanion(
      id: id ?? this.id,
      workId: workId ?? this.workId,
      filePath: filePath ?? this.filePath,
      relativePath: relativePath ?? this.relativePath,
      fileName: fileName ?? this.fileName,
      fileFormat: fileFormat ?? this.fileFormat,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      durationMs: durationMs ?? this.durationMs,
      sampleRate: sampleRate ?? this.sampleRate,
      bitRate: bitRate ?? this.bitRate,
      categoryHint: categoryHint ?? this.categoryHint,
      userCategory: userCategory ?? this.userCategory,
      parentDirName: parentDirName ?? this.parentDirName,
      trackNumber: trackNumber ?? this.trackNumber,
      title: title ?? this.title,
      alternateQualityPathsJson:
          alternateQualityPathsJson ?? this.alternateQualityPathsJson,
      lastPositionMs: lastPositionMs ?? this.lastPositionMs,
      playCount: playCount ?? this.playCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workId.present) {
      map['work_id'] = Variable<String>(workId.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (fileFormat.present) {
      map['file_format'] = Variable<String>(fileFormat.value);
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (sampleRate.present) {
      map['sample_rate'] = Variable<int>(sampleRate.value);
    }
    if (bitRate.present) {
      map['bit_rate'] = Variable<int>(bitRate.value);
    }
    if (categoryHint.present) {
      map['category_hint'] = Variable<String>(categoryHint.value);
    }
    if (userCategory.present) {
      map['user_category'] = Variable<String>(userCategory.value);
    }
    if (parentDirName.present) {
      map['parent_dir_name'] = Variable<String>(parentDirName.value);
    }
    if (trackNumber.present) {
      map['track_number'] = Variable<int>(trackNumber.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (alternateQualityPathsJson.present) {
      map['alternate_quality_paths_json'] = Variable<String>(
        alternateQualityPathsJson.value,
      );
    }
    if (lastPositionMs.present) {
      map['last_position_ms'] = Variable<int>(lastPositionMs.value);
    }
    if (playCount.present) {
      map['play_count'] = Variable<int>(playCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TracksCompanion(')
          ..write('id: $id, ')
          ..write('workId: $workId, ')
          ..write('filePath: $filePath, ')
          ..write('relativePath: $relativePath, ')
          ..write('fileName: $fileName, ')
          ..write('fileFormat: $fileFormat, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('durationMs: $durationMs, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('bitRate: $bitRate, ')
          ..write('categoryHint: $categoryHint, ')
          ..write('userCategory: $userCategory, ')
          ..write('parentDirName: $parentDirName, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('title: $title, ')
          ..write('alternateQualityPathsJson: $alternateQualityPathsJson, ')
          ..write('lastPositionMs: $lastPositionMs, ')
          ..write('playCount: $playCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkFilesTable extends WorkFiles
    with TableInfo<$WorkFilesTable, WorkFile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workIdMeta = const VerificationMeta('workId');
  @override
  late final GeneratedColumn<String> workId = GeneratedColumn<String>(
    'work_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES works (product_id)',
    ),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileKindMeta = const VerificationMeta(
    'fileKind',
  );
  @override
  late final GeneratedColumn<String> fileKind = GeneratedColumn<String>(
    'file_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileSizeBytesMeta = const VerificationMeta(
    'fileSizeBytes',
  );
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
    'file_size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workId,
    filePath,
    relativePath,
    fileName,
    fileKind,
    fileSizeBytes,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'work_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkFile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('work_id')) {
      context.handle(
        _workIdMeta,
        workId.isAcceptableOrUnknown(data['work_id']!, _workIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workIdMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('file_kind')) {
      context.handle(
        _fileKindMeta,
        fileKind.isAcceptableOrUnknown(data['file_kind']!, _fileKindMeta),
      );
    } else if (isInserting) {
      context.missing(_fileKindMeta);
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(
        _fileSizeBytesMeta,
        fileSizeBytes.isAcceptableOrUnknown(
          data['file_size_bytes']!,
          _fileSizeBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fileSizeBytesMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkFile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkFile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      workId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_id'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      fileKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_kind'],
      )!,
      fileSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size_bytes'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $WorkFilesTable createAlias(String alias) {
    return $WorkFilesTable(attachedDatabase, alias);
  }
}

class WorkFile extends DataClass implements Insertable<WorkFile> {
  final String id;
  final String workId;
  final String filePath;
  final String relativePath;
  final String fileName;

  /// 'image' / 'subtitle' / 'text' / 'other'
  final String fileKind;
  final int fileSizeBytes;
  final DateTime createdAt;
  final DateTime updatedAt;
  const WorkFile({
    required this.id,
    required this.workId,
    required this.filePath,
    required this.relativePath,
    required this.fileName,
    required this.fileKind,
    required this.fileSizeBytes,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['work_id'] = Variable<String>(workId);
    map['file_path'] = Variable<String>(filePath);
    map['relative_path'] = Variable<String>(relativePath);
    map['file_name'] = Variable<String>(fileName);
    map['file_kind'] = Variable<String>(fileKind);
    map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WorkFilesCompanion toCompanion(bool nullToAbsent) {
    return WorkFilesCompanion(
      id: Value(id),
      workId: Value(workId),
      filePath: Value(filePath),
      relativePath: Value(relativePath),
      fileName: Value(fileName),
      fileKind: Value(fileKind),
      fileSizeBytes: Value(fileSizeBytes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory WorkFile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkFile(
      id: serializer.fromJson<String>(json['id']),
      workId: serializer.fromJson<String>(json['workId']),
      filePath: serializer.fromJson<String>(json['filePath']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      fileName: serializer.fromJson<String>(json['fileName']),
      fileKind: serializer.fromJson<String>(json['fileKind']),
      fileSizeBytes: serializer.fromJson<int>(json['fileSizeBytes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workId': serializer.toJson<String>(workId),
      'filePath': serializer.toJson<String>(filePath),
      'relativePath': serializer.toJson<String>(relativePath),
      'fileName': serializer.toJson<String>(fileName),
      'fileKind': serializer.toJson<String>(fileKind),
      'fileSizeBytes': serializer.toJson<int>(fileSizeBytes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WorkFile copyWith({
    String? id,
    String? workId,
    String? filePath,
    String? relativePath,
    String? fileName,
    String? fileKind,
    int? fileSizeBytes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => WorkFile(
    id: id ?? this.id,
    workId: workId ?? this.workId,
    filePath: filePath ?? this.filePath,
    relativePath: relativePath ?? this.relativePath,
    fileName: fileName ?? this.fileName,
    fileKind: fileKind ?? this.fileKind,
    fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WorkFile copyWithCompanion(WorkFilesCompanion data) {
    return WorkFile(
      id: data.id.present ? data.id.value : this.id,
      workId: data.workId.present ? data.workId.value : this.workId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      fileKind: data.fileKind.present ? data.fileKind.value : this.fileKind,
      fileSizeBytes: data.fileSizeBytes.present
          ? data.fileSizeBytes.value
          : this.fileSizeBytes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkFile(')
          ..write('id: $id, ')
          ..write('workId: $workId, ')
          ..write('filePath: $filePath, ')
          ..write('relativePath: $relativePath, ')
          ..write('fileName: $fileName, ')
          ..write('fileKind: $fileKind, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    workId,
    filePath,
    relativePath,
    fileName,
    fileKind,
    fileSizeBytes,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkFile &&
          other.id == this.id &&
          other.workId == this.workId &&
          other.filePath == this.filePath &&
          other.relativePath == this.relativePath &&
          other.fileName == this.fileName &&
          other.fileKind == this.fileKind &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WorkFilesCompanion extends UpdateCompanion<WorkFile> {
  final Value<String> id;
  final Value<String> workId;
  final Value<String> filePath;
  final Value<String> relativePath;
  final Value<String> fileName;
  final Value<String> fileKind;
  final Value<int> fileSizeBytes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WorkFilesCompanion({
    this.id = const Value.absent(),
    this.workId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.fileName = const Value.absent(),
    this.fileKind = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkFilesCompanion.insert({
    required String id,
    required String workId,
    required String filePath,
    required String relativePath,
    required String fileName,
    required String fileKind,
    required int fileSizeBytes,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       workId = Value(workId),
       filePath = Value(filePath),
       relativePath = Value(relativePath),
       fileName = Value(fileName),
       fileKind = Value(fileKind),
       fileSizeBytes = Value(fileSizeBytes),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<WorkFile> custom({
    Expression<String>? id,
    Expression<String>? workId,
    Expression<String>? filePath,
    Expression<String>? relativePath,
    Expression<String>? fileName,
    Expression<String>? fileKind,
    Expression<int>? fileSizeBytes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workId != null) 'work_id': workId,
      if (filePath != null) 'file_path': filePath,
      if (relativePath != null) 'relative_path': relativePath,
      if (fileName != null) 'file_name': fileName,
      if (fileKind != null) 'file_kind': fileKind,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkFilesCompanion copyWith({
    Value<String>? id,
    Value<String>? workId,
    Value<String>? filePath,
    Value<String>? relativePath,
    Value<String>? fileName,
    Value<String>? fileKind,
    Value<int>? fileSizeBytes,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return WorkFilesCompanion(
      id: id ?? this.id,
      workId: workId ?? this.workId,
      filePath: filePath ?? this.filePath,
      relativePath: relativePath ?? this.relativePath,
      fileName: fileName ?? this.fileName,
      fileKind: fileKind ?? this.fileKind,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workId.present) {
      map['work_id'] = Variable<String>(workId.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (fileKind.present) {
      map['file_kind'] = Variable<String>(fileKind.value);
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkFilesCompanion(')
          ..write('id: $id, ')
          ..write('workId: $workId, ')
          ..write('filePath: $filePath, ')
          ..write('relativePath: $relativePath, ')
          ..write('fileName: $fileName, ')
          ..write('fileKind: $fileKind, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubtitlesTable extends Subtitles
    with TableInfo<$SubtitlesTable, Subtitle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubtitlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id)',
    ),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileFormatMeta = const VerificationMeta(
    'fileFormat',
  );
  @override
  late final GeneratedColumn<String> fileFormat = GeneratedColumn<String>(
    'file_format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileHashMeta = const VerificationMeta(
    'fileHash',
  );
  @override
  late final GeneratedColumn<String> fileHash = GeneratedColumn<String>(
    'file_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeOffsetMsMeta = const VerificationMeta(
    'timeOffsetMs',
  );
  @override
  late final GeneratedColumn<int> timeOffsetMs = GeneratedColumn<int>(
    'time_offset_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _originalLinesJsonMeta = const VerificationMeta(
    'originalLinesJson',
  );
  @override
  late final GeneratedColumn<String> originalLinesJson =
      GeneratedColumn<String>(
        'original_lines_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _translatedLinesJsonMeta =
      const VerificationMeta('translatedLinesJson');
  @override
  late final GeneratedColumn<String> translatedLinesJson =
      GeneratedColumn<String>(
        'translated_lines_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _translatedAtMeta = const VerificationMeta(
    'translatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> translatedAt = GeneratedColumn<DateTime>(
    'translated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _translatedByModelMeta = const VerificationMeta(
    'translatedByModel',
  );
  @override
  late final GeneratedColumn<String> translatedByModel =
      GeneratedColumn<String>(
        'translated_by_model',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackId,
    filePath,
    fileFormat,
    fileHash,
    timeOffsetMs,
    originalLinesJson,
    translatedLinesJson,
    translatedAt,
    translatedByModel,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subtitles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Subtitle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('file_format')) {
      context.handle(
        _fileFormatMeta,
        fileFormat.isAcceptableOrUnknown(data['file_format']!, _fileFormatMeta),
      );
    } else if (isInserting) {
      context.missing(_fileFormatMeta);
    }
    if (data.containsKey('file_hash')) {
      context.handle(
        _fileHashMeta,
        fileHash.isAcceptableOrUnknown(data['file_hash']!, _fileHashMeta),
      );
    } else if (isInserting) {
      context.missing(_fileHashMeta);
    }
    if (data.containsKey('time_offset_ms')) {
      context.handle(
        _timeOffsetMsMeta,
        timeOffsetMs.isAcceptableOrUnknown(
          data['time_offset_ms']!,
          _timeOffsetMsMeta,
        ),
      );
    }
    if (data.containsKey('original_lines_json')) {
      context.handle(
        _originalLinesJsonMeta,
        originalLinesJson.isAcceptableOrUnknown(
          data['original_lines_json']!,
          _originalLinesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalLinesJsonMeta);
    }
    if (data.containsKey('translated_lines_json')) {
      context.handle(
        _translatedLinesJsonMeta,
        translatedLinesJson.isAcceptableOrUnknown(
          data['translated_lines_json']!,
          _translatedLinesJsonMeta,
        ),
      );
    }
    if (data.containsKey('translated_at')) {
      context.handle(
        _translatedAtMeta,
        translatedAt.isAcceptableOrUnknown(
          data['translated_at']!,
          _translatedAtMeta,
        ),
      );
    }
    if (data.containsKey('translated_by_model')) {
      context.handle(
        _translatedByModelMeta,
        translatedByModel.isAcceptableOrUnknown(
          data['translated_by_model']!,
          _translatedByModelMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Subtitle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Subtitle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      fileFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_format'],
      )!,
      fileHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_hash'],
      )!,
      timeOffsetMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_offset_ms'],
      )!,
      originalLinesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_lines_json'],
      )!,
      translatedLinesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translated_lines_json'],
      ),
      translatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}translated_at'],
      ),
      translatedByModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translated_by_model'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SubtitlesTable createAlias(String alias) {
    return $SubtitlesTable(attachedDatabase, alias);
  }
}

class Subtitle extends DataClass implements Insertable<Subtitle> {
  final String id;
  final String trackId;
  final String filePath;
  final String fileFormat;
  final String fileHash;
  final int timeOffsetMs;
  final String originalLinesJson;
  final String? translatedLinesJson;
  final DateTime? translatedAt;
  final String? translatedByModel;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Subtitle({
    required this.id,
    required this.trackId,
    required this.filePath,
    required this.fileFormat,
    required this.fileHash,
    required this.timeOffsetMs,
    required this.originalLinesJson,
    this.translatedLinesJson,
    this.translatedAt,
    this.translatedByModel,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['track_id'] = Variable<String>(trackId);
    map['file_path'] = Variable<String>(filePath);
    map['file_format'] = Variable<String>(fileFormat);
    map['file_hash'] = Variable<String>(fileHash);
    map['time_offset_ms'] = Variable<int>(timeOffsetMs);
    map['original_lines_json'] = Variable<String>(originalLinesJson);
    if (!nullToAbsent || translatedLinesJson != null) {
      map['translated_lines_json'] = Variable<String>(translatedLinesJson);
    }
    if (!nullToAbsent || translatedAt != null) {
      map['translated_at'] = Variable<DateTime>(translatedAt);
    }
    if (!nullToAbsent || translatedByModel != null) {
      map['translated_by_model'] = Variable<String>(translatedByModel);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SubtitlesCompanion toCompanion(bool nullToAbsent) {
    return SubtitlesCompanion(
      id: Value(id),
      trackId: Value(trackId),
      filePath: Value(filePath),
      fileFormat: Value(fileFormat),
      fileHash: Value(fileHash),
      timeOffsetMs: Value(timeOffsetMs),
      originalLinesJson: Value(originalLinesJson),
      translatedLinesJson: translatedLinesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(translatedLinesJson),
      translatedAt: translatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(translatedAt),
      translatedByModel: translatedByModel == null && nullToAbsent
          ? const Value.absent()
          : Value(translatedByModel),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Subtitle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Subtitle(
      id: serializer.fromJson<String>(json['id']),
      trackId: serializer.fromJson<String>(json['trackId']),
      filePath: serializer.fromJson<String>(json['filePath']),
      fileFormat: serializer.fromJson<String>(json['fileFormat']),
      fileHash: serializer.fromJson<String>(json['fileHash']),
      timeOffsetMs: serializer.fromJson<int>(json['timeOffsetMs']),
      originalLinesJson: serializer.fromJson<String>(json['originalLinesJson']),
      translatedLinesJson: serializer.fromJson<String?>(
        json['translatedLinesJson'],
      ),
      translatedAt: serializer.fromJson<DateTime?>(json['translatedAt']),
      translatedByModel: serializer.fromJson<String?>(
        json['translatedByModel'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'trackId': serializer.toJson<String>(trackId),
      'filePath': serializer.toJson<String>(filePath),
      'fileFormat': serializer.toJson<String>(fileFormat),
      'fileHash': serializer.toJson<String>(fileHash),
      'timeOffsetMs': serializer.toJson<int>(timeOffsetMs),
      'originalLinesJson': serializer.toJson<String>(originalLinesJson),
      'translatedLinesJson': serializer.toJson<String?>(translatedLinesJson),
      'translatedAt': serializer.toJson<DateTime?>(translatedAt),
      'translatedByModel': serializer.toJson<String?>(translatedByModel),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Subtitle copyWith({
    String? id,
    String? trackId,
    String? filePath,
    String? fileFormat,
    String? fileHash,
    int? timeOffsetMs,
    String? originalLinesJson,
    Value<String?> translatedLinesJson = const Value.absent(),
    Value<DateTime?> translatedAt = const Value.absent(),
    Value<String?> translatedByModel = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Subtitle(
    id: id ?? this.id,
    trackId: trackId ?? this.trackId,
    filePath: filePath ?? this.filePath,
    fileFormat: fileFormat ?? this.fileFormat,
    fileHash: fileHash ?? this.fileHash,
    timeOffsetMs: timeOffsetMs ?? this.timeOffsetMs,
    originalLinesJson: originalLinesJson ?? this.originalLinesJson,
    translatedLinesJson: translatedLinesJson.present
        ? translatedLinesJson.value
        : this.translatedLinesJson,
    translatedAt: translatedAt.present ? translatedAt.value : this.translatedAt,
    translatedByModel: translatedByModel.present
        ? translatedByModel.value
        : this.translatedByModel,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Subtitle copyWithCompanion(SubtitlesCompanion data) {
    return Subtitle(
      id: data.id.present ? data.id.value : this.id,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileFormat: data.fileFormat.present
          ? data.fileFormat.value
          : this.fileFormat,
      fileHash: data.fileHash.present ? data.fileHash.value : this.fileHash,
      timeOffsetMs: data.timeOffsetMs.present
          ? data.timeOffsetMs.value
          : this.timeOffsetMs,
      originalLinesJson: data.originalLinesJson.present
          ? data.originalLinesJson.value
          : this.originalLinesJson,
      translatedLinesJson: data.translatedLinesJson.present
          ? data.translatedLinesJson.value
          : this.translatedLinesJson,
      translatedAt: data.translatedAt.present
          ? data.translatedAt.value
          : this.translatedAt,
      translatedByModel: data.translatedByModel.present
          ? data.translatedByModel.value
          : this.translatedByModel,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Subtitle(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('filePath: $filePath, ')
          ..write('fileFormat: $fileFormat, ')
          ..write('fileHash: $fileHash, ')
          ..write('timeOffsetMs: $timeOffsetMs, ')
          ..write('originalLinesJson: $originalLinesJson, ')
          ..write('translatedLinesJson: $translatedLinesJson, ')
          ..write('translatedAt: $translatedAt, ')
          ..write('translatedByModel: $translatedByModel, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    trackId,
    filePath,
    fileFormat,
    fileHash,
    timeOffsetMs,
    originalLinesJson,
    translatedLinesJson,
    translatedAt,
    translatedByModel,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Subtitle &&
          other.id == this.id &&
          other.trackId == this.trackId &&
          other.filePath == this.filePath &&
          other.fileFormat == this.fileFormat &&
          other.fileHash == this.fileHash &&
          other.timeOffsetMs == this.timeOffsetMs &&
          other.originalLinesJson == this.originalLinesJson &&
          other.translatedLinesJson == this.translatedLinesJson &&
          other.translatedAt == this.translatedAt &&
          other.translatedByModel == this.translatedByModel &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SubtitlesCompanion extends UpdateCompanion<Subtitle> {
  final Value<String> id;
  final Value<String> trackId;
  final Value<String> filePath;
  final Value<String> fileFormat;
  final Value<String> fileHash;
  final Value<int> timeOffsetMs;
  final Value<String> originalLinesJson;
  final Value<String?> translatedLinesJson;
  final Value<DateTime?> translatedAt;
  final Value<String?> translatedByModel;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SubtitlesCompanion({
    this.id = const Value.absent(),
    this.trackId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileFormat = const Value.absent(),
    this.fileHash = const Value.absent(),
    this.timeOffsetMs = const Value.absent(),
    this.originalLinesJson = const Value.absent(),
    this.translatedLinesJson = const Value.absent(),
    this.translatedAt = const Value.absent(),
    this.translatedByModel = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubtitlesCompanion.insert({
    required String id,
    required String trackId,
    required String filePath,
    required String fileFormat,
    required String fileHash,
    this.timeOffsetMs = const Value.absent(),
    required String originalLinesJson,
    this.translatedLinesJson = const Value.absent(),
    this.translatedAt = const Value.absent(),
    this.translatedByModel = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       trackId = Value(trackId),
       filePath = Value(filePath),
       fileFormat = Value(fileFormat),
       fileHash = Value(fileHash),
       originalLinesJson = Value(originalLinesJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Subtitle> custom({
    Expression<String>? id,
    Expression<String>? trackId,
    Expression<String>? filePath,
    Expression<String>? fileFormat,
    Expression<String>? fileHash,
    Expression<int>? timeOffsetMs,
    Expression<String>? originalLinesJson,
    Expression<String>? translatedLinesJson,
    Expression<DateTime>? translatedAt,
    Expression<String>? translatedByModel,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackId != null) 'track_id': trackId,
      if (filePath != null) 'file_path': filePath,
      if (fileFormat != null) 'file_format': fileFormat,
      if (fileHash != null) 'file_hash': fileHash,
      if (timeOffsetMs != null) 'time_offset_ms': timeOffsetMs,
      if (originalLinesJson != null) 'original_lines_json': originalLinesJson,
      if (translatedLinesJson != null)
        'translated_lines_json': translatedLinesJson,
      if (translatedAt != null) 'translated_at': translatedAt,
      if (translatedByModel != null) 'translated_by_model': translatedByModel,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubtitlesCompanion copyWith({
    Value<String>? id,
    Value<String>? trackId,
    Value<String>? filePath,
    Value<String>? fileFormat,
    Value<String>? fileHash,
    Value<int>? timeOffsetMs,
    Value<String>? originalLinesJson,
    Value<String?>? translatedLinesJson,
    Value<DateTime?>? translatedAt,
    Value<String?>? translatedByModel,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SubtitlesCompanion(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      filePath: filePath ?? this.filePath,
      fileFormat: fileFormat ?? this.fileFormat,
      fileHash: fileHash ?? this.fileHash,
      timeOffsetMs: timeOffsetMs ?? this.timeOffsetMs,
      originalLinesJson: originalLinesJson ?? this.originalLinesJson,
      translatedLinesJson: translatedLinesJson ?? this.translatedLinesJson,
      translatedAt: translatedAt ?? this.translatedAt,
      translatedByModel: translatedByModel ?? this.translatedByModel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileFormat.present) {
      map['file_format'] = Variable<String>(fileFormat.value);
    }
    if (fileHash.present) {
      map['file_hash'] = Variable<String>(fileHash.value);
    }
    if (timeOffsetMs.present) {
      map['time_offset_ms'] = Variable<int>(timeOffsetMs.value);
    }
    if (originalLinesJson.present) {
      map['original_lines_json'] = Variable<String>(originalLinesJson.value);
    }
    if (translatedLinesJson.present) {
      map['translated_lines_json'] = Variable<String>(
        translatedLinesJson.value,
      );
    }
    if (translatedAt.present) {
      map['translated_at'] = Variable<DateTime>(translatedAt.value);
    }
    if (translatedByModel.present) {
      map['translated_by_model'] = Variable<String>(translatedByModel.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubtitlesCompanion(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('filePath: $filePath, ')
          ..write('fileFormat: $fileFormat, ')
          ..write('fileHash: $fileHash, ')
          ..write('timeOffsetMs: $timeOffsetMs, ')
          ..write('originalLinesJson: $originalLinesJson, ')
          ..write('translatedLinesJson: $translatedLinesJson, ')
          ..write('translatedAt: $translatedAt, ')
          ..write('translatedByModel: $translatedByModel, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImportedFoldersTable extends ImportedFolders
    with TableInfo<$ImportedFoldersTable, ImportedFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportedFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookmarkBase64Meta = const VerificationMeta(
    'bookmarkBase64',
  );
  @override
  late final GeneratedColumn<String> bookmarkBase64 = GeneratedColumn<String>(
    'bookmark_base64',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    bookmarkBase64,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'imported_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportedFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('bookmark_base64')) {
      context.handle(
        _bookmarkBase64Meta,
        bookmarkBase64.isAcceptableOrUnknown(
          data['bookmark_base64']!,
          _bookmarkBase64Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bookmarkBase64Meta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImportedFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportedFolder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      bookmarkBase64: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bookmark_base64'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ImportedFoldersTable createAlias(String alias) {
    return $ImportedFoldersTable(attachedDatabase, alias);
  }
}

class ImportedFolder extends DataClass implements Insertable<ImportedFolder> {
  final String id;
  final String displayName;
  final String bookmarkBase64;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ImportedFolder({
    required this.id,
    required this.displayName,
    required this.bookmarkBase64,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['bookmark_base64'] = Variable<String>(bookmarkBase64);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ImportedFoldersCompanion toCompanion(bool nullToAbsent) {
    return ImportedFoldersCompanion(
      id: Value(id),
      displayName: Value(displayName),
      bookmarkBase64: Value(bookmarkBase64),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ImportedFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportedFolder(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      bookmarkBase64: serializer.fromJson<String>(json['bookmarkBase64']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'bookmarkBase64': serializer.toJson<String>(bookmarkBase64),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ImportedFolder copyWith({
    String? id,
    String? displayName,
    String? bookmarkBase64,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ImportedFolder(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    bookmarkBase64: bookmarkBase64 ?? this.bookmarkBase64,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ImportedFolder copyWithCompanion(ImportedFoldersCompanion data) {
    return ImportedFolder(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      bookmarkBase64: data.bookmarkBase64.present
          ? data.bookmarkBase64.value
          : this.bookmarkBase64,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportedFolder(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('bookmarkBase64: $bookmarkBase64, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, displayName, bookmarkBase64, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportedFolder &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.bookmarkBase64 == this.bookmarkBase64 &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ImportedFoldersCompanion extends UpdateCompanion<ImportedFolder> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String> bookmarkBase64;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ImportedFoldersCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.bookmarkBase64 = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImportedFoldersCompanion.insert({
    required String id,
    required String displayName,
    required String bookmarkBase64,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       displayName = Value(displayName),
       bookmarkBase64 = Value(bookmarkBase64),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ImportedFolder> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? bookmarkBase64,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (bookmarkBase64 != null) 'bookmark_base64': bookmarkBase64,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImportedFoldersCompanion copyWith({
    Value<String>? id,
    Value<String>? displayName,
    Value<String>? bookmarkBase64,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ImportedFoldersCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      bookmarkBase64: bookmarkBase64 ?? this.bookmarkBase64,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (bookmarkBase64.present) {
      map['bookmark_base64'] = Variable<String>(bookmarkBase64.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportedFoldersCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('bookmarkBase64: $bookmarkBase64, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LlmProvidersTable extends LlmProviders
    with TableInfo<$LlmProvidersTable, LlmProvider> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LlmProvidersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _systemPromptMeta = const VerificationMeta(
    'systemPrompt',
  );
  @override
  late final GeneratedColumn<String> systemPrompt = GeneratedColumn<String>(
    'system_prompt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    baseUrl,
    model,
    systemPrompt,
    isDefault,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'llm_providers';
  @override
  VerificationContext validateIntegrity(
    Insertable<LlmProvider> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('system_prompt')) {
      context.handle(
        _systemPromptMeta,
        systemPrompt.isAcceptableOrUnknown(
          data['system_prompt']!,
          _systemPromptMeta,
        ),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LlmProvider map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LlmProvider(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      systemPrompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}system_prompt'],
      ),
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LlmProvidersTable createAlias(String alias) {
    return $LlmProvidersTable(attachedDatabase, alias);
  }
}

class LlmProvider extends DataClass implements Insertable<LlmProvider> {
  final String id;
  final String name;
  final String baseUrl;
  final String model;
  final String? systemPrompt;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LlmProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.model,
    this.systemPrompt,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['base_url'] = Variable<String>(baseUrl);
    map['model'] = Variable<String>(model);
    if (!nullToAbsent || systemPrompt != null) {
      map['system_prompt'] = Variable<String>(systemPrompt);
    }
    map['is_default'] = Variable<bool>(isDefault);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LlmProvidersCompanion toCompanion(bool nullToAbsent) {
    return LlmProvidersCompanion(
      id: Value(id),
      name: Value(name),
      baseUrl: Value(baseUrl),
      model: Value(model),
      systemPrompt: systemPrompt == null && nullToAbsent
          ? const Value.absent()
          : Value(systemPrompt),
      isDefault: Value(isDefault),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LlmProvider.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LlmProvider(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      model: serializer.fromJson<String>(json['model']),
      systemPrompt: serializer.fromJson<String?>(json['systemPrompt']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'model': serializer.toJson<String>(model),
      'systemPrompt': serializer.toJson<String?>(systemPrompt),
      'isDefault': serializer.toJson<bool>(isDefault),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LlmProvider copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? model,
    Value<String?> systemPrompt = const Value.absent(),
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LlmProvider(
    id: id ?? this.id,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    systemPrompt: systemPrompt.present ? systemPrompt.value : this.systemPrompt,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LlmProvider copyWithCompanion(LlmProvidersCompanion data) {
    return LlmProvider(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      model: data.model.present ? data.model.value : this.model,
      systemPrompt: data.systemPrompt.present
          ? data.systemPrompt.value
          : this.systemPrompt,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LlmProvider(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('model: $model, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    baseUrl,
    model,
    systemPrompt,
    isDefault,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LlmProvider &&
          other.id == this.id &&
          other.name == this.name &&
          other.baseUrl == this.baseUrl &&
          other.model == this.model &&
          other.systemPrompt == this.systemPrompt &&
          other.isDefault == this.isDefault &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LlmProvidersCompanion extends UpdateCompanion<LlmProvider> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> baseUrl;
  final Value<String> model;
  final Value<String?> systemPrompt;
  final Value<bool> isDefault;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LlmProvidersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.model = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LlmProvidersCompanion.insert({
    required String id,
    required String name,
    required String baseUrl,
    required String model,
    this.systemPrompt = const Value.absent(),
    this.isDefault = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       baseUrl = Value(baseUrl),
       model = Value(model),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LlmProvider> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? baseUrl,
    Expression<String>? model,
    Expression<String>? systemPrompt,
    Expression<bool>? isDefault,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (baseUrl != null) 'base_url': baseUrl,
      if (model != null) 'model': model,
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      if (isDefault != null) 'is_default': isDefault,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LlmProvidersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? baseUrl,
    Value<String>? model,
    Value<String?>? systemPrompt,
    Value<bool>? isDefault,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LlmProvidersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (systemPrompt.present) {
      map['system_prompt'] = Variable<String>(systemPrompt.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LlmProvidersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('model: $model, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$TonariDatabase extends GeneratedDatabase {
  _$TonariDatabase(QueryExecutor e) : super(e);
  $TonariDatabaseManager get managers => $TonariDatabaseManager(this);
  late final $WorksTable works = $WorksTable(this);
  late final $TracksTable tracks = $TracksTable(this);
  late final $WorkFilesTable workFiles = $WorkFilesTable(this);
  late final $SubtitlesTable subtitles = $SubtitlesTable(this);
  late final $ImportedFoldersTable importedFolders = $ImportedFoldersTable(
    this,
  );
  late final $LlmProvidersTable llmProviders = $LlmProvidersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    works,
    tracks,
    workFiles,
    subtitles,
    importedFolders,
    llmProviders,
  ];
}

typedef $$WorksTableCreateCompanionBuilder =
    WorksCompanion Function({
      required String productId,
      required String title,
      Value<String?> titleRomaji,
      Value<String?> translatedTitle,
      Value<String?> originalProductId,
      Value<String?> circleId,
      Value<String?> circleName,
      Value<DateTime?> releaseDate,
      Value<List<String>> voiceActors,
      Value<List<String>> illustrators,
      Value<List<String>> scenarioWriters,
      Value<List<String>> musicians,
      Value<String?> ageRating,
      Value<String?> workType,
      Value<String?> workTypeName,
      Value<List<String>> fileFormats,
      Value<String> genresJson,
      Value<String?> fileSize,
      Value<String?> seriesId,
      Value<String?> seriesName,
      Value<String?> descriptionHtml,
      Value<String?> titleZh,
      Value<String?> descriptionHtmlZh,
      Value<String?> mainImageUrl,
      Value<List<String>> sampleImageUrls,
      Value<String?> mainImageLocalPath,
      Value<List<String>> sampleImageLocalPaths,
      Value<List<String>> descriptionImageLocalPaths,
      Value<int?> officialPrice,
      Value<int?> currentPrice,
      Value<int?> discountRate,
      Value<double?> rating,
      Value<int?> ratingCount,
      Value<int?> dlCount,
      Value<int?> wishlistCount,
      Value<int?> reviewCount,
      Value<int?> rankDay,
      Value<int?> rankWeek,
      Value<int?> rankMonth,
      Value<List<String>> supportedLanguages,
      Value<DateTime?> scrapedAt,
      required DateTime localImportedAt,
      required String localFolderPath,
      Value<String?> importedFolderId,
      Value<DateTime?> lastPlayedAt,
      Value<String?> lastPlayedTrackId,
      Value<bool> isFavorite,
      Value<bool> isRemoved,
      Value<bool> needsRescan,
      Value<int?> userRating,
      Value<List<String>> userTags,
      Value<String?> notes,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$WorksTableUpdateCompanionBuilder =
    WorksCompanion Function({
      Value<String> productId,
      Value<String> title,
      Value<String?> titleRomaji,
      Value<String?> translatedTitle,
      Value<String?> originalProductId,
      Value<String?> circleId,
      Value<String?> circleName,
      Value<DateTime?> releaseDate,
      Value<List<String>> voiceActors,
      Value<List<String>> illustrators,
      Value<List<String>> scenarioWriters,
      Value<List<String>> musicians,
      Value<String?> ageRating,
      Value<String?> workType,
      Value<String?> workTypeName,
      Value<List<String>> fileFormats,
      Value<String> genresJson,
      Value<String?> fileSize,
      Value<String?> seriesId,
      Value<String?> seriesName,
      Value<String?> descriptionHtml,
      Value<String?> titleZh,
      Value<String?> descriptionHtmlZh,
      Value<String?> mainImageUrl,
      Value<List<String>> sampleImageUrls,
      Value<String?> mainImageLocalPath,
      Value<List<String>> sampleImageLocalPaths,
      Value<List<String>> descriptionImageLocalPaths,
      Value<int?> officialPrice,
      Value<int?> currentPrice,
      Value<int?> discountRate,
      Value<double?> rating,
      Value<int?> ratingCount,
      Value<int?> dlCount,
      Value<int?> wishlistCount,
      Value<int?> reviewCount,
      Value<int?> rankDay,
      Value<int?> rankWeek,
      Value<int?> rankMonth,
      Value<List<String>> supportedLanguages,
      Value<DateTime?> scrapedAt,
      Value<DateTime> localImportedAt,
      Value<String> localFolderPath,
      Value<String?> importedFolderId,
      Value<DateTime?> lastPlayedAt,
      Value<String?> lastPlayedTrackId,
      Value<bool> isFavorite,
      Value<bool> isRemoved,
      Value<bool> needsRescan,
      Value<int?> userRating,
      Value<List<String>> userTags,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$WorksTableReferences
    extends BaseReferences<_$TonariDatabase, $WorksTable, Work> {
  $$WorksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TracksTable, List<Track>> _tracksRefsTable(
    _$TonariDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tracks,
    aliasName: $_aliasNameGenerator(db.works.productId, db.tracks.workId),
  );

  $$TracksTableProcessedTableManager get tracksRefs {
    final manager = $$TracksTableTableManager($_db, $_db.tracks).filter(
      (f) => f.workId.productId.sqlEquals($_itemColumn<String>('product_id')!),
    );

    final cache = $_typedResult.readTableOrNull(_tracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WorkFilesTable, List<WorkFile>>
  _workFilesRefsTable(_$TonariDatabase db) => MultiTypedResultKey.fromTable(
    db.workFiles,
    aliasName: $_aliasNameGenerator(db.works.productId, db.workFiles.workId),
  );

  $$WorkFilesTableProcessedTableManager get workFilesRefs {
    final manager = $$WorkFilesTableTableManager($_db, $_db.workFiles).filter(
      (f) => f.workId.productId.sqlEquals($_itemColumn<String>('product_id')!),
    );

    final cache = $_typedResult.readTableOrNull(_workFilesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorksTableFilterComposer
    extends Composer<_$TonariDatabase, $WorksTable> {
  $$WorksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleRomaji => $composableBuilder(
    column: $table.titleRomaji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translatedTitle => $composableBuilder(
    column: $table.translatedTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalProductId => $composableBuilder(
    column: $table.originalProductId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get circleId => $composableBuilder(
    column: $table.circleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get circleName => $composableBuilder(
    column: $table.circleName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get voiceActors => $composableBuilder(
    column: $table.voiceActors,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get illustrators => $composableBuilder(
    column: $table.illustrators,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get scenarioWriters => $composableBuilder(
    column: $table.scenarioWriters,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get musicians => $composableBuilder(
    column: $table.musicians,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get ageRating => $composableBuilder(
    column: $table.ageRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workType => $composableBuilder(
    column: $table.workType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workTypeName => $composableBuilder(
    column: $table.workTypeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get fileFormats => $composableBuilder(
    column: $table.fileFormats,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get genresJson => $composableBuilder(
    column: $table.genresJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesName => $composableBuilder(
    column: $table.seriesName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get descriptionHtml => $composableBuilder(
    column: $table.descriptionHtml,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleZh => $composableBuilder(
    column: $table.titleZh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get descriptionHtmlZh => $composableBuilder(
    column: $table.descriptionHtmlZh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mainImageUrl => $composableBuilder(
    column: $table.mainImageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get sampleImageUrls => $composableBuilder(
    column: $table.sampleImageUrls,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get mainImageLocalPath => $composableBuilder(
    column: $table.mainImageLocalPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get sampleImageLocalPaths => $composableBuilder(
    column: $table.sampleImageLocalPaths,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get descriptionImageLocalPaths => $composableBuilder(
    column: $table.descriptionImageLocalPaths,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get officialPrice => $composableBuilder(
    column: $table.officialPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentPrice => $composableBuilder(
    column: $table.currentPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discountRate => $composableBuilder(
    column: $table.discountRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ratingCount => $composableBuilder(
    column: $table.ratingCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dlCount => $composableBuilder(
    column: $table.dlCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wishlistCount => $composableBuilder(
    column: $table.wishlistCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reviewCount => $composableBuilder(
    column: $table.reviewCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rankDay => $composableBuilder(
    column: $table.rankDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rankWeek => $composableBuilder(
    column: $table.rankWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rankMonth => $composableBuilder(
    column: $table.rankMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get supportedLanguages => $composableBuilder(
    column: $table.supportedLanguages,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get scrapedAt => $composableBuilder(
    column: $table.scrapedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get localImportedAt => $composableBuilder(
    column: $table.localImportedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localFolderPath => $composableBuilder(
    column: $table.localFolderPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importedFolderId => $composableBuilder(
    column: $table.importedFolderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastPlayedTrackId => $composableBuilder(
    column: $table.lastPlayedTrackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRemoved => $composableBuilder(
    column: $table.isRemoved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsRescan => $composableBuilder(
    column: $table.needsRescan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userRating => $composableBuilder(
    column: $table.userRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get userTags => $composableBuilder(
    column: $table.userTags,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tracksRefs(
    Expression<bool> Function($$TracksTableFilterComposer f) f,
  ) {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.workId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> workFilesRefs(
    Expression<bool> Function($$WorkFilesTableFilterComposer f) f,
  ) {
    final $$WorkFilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.workFiles,
      getReferencedColumn: (t) => t.workId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkFilesTableFilterComposer(
            $db: $db,
            $table: $db.workFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorksTableOrderingComposer
    extends Composer<_$TonariDatabase, $WorksTable> {
  $$WorksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleRomaji => $composableBuilder(
    column: $table.titleRomaji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translatedTitle => $composableBuilder(
    column: $table.translatedTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalProductId => $composableBuilder(
    column: $table.originalProductId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get circleId => $composableBuilder(
    column: $table.circleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get circleName => $composableBuilder(
    column: $table.circleName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voiceActors => $composableBuilder(
    column: $table.voiceActors,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get illustrators => $composableBuilder(
    column: $table.illustrators,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scenarioWriters => $composableBuilder(
    column: $table.scenarioWriters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get musicians => $composableBuilder(
    column: $table.musicians,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ageRating => $composableBuilder(
    column: $table.ageRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workType => $composableBuilder(
    column: $table.workType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workTypeName => $composableBuilder(
    column: $table.workTypeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileFormats => $composableBuilder(
    column: $table.fileFormats,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genresJson => $composableBuilder(
    column: $table.genresJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesName => $composableBuilder(
    column: $table.seriesName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get descriptionHtml => $composableBuilder(
    column: $table.descriptionHtml,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleZh => $composableBuilder(
    column: $table.titleZh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get descriptionHtmlZh => $composableBuilder(
    column: $table.descriptionHtmlZh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mainImageUrl => $composableBuilder(
    column: $table.mainImageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sampleImageUrls => $composableBuilder(
    column: $table.sampleImageUrls,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mainImageLocalPath => $composableBuilder(
    column: $table.mainImageLocalPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sampleImageLocalPaths => $composableBuilder(
    column: $table.sampleImageLocalPaths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get descriptionImageLocalPaths => $composableBuilder(
    column: $table.descriptionImageLocalPaths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get officialPrice => $composableBuilder(
    column: $table.officialPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentPrice => $composableBuilder(
    column: $table.currentPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discountRate => $composableBuilder(
    column: $table.discountRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ratingCount => $composableBuilder(
    column: $table.ratingCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dlCount => $composableBuilder(
    column: $table.dlCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wishlistCount => $composableBuilder(
    column: $table.wishlistCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reviewCount => $composableBuilder(
    column: $table.reviewCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rankDay => $composableBuilder(
    column: $table.rankDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rankWeek => $composableBuilder(
    column: $table.rankWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rankMonth => $composableBuilder(
    column: $table.rankMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supportedLanguages => $composableBuilder(
    column: $table.supportedLanguages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scrapedAt => $composableBuilder(
    column: $table.scrapedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get localImportedAt => $composableBuilder(
    column: $table.localImportedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localFolderPath => $composableBuilder(
    column: $table.localFolderPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importedFolderId => $composableBuilder(
    column: $table.importedFolderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastPlayedTrackId => $composableBuilder(
    column: $table.lastPlayedTrackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRemoved => $composableBuilder(
    column: $table.isRemoved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsRescan => $composableBuilder(
    column: $table.needsRescan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userRating => $composableBuilder(
    column: $table.userRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userTags => $composableBuilder(
    column: $table.userTags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorksTableAnnotationComposer
    extends Composer<_$TonariDatabase, $WorksTable> {
  $$WorksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get titleRomaji => $composableBuilder(
    column: $table.titleRomaji,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translatedTitle => $composableBuilder(
    column: $table.translatedTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalProductId => $composableBuilder(
    column: $table.originalProductId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get circleId =>
      $composableBuilder(column: $table.circleId, builder: (column) => column);

  GeneratedColumn<String> get circleName => $composableBuilder(
    column: $table.circleName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get voiceActors =>
      $composableBuilder(
        column: $table.voiceActors,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<String>, String> get illustrators =>
      $composableBuilder(
        column: $table.illustrators,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<String>, String> get scenarioWriters =>
      $composableBuilder(
        column: $table.scenarioWriters,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<String>, String> get musicians =>
      $composableBuilder(column: $table.musicians, builder: (column) => column);

  GeneratedColumn<String> get ageRating =>
      $composableBuilder(column: $table.ageRating, builder: (column) => column);

  GeneratedColumn<String> get workType =>
      $composableBuilder(column: $table.workType, builder: (column) => column);

  GeneratedColumn<String> get workTypeName => $composableBuilder(
    column: $table.workTypeName,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get fileFormats =>
      $composableBuilder(
        column: $table.fileFormats,
        builder: (column) => column,
      );

  GeneratedColumn<String> get genresJson => $composableBuilder(
    column: $table.genresJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get seriesId =>
      $composableBuilder(column: $table.seriesId, builder: (column) => column);

  GeneratedColumn<String> get seriesName => $composableBuilder(
    column: $table.seriesName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get descriptionHtml => $composableBuilder(
    column: $table.descriptionHtml,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleZh =>
      $composableBuilder(column: $table.titleZh, builder: (column) => column);

  GeneratedColumn<String> get descriptionHtmlZh => $composableBuilder(
    column: $table.descriptionHtmlZh,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mainImageUrl => $composableBuilder(
    column: $table.mainImageUrl,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get sampleImageUrls =>
      $composableBuilder(
        column: $table.sampleImageUrls,
        builder: (column) => column,
      );

  GeneratedColumn<String> get mainImageLocalPath => $composableBuilder(
    column: $table.mainImageLocalPath,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String>
  get sampleImageLocalPaths => $composableBuilder(
    column: $table.sampleImageLocalPaths,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String>
  get descriptionImageLocalPaths => $composableBuilder(
    column: $table.descriptionImageLocalPaths,
    builder: (column) => column,
  );

  GeneratedColumn<int> get officialPrice => $composableBuilder(
    column: $table.officialPrice,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentPrice => $composableBuilder(
    column: $table.currentPrice,
    builder: (column) => column,
  );

  GeneratedColumn<int> get discountRate => $composableBuilder(
    column: $table.discountRate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<int> get ratingCount => $composableBuilder(
    column: $table.ratingCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dlCount =>
      $composableBuilder(column: $table.dlCount, builder: (column) => column);

  GeneratedColumn<int> get wishlistCount => $composableBuilder(
    column: $table.wishlistCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reviewCount => $composableBuilder(
    column: $table.reviewCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rankDay =>
      $composableBuilder(column: $table.rankDay, builder: (column) => column);

  GeneratedColumn<int> get rankWeek =>
      $composableBuilder(column: $table.rankWeek, builder: (column) => column);

  GeneratedColumn<int> get rankMonth =>
      $composableBuilder(column: $table.rankMonth, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String>
  get supportedLanguages => $composableBuilder(
    column: $table.supportedLanguages,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scrapedAt =>
      $composableBuilder(column: $table.scrapedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get localImportedAt => $composableBuilder(
    column: $table.localImportedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localFolderPath => $composableBuilder(
    column: $table.localFolderPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importedFolderId => $composableBuilder(
    column: $table.importedFolderId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastPlayedTrackId => $composableBuilder(
    column: $table.lastPlayedTrackId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isRemoved =>
      $composableBuilder(column: $table.isRemoved, builder: (column) => column);

  GeneratedColumn<bool> get needsRescan => $composableBuilder(
    column: $table.needsRescan,
    builder: (column) => column,
  );

  GeneratedColumn<int> get userRating => $composableBuilder(
    column: $table.userRating,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get userTags =>
      $composableBuilder(column: $table.userTags, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> tracksRefs<T extends Object>(
    Expression<T> Function($$TracksTableAnnotationComposer a) f,
  ) {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.workId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> workFilesRefs<T extends Object>(
    Expression<T> Function($$WorkFilesTableAnnotationComposer a) f,
  ) {
    final $$WorkFilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.workFiles,
      getReferencedColumn: (t) => t.workId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkFilesTableAnnotationComposer(
            $db: $db,
            $table: $db.workFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorksTableTableManager
    extends
        RootTableManager<
          _$TonariDatabase,
          $WorksTable,
          Work,
          $$WorksTableFilterComposer,
          $$WorksTableOrderingComposer,
          $$WorksTableAnnotationComposer,
          $$WorksTableCreateCompanionBuilder,
          $$WorksTableUpdateCompanionBuilder,
          (Work, $$WorksTableReferences),
          Work,
          PrefetchHooks Function({bool tracksRefs, bool workFilesRefs})
        > {
  $$WorksTableTableManager(_$TonariDatabase db, $WorksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> productId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> titleRomaji = const Value.absent(),
                Value<String?> translatedTitle = const Value.absent(),
                Value<String?> originalProductId = const Value.absent(),
                Value<String?> circleId = const Value.absent(),
                Value<String?> circleName = const Value.absent(),
                Value<DateTime?> releaseDate = const Value.absent(),
                Value<List<String>> voiceActors = const Value.absent(),
                Value<List<String>> illustrators = const Value.absent(),
                Value<List<String>> scenarioWriters = const Value.absent(),
                Value<List<String>> musicians = const Value.absent(),
                Value<String?> ageRating = const Value.absent(),
                Value<String?> workType = const Value.absent(),
                Value<String?> workTypeName = const Value.absent(),
                Value<List<String>> fileFormats = const Value.absent(),
                Value<String> genresJson = const Value.absent(),
                Value<String?> fileSize = const Value.absent(),
                Value<String?> seriesId = const Value.absent(),
                Value<String?> seriesName = const Value.absent(),
                Value<String?> descriptionHtml = const Value.absent(),
                Value<String?> titleZh = const Value.absent(),
                Value<String?> descriptionHtmlZh = const Value.absent(),
                Value<String?> mainImageUrl = const Value.absent(),
                Value<List<String>> sampleImageUrls = const Value.absent(),
                Value<String?> mainImageLocalPath = const Value.absent(),
                Value<List<String>> sampleImageLocalPaths =
                    const Value.absent(),
                Value<List<String>> descriptionImageLocalPaths =
                    const Value.absent(),
                Value<int?> officialPrice = const Value.absent(),
                Value<int?> currentPrice = const Value.absent(),
                Value<int?> discountRate = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<int?> ratingCount = const Value.absent(),
                Value<int?> dlCount = const Value.absent(),
                Value<int?> wishlistCount = const Value.absent(),
                Value<int?> reviewCount = const Value.absent(),
                Value<int?> rankDay = const Value.absent(),
                Value<int?> rankWeek = const Value.absent(),
                Value<int?> rankMonth = const Value.absent(),
                Value<List<String>> supportedLanguages = const Value.absent(),
                Value<DateTime?> scrapedAt = const Value.absent(),
                Value<DateTime> localImportedAt = const Value.absent(),
                Value<String> localFolderPath = const Value.absent(),
                Value<String?> importedFolderId = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<String?> lastPlayedTrackId = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isRemoved = const Value.absent(),
                Value<bool> needsRescan = const Value.absent(),
                Value<int?> userRating = const Value.absent(),
                Value<List<String>> userTags = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorksCompanion(
                productId: productId,
                title: title,
                titleRomaji: titleRomaji,
                translatedTitle: translatedTitle,
                originalProductId: originalProductId,
                circleId: circleId,
                circleName: circleName,
                releaseDate: releaseDate,
                voiceActors: voiceActors,
                illustrators: illustrators,
                scenarioWriters: scenarioWriters,
                musicians: musicians,
                ageRating: ageRating,
                workType: workType,
                workTypeName: workTypeName,
                fileFormats: fileFormats,
                genresJson: genresJson,
                fileSize: fileSize,
                seriesId: seriesId,
                seriesName: seriesName,
                descriptionHtml: descriptionHtml,
                titleZh: titleZh,
                descriptionHtmlZh: descriptionHtmlZh,
                mainImageUrl: mainImageUrl,
                sampleImageUrls: sampleImageUrls,
                mainImageLocalPath: mainImageLocalPath,
                sampleImageLocalPaths: sampleImageLocalPaths,
                descriptionImageLocalPaths: descriptionImageLocalPaths,
                officialPrice: officialPrice,
                currentPrice: currentPrice,
                discountRate: discountRate,
                rating: rating,
                ratingCount: ratingCount,
                dlCount: dlCount,
                wishlistCount: wishlistCount,
                reviewCount: reviewCount,
                rankDay: rankDay,
                rankWeek: rankWeek,
                rankMonth: rankMonth,
                supportedLanguages: supportedLanguages,
                scrapedAt: scrapedAt,
                localImportedAt: localImportedAt,
                localFolderPath: localFolderPath,
                importedFolderId: importedFolderId,
                lastPlayedAt: lastPlayedAt,
                lastPlayedTrackId: lastPlayedTrackId,
                isFavorite: isFavorite,
                isRemoved: isRemoved,
                needsRescan: needsRescan,
                userRating: userRating,
                userTags: userTags,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String productId,
                required String title,
                Value<String?> titleRomaji = const Value.absent(),
                Value<String?> translatedTitle = const Value.absent(),
                Value<String?> originalProductId = const Value.absent(),
                Value<String?> circleId = const Value.absent(),
                Value<String?> circleName = const Value.absent(),
                Value<DateTime?> releaseDate = const Value.absent(),
                Value<List<String>> voiceActors = const Value.absent(),
                Value<List<String>> illustrators = const Value.absent(),
                Value<List<String>> scenarioWriters = const Value.absent(),
                Value<List<String>> musicians = const Value.absent(),
                Value<String?> ageRating = const Value.absent(),
                Value<String?> workType = const Value.absent(),
                Value<String?> workTypeName = const Value.absent(),
                Value<List<String>> fileFormats = const Value.absent(),
                Value<String> genresJson = const Value.absent(),
                Value<String?> fileSize = const Value.absent(),
                Value<String?> seriesId = const Value.absent(),
                Value<String?> seriesName = const Value.absent(),
                Value<String?> descriptionHtml = const Value.absent(),
                Value<String?> titleZh = const Value.absent(),
                Value<String?> descriptionHtmlZh = const Value.absent(),
                Value<String?> mainImageUrl = const Value.absent(),
                Value<List<String>> sampleImageUrls = const Value.absent(),
                Value<String?> mainImageLocalPath = const Value.absent(),
                Value<List<String>> sampleImageLocalPaths =
                    const Value.absent(),
                Value<List<String>> descriptionImageLocalPaths =
                    const Value.absent(),
                Value<int?> officialPrice = const Value.absent(),
                Value<int?> currentPrice = const Value.absent(),
                Value<int?> discountRate = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<int?> ratingCount = const Value.absent(),
                Value<int?> dlCount = const Value.absent(),
                Value<int?> wishlistCount = const Value.absent(),
                Value<int?> reviewCount = const Value.absent(),
                Value<int?> rankDay = const Value.absent(),
                Value<int?> rankWeek = const Value.absent(),
                Value<int?> rankMonth = const Value.absent(),
                Value<List<String>> supportedLanguages = const Value.absent(),
                Value<DateTime?> scrapedAt = const Value.absent(),
                required DateTime localImportedAt,
                required String localFolderPath,
                Value<String?> importedFolderId = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<String?> lastPlayedTrackId = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isRemoved = const Value.absent(),
                Value<bool> needsRescan = const Value.absent(),
                Value<int?> userRating = const Value.absent(),
                Value<List<String>> userTags = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WorksCompanion.insert(
                productId: productId,
                title: title,
                titleRomaji: titleRomaji,
                translatedTitle: translatedTitle,
                originalProductId: originalProductId,
                circleId: circleId,
                circleName: circleName,
                releaseDate: releaseDate,
                voiceActors: voiceActors,
                illustrators: illustrators,
                scenarioWriters: scenarioWriters,
                musicians: musicians,
                ageRating: ageRating,
                workType: workType,
                workTypeName: workTypeName,
                fileFormats: fileFormats,
                genresJson: genresJson,
                fileSize: fileSize,
                seriesId: seriesId,
                seriesName: seriesName,
                descriptionHtml: descriptionHtml,
                titleZh: titleZh,
                descriptionHtmlZh: descriptionHtmlZh,
                mainImageUrl: mainImageUrl,
                sampleImageUrls: sampleImageUrls,
                mainImageLocalPath: mainImageLocalPath,
                sampleImageLocalPaths: sampleImageLocalPaths,
                descriptionImageLocalPaths: descriptionImageLocalPaths,
                officialPrice: officialPrice,
                currentPrice: currentPrice,
                discountRate: discountRate,
                rating: rating,
                ratingCount: ratingCount,
                dlCount: dlCount,
                wishlistCount: wishlistCount,
                reviewCount: reviewCount,
                rankDay: rankDay,
                rankWeek: rankWeek,
                rankMonth: rankMonth,
                supportedLanguages: supportedLanguages,
                scrapedAt: scrapedAt,
                localImportedAt: localImportedAt,
                localFolderPath: localFolderPath,
                importedFolderId: importedFolderId,
                lastPlayedAt: lastPlayedAt,
                lastPlayedTrackId: lastPlayedTrackId,
                isFavorite: isFavorite,
                isRemoved: isRemoved,
                needsRescan: needsRescan,
                userRating: userRating,
                userTags: userTags,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$WorksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({tracksRefs = false, workFilesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (tracksRefs) db.tracks,
                if (workFilesRefs) db.workFiles,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tracksRefs)
                    await $_getPrefetchedData<Work, $WorksTable, Track>(
                      currentTable: table,
                      referencedTable: $$WorksTableReferences._tracksRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$WorksTableReferences(db, table, p0).tracksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.workId == item.productId,
                          ),
                      typedResults: items,
                    ),
                  if (workFilesRefs)
                    await $_getPrefetchedData<Work, $WorksTable, WorkFile>(
                      currentTable: table,
                      referencedTable: $$WorksTableReferences
                          ._workFilesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$WorksTableReferences(db, table, p0).workFilesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.workId == item.productId,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WorksTableProcessedTableManager =
    ProcessedTableManager<
      _$TonariDatabase,
      $WorksTable,
      Work,
      $$WorksTableFilterComposer,
      $$WorksTableOrderingComposer,
      $$WorksTableAnnotationComposer,
      $$WorksTableCreateCompanionBuilder,
      $$WorksTableUpdateCompanionBuilder,
      (Work, $$WorksTableReferences),
      Work,
      PrefetchHooks Function({bool tracksRefs, bool workFilesRefs})
    >;
typedef $$TracksTableCreateCompanionBuilder =
    TracksCompanion Function({
      required String id,
      required String workId,
      required String filePath,
      Value<String> relativePath,
      required String fileName,
      required String fileFormat,
      required int fileSizeBytes,
      required int durationMs,
      Value<int?> sampleRate,
      Value<int?> bitRate,
      Value<String?> categoryHint,
      Value<String?> userCategory,
      required String parentDirName,
      Value<int?> trackNumber,
      required String title,
      Value<String> alternateQualityPathsJson,
      Value<int> lastPositionMs,
      Value<int> playCount,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$TracksTableUpdateCompanionBuilder =
    TracksCompanion Function({
      Value<String> id,
      Value<String> workId,
      Value<String> filePath,
      Value<String> relativePath,
      Value<String> fileName,
      Value<String> fileFormat,
      Value<int> fileSizeBytes,
      Value<int> durationMs,
      Value<int?> sampleRate,
      Value<int?> bitRate,
      Value<String?> categoryHint,
      Value<String?> userCategory,
      Value<String> parentDirName,
      Value<int?> trackNumber,
      Value<String> title,
      Value<String> alternateQualityPathsJson,
      Value<int> lastPositionMs,
      Value<int> playCount,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$TracksTableReferences
    extends BaseReferences<_$TonariDatabase, $TracksTable, Track> {
  $$TracksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WorksTable _workIdTable(_$TonariDatabase db) => db.works.createAlias(
    $_aliasNameGenerator(db.tracks.workId, db.works.productId),
  );

  $$WorksTableProcessedTableManager get workId {
    final $_column = $_itemColumn<String>('work_id')!;

    final manager = $$WorksTableTableManager(
      $_db,
      $_db.works,
    ).filter((f) => f.productId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SubtitlesTable, List<Subtitle>>
  _subtitlesRefsTable(_$TonariDatabase db) => MultiTypedResultKey.fromTable(
    db.subtitles,
    aliasName: $_aliasNameGenerator(db.tracks.id, db.subtitles.trackId),
  );

  $$SubtitlesTableProcessedTableManager get subtitlesRefs {
    final manager = $$SubtitlesTableTableManager(
      $_db,
      $_db.subtitles,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_subtitlesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TracksTableFilterComposer
    extends Composer<_$TonariDatabase, $TracksTable> {
  $$TracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileFormat => $composableBuilder(
    column: $table.fileFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bitRate => $composableBuilder(
    column: $table.bitRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryHint => $composableBuilder(
    column: $table.categoryHint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userCategory => $composableBuilder(
    column: $table.userCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentDirName => $composableBuilder(
    column: $table.parentDirName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alternateQualityPathsJson => $composableBuilder(
    column: $table.alternateQualityPathsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPositionMs => $composableBuilder(
    column: $table.lastPositionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WorksTableFilterComposer get workId {
    final $$WorksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workId,
      referencedTable: $db.works,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorksTableFilterComposer(
            $db: $db,
            $table: $db.works,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> subtitlesRefs(
    Expression<bool> Function($$SubtitlesTableFilterComposer f) f,
  ) {
    final $$SubtitlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subtitles,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubtitlesTableFilterComposer(
            $db: $db,
            $table: $db.subtitles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TracksTableOrderingComposer
    extends Composer<_$TonariDatabase, $TracksTable> {
  $$TracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileFormat => $composableBuilder(
    column: $table.fileFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bitRate => $composableBuilder(
    column: $table.bitRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryHint => $composableBuilder(
    column: $table.categoryHint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userCategory => $composableBuilder(
    column: $table.userCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentDirName => $composableBuilder(
    column: $table.parentDirName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alternateQualityPathsJson => $composableBuilder(
    column: $table.alternateQualityPathsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPositionMs => $composableBuilder(
    column: $table.lastPositionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorksTableOrderingComposer get workId {
    final $$WorksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workId,
      referencedTable: $db.works,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorksTableOrderingComposer(
            $db: $db,
            $table: $db.works,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TracksTableAnnotationComposer
    extends Composer<_$TonariDatabase, $TracksTable> {
  $$TracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get fileFormat => $composableBuilder(
    column: $table.fileFormat,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bitRate =>
      $composableBuilder(column: $table.bitRate, builder: (column) => column);

  GeneratedColumn<String> get categoryHint => $composableBuilder(
    column: $table.categoryHint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userCategory => $composableBuilder(
    column: $table.userCategory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentDirName => $composableBuilder(
    column: $table.parentDirName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get alternateQualityPathsJson => $composableBuilder(
    column: $table.alternateQualityPathsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastPositionMs => $composableBuilder(
    column: $table.lastPositionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get playCount =>
      $composableBuilder(column: $table.playCount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$WorksTableAnnotationComposer get workId {
    final $$WorksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workId,
      referencedTable: $db.works,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorksTableAnnotationComposer(
            $db: $db,
            $table: $db.works,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> subtitlesRefs<T extends Object>(
    Expression<T> Function($$SubtitlesTableAnnotationComposer a) f,
  ) {
    final $$SubtitlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subtitles,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubtitlesTableAnnotationComposer(
            $db: $db,
            $table: $db.subtitles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TracksTableTableManager
    extends
        RootTableManager<
          _$TonariDatabase,
          $TracksTable,
          Track,
          $$TracksTableFilterComposer,
          $$TracksTableOrderingComposer,
          $$TracksTableAnnotationComposer,
          $$TracksTableCreateCompanionBuilder,
          $$TracksTableUpdateCompanionBuilder,
          (Track, $$TracksTableReferences),
          Track,
          PrefetchHooks Function({bool workId, bool subtitlesRefs})
        > {
  $$TracksTableTableManager(_$TonariDatabase db, $TracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> workId = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> fileFormat = const Value.absent(),
                Value<int> fileSizeBytes = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int?> sampleRate = const Value.absent(),
                Value<int?> bitRate = const Value.absent(),
                Value<String?> categoryHint = const Value.absent(),
                Value<String?> userCategory = const Value.absent(),
                Value<String> parentDirName = const Value.absent(),
                Value<int?> trackNumber = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> alternateQualityPathsJson = const Value.absent(),
                Value<int> lastPositionMs = const Value.absent(),
                Value<int> playCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TracksCompanion(
                id: id,
                workId: workId,
                filePath: filePath,
                relativePath: relativePath,
                fileName: fileName,
                fileFormat: fileFormat,
                fileSizeBytes: fileSizeBytes,
                durationMs: durationMs,
                sampleRate: sampleRate,
                bitRate: bitRate,
                categoryHint: categoryHint,
                userCategory: userCategory,
                parentDirName: parentDirName,
                trackNumber: trackNumber,
                title: title,
                alternateQualityPathsJson: alternateQualityPathsJson,
                lastPositionMs: lastPositionMs,
                playCount: playCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String workId,
                required String filePath,
                Value<String> relativePath = const Value.absent(),
                required String fileName,
                required String fileFormat,
                required int fileSizeBytes,
                required int durationMs,
                Value<int?> sampleRate = const Value.absent(),
                Value<int?> bitRate = const Value.absent(),
                Value<String?> categoryHint = const Value.absent(),
                Value<String?> userCategory = const Value.absent(),
                required String parentDirName,
                Value<int?> trackNumber = const Value.absent(),
                required String title,
                Value<String> alternateQualityPathsJson = const Value.absent(),
                Value<int> lastPositionMs = const Value.absent(),
                Value<int> playCount = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TracksCompanion.insert(
                id: id,
                workId: workId,
                filePath: filePath,
                relativePath: relativePath,
                fileName: fileName,
                fileFormat: fileFormat,
                fileSizeBytes: fileSizeBytes,
                durationMs: durationMs,
                sampleRate: sampleRate,
                bitRate: bitRate,
                categoryHint: categoryHint,
                userCategory: userCategory,
                parentDirName: parentDirName,
                trackNumber: trackNumber,
                title: title,
                alternateQualityPathsJson: alternateQualityPathsJson,
                lastPositionMs: lastPositionMs,
                playCount: playCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TracksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({workId = false, subtitlesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (subtitlesRefs) db.subtitles],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (workId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.workId,
                                referencedTable: $$TracksTableReferences
                                    ._workIdTable(db),
                                referencedColumn: $$TracksTableReferences
                                    ._workIdTable(db)
                                    .productId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (subtitlesRefs)
                    await $_getPrefetchedData<Track, $TracksTable, Subtitle>(
                      currentTable: table,
                      referencedTable: $$TracksTableReferences
                          ._subtitlesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TracksTableReferences(db, table, p0).subtitlesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.trackId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TracksTableProcessedTableManager =
    ProcessedTableManager<
      _$TonariDatabase,
      $TracksTable,
      Track,
      $$TracksTableFilterComposer,
      $$TracksTableOrderingComposer,
      $$TracksTableAnnotationComposer,
      $$TracksTableCreateCompanionBuilder,
      $$TracksTableUpdateCompanionBuilder,
      (Track, $$TracksTableReferences),
      Track,
      PrefetchHooks Function({bool workId, bool subtitlesRefs})
    >;
typedef $$WorkFilesTableCreateCompanionBuilder =
    WorkFilesCompanion Function({
      required String id,
      required String workId,
      required String filePath,
      required String relativePath,
      required String fileName,
      required String fileKind,
      required int fileSizeBytes,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$WorkFilesTableUpdateCompanionBuilder =
    WorkFilesCompanion Function({
      Value<String> id,
      Value<String> workId,
      Value<String> filePath,
      Value<String> relativePath,
      Value<String> fileName,
      Value<String> fileKind,
      Value<int> fileSizeBytes,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$WorkFilesTableReferences
    extends BaseReferences<_$TonariDatabase, $WorkFilesTable, WorkFile> {
  $$WorkFilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WorksTable _workIdTable(_$TonariDatabase db) => db.works.createAlias(
    $_aliasNameGenerator(db.workFiles.workId, db.works.productId),
  );

  $$WorksTableProcessedTableManager get workId {
    final $_column = $_itemColumn<String>('work_id')!;

    final manager = $$WorksTableTableManager(
      $_db,
      $_db.works,
    ).filter((f) => f.productId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorkFilesTableFilterComposer
    extends Composer<_$TonariDatabase, $WorkFilesTable> {
  $$WorkFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileKind => $composableBuilder(
    column: $table.fileKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WorksTableFilterComposer get workId {
    final $$WorksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workId,
      referencedTable: $db.works,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorksTableFilterComposer(
            $db: $db,
            $table: $db.works,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkFilesTableOrderingComposer
    extends Composer<_$TonariDatabase, $WorkFilesTable> {
  $$WorkFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileKind => $composableBuilder(
    column: $table.fileKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorksTableOrderingComposer get workId {
    final $$WorksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workId,
      referencedTable: $db.works,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorksTableOrderingComposer(
            $db: $db,
            $table: $db.works,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkFilesTableAnnotationComposer
    extends Composer<_$TonariDatabase, $WorkFilesTable> {
  $$WorkFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get fileKind =>
      $composableBuilder(column: $table.fileKind, builder: (column) => column);

  GeneratedColumn<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$WorksTableAnnotationComposer get workId {
    final $$WorksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workId,
      referencedTable: $db.works,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorksTableAnnotationComposer(
            $db: $db,
            $table: $db.works,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkFilesTableTableManager
    extends
        RootTableManager<
          _$TonariDatabase,
          $WorkFilesTable,
          WorkFile,
          $$WorkFilesTableFilterComposer,
          $$WorkFilesTableOrderingComposer,
          $$WorkFilesTableAnnotationComposer,
          $$WorkFilesTableCreateCompanionBuilder,
          $$WorkFilesTableUpdateCompanionBuilder,
          (WorkFile, $$WorkFilesTableReferences),
          WorkFile,
          PrefetchHooks Function({bool workId})
        > {
  $$WorkFilesTableTableManager(_$TonariDatabase db, $WorkFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> workId = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> fileKind = const Value.absent(),
                Value<int> fileSizeBytes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkFilesCompanion(
                id: id,
                workId: workId,
                filePath: filePath,
                relativePath: relativePath,
                fileName: fileName,
                fileKind: fileKind,
                fileSizeBytes: fileSizeBytes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String workId,
                required String filePath,
                required String relativePath,
                required String fileName,
                required String fileKind,
                required int fileSizeBytes,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WorkFilesCompanion.insert(
                id: id,
                workId: workId,
                filePath: filePath,
                relativePath: relativePath,
                fileName: fileName,
                fileKind: fileKind,
                fileSizeBytes: fileSizeBytes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkFilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({workId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (workId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.workId,
                                referencedTable: $$WorkFilesTableReferences
                                    ._workIdTable(db),
                                referencedColumn: $$WorkFilesTableReferences
                                    ._workIdTable(db)
                                    .productId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WorkFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$TonariDatabase,
      $WorkFilesTable,
      WorkFile,
      $$WorkFilesTableFilterComposer,
      $$WorkFilesTableOrderingComposer,
      $$WorkFilesTableAnnotationComposer,
      $$WorkFilesTableCreateCompanionBuilder,
      $$WorkFilesTableUpdateCompanionBuilder,
      (WorkFile, $$WorkFilesTableReferences),
      WorkFile,
      PrefetchHooks Function({bool workId})
    >;
typedef $$SubtitlesTableCreateCompanionBuilder =
    SubtitlesCompanion Function({
      required String id,
      required String trackId,
      required String filePath,
      required String fileFormat,
      required String fileHash,
      Value<int> timeOffsetMs,
      required String originalLinesJson,
      Value<String?> translatedLinesJson,
      Value<DateTime?> translatedAt,
      Value<String?> translatedByModel,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SubtitlesTableUpdateCompanionBuilder =
    SubtitlesCompanion Function({
      Value<String> id,
      Value<String> trackId,
      Value<String> filePath,
      Value<String> fileFormat,
      Value<String> fileHash,
      Value<int> timeOffsetMs,
      Value<String> originalLinesJson,
      Value<String?> translatedLinesJson,
      Value<DateTime?> translatedAt,
      Value<String?> translatedByModel,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$SubtitlesTableReferences
    extends BaseReferences<_$TonariDatabase, $SubtitlesTable, Subtitle> {
  $$SubtitlesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$TonariDatabase db) => db.tracks
      .createAlias($_aliasNameGenerator(db.subtitles.trackId, db.tracks.id));

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SubtitlesTableFilterComposer
    extends Composer<_$TonariDatabase, $SubtitlesTable> {
  $$SubtitlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileFormat => $composableBuilder(
    column: $table.fileFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeOffsetMs => $composableBuilder(
    column: $table.timeOffsetMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalLinesJson => $composableBuilder(
    column: $table.originalLinesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translatedLinesJson => $composableBuilder(
    column: $table.translatedLinesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get translatedAt => $composableBuilder(
    column: $table.translatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translatedByModel => $composableBuilder(
    column: $table.translatedByModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubtitlesTableOrderingComposer
    extends Composer<_$TonariDatabase, $SubtitlesTable> {
  $$SubtitlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileFormat => $composableBuilder(
    column: $table.fileFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeOffsetMs => $composableBuilder(
    column: $table.timeOffsetMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalLinesJson => $composableBuilder(
    column: $table.originalLinesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translatedLinesJson => $composableBuilder(
    column: $table.translatedLinesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get translatedAt => $composableBuilder(
    column: $table.translatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translatedByModel => $composableBuilder(
    column: $table.translatedByModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubtitlesTableAnnotationComposer
    extends Composer<_$TonariDatabase, $SubtitlesTable> {
  $$SubtitlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get fileFormat => $composableBuilder(
    column: $table.fileFormat,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileHash =>
      $composableBuilder(column: $table.fileHash, builder: (column) => column);

  GeneratedColumn<int> get timeOffsetMs => $composableBuilder(
    column: $table.timeOffsetMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalLinesJson => $composableBuilder(
    column: $table.originalLinesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translatedLinesJson => $composableBuilder(
    column: $table.translatedLinesJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get translatedAt => $composableBuilder(
    column: $table.translatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translatedByModel => $composableBuilder(
    column: $table.translatedByModel,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubtitlesTableTableManager
    extends
        RootTableManager<
          _$TonariDatabase,
          $SubtitlesTable,
          Subtitle,
          $$SubtitlesTableFilterComposer,
          $$SubtitlesTableOrderingComposer,
          $$SubtitlesTableAnnotationComposer,
          $$SubtitlesTableCreateCompanionBuilder,
          $$SubtitlesTableUpdateCompanionBuilder,
          (Subtitle, $$SubtitlesTableReferences),
          Subtitle,
          PrefetchHooks Function({bool trackId})
        > {
  $$SubtitlesTableTableManager(_$TonariDatabase db, $SubtitlesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubtitlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubtitlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubtitlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> trackId = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> fileFormat = const Value.absent(),
                Value<String> fileHash = const Value.absent(),
                Value<int> timeOffsetMs = const Value.absent(),
                Value<String> originalLinesJson = const Value.absent(),
                Value<String?> translatedLinesJson = const Value.absent(),
                Value<DateTime?> translatedAt = const Value.absent(),
                Value<String?> translatedByModel = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubtitlesCompanion(
                id: id,
                trackId: trackId,
                filePath: filePath,
                fileFormat: fileFormat,
                fileHash: fileHash,
                timeOffsetMs: timeOffsetMs,
                originalLinesJson: originalLinesJson,
                translatedLinesJson: translatedLinesJson,
                translatedAt: translatedAt,
                translatedByModel: translatedByModel,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String trackId,
                required String filePath,
                required String fileFormat,
                required String fileHash,
                Value<int> timeOffsetMs = const Value.absent(),
                required String originalLinesJson,
                Value<String?> translatedLinesJson = const Value.absent(),
                Value<DateTime?> translatedAt = const Value.absent(),
                Value<String?> translatedByModel = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SubtitlesCompanion.insert(
                id: id,
                trackId: trackId,
                filePath: filePath,
                fileFormat: fileFormat,
                fileHash: fileHash,
                timeOffsetMs: timeOffsetMs,
                originalLinesJson: originalLinesJson,
                translatedLinesJson: translatedLinesJson,
                translatedAt: translatedAt,
                translatedByModel: translatedByModel,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SubtitlesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.trackId,
                                referencedTable: $$SubtitlesTableReferences
                                    ._trackIdTable(db),
                                referencedColumn: $$SubtitlesTableReferences
                                    ._trackIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SubtitlesTableProcessedTableManager =
    ProcessedTableManager<
      _$TonariDatabase,
      $SubtitlesTable,
      Subtitle,
      $$SubtitlesTableFilterComposer,
      $$SubtitlesTableOrderingComposer,
      $$SubtitlesTableAnnotationComposer,
      $$SubtitlesTableCreateCompanionBuilder,
      $$SubtitlesTableUpdateCompanionBuilder,
      (Subtitle, $$SubtitlesTableReferences),
      Subtitle,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$ImportedFoldersTableCreateCompanionBuilder =
    ImportedFoldersCompanion Function({
      required String id,
      required String displayName,
      required String bookmarkBase64,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ImportedFoldersTableUpdateCompanionBuilder =
    ImportedFoldersCompanion Function({
      Value<String> id,
      Value<String> displayName,
      Value<String> bookmarkBase64,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ImportedFoldersTableFilterComposer
    extends Composer<_$TonariDatabase, $ImportedFoldersTable> {
  $$ImportedFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookmarkBase64 => $composableBuilder(
    column: $table.bookmarkBase64,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ImportedFoldersTableOrderingComposer
    extends Composer<_$TonariDatabase, $ImportedFoldersTable> {
  $$ImportedFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookmarkBase64 => $composableBuilder(
    column: $table.bookmarkBase64,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImportedFoldersTableAnnotationComposer
    extends Composer<_$TonariDatabase, $ImportedFoldersTable> {
  $$ImportedFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bookmarkBase64 => $composableBuilder(
    column: $table.bookmarkBase64,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ImportedFoldersTableTableManager
    extends
        RootTableManager<
          _$TonariDatabase,
          $ImportedFoldersTable,
          ImportedFolder,
          $$ImportedFoldersTableFilterComposer,
          $$ImportedFoldersTableOrderingComposer,
          $$ImportedFoldersTableAnnotationComposer,
          $$ImportedFoldersTableCreateCompanionBuilder,
          $$ImportedFoldersTableUpdateCompanionBuilder,
          (
            ImportedFolder,
            BaseReferences<
              _$TonariDatabase,
              $ImportedFoldersTable,
              ImportedFolder
            >,
          ),
          ImportedFolder,
          PrefetchHooks Function()
        > {
  $$ImportedFoldersTableTableManager(
    _$TonariDatabase db,
    $ImportedFoldersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportedFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportedFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportedFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> bookmarkBase64 = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportedFoldersCompanion(
                id: id,
                displayName: displayName,
                bookmarkBase64: bookmarkBase64,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String displayName,
                required String bookmarkBase64,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ImportedFoldersCompanion.insert(
                id: id,
                displayName: displayName,
                bookmarkBase64: bookmarkBase64,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ImportedFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$TonariDatabase,
      $ImportedFoldersTable,
      ImportedFolder,
      $$ImportedFoldersTableFilterComposer,
      $$ImportedFoldersTableOrderingComposer,
      $$ImportedFoldersTableAnnotationComposer,
      $$ImportedFoldersTableCreateCompanionBuilder,
      $$ImportedFoldersTableUpdateCompanionBuilder,
      (
        ImportedFolder,
        BaseReferences<_$TonariDatabase, $ImportedFoldersTable, ImportedFolder>,
      ),
      ImportedFolder,
      PrefetchHooks Function()
    >;
typedef $$LlmProvidersTableCreateCompanionBuilder =
    LlmProvidersCompanion Function({
      required String id,
      required String name,
      required String baseUrl,
      required String model,
      Value<String?> systemPrompt,
      Value<bool> isDefault,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LlmProvidersTableUpdateCompanionBuilder =
    LlmProvidersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> baseUrl,
      Value<String> model,
      Value<String?> systemPrompt,
      Value<bool> isDefault,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LlmProvidersTableFilterComposer
    extends Composer<_$TonariDatabase, $LlmProvidersTable> {
  $$LlmProvidersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LlmProvidersTableOrderingComposer
    extends Composer<_$TonariDatabase, $LlmProvidersTable> {
  $$LlmProvidersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LlmProvidersTableAnnotationComposer
    extends Composer<_$TonariDatabase, $LlmProvidersTable> {
  $$LlmProvidersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LlmProvidersTableTableManager
    extends
        RootTableManager<
          _$TonariDatabase,
          $LlmProvidersTable,
          LlmProvider,
          $$LlmProvidersTableFilterComposer,
          $$LlmProvidersTableOrderingComposer,
          $$LlmProvidersTableAnnotationComposer,
          $$LlmProvidersTableCreateCompanionBuilder,
          $$LlmProvidersTableUpdateCompanionBuilder,
          (
            LlmProvider,
            BaseReferences<_$TonariDatabase, $LlmProvidersTable, LlmProvider>,
          ),
          LlmProvider,
          PrefetchHooks Function()
        > {
  $$LlmProvidersTableTableManager(_$TonariDatabase db, $LlmProvidersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LlmProvidersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LlmProvidersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LlmProvidersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<String?> systemPrompt = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LlmProvidersCompanion(
                id: id,
                name: name,
                baseUrl: baseUrl,
                model: model,
                systemPrompt: systemPrompt,
                isDefault: isDefault,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String baseUrl,
                required String model,
                Value<String?> systemPrompt = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LlmProvidersCompanion.insert(
                id: id,
                name: name,
                baseUrl: baseUrl,
                model: model,
                systemPrompt: systemPrompt,
                isDefault: isDefault,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LlmProvidersTableProcessedTableManager =
    ProcessedTableManager<
      _$TonariDatabase,
      $LlmProvidersTable,
      LlmProvider,
      $$LlmProvidersTableFilterComposer,
      $$LlmProvidersTableOrderingComposer,
      $$LlmProvidersTableAnnotationComposer,
      $$LlmProvidersTableCreateCompanionBuilder,
      $$LlmProvidersTableUpdateCompanionBuilder,
      (
        LlmProvider,
        BaseReferences<_$TonariDatabase, $LlmProvidersTable, LlmProvider>,
      ),
      LlmProvider,
      PrefetchHooks Function()
    >;

class $TonariDatabaseManager {
  final _$TonariDatabase _db;
  $TonariDatabaseManager(this._db);
  $$WorksTableTableManager get works =>
      $$WorksTableTableManager(_db, _db.works);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db, _db.tracks);
  $$WorkFilesTableTableManager get workFiles =>
      $$WorkFilesTableTableManager(_db, _db.workFiles);
  $$SubtitlesTableTableManager get subtitles =>
      $$SubtitlesTableTableManager(_db, _db.subtitles);
  $$ImportedFoldersTableTableManager get importedFolders =>
      $$ImportedFoldersTableTableManager(_db, _db.importedFolders);
  $$LlmProvidersTableTableManager get llmProviders =>
      $$LlmProvidersTableTableManager(_db, _db.llmProviders);
}
