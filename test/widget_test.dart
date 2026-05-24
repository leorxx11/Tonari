import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/app.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/core/files/folder_picker_service.dart';

Widget testApp({List<ImportedFolder> folders = const []}) => ProviderScope(
      overrides: [
        importedFoldersProvider.overrideWith((ref) => Stream.value(folders)),
      ],
      child: const TonariApp(),
    );

void main() {
  testWidgets('root renders 4 navigation tabs', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.text('媒体库'), findsWidgets);
    expect(find.text('收藏'), findsWidgets);
    expect(find.text('历史'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });

  testWidgets('library tab shows empty state when no folders imported',
      (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.text('媒体库还是空的'), findsOneWidget);
  });

  testWidgets('library tab lists imported folders', (tester) async {
    final now = DateTime(2026, 5, 24, 14, 30);
    await tester.pumpWidget(testApp(folders: [
      ImportedFolder(
        id: 'f1',
        displayName: 'RJ01560714',
        bookmarkBase64: 'b',
        createdAt: now,
        updatedAt: now,
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('RJ01560714'), findsOneWidget);
    expect(find.textContaining('导入于'), findsOneWidget);
  });

  testWidgets('tapping a tab switches the page', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();

    expect(find.text('Favorites (M2+)'), findsOneWidget);
  });
}
