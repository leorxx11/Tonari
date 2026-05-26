import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tonari/app.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/core/files/folder_picker_service.dart';
import 'package:tonari/core/prefs/shared_prefs_provider.dart';
import 'package:tonari/features/library/data/import_flow.dart';
import 'package:tonari/features/library/data/metadata_enrichment.dart';
import 'package:tonari/features/library/data/rescan_service.dart';
import 'package:tonari/features/library/data/work_actions_provider.dart';
import 'package:tonari/features/library/data/works_providers.dart';
import 'package:tonari/features/settings/data/path_prefs.dart';

late SharedPreferences _testPrefs;

Widget testApp({
  List<Work> works = const [],
  List<Track> tracks = const [],
  List<WorkFile> workFiles = const [],
  List<ImportedFolder> folders = const [],
  RemoveWork? removeWork,
  RestoreWork? restoreWork,
  ToggleFavorite? toggleFavorite,
  ImportFlow? importFlow,
  PathPrefs pathPrefs = const PathPrefs(
    smartPath: false,
    preferEffectSound: true,
    typeOrderEnabled: true,
    typeOrder: PathPrefs.defaultTypeOrder,
  ),
}) => ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(_testPrefs),
    pathPrefsProvider.overrideWith(() => _FakePathPrefs(pathPrefs)),
    allWorksProvider.overrideWith(
      (ref) => Stream.value(works.where((work) => !work.isRemoved).toList()),
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
      return Stream.value(
        workFiles.where((f) => f.workId == workId).toList(),
      );
    }),
    if (removeWork != null) removeWorkProvider.overrideWithValue(removeWork),
    if (restoreWork != null) restoreWorkProvider.overrideWithValue(restoreWork),
    if (toggleFavorite != null)
      toggleFavoriteProvider.overrideWithValue(toggleFavorite),
    if (importFlow != null) importFlowProvider.overrideWithValue(importFlow),
    metadataEnrichmentProvider.overrideWith((ref) => _NoopEnrichment()),
    rescanServiceProvider.overrideWith((ref) => _NoopRescan()),
  ],
  child: const TonariApp(),
);

class _NoopEnrichment implements MetadataEnrichmentService {
  @override
  Future<void> enrichBatch(Iterable<String> productIds) async {}

  @override
  Future<void> enrichOne(String productId, {bool force = false}) async {}

  @override
  Future<void> enrichPending() async {}
}

class _NoopRescan implements RescanService {
  @override
  TonariDatabase get db => throw UnimplementedError();

  @override
  ImportFlow get flow => throw UnimplementedError();

  @override
  Future<void> runPending() async {}
}

class _FakePathPrefs extends PathPrefsNotifier {
  _FakePathPrefs(this._initial);
  final PathPrefs _initial;

  @override
  PathPrefs build() => _initial;

  @override
  Future<void> setSmartPath(bool value) async {
    state = state.copyWith(smartPath: value);
  }

  @override
  Future<void> setPreferEffectSound(bool value) async {
    state = state.copyWith(preferEffectSound: value);
  }

  @override
  Future<void> setTypeOrderEnabled(bool value) async {
    state = state.copyWith(typeOrderEnabled: value);
  }

  @override
  Future<void> reorderType(int oldIndex, int newIndex) async {
    final list = [...state.typeOrder];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(typeOrder: list);
  }
}

Work _work(
  String rj, {
  String? title,
  bool isRemoved = false,
  bool isFavorite = false,
}) {
  final now = DateTime(2026, 5, 24, 14, 30);
  return Work(
    productId: rj,
    title: title ?? rj,
    voiceActors: const [],
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
    expect(find.text('收藏'), findsWidgets);
    expect(find.text('历史'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });

  testWidgets('library tab shows empty state when no works', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.text('媒体库还是空的'), findsOneWidget);
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

  testWidgets('settings restores a removed work', (tester) async {
    String? restoredProductId;

    await tester.pumpWidget(
      testApp(
        works: [_work('RJ01560714', title: 'Hidden Work', isRemoved: true)],
        restoreWork: (productId) async {
          restoredProductId = productId;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('已移除作品'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('已移除作品'));
    await tester.pumpAndSettle();

    expect(find.text('Hidden Work'), findsOneWidget);

    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();

    expect(restoredProductId, 'RJ01560714');
    expect(find.text('已恢复 Hidden Work'), findsOneWidget);
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
    for (final label in ['媒体库', '收藏', '历史', '设置']) {
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

  testWidgets('autoPath drills into the wav folder when smartPath is on', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        pathPrefs: const PathPrefs(
          smartPath: true,
          preferEffectSound: true,
          typeOrderEnabled: true,
          typeOrder: PathPrefs.defaultTypeOrder,
        ),
        works: [_work('RJ01560714', title: 'Test Work')],
        tracks: [
          _track(
            id: 'wav',
            workId: 'RJ01560714',
            title: 'wav-track',
            fileName: 'wav-track.wav',
            fileFormat: 'wav',
            relativeDir: '01_WAV',
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

    // typeOrder = wav > mp3, so we expect to land inside 01_WAV directly.
    expect(find.text('wav-track.wav'), findsOneWidget);
    expect(find.text('mp3-track.mp3'), findsNothing);
    // Breadcrumb reflects the auto-applied path.
    expect(find.text('01_WAV'), findsWidgets);
  });

  testWidgets('favorite work shows heart icon on card', (tester) async {
    await tester.pumpWidget(
      testApp(works: [_work('RJ01560714', isFavorite: true)]),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsWidgets);
  });

  testWidgets('long press menu includes 添加收藏 and triggers toggle',
      (tester) async {
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

  testWidgets('search button reveals a text field and back closes it',
      (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('搜索 RJ 编号或标题…'), findsOneWidget);

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

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();

    expect(find.text('Favorites (M2+)'), findsOneWidget);
  });
}
