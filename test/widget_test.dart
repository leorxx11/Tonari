import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tonari/app.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/core/files/folder_picker_service.dart';
import 'package:tonari/core/subtitle/subtitle_cue.dart';
import 'package:tonari/core/prefs/shared_prefs_provider.dart';
import 'package:tonari/features/history/data/play_history_repository.dart';
import 'package:tonari/features/library/data/app_events.dart';
import 'package:tonari/features/library/data/collections_providers.dart';
import 'package:tonari/features/library/data/import_flow.dart';
import 'package:tonari/features/library/data/import_service.dart';
import 'package:tonari/features/library/data/metadata_enrichment.dart';
import 'package:tonari/features/library/data/rescan_service.dart';
import 'package:tonari/features/library/data/work_actions_provider.dart';
import 'package:tonari/features/library/data/work_image_cache.dart';
import 'package:tonari/features/library/data/work_reimport_provider.dart';
import 'package:tonari/features/library/data/works_providers.dart';
import 'package:tonari/features/p115/data/p115_cookie_store.dart';
import 'package:tonari/features/subtitle/data/subtitle_providers.dart';
import 'package:tonari/features/video_library/data/video_library_providers.dart';
import 'package:tonari/features/webdav/data/webdav_server_repository.dart';

late SharedPreferences _testPrefs;

Widget testApp({
  List<Work> works = const [],
  List<Track> tracks = const [],
  List<WorkFile> workFiles = const [],
  List<ImportedFolder> folders = const [],
  RemoveWork? removeWork,
  DeleteWorkPermanently? deleteWorkPermanently,
  ReimportWork? reimportWork,
  ToggleFavorite? toggleFavorite,
  ImportFlow? importFlow,
  List<AppEvent> appEvents = const [],
  Map<String, List<SubtitleCue>> subtitlePreviews = const {},
}) => ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(_testPrefs),
    appEventSinkProvider.overrideWithValue(_FakeEventSink()),
    appEventsProvider.overrideWith((ref) => Stream.value(appEvents)),
    unreadEventCountProvider.overrideWith(
      (ref) => Stream.value(appEvents.where((e) => !e.read).length),
    ),
    allWorksProvider.overrideWith((ref) {
      final filter = ref.watch(workFilterProvider);
      return Stream.value(
        works
            .where(
              (w) =>
                  !w.isRemoved &&
                  filter.chips.every((c) => workMatchesChip(w, c)),
            )
            .toList(),
      );
    }),
    collectionsProvider.overrideWith(
      (ref) => Stream.value(const <Collection>[]),
    ),
    videoItemsProvider.overrideWith(
      (ref) => Stream.value(const <VideoItem>[]),
    ),
    collectionVideosProvider.overrideWith(
      (ref, collectionId) => Stream.value(const <VideoItem>[]),
    ),
    playHistoryProvider.overrideWith(
      (ref) => Stream.value(const <PlayHistoryEntry>[]),
    ),
    removedWorksProvider.overrideWith(
      (ref) => Stream.value(works.where((work) => work.isRemoved).toList()),
    ),
    importedFoldersProvider.overrideWith((ref) => Stream.value(folders)),
    tracksByWorkProvider.overrideWith((ref, workId) {
      return Stream.value(
        tracks.where((track) => track.workId == workId).toList(),
      );
    }),
    workFilesByWorkProvider.overrideWith((ref, workId) {
      return Stream.value(workFiles.where((f) => f.workId == workId).toList());
    }),
    p115CookieProvider.overrideWith((ref) => Future.value(null)),
    webdavServersStreamProvider.overrideWith((ref) => Stream.value(const [])),
    if (removeWork != null) removeWorkProvider.overrideWithValue(removeWork),
    if (deleteWorkPermanently != null)
      deleteWorkPermanentlyProvider.overrideWithValue(deleteWorkPermanently),
    if (reimportWork != null)
      reimportWorkProvider.overrideWithValue(reimportWork),
    if (toggleFavorite != null)
      toggleFavoriteProvider.overrideWithValue(toggleFavorite),
    if (importFlow != null) importFlowProvider.overrideWithValue(importFlow),
    if (subtitlePreviews.isNotEmpty)
      subtitlePreviewProvider.overrideWith(
        (ref, filePath) async => subtitlePreviews[filePath],
      ),
    metadataEnrichmentProvider.overrideWith((ref) => _NoopEnrichment()),
    rescanServiceProvider.overrideWith((ref) => _NoopRescan()),
  ],
  child: const TonariApp(),
);

