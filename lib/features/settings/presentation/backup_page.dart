import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/library_home_button.dart';
import '../../../core/files/folder_bookmark.dart';
import '../../../core/ui/app_toast.dart';
import '../data/backup_service.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  // Video covers are tiny and referenced by the database, so they always go.
  final _dirs = {...BackupDir.values};
  final _sizes = <BackupDir, int>{};

  @override
  void initState() {
    super.initState();
    final service = ref.read(backupServiceProvider);
    service.dirSizeBytes(BackupDir.images).then((v) {
      if (mounted) setState(() => _sizes[BackupDir.images] = v);
    });
  }

  Widget _dirSwitch(BackupDir dir, String title) => SwitchListTile(
    title: Text(title),
    subtitle: Text(switch (_sizes[dir]) {
      null => '计算中…',
      final bytes => _formatBytes(bytes),
    }),
    value: _dirs.contains(dir),
    onChanged: (v) => setState(() => v ? _dirs.add(dir) : _dirs.remove(dir)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('备份与恢复'),
        actions: const [LibraryHomeButton()],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '备份包含媒体库数据（元数据、收藏、分组、历史、播放进度、评分笔记）、'
              '视频封面、设置和登录凭据。'
              '音视频文件本身不在备份里：本地音频存在文件 App 中不会丢失，恢复后在'
              '「媒体来源」里重新选择一次文件夹即可恢复访问。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _dirSwitch(BackupDir.images, '包含作品封面与图片缓存'),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('导出备份'),
            subtitle: const Text('选择目标文件夹（建议 iCloud Drive 或本机）'),
            onTap: _onExport,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('从备份恢复'),
            subtitle: const Text('选择之前导出的 Tonari备份 文件夹'),
            onTap: _onRestore,
          ),
        ],
      ),
    );
  }

  Future<void> _onExport() async {
    await _withScopedDir((dir) async {
      final progress = ValueNotifier<(String, int, int)>(('准备中', 0, 0));
      _showProgressDialog(progress);
      try {
        final path = await ref
            .read(backupServiceProvider)
            .export(
              targetDir: dir,
              dirs: _dirs,
              onProgress: (stage, done, total) =>
                  progress.value = (stage, done, total),
            );
        if (!mounted) return;
        Navigator.of(context).pop();
        showAppToast('备份完成：${path.split('/').last}');
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();
        showAppToast('备份失败：$e');
      }
    });
  }

  Future<void> _onRestore() async {
    await _withScopedDir((dir) async {
      final service = ref.read(backupServiceProvider);
      final BackupManifest manifest;
      try {
        manifest = await service.inspect(dir);
      } catch (e) {
        showAppToast('$e');
        return;
      }
      if (!mounted) return;
      final created = manifest.createdAt;
      final desc =
          '备份时间：${created.year}-${created.month}-${created.day}\n'
          '包含：${manifest.dirs.isEmpty ? '仅数据' : manifest.dirs.map((d) => d.label).join('、')}\n\n'
          '恢复会覆盖当前的媒体库数据和设置，且无法撤销。';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认恢复？'),
          content: Text(desc),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('恢复'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final progress = ValueNotifier<(String, int, int)>(('准备中', 0, 0));
      _showProgressDialog(progress);
      try {
        await service.stageRestore(
          dir,
          onProgress: (stage, done, total) =>
              progress.value = (stage, done, total),
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('备份已就绪'),
            content: const Text('请完全关闭 App（从后台上滑移除），再重新打开即完成恢复。'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();
        showAppToast('恢复失败：$e');
      }
    });
  }

  Future<void> _withScopedDir(Future<void> Function(String dir) action) async {
    final url = await FilePicker.getDirectoryPath();
    if (url == null) return;
    String? scoped;
    try {
      final bookmark = await FolderBookmark.create(url);
      final r = await FolderBookmark.resolve(bookmark);
      scoped = r.url;
    } catch (_) {
      // Simulator / in-sandbox folders don't need an active scope.
    }
    try {
      await action(scoped ?? url);
    } finally {
      if (scoped != null) {
        try {
          await FolderBookmark.release(scoped);
        } catch (_) {}
      }
    }
  }

  void _showProgressDialog(ValueNotifier<(String, int, int)> progress) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: ValueListenableBuilder<(String, int, int)>(
          valueListenable: progress,
          builder: (_, v, _) {
            final (stage, done, total) = v;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total > 1
                      ? '$stage  ${_formatBytes(done)} / ${_formatBytes(total)}'
                      : stage,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: total > 0 ? done / total : null),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
