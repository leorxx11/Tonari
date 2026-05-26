import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../player/data/playback_controller.dart';
import '../../settings/data/path_prefs.dart';
import '../data/work_tree.dart';
import '../data/works_providers.dart';

class WorkFilesPage extends ConsumerStatefulWidget {
  const WorkFilesPage({super.key, required this.work});

  final Work work;

  @override
  ConsumerState<WorkFilesPage> createState() => _WorkFilesPageState();
}

class _WorkFilesPageState extends ConsumerState<WorkFilesPage> {
  final List<String> _path = [];
  bool _autoApplied = false;

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(tracksByWorkProvider(widget.work.productId));
    final filesAsync = ref.watch(
      workFilesByWorkProvider(widget.work.productId),
    );
    final tracks = tracksAsync.value ?? const <Track>[];
    final files = filesAsync.value ?? const <WorkFile>[];
    final roots = buildWorkTree(tracks, workFiles: files);
    final playQueue = flattenForPlayback(roots);
    final prefs = ref.watch(pathPrefsProvider);
    final autoHint = autoPath(
      roots,
      smartPath: prefs.smartPath,
      preferEffectSound: prefs.preferEffectSound,
      typeOrderEnabled: prefs.typeOrderEnabled,
      typeOrder: prefs.typeOrder,
    );

