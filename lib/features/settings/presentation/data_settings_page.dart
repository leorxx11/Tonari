import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/presentation/import_entry.dart';
import '../../p115/presentation/p115_settings_page.dart';
import '../../webdav/presentation/webdav_settings_page.dart';
import 'backup_page.dart';
import 'media_sources_page.dart';
import 'removed_works_page.dart';

class DataSettingsPage extends ConsumerWidget {
  const DataSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据管理')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('导入'),
            subtitle: const Text('本地文件夹、115 网盘、WebDAV'),
            onTap: () => showImportSourcesSheet(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.folder_copy_outlined),
            title: const Text('媒体来源'),
            subtitle: const Text('查看、删除来源'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const MediaSourcesPage()),
          ),
          ListTile(
            leading: const Icon(Icons.restore_from_trash_outlined),
            title: const Text('已移除作品'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const RemovedWorksPage()),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.save_alt_outlined),
            title: const Text('备份与恢复'),
            subtitle: const Text('导出媒体库数据，换机 / 换证书用'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const BackupPage()),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('WebDAV'),
            subtitle: const Text('远程存储服务器'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const WebdavSettingsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_queue_outlined),
            title: const Text('115 网盘'),
            subtitle: const Text('登录与清理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const P115SettingsPage()),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}
