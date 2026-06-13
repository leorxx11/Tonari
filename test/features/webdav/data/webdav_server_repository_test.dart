import 'package:drift/drift.dart' show Value;
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

  test(
    'countActiveWorks counts active works for the server, '
    'excluding tombstoned works and other sources',
    () async {
      final now = DateTime(2026, 6, 1);
      Future<void> insertFolder(String id, String? serverId) {
        return db
            .into(db.importedFolders)
            .insert(
              ImportedFoldersCompanion.insert(
                id: id,
                displayName: id,
                bookmarkBase64: '',
                type: const Value('webdav'),
                serverId: Value(serverId),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      Future<void> insertWork(
        String productId,
        String folderId, {
        bool removed = false,
      }) {
        return db
            .into(db.works)
            .insert(
              WorksCompanion.insert(
                productId: productId,
                title: productId,
                localFolderPath: '/library/$productId',
                localImportedAt: now,
                createdAt: now,
                updatedAt: now,
                importedFolderId: Value(folderId),
                isRemoved: Value(removed),
              ),
            );
      }

      final serverId = await repo.create(
        name: 'S',
        scheme: 'https',
        host: 'h',
      );
      await insertFolder('f1', serverId);
      await insertFolder('f2', serverId);
      await insertFolder('other', 'other-server');
      await insertWork('RJ1', 'f1');
      await insertWork('RJ2', 'f1');
      await insertWork('RJ3', 'f2');
      await insertWork('RJ4', 'f2', removed: true); // tombstoned: excluded
      await insertWork('RJ5', 'other'); // other server: excluded

      expect(await repo.countActiveWorks(serverId), 3);
      expect(await repo.countActiveWorks('no-such-server'), 0);
    },
  );
}