    if (!_autoApplied && tracksAsync.hasValue && filesAsync.hasValue) {
      _autoApplied = true;
      if (autoHint.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _path.isNotEmpty) return;
          setState(() => _path.addAll(autoHint));
        });
      }
    }

    final currentChildren = _resolve(roots, _path);
    final theme = Theme.of(context);

    return PopScope(
      canPop: _path.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_path.isNotEmpty) {
          setState(() => _path.removeLast());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _onBack),
          title: Text(_path.isEmpty ? '资源' : _path.last),
        ),
        body: Column(
          children: [
            _Breadcrumbs(
              workId: widget.work.productId,
              path: _path,
              onTapSegment: _onTapBreadcrumb,
            ),
            _AutoPathHint(enabled: prefs.smartPath, hint: autoHint),
            const Divider(height: 1),
            Expanded(
              child: currentChildren.isEmpty
                  ? Center(
                      child: Text(
                        '此目录为空',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: currentChildren.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) => _NodeRow(
                        node: currentChildren[i],
                        onTapFolder: (name) =>
                            setState(() => _path.add(name)),
                        onPlayTrack: (t) => _play(t, playQueue),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _onBack() {
    if (_path.isNotEmpty) {
      setState(() => _path.removeLast());
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _onTapBreadcrumb(int segmentIndex) {
    // segmentIndex == -1 means root.
    setState(() {
      if (segmentIndex < 0) {
        _path.clear();
      } else {
        _path.removeRange(segmentIndex + 1, _path.length);
      }
    });
  }

  Future<void> _play(Track track, List<Track> playQueue) async {
    final index = playQueue.indexWhere((t) => t.id == track.id);
    if (index < 0) return;
    final bookmark = await ref.read(
      bookmarkForWorkProvider(widget.work.productId).future,
    );
    await ref.read(playbackControllerProvider.notifier).startWork(
          work: widget.work,
          tracks: playQueue,
          initialIndex: index,
          bookmarkBase64: bookmark,
        );
  }

  /// Walks [roots] following [path], returning the children at that depth.
  /// Returns an empty list if any segment is missing (e.g. tree changed
  /// under us during a rescan).
  List<WorkTreeNode> _resolve(List<WorkTreeNode> roots, List<String> path) {
    var cursor = roots;
    for (final seg in path) {
      final next = cursor.whereType<WorkTreeFolder>().firstWhere(
            (f) => f.name == seg,
            orElse: () => WorkTreeFolder(name: '', children: const []),
          );
      if (next.name.isEmpty) return const [];
      cursor = next.children;
    }
    return cursor;
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({
    required this.workId,
    required this.path,
    required this.onTapSegment,
  });

  final String workId;
  final List<String> path;
  final void Function(int segmentIndex) onTapSegment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _crumb(
            theme,
            label: workId,
            onTap: path.isEmpty ? null : () => onTapSegment(-1),
            current: path.isEmpty,
          ),
          for (var i = 0; i < path.length; i++) ...[
            _sep(theme),
            _crumb(
              theme,
              label: path[i],
              onTap: i == path.length - 1 ? null : () => onTapSegment(i),
              current: i == path.length - 1,
            ),
          ],
        ],
      ),
    );
  }

  Widget _crumb(
    ThemeData theme, {
    required String label,
    VoidCallback? onTap,
    bool current = false,
  }) {
    final color = current
        ? theme.colorScheme.onSurface
        : theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.folder, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: current ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sep(ThemeData theme) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          '/',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      );
}

class _AutoPathHint extends StatelessWidget {
  const _AutoPathHint({required this.enabled, required this.hint});

  final bool enabled;
  final List<String> hint;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final label = hint.isEmpty ? '未命中' : hint.join(' / ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Icon(
            Icons.alt_route,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '智能路径: $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeRow extends ConsumerWidget {
  const _NodeRow({
    required this.node,
    required this.onTapFolder,
    required this.onPlayTrack,
  });

  final WorkTreeNode node;
  final void Function(String name) onTapFolder;
  final void Function(Track track) onPlayTrack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final n = node;
    if (n is WorkTreeFolder) {
      final parts = <String>[
        '${n.itemCount} 项',
        if (n.audioCount > 0) _formatTotalDuration(n.totalDurationMs),
      ];
      return ListTile(
        leading: const Icon(Icons.folder, color: Color(0xFFFFC857), size: 32),
        title: Text(
          n.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(parts.join(', ')),
        trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
        onTap: () => onTapFolder(n.name),
      );
    }
    if (n is WorkTreeTrack) {
      final t = n.track;
      final playback = ref.watch(playbackControllerProvider);
      final isCurrent = playback.currentTrack?.id == t.id;
      final completed = t.durationMs > 0 &&
          t.lastPositionMs / t.durationMs >= 0.95;
      final mutedColor = theme.colorScheme.onSurfaceVariant;
      return ListTile(
        leading: Icon(
          isCurrent
              ? Icons.graphic_eq
              : (completed ? Icons.check_circle : Icons.play_circle),
          color: isCurrent
              ? theme.colorScheme.primary
              : (completed ? mutedColor : theme.colorScheme.primary),
          size: 32,
        ),
        title: Text(
          t.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (completed && !isCurrent)
              ? theme.textTheme.bodyLarge?.copyWith(color: mutedColor)
              : null,
        ),
        subtitle: t.durationMs > 0
            ? Text(_formatTrackDuration(t.durationMs))
            : null,
        onTap: () => onPlayTrack(t),
      );
    }
    final f = (n as WorkTreeFile).file;
    final (icon, color) = _iconForKind(f.fileKind, theme);
    return ListTile(
      leading: Icon(icon, color: color, size: 32),
      title: Text(
        f.fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(_formatBytes(f.fileSizeBytes)),
    );
  }
}

(IconData, Color) _iconForKind(String kind, ThemeData theme) {
  return switch (kind) {
    'image' => (Icons.image_outlined, theme.colorScheme.tertiary),
    'text' => (Icons.description, theme.colorScheme.primary),
    'subtitle' => (Icons.subtitles_outlined, theme.colorScheme.secondary),
    _ => (Icons.insert_drive_file_outlined, theme.colorScheme.onSurfaceVariant),
  };
}

String _formatTotalDuration(int ms) {
  if (ms <= 0) return '0s';
  final totalMinutes = ms ~/ 60000;
  if (totalMinutes >= 60) {
    final halfHours = (totalMinutes / 30).round();
    final hours = halfHours / 2;
    final text = hours == hours.truncate()
        ? hours.toStringAsFixed(0)
        : hours.toStringAsFixed(1);
    return '${text}hr';
  }
  if (totalMinutes > 0) return '${totalMinutes}min';
  return '${(ms / 1000).round()}s';
}

String _formatTrackDuration(int ms) {
  final d = Duration(milliseconds: ms);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h == 0 ? '$m:$s' : '$h:$m:$s';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}
