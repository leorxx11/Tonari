import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/app.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/core/files/folder_picker_service.dart';
import 'package:tonari/features/library/data/import_flow.dart';
import 'package:tonari/features/library/data/import_service.dart';
import 'package:tonari/features/library/data/work_actions_provider.dart';
import 'package:tonari/features/library/data/works_providers.dart';

Widget testApp({
  List<Work> works = const [],
  List<Track> tracks = const [],
  List<ImportedFolder> folders = const [],
  RemoveWork? removeWork,
  RestoreWork? restoreWork,
  ToggleFavorite? toggleFavorite,
  ImportFlow? importFlow,
}) => ProviderScope(
  overrides: [
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
    if (removeWork != null) removeWorkProvider.overrideWithValue(removeWork),
    if (restoreWork != null) restoreWorkProvider.overrideWithValue(restoreWork),
    if (toggleFavorite != null)
      toggleFavoriteProvider.overrideWithValue(toggleFavorite),
    if (importFlow != null) importFlowProvider.overrideWithValue(importFlow),
  ],
  child: const TonariApp(),
);

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
    genresJson: '[]',
    sampleImageUrls: const [],
    sampleImageLocalPaths: const [],
    localImportedAt: now,
    localFolderPath: '/imported/$rj',
    isFavorite: isFavorite,
    isRemoved: isRemoved,
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
  Map<String, String> alternates = const {},
}) {
  final now = DateTime(2026, 5, 24, 14, 30);
  final filePath = relativeDir == '.'
      ? '/imported/$workId/$fileName'
      : '/imported/$workId/$relativeDir/$fileName';
  return Track(
    id: id,
    workId: workId,
    filePath: filePath,
    fileName: fileName,
    fileFormat: fileFormat,
    fileSizeBytes: 1024,
    durationMs: 0,
    parentDirName: relativeDir == '.' ? workId : relativeDir.split('/').last,
    title: title,
    alternateQualityPathsJson: jsonEncode(alternates),
    lastPositionMs: 0,
    playCount: 0,
    createdAt: now,
    updatedAt: now,
  );
}

ImportedFolder _folder(String id) {
  final now = DateTime(2026, 5, 24, 14, 30);
  return ImportedFolder(
    id: id,
    displayName: id,
    bookmarkBase64: 'bookmark-$id',
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeImportFlow implements ImportFlow {
  _FakeImportFlow(this._summaries);

  final List<ImportSummary> _summaries;
  var _index = 0;

  @override
  ImportService get importer => throw UnimplementedError();

  @override
  Future<ImportSummary> importFromFolder(ImportedFolder folder) async {
    final summary = _summaries[_index];
    _index++;
    return summary;
  }
}

void main() {
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

  testWidgets('rescan message counts unique works and tracks', (tester) async {
    await tester.pumpWidget(
      testApp(
        works: [_work('RJ01560714'), _work('RJ01507563')],
        folders: [
          _folder('folder-1'),
          _folder('folder-2'),
          _folder('folder-3'),
        ],
        importFlow: _FakeImportFlow(const [
          ImportSummary(
            worksInserted: 0,
            worksUpdated: 1,
            tracksTotal: 2,
            workIds: {'RJ01560714'},
            trackIds: {'t1', 't2'},
          ),
          ImportSummary(
            worksInserted: 0,
            worksUpdated: 1,
            tracksTotal: 2,
            workIds: {'RJ01560714'},
            trackIds: {'t1', 't2'},
          ),
          ImportSummary(
            worksInserted: 0,
            worksUpdated: 1,
            tracksTotal: 1,
            workIds: {'RJ01507563'},
            trackIds: {'t3'},
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('重新扫描'));
    await tester.pumpAndSettle();

    expect(find.text('扫描完成：2 部作品，共 3 个音轨'), findsOneWidget);
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
    await tester.tap(find.text('已移除作品'));
    await tester.pumpAndSettle();

    expect(find.text('Hidden Work'), findsOneWidget);

    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();

    expect(restoredProductId, 'RJ01560714');
    expect(find.text('已恢复 Hidden Work'), findsOneWidget);
  });

  testWidgets('tapping a work opens track detail', (tester) async {
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
            alternates: {'mp3': '/imported/RJ01560714/track01.mp3'},
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test Work'));
    await tester.pumpAndSettle();

    expect(find.text('RJ01560714'), findsOneWidget);
    expect(find.text('章节'), findsOneWidget);
    expect(find.text('track01'), findsOneWidget);
    expect(find.text('主音质 WAV'), findsOneWidget);
    expect(find.text('备用 MP3'), findsOneWidget);
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

    expect(find.text('章节'), findsOneWidget);
    for (final label in ['媒体库', '收藏', '历史', '设置']) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets('work detail opens the best original audio folder', (
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
            id: 'effect',
            workId: 'RJ01560714',
            title: 'effect-track',
            fileName: 'effect-track.mp3',
            fileFormat: 'mp3',
            relativeDir: '02_効果音あり_MP3',
          ),
          _track(
            id: 'no-effect',
            workId: 'RJ01560714',
            title: 'no-effect-track',
            fileName: 'no-effect-track.wav',
            fileFormat: 'wav',
            relativeDir: '03_効果音なし_WAV',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test Work'));
    await tester.pumpAndSettle();

    expect(find.text('目录'), findsOneWidget);
    expect(find.text('effect-track'), findsOneWidget);
    expect(find.text('flac-track'), findsNothing);
    expect(find.text('no-effect-track'), findsNothing);

    await tester.tap(find.text('01_FLAC'));
    await tester.pumpAndSettle();

    expect(find.text('flac-track'), findsOneWidget);
    expect(find.text('effect-track'), findsNothing);
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
