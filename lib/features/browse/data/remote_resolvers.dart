import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import '../../p115/data/p115_auth_service.dart';
import '../../p115/data/p115_client.dart';
import '../../p115/data/p115_cookie_store.dart';
import '../../webdav/data/webdav_client.dart';
import '../../webdav/data/webdav_password_store.dart';
import 'remote_models.dart';

/// Builds a resolver from a bare (sourceKind, sourceId, path, pickcode)
/// identity — shared by video-controller rehydration, play-history replay and
/// the video library. Failures surface when the returned closure runs, so
/// items can always be constructed and errors flow through the normal
/// playback error paths.
PlayableResolver buildRemoteResolver(
  Ref ref, {
  required RemoteSourceKind sourceKind,
  required String sourceId,
  required String path,
  required String? pickcode,
  required bool isVideo,
}) {
  switch (sourceKind) {
    case RemoteSourceKind.p115:
      return () async {
        final pc = pickcode;
        if (pc == null || pc.isEmpty) {
          throw const P115Exception('115 文件缺少 pickcode');
        }
        try {
          final client = ref.read(p115ClientProvider);
          return isVideo
              ? await client.resolveVideoUrl(pc)
              : await client.resolveAudioUrl(pc);
        } on P115AuthExpiredException {
          await ref.read(p115AuthServiceProvider).clearCookie();
          ref.invalidate(p115CookieProvider);
          rethrow;
        }
      };
    case RemoteSourceKind.local:
      return () async => ResolvedMediaUrl(url: Uri.file(path));
    case RemoteSourceKind.webdav:
      return () async {
        final config = await _webdavConfig(ref, sourceId);
        if (config == null) throw Exception('WebDAV 服务器配置缺失');
        final auth = config.authHeader;
        return ResolvedMediaUrl(
          url: Uri.parse(config.streamUrl(path)),
          headers: auth == null ? null : {'Authorization': auth},
        );
      };
  }
}

Future<WebdavConfig?> _webdavConfig(Ref ref, String serverId) async {
  final db = ref.read(databaseProvider);
  final server = await (db.select(
    db.webdavServers,
  )..where((s) => s.id.equals(serverId))).getSingleOrNull();
  if (server == null) return null;
  final password = await ref.read(webdavPasswordStoreProvider).read(server.id);
  return WebdavConfig(
    scheme: server.scheme,
    host: server.host,
    port: server.port,
    basePath: server.basePath,
    username: server.username,
    password: password,
  );
}
