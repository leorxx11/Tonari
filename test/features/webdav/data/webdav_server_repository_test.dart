import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/features/webdav/data/webdav_password_store.dart';
import 'package:tonari/features/webdav/data/webdav_server_repository.dart';

void main() {
  late TonariDatabase db;
  late WebdavServerRepository repo;

  setUp(() {
    db = TonariDatabase.forTesting(NativeDatabase.memory());
    repo = WebdavServerRepository(db: db, passwordStore: WebdavPasswordStore());
  });

  tearDown(() => db.close());

  test(
    'listAll reads configured servers without stream subscription',
    () async {
      await repo.create(
        name: 'PikPak',
        scheme: 'https',
        host: 'example.com',
        basePath: '/dav',
        username: 'leo',
      );

      final servers = await repo.listAll();

      expect(servers, hasLength(1));
      expect(servers.single.name, 'PikPak');
      expect(servers.single.host, 'example.com');
    },
  );
}
