import 'package:flutter/material.dart';

import '../../p115/presentation/p115_settings_page.dart';
import '../../webdav/presentation/webdav_settings_page.dart';
import 'media_sources_page.dart';

class MediaSourceSettingsPage extends StatelessWidget {
  const MediaSourceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('媒体来源')),
      body: ListView(
        children: const [
          _Entry(
            icon: Icons.folder_copy_outlined,
            title: '已导入来源',
            subtitle: '查看或删除本地、WebDAV、115 来源',
            page: MediaSourcesPage(),
          ),
          Divider(),
          _Entry(
            icon: Icons.cloud_outlined,
            title: 'WebDAV',
            subtitle: '远程存储服务器',
            page: WebdavSettingsPage(),
          ),
          _Entry(
            icon: Icons.cloud_queue_outlined,
            title: '115 网盘',
            subtitle: '登录与清理',
            page: P115SettingsPage(),
          ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => page)),
    );
  }
}