class _FakeEventSink implements AppEventSink {
  @override
  Future<void> log({
    required String category,
    String severity = 'error',
    required String title,
    String detail = '',
    String? productId,
    String? workTitle,
    String? sourceName,
    String? actionKey,
  }) async {}

  @override
  Future<void> markAllRead() async {}

  @override
  Future<void> dismiss(String id) async {}

  @override
  Future<void> clear() async {}
}

class _NoopEnrichment implements MetadataEnrichmentService {
  @override
  Future<void> enrichBatch(
    Iterable<String> productIds, {
    MetadataProgress? onProgress,
  }) async {}

  @override
  Future<void> enrichOne(
    String productId, {
    bool force = false,
    ImageCacheProgress? onImageProgress,
  }) async {}

  @override
  Future<void> enrichPending() async {}

  @override
  Future<void> refreshImages(
    String productId, {
    ImageCacheProgress? onImageProgress,
  }) async {}
}

class _NoopRescan implements RescanService {
  @override
  TonariDatabase get db => throw UnimplementedError();

  @override
  ImportFlow get flow => throw UnimplementedError();

  @override
  Future<void> runPending() async {}
}

Work _work(
  String rj, {
  String? title,
  bool isRemoved = false,
  bool isFavorite = false,
  List<String> voiceActors = const [],
}) {
  final now = DateTime(2026, 5, 24, 14, 30);
  return Work(
    productId: rj,
    title: title ?? rj,
    voiceActors: voiceActors,
    illustrators: const [],
    scenarioWriters: const [],
    musicians: const [],
    fileFormats: const [],
    supportedLanguages: const [],
    genresJson: '[]',
    sampleImageUrls: const [],
    sampleImageLocalPaths: const [],
    descriptionImageLocalPaths: const [],
    localImportedAt: now,
    localFolderPath: '/imported/$rj',
    isFavorite: isFavorite,
    isRemoved: isRemoved,
    needsRescan: false,
    userTags: const [],
    createdAt: now,
    updatedAt: now,
  );
}

AppEvent _event({required String title, String? actionKey, bool read = false}) {
  final now = DateTime(2026, 6, 18);
  return AppEvent(
    id: title,
    createdAt: now,
    lastAt: now,
    category: 'metadata',
    severity: 'error',
    title: title,
    detail: 'boom',
    productId: 'RJ1',
    workTitle: 'W',
    actionKey: actionKey,
    count: 1,
    read: read,
  );
}

Track _track({
  required String id,
  required String workId,
  required String title,
  required String fileName,
  required String fileFormat,
  String relativeDir = '本編',
}) {
  final now = DateTime(2026, 5, 24, 14, 30);
  final relPath = relativeDir == '.' ? fileName : '$relativeDir/$fileName';
  final filePath = '/imported/$workId/$relPath';
  return Track(
    id: id,
    workId: workId,
    filePath: filePath,
    relativePath: relPath,
    fileName: fileName,
    fileFormat: fileFormat,
    fileSizeBytes: 1024,
    durationMs: 0,
    parentDirName: relativeDir == '.' ? workId : relativeDir.split('/').last,
    title: title,
    alternateQualityPathsJson: '{}',
    lastPositionMs: 0,
    playCount: 0,
    createdAt: now,
    updatedAt: now,
  );
}

