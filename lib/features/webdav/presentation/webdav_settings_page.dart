import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../data/webdav_server_repository.dart';
import 'webdav_server_edit_page.dart';

class WebdavSettingsPage extends ConsumerWidget {
  const WebdavSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final serversAsync = ref.watch(webdavServersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WebDAV'),
        actions: [
          IconButton(
            tooltip: '添加服务器',
            icon: const Icon(Icons.add),
            onPressed: () => _openCreate(context),
          ),
        ],
      ),
      body: serversAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (servers) {
          if (servers.isEmpty) return _Empty(theme: theme);
          return ListView.separated(
            itemCount: servers.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) => _ServerTile(server: servers[i]),
          );
        },
      ),
    );
  }

  void _openCreate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WebdavServerEditPage()),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text('还没配置 WebDAV 服务器', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '点右上 + 添加。可以是自建 NAS，或 Alist 转出来的 WebDAV',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerTile extends ConsumerWidget {
  const _ServerTile({required this.server});

  final WebdavServer server;

  void _openEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WebdavServerEditPage(server: server),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(webdavServerRepositoryProvider);
    final authority = server.port == null
        ? server.host
        : '${server.host}:${server.port}';
    final url = '${server.scheme}://$authority${server.basePath ?? ''}';

    return ListTile(
      leading: const Icon(Icons.cloud_outlined),
      title: Text(server.name),
      subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => _openEdit(context),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'edit') {
            _openEdit(context);
          } else if (v == 'delete') {
            final affected = await repo.countActiveWorks(server.id);
            if (!context.mounted) return;
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('删除服务器'),
                content: Text(
                  affected > 0
                      ? '「${server.name}」已导入 $affected 个作品。删除服务器后它们仍留在媒体库，'
                            '但无法再播放或刷新（流地址依赖此服务器）。确定删除？'
                      : '确认删除「${server.name}」？',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
            if (confirm ?? false) await repo.delete(server.id);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('编辑')),
          PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
    );
  }
}
