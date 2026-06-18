import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/core/db/providers.dart';
import 'package:tonari/features/library/data/app_events.dart';

void main() {
  late TonariDatabase db;
  late ProviderContainer container;
  late AppEventSink sink;

  setUp(() {
    db = TonariDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    sink = container.read(appEventSinkProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<List<AppEvent>> rows() => db.select(db.appEvents).get();

  test('dedups same category+productId+title into a single row', () async {
    await sink.log(category: 'metadata', title: '资料补全失败', productId: 'RJ1');
    await sink.log(category: 'metadata', title: '资料补全失败', productId: 'RJ1');
    await sink.log(category: 'metadata', title: '资料补全失败', productId: 'RJ1');

    final all = await rows();
    expect(all, hasLength(1));
    expect(all.single.count, 3);
  });

  test('different keys create separate rows', () async {
    await sink.log(category: 'metadata', title: '资料补全失败', productId: 'RJ1');
    await sink.log(category: 'metadata', title: '资料补全失败', productId: 'RJ2');
    await sink.log(category: 'import', title: '导入失败');

    expect(await rows(), hasLength(3));
  });

  test('re-logging clears the read flag', () async {
    await sink.log(category: 'import', title: '导入失败');
    await sink.markAllRead();
    expect((await rows()).single.read, isTrue);

    await sink.log(category: 'import', title: '导入失败');
    expect((await rows()).single.read, isFalse);
  });

  test('trims to the newest 200 rows', () async {
    for (var i = 0; i < 230; i++) {
      await sink.log(category: 'import', title: '导入失败 $i');
    }
    expect(await rows(), hasLength(200));
  });

  test('markAllRead, dismiss and clear', () async {
    await sink.log(category: 'import', title: 'a');
    await sink.log(category: 'import', title: 'b');

    Future<int> unread() async =>
        (await rows()).where((e) => !e.read).length;
    expect(await unread(), 2);

    await sink.markAllRead();
    expect(await unread(), 0);

    final first = (await rows()).first;
    await sink.dismiss(first.id);
    expect(await rows(), hasLength(1));

    await sink.clear();
    expect(await rows(), isEmpty);
  });
}
