import 'package:flutter/material.dart';

import 'appearance_settings_page.dart';
import 'data_settings_page.dart';
import 'playback_settings_page.dart';
import 'translation_settings_page.dart';
import '../../p115/presentation/p115_settings_page.dart';
import '../../webdav/presentation/webdav_settings_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: const [
          _Entry(
            icon: Icons.palette_outlined,
            title: '外观',
            subtitle: '主题模式',
            page: AppearanceSettingsPage(),
          ),
          _Entry(
            icon: Icons.play_circle_outline,
            title: '播放',
            subtitle: '跳秒步长',
            page: PlaybackSettingsPage(),
          ),
          _Entry(
            icon: Icons.translate_outlined,
            title: '翻译',
            subtitle: 'LLM Provider 配置',
            page: TranslationSettingsPage(),
          ),
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
          _Entry(
            icon: Icons.storage_outlined,
            title: '数据管理',
            subtitle: '已移除作品',
            page: DataSettingsPage(),
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
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => page));
      },
    );
  }
}
