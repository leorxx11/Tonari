import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/library_home_button.dart';
import '../../library/presentation/import_entry.dart';
import 'appearance_settings_page.dart';
import 'backup_page.dart';
import 'diagnostic_log_page.dart';
import 'media_source_settings_page.dart';
import 'playback_settings_page.dart';
import 'removed_works_page.dart';
import 'translation_settings_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('设置'),
        actions: const [LibraryHomeButton()],
      ),
      body: ListView(
        children: [
          const _SectionLabel('内容'),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('导入'),
            subtitle: const Text('本地文件夹、115 网盘、WebDAV'),
            onTap: () => showImportSourcesSheet(context, ref),
          ),
          const _Entry(
            icon: Icons.folder_copy_outlined,
            title: '媒体来源',
            subtitle: '已导入来源与远程存储配置',
            page: MediaSourceSettingsPage(),
          ),
          const _SectionLabel('偏好'),
          const _Entry(
            icon: Icons.play_circle_outline,
            title: '播放',
            subtitle: '跳秒步长、视频默认封面',
            page: PlaybackSettingsPage(),
          ),
          const _Entry(
            icon: Icons.palette_outlined,
            title: '外观',
            subtitle: '主题、隐私与作品文件入口',
            page: AppearanceSettingsPage(),
          ),
          const _Entry(
            icon: Icons.translate_outlined,
            title: '翻译',
            subtitle: 'LLM Provider 配置',
            page: TranslationSettingsPage(),
          ),
          const _SectionLabel('数据'),
          const _Entry(
            icon: Icons.restore_from_trash_outlined,
            title: '已移除作品',
            subtitle: '重新导入或彻底移除记录',
            page: RemovedWorksPage(),
          ),
          const _Entry(
            icon: Icons.save_alt_outlined,
            title: '备份与恢复',
            subtitle: '导出媒体库数据，换机或换证书使用',
            page: BackupPage(),
          ),
          const _SectionLabel('支持'),
          const _Entry(
            icon: Icons.bug_report_outlined,
            title: '诊断日志',
            subtitle: '复制播放代理日志',
            page: DiagnosticLogPage(),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
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
