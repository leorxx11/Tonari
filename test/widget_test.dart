import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/app.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/features/library/data/works_providers.dart';

Widget testApp({List<Work> works = const []}) => ProviderScope(
      overrides: [
        allWorksProvider.overrideWith((ref) => Stream.value(works)),
      ],
      child: const TonariApp(),
    );

Work _work(String rj, {String? title}) {
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
    isFavorite: false,
    userTags: const [],
    createdAt: now,
    updatedAt: now,
  );
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
    await tester.pumpWidget(testApp(works: [
      _work('RJ01560714', title: 'Test Work'),
      _work('RJ00000001', title: 'Another'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Test Work'), findsOneWidget);
    expect(find.text('Another'), findsOneWidget);
  });

  testWidgets('tapping a tab switches the page', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();

    expect(find.text('Favorites (M2+)'), findsOneWidget);
  });
}
