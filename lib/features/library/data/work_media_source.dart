import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../browse/data/remote_models.dart';
import '../../p115/data/p115_client.dart';
import '../../webdav/data/webdav_client.dart';
import '../../webdav/data/webdav_password_store.dart';

class WorkMediaSource {
  const WorkMediaSource({
    required this.kind,
    required this.sourceId,
    required this.sourceName,
    this.webdavConfig,
  });

  final RemoteSourceKind kind;
  final String sourceId;
  final String sourceName;
  final WebdavConfig? webdavConfig;
}

class WorkMediaSourceResolver {
  WorkMediaSourceResolver(this._db, this._passwordStore);

  final TonariDatabase _db;
  final WebdavPasswordStore _passwordStore;

  Future<WorkMediaSource> sourceForWork(Work work) async {
    final folderId = work.importedFolderId;
    if (folderId == null) {
      return const WorkMediaSource(
        kind: RemoteSourceKind.local,
        sourceId: 'local',
        sourceName: '本地',
      );
    }
    final folder = await (_db.select(
      _db.importedFolders,
    )..where((f) => f.id.equals(folderId))).getSingleOrNull();
    if (folder == null || folder.type == 'local') {
      return const WorkMediaSource(
        kind: RemoteSourceKind.local,
        sourceId: 'local',
        sourceName: '本地',
      );
    }
    if (folder.type == 'p115') {
      return const WorkMediaSource(
        kind: RemoteSourceKind.p115,
        sourceId: P115Client.sourceId,
        sourceName: P115Client.sourceName,
      );
    }

    final serverId = folder.serverId!;
    final server = await (_db.select(
      _db.webdavServers,
    )..where((s) => s.id.equals(serverId))).getSingle();
    final password = await _passwordStore.read(server.id);
    return WorkMediaSource(
      kind: RemoteSourceKind.webdav,
      sourceId: server.id,
      sourceName: server.name,
      webdavConfig: WebdavConfig(
        scheme: server.scheme,
        host: server.host,
        port: server.port,
        basePath: server.basePath,
        username: server.username,
        password: password,
      ),
    );
  }
}

final workMediaSourceProvider = Provider<WorkMediaSourceResolver>((ref) {
  return WorkMediaSourceResolver(
    ref.watch(databaseProvider),
    ref.watch(webdavPasswordStoreProvider),
  );
});
