import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/library_home_button.dart';
import '../../../core/files/local_image_path.dart';
import '../../video_library/data/video_cover_store.dart';
import '../data/player_prefs.dart';
import '../../../core/ui/app_toast.dart';

class PlaybackSettingsPage extends ConsumerWidget {
  const PlaybackSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerPrefs = ref.watch(playerPrefsProvider);
    final playerNotifier = ref.read(playerPrefsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('播放'),
        actions: const [LibraryHomeButton()],
      ),
      body: ListView(
        children: [
          _SeekStepSelector(
            current: playerPrefs.seekStepSeconds,
            onChanged: playerNotifier.setSeekStep,
          ),
          const Divider(height: 24),
          const _DefaultVideoCoverTile(),
        ],
      ),
    );
  }
}

class _DefaultVideoCoverTile extends ConsumerWidget {
  const _DefaultVideoCoverTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cover = ref.watch(defaultVideoCoverProvider);
    final resolved = LocalImagePath.resolve(cover);
    return ListTile(
      leading: SizedBox(
        width: 56,
        height: 42,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: resolved != null
              ? Image.file(File(resolved), fit: BoxFit.cover)
              : Container(
                  color: theme.colorScheme.surfaceContainerHigh,
                  child: Icon(
                    CupertinoIcons.videocam_fill,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
      ),
      title: const Text('视频默认封面'),
      subtitle: Text(resolved != null ? '视频库条目没有封面时显示' : '未设置，无封面条目显示占位图标'),
      trailing: resolved == null
          ? null
          : IconButton(
              tooltip: '清除默认封面',
              icon: const Icon(Icons.close),
              onPressed: () =>
                  ref.read(defaultVideoCoverProvider.notifier).set(null),
            ),
      onTap: () => _pick(context, ref),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    final path = result?.files.singleOrNull?.path;
    if (path == null) return;
    try {
      final rel = await ref.read(videoCoverStoreProvider).importFile(path);
      await ref.read(defaultVideoCoverProvider.notifier).set(rel);
    } catch (e) {
      showAppToast('设置失败：$e');
    }
  }
}

class _SeekStepSelector extends StatelessWidget {
  const _SeekStepSelector({required this.current, required this.onChanged});

  final int current;
  final Future<void> Function(int seconds) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPreset = PlayerPrefs.presetSteps.contains(current);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.fast_forward_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text('快进 / 快退步长', style: theme.textTheme.bodyLarge),
                const Spacer(),
                Text(
                  '$current 秒',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in PlayerPrefs.presetSteps)
                ChoiceChip(
                  label: Text('${s}s'),
                  selected: s == current,
                  onSelected: (sel) {
                    if (sel) onChanged(s);
                  },
                ),
              ActionChip(
                avatar: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('自定义'),
                onPressed: () => _promptCustom(context),
              ),
              if (!isPreset)
                InputChip(
                  label: Text('${current}s'),
                  selected: true,
                  onPressed: () => _promptCustom(context),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '播放页 -X / +X 按钮按此值跳秒',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptCustom(BuildContext context) async {
    final controller = TextEditingController(text: '$current');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义步长'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            suffixText: '秒',
            hintText: '1 - 600',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed != null && parsed > 0) {
                Navigator.of(ctx).pop(parsed);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result != null) await onChanged(result);
  }
}
