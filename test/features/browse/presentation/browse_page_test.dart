import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tonari/features/browse/presentation/browse_page.dart';
import 'package:tonari/features/p115/data/p115_cookie_store.dart';
import 'package:tonari/features/webdav/data/webdav_server_repository.dart';

void main() {
  testWidgets('browse home shows 115 login entry when logged out', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          p115CookieProvider.overrideWith((ref) => Future.value(null)),
          webdavServersStreamProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
        ],
        child: const MaterialApp(home: BrowsePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('115 网盘'), findsOneWidget);
    expect(find.text('未登录'), findsOneWidget);
  });
}
