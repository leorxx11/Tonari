import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import 'webdav_client.dart';
import 'webdav_password_store.dart';

/// Resolves the streaming [WebdavConfig] for a [Work], or null when the work is
/// local. Used by the player to decide how to build each track's AudioSource.
class WebdavWorkSource {
  WebdavWorkSource(this._db, this._passwordStore);

  final TonariDatabase _db;
  final WebdavPasswordStore _passwordStore;

  Future<WebdavConfig?> configForWork(Work work) async {
    final folderId = work.importedFolderId;
    if (folderId == null) return null;
    final folder =
        await (_db.select(_db.importedFolders)
              ..where((f) => f.id.equals(folderId)))
            .getSingleOrNull();
    if (folder == null || folder.type != 'webdav') return null;
    final serverId = folder.serverId;
    if (serverId == null) return null;
    final server =
        await (_db.select(_db.webdavServers)
              ..where((s) => s.id.equals(serverId)))
            .getSingleOrNull();
    if (server == null) return null;
    final password = await _passwordStore.read(server.id);
    return WebdavConfig(
      scheme: server.scheme,
      host: server.host,
      port: server.port,
      basePath: server.basePath,
      username: server.username,
      password: password,
    );
  }
}

final webdavWorkSourceProvider = Provider<WebdavWorkSource>((ref) {
  return WebdavWorkSource(
    ref.watch(databaseProvider),
    ref.watch(webdavPasswordStoreProvider),
  );
});
