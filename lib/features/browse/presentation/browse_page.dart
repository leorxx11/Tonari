import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../p115/data/p115_cookie_store.dart';
import '../../p115/presentation/p115_browser_page.dart';
import '../../p115/presentation/p115_login_page.dart';
import '../../webdav/data/webdav_client.dart';
import '../../webdav/data/webdav_server_repository.dart';
import '../../webdav/presentation/webdav_browser_page.dart';

class BrowsePage extends ConsumerWidget {
  const BrowsePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p115Cookie = ref.watch(p115CookieProvider);
    final webdavServers = ref.watch(webdavServersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('浏览')),
      body: ListView(
        children: [
          p115Cookie.when(
            loading: () => const ListTile(
              leading: Icon(Icons.cloud_queue_outlined),
              title: Text('115 网盘'),
              subtitle: Text('读取登录状态…'),
            ),
            error: (e, _) => ListTile(
              leading: const Icon(Icons.cloud_queue_outlined),
              title: const Text('115 网盘'),
              subtitle: Text('登录状态读取失败：$e'),
            ),
            data: (cookie) => ListTile(
              leading: const Icon(Icons.cloud_queue_outlined),
              title: const Text('115 网盘'),
              subtitle: Text(cookie == null ? '未登录' : '已登录'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => cookie == null
                  ? _openP115Login(context)
                  : _openP115Browser(context),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Text(
              'WebDAV',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          webdavServers.when(
            loading: () => const ListTile(
              leading: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('正在读取 WebDAV'),
            ),
            error: (e, _) => ListTile(title: Text('WebDAV 加载失败：$e')),
            data: (servers) {
              if (servers.isEmpty) {
                return const ListTile(
                  leading: Icon(Icons.cloud_off_outlined),
                  title: Text('未配置 WebDAV'),
                );
              }
              return Column(
                children: [
                  for (final server in servers) _WebdavTile(server: server),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openP115Login(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const P115LoginPage()));
  }

  void _openP115Browser(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoSheetRoute<void>(
        scrollableBuilder: (_, _) => const P115BrowserPage(),
        showDragHandle: true,
      ),
    );
  }
}

class _WebdavTile extends ConsumerWidget {
  const _WebdavTile({required this.server});

  final WebdavServer server;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = server.port == null
        ? server.host
        : '${server.host}:${server.port}';
    final url = '${server.scheme}://$authority${server.basePath ?? ''}';
    return ListTile(
      leading: const Icon(Icons.cloud_outlined),
      title: Text(server.name),
      subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openBrowser(context, ref),
    );
  }

  Future<void> _openBrowser(BuildContext context, WidgetRef ref) async {
    final password = await ref
        .read(webdavServerRepositoryProvider)
        .readPassword(server.id);
    final config = WebdavConfig(
      scheme: server.scheme,
      host: server.host,
      port: server.port,
      basePath: server.basePath,
      username: server.username,
      password: password,
    );
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      CupertinoSheetRoute<void>(
        scrollableBuilder: (_, _) =>
            WebdavBrowserPage(server: server, config: config),
        showDragHandle: true,
      ),
    );
  }
}
