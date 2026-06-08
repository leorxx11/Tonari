import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import 'webdav_password_store.dart';

class WebdavServerRepository {
  WebdavServerRepository({
    required this.db,
    required this.passwordStore,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final TonariDatabase db;
  final WebdavPasswordStore passwordStore;
  final Uuid _uuid;

  Stream<List<WebdavServer>> watchAll() {
    return (db.select(
      db.webdavServers,
    )..orderBy([(s) => OrderingTerm(expression: s.createdAt)])).watch();
  }

  Future<List<WebdavServer>> listAll() {
    return (db.select(
      db.webdavServers,
    )..orderBy([(s) => OrderingTerm(expression: s.createdAt)])).get();
  }

  Future<String?> readPassword(String serverId) => passwordStore.read(serverId);

  Future<String> create({
    required String name,
    required String scheme,
    required String host,
    int? port,
    String? basePath,
    String? username,
    String? password,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    await db
        .into(db.webdavServers)
        .insert(
          WebdavServersCompanion.insert(
            id: id,
            name: name,
            scheme: scheme,
            host: host,
            port: Value(port),
            basePath: Value(basePath),
            username: Value(username),
            createdAt: now,
            updatedAt: now,
          ),
        );
    if (password != null && password.isNotEmpty) {
      await passwordStore.write(id, password);
    }
    return id;
  }

  Future<void> update({
    required String id,
    required String name,
    required String scheme,
    required String host,
    int? port,
    String? basePath,
    String? username,
    String? password,
  }) async {
    await (db.update(db.webdavServers)..where((s) => s.id.equals(id))).write(
      WebdavServersCompanion(
        name: Value(name),
        scheme: Value(scheme),
        host: Value(host),
        port: Value(port),
        basePath: Value(basePath),
        username: Value(username),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (password != null && password.isNotEmpty) {
      await passwordStore.write(id, password);
    }
  }

  Future<void> delete(String id) async {
    await (db.delete(db.webdavServers)..where((s) => s.id.equals(id))).go();
    await passwordStore.delete(id);
  }
}

final webdavServerRepositoryProvider = Provider<WebdavServerRepository>((ref) {
  return WebdavServerRepository(
    db: ref.watch(databaseProvider),
    passwordStore: ref.watch(webdavPasswordStoreProvider),
  );
});

final webdavServersStreamProvider = StreamProvider<List<WebdavServer>>((ref) {
  return ref.watch(webdavServerRepositoryProvider).watchAll();
});
