import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/app.dart';

void main() {
  testWidgets('root renders 4 navigation tabs', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TonariApp()));
    await tester.pumpAndSettle();

    expect(find.text('媒体库'), findsWidgets);
    expect(find.text('收藏'), findsWidgets);
    expect(find.text('历史'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });

  testWidgets('tapping a tab switches the page', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TonariApp()));
    await tester.pumpAndSettle();

    expect(find.text('Library (M2)'), findsOneWidget);

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();

    expect(find.text('Favorites (M2+)'), findsOneWidget);
  });
}
