import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/features/library/data/app_events.dart';
import 'package:tonari/core/db/providers.dart';
import 'package:tonari/core/prefs/shared_prefs_provider.dart';
import 'package:tonari/features/video_library/data/local_video_import.dart';
import 'package:tonari/features/video_library/data/local_video_store.dart';
import 'package:tonari/features/video_library/data/video_library_providers.dart';
import 'package:tonari/features/video_library/presentation/video_library_page.dart';

class _Import extends LocalVideoImport {
  _Import(super.store, super.repository);
  final result = Completer<int>();
  int calls = 0;
  @override
  Future<int> pickAndImport({required void Function(int, int) onProgress}) {
    calls++;
    onProgress(0, 2);
    return result.future;
  }
}

void main() {
  testWidgets('empty library exposes import and prevents duplicate launches', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = TonariDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    late _Import importer;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unreadEventCountProvider.overrideWith((ref) => Stream.value(0)),
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          videoItemsProvider.overrideWith((ref) => Stream.value([])),
          localVideoImportProvider.overrideWith((ref) {
            importer = _Import(
              ref.read(localVideoStoreProvider),
              ref.read(videoLibraryRepositoryProvider),
            );
            return importer;
          }),
        ],
        child: const MaterialApp(home: VideoLibraryPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('视频库还是空的'), findsOneWidget);
    await tester.tap(find.text('导入本地视频'));
    await tester.pump();
    expect(importer.calls, 1);
    expect(find.text('正在导入 1 / 2'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == '导入本地视频',
            ),
          )
          .onPressed,
      isNull,
    );
    importer.result.complete(0);
    await tester.pumpAndSettle();
    expect(find.text('正在导入 1 / 2'), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == '导入本地视频',
            ),
          )
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'local video deletion requires confirmation and can be canceled',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = TonariDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final item = VideoItem(
        id: 'local:video_import:videos/id/movie.mp4',
        sourceKind: 'local',
        sourceId: LocalVideoStore.sourceId,
        sourceName: '本地导入',
        path: 'videos/id/movie.mp4',
        fileName: 'movie.mp4',
        isFavorite: false,
        addedAt: DateTime.now(),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadEventCountProvider.overrideWith((ref) => Stream.value(0)),
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
            videoItemsProvider.overrideWith((ref) => Stream.value([item])),
          ],
          child: const MaterialApp(home: VideoLibraryPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('movie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除视频'));
      await tester.pumpAndSettle();
      expect(find.text('删除视频？'), findsOneWidget);
      expect(find.textContaining('原始文件不受影响'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('删除视频？'), findsNothing);
      expect(find.text('movie'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