WorkFile _workFile({
  required String id,
  required String workId,
  required String fileName,
  required String fileKind,
  required String filePath,
  String? relativePath,
}) {
  final now = DateTime(2026, 5, 24, 14, 30);
  return WorkFile(
    id: id,
    workId: workId,
    filePath: filePath,
    relativePath: relativePath ?? fileName,
    fileName: fileName,
    fileKind: fileKind,
    fileSizeBytes: 128,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    _testPrefs = await SharedPreferences.getInstance();
  });

  testWidgets('root renders 4 navigation tabs', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.text('媒体库'), findsWidgets);
    expect(find.text('书架'), findsWidgets);
    expect(find.text('浏览'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });

  testWidgets('library tab shows empty state when no works', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.text('媒体库还是空的'), findsOneWidget);
  });

  testWidgets('message bell shows unread badge and opens sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        appEvents: [_event(title: '资料补全失败', actionKey: 'enrich')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('1 条未读消息'), findsOneWidget);

    await tester.tap(find.byTooltip('1 条未读消息'));
    await tester.pumpAndSettle();

    expect(find.text('消息'), findsOneWidget);
    expect(find.text('资料补全失败'), findsOneWidget);
    expect(find.text('补全资料'), findsOneWidget);
  });

  testWidgets('message sheet shows empty state with no events', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('消息'), findsOneWidget);
    await tester.tap(find.byTooltip('消息'));
    await tester.pumpAndSettle();

    expect(find.text('暂无消息'), findsOneWidget);
  });

  testWidgets('library tab shows works grid when populated', (tester) async {
    await tester.pumpWidget(
      testApp(
        works: [
          _work('RJ01560714', title: 'Test Work'),
          _work('RJ00000001', title: 'Another'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Work'), findsOneWidget);
    expect(find.text('Another'), findsOneWidget);
  });

  testWidgets('tapping a CV chip adds a removable AND filter token', (
    tester,
  ) async {
    // The segment bar above the library grid pushes the first card's tag row
    // just below the default 600px viewport — use a taller surface.
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testApp(
        works: [
          _work('RJ1', title: 'With CV', voiceActors: ['花玲']),
          _work('RJ2', title: 'Other Work'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('花玲').first);
    await tester.pumpAndSettle();

    expect(find.text('CV：花玲'), findsOneWidget);
    expect(find.text('With CV'), findsOneWidget);
    expect(find.text('Other Work'), findsNothing);

    await tester.tap(find.byIcon(Icons.cancel));
    await tester.pumpAndSettle();

    expect(find.text('CV：花玲'), findsNothing);
    expect(find.text('Other Work'), findsOneWidget);
  });

  testWidgets('shelf tab shows empty state', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('书架'));
    await tester.pumpAndSettle();

    expect(find.text('书架还是空的'), findsOneWidget);
  });

  testWidgets('long press menu includes 加入分组 and opens picker', (tester) async {
    await tester.pumpWidget(
      testApp(works: [_work('RJ01560714', title: 'Test Work')]),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Test Work'));
    await tester.pumpAndSettle();

    expect(find.text('加入分组…'), findsOneWidget);

    await tester.tap(find.text('加入分组…'));
    await tester.pumpAndSettle();

    expect(find.text('还没有分组，点右上角新建一个'), findsOneWidget);
  });

  testWidgets('long pressing a work shows remove menu action', (tester) async {
    String? removedProductId;

    await tester.pumpWidget(
      testApp(
        works: [_work('RJ01560714', title: 'Test Work')],
        removeWork: (productId) async {
          removedProductId = productId;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Test Work'));
    await tester.pumpAndSettle();

    expect(find.text('移除作品'), findsOneWidget);

    await tester.tap(find.text('移除作品'));
    await tester.pumpAndSettle();

    expect(removedProductId, 'RJ01560714');
    expect(find.text('已移除 Test Work'), findsOneWidget);
  });

  testWidgets('settings re-imports a removed work', (tester) async {
    String? reimportedProductId;
    await tester.pumpWidget(
      testApp(
        works: [_work('RJ01560714', title: 'Hidden Work', isRemoved: true)],
        reimportWork: (work, {task}) async {
          reimportedProductId = work.productId;
          return ImportSummary(
            worksInserted: 0,
            worksUpdated: 1,
            tracksTotal: 1,
            workIds: {work.productId},
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('数据管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已移除作品'));
    await tester.pumpAndSettle();

    expect(find.text('Hidden Work'), findsOneWidget);
    final reimport = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '重新导入'),
    );
    expect(reimport.onPressed, isNotNull);

    await tester.tap(find.text('重新导入'));
    await tester.pumpAndSettle();

    expect(reimportedProductId, 'RJ01560714');
    expect(find.text('已重新导入 Hidden Work'), findsOneWidget);
  });

  testWidgets('settings permanently deletes a removed work', (tester) async {
    String? deletedProductId;
    await tester.pumpWidget(
      testApp(
        works: [_work('RJ01560714', title: 'Hidden Work', isRemoved: true)],
        deleteWorkPermanently: (productId) async {
          deletedProductId = productId;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('数据管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已移除作品'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('彻底移除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '彻底移除'));
    await tester.pumpAndSettle();

    expect(deletedProductId, 'RJ01560714');
    expect(find.text('已彻底移除 Hidden Work'), findsOneWidget);
  });

  testWidgets('detail menu rescans the current work', (tester) async {
    String? rescannedProductId;
    await tester.pumpWidget(
      testApp(
        works: [_work('RJ01560714', title: 'Test Work')],
        reimportWork: (work, {task}) async {
          rescannedProductId = work.productId;
          return ImportSummary(
            worksInserted: 0,
            worksUpdated: 1,
            tracksTotal: 1,
            workIds: {work.productId},
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();

    expect(find.text('重新扫描此作品'), findsOneWidget);

    await tester.tap(find.text('重新扫描此作品'));
    await tester.pumpAndSettle();

    expect(rescannedProductId, 'RJ01560714');
    expect(find.text('作品已重新扫描'), findsOneWidget);
  });

  testWidgets('tapping a work opens detail with a files entry', (tester) async {
    await tester.pumpWidget(
      testApp(
        works: [_work('RJ01560714', title: 'Test Work')],
        tracks: [
          _track(
            id: 't1',
            workId: 'RJ01560714',
            title: 'track01',
            fileName: 'track01.wav',
            fileFormat: 'wav',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test Work'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('文件'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(find.text('RJ01560714'), findsOneWidget);
    expect(find.text('文件'), findsOneWidget);
    // Track list lives on the WorkFilesPage now, not the detail page.
    expect(find.text('track01.wav'), findsNothing);
  });

  testWidgets('detail page hides the tab bar (full-screen detail)', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        works: [_work('RJ01560714', title: 'Test Work')],
        tracks: [
          _track(
            id: 't1',
            workId: 'RJ01560714',
            title: 'track01',
            fileName: 'track01.wav',
            fileFormat: 'wav',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test Work'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('文件'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(find.text('文件'), findsOneWidget);
    for (final label in ['媒体库', '设置']) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets('files entry opens drill-in WorkFilesPage with folders', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        works: [_work('RJ01560714', title: 'Test Work')],
        tracks: [
          _track(
            id: 'flac',
            workId: 'RJ01560714',
            title: 'flac-track',
            fileName: 'flac-track.flac',
            fileFormat: 'flac',
            relativeDir: '01_FLAC',
          ),
          _track(
            id: 'mp3',
            workId: 'RJ01560714',
            title: 'mp3-track',
            fileName: 'mp3-track.mp3',
            fileFormat: 'mp3',
            relativeDir: '02_MP3',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test Work'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('文件'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('文件'));
    await tester.pumpAndSettle();

    // Resource page is now in front; root level shows both folders.
    expect(find.text('01_FLAC'), findsOneWidget);
    expect(find.text('02_MP3'), findsOneWidget);
    // RJ id is the breadcrumb root.
    expect(find.text('RJ01560714'), findsWidgets);

    // Drill into the FLAC folder.
    await tester.tap(find.text('01_FLAC'));
    await tester.pumpAndSettle();

    expect(find.text('flac-track.flac'), findsOneWidget);
    expect(find.text('mp3-track.mp3'), findsNothing);

    // Tap RJ id in the breadcrumb → back to root listing. Use `hitTestable`
    // to ignore the same RJ id rendered on the obscured detail page below.
    await tester.tap(find.text('RJ01560714').hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('01_FLAC'), findsOneWidget);
    expect(find.text('02_MP3'), findsOneWidget);
    expect(find.text('flac-track.flac'), findsNothing);
  });

  testWidgets('subtitle file opens parsed text preview', (tester) async {
    await tester.pumpWidget(
      testApp(
        works: [_work('RJ01560714', title: 'Test Work')],
        tracks: [
          _track(
            id: 'track-1',
            workId: 'RJ01560714',
            title: 'track01',
            fileName: 'track01.wav',
            fileFormat: 'wav',
            relativeDir: '.',
          ),
        ],
        workFiles: [
          _workFile(
            id: 'subtitle-1',
            workId: 'RJ01560714',
            fileName: 'track01.wav.lrc',
            fileKind: 'subtitle',
            filePath: '/imported/RJ01560714/track01.wav.lrc',
          ),
        ],
        subtitlePreviews: {
          '/imported/RJ01560714/track01.wav.lrc': const [
            SubtitleCue(startMs: 0, endMs: 1500, text: 'hello'),
            SubtitleCue(startMs: 1500, endMs: 6500, text: 'world'),
          ],
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test Work'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('文件'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('文件'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('track01.wav.lrc'));
    await tester.pumpAndSettle();

    expect(find.textContaining('00:00.000 - 00:01.500'), findsOneWidget);
    expect(find.textContaining('hello'), findsOneWidget);
    expect(find.textContaining('00:01.500 - 00:06.500'), findsOneWidget);
    expect(find.textContaining('world'), findsOneWidget);
  });

  testWidgets('favorite work shows heart icon on card', (tester) async {
    await tester.pumpWidget(
      testApp(works: [_work('RJ01560714', isFavorite: true)]),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsWidgets);
  });

  testWidgets('long press menu includes 添加收藏 and triggers toggle', (
    tester,
  ) async {
    String? toggledId;
    bool? toggledValue;
    await tester.pumpWidget(
      testApp(
        works: [_work('RJ01560714', title: 'Test Work')],
        toggleFavorite: (productId, favorite) async {
          toggledId = productId;
          toggledValue = favorite;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Test Work'));
    await tester.pumpAndSettle();

    expect(find.text('添加收藏'), findsOneWidget);
    await tester.tap(find.text('添加收藏'));
    await tester.pumpAndSettle();

    expect(toggledId, 'RJ01560714');
    expect(toggledValue, true);
  });

  testWidgets('search button reveals a text field and back closes it', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('搜索 RJ 编号、标题，#标签…'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭搜索'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('favorite filter button toggles its tooltip', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('只看收藏'), findsOneWidget);
    expect(find.byTooltip('取消只看收藏'), findsNothing);

    await tester.tap(find.byTooltip('只看收藏'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('只看收藏'), findsNothing);
    expect(find.byTooltip('取消只看收藏'), findsOneWidget);
  });

  testWidgets('library tab exposes 4 sort modes in the menu', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('排序'));
    await tester.pumpAndSettle();

    expect(find.text('导入时间 ↓'), findsOneWidget);
    expect(find.text('导入时间 ↑'), findsOneWidget);
    expect(find.text('RJ 编号'), findsOneWidget);
    expect(find.text('最近播放'), findsOneWidget);
  });

  testWidgets('tapping a tab switches the page', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    expect(find.text('外观'), findsOneWidget);
  });
}
