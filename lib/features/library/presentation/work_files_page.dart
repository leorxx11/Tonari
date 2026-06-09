import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../browse/data/remote_models.dart';
import '../../p115/data/p115_auth_service.dart';
import '../../p115/data/p115_client.dart';
import '../../p115/data/p115_cookie_store.dart';
import '../../player/data/playback_controller.dart';
import '../../video/data/video_controller.dart';
import '../data/track_duration_probe.dart';
import '../data/work_media_source.dart';
import '../data/work_tree.dart';
import '../data/works_providers.dart';

/// Teal highlight applied to the track row currently being played.
const Color _kCurrentTrackBackground = Color(0xFF008B7D);

class WorkFilesPage extends ConsumerStatefulWidget {
  const WorkFilesPage({super.key, required this.work});

  final Work work;

  @override
  ConsumerState<WorkFilesPage> createState() => _WorkFilesPageState();
}

class _WorkFilesPageState extends ConsumerState<WorkFilesPage> {
  final List<String> _path = [];
  bool _probeStarted = false;

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

    if (!_probeStarted && tracksAsync.hasValue) {
      _probeStarted = true;
      final toProbe = tracksAsync.value!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(trackDurationProbeProvider).probe(toProbe);
      });
    }

    final currentChildren = _resolve(roots, _path);
    final theme = Theme.of(context);
    final titleText = _path.isEmpty ? '资源' : _path.last;

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
          title: Text(titleText, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: Column(
          children: [
            _Breadcrumbs(
              workId: widget.work.productId,
              path: _path,
              onTapSegment: _onTapBreadcrumb,
            ),
            Divider(
              height: 0.5,
              thickness: 0.5,
              color: CupertinoColors.separator.resolveFrom(context),
            ),
            Expanded(
              child: currentChildren.isEmpty
                  ? Center(
                      child: Text(
                        '此目录为空',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: currentChildren.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 0.5,
                        thickness: 0.5,
                        indent: 72,
                        color: CupertinoColors.separator.resolveFrom(context),
                      ),
                      itemBuilder: (context, i) => _NodeRow(
                        node: currentChildren[i],
                        onTapFolder: (name) => setState(() => _path.add(name)),
                        onPlayTrack: (t) => _play(t, playQueue),
                        onPlayVideo: _playVideo,
                      ),
                    ),
            ),
            if (currentChildren.isNotEmpty)
              _FooterStats(children: currentChildren),
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
    final source = await ref
        .read(workMediaSourceProvider)
        .sourceForWork(widget.work);
    final bookmark = source.kind == RemoteSourceKind.local
        ? await ref.read(bookmarkForWorkProvider(widget.work.productId).future)
        : null;
    await ref
        .read(playbackControllerProvider.notifier)
        .startWork(
          work: widget.work,
          tracks: playQueue,
          initialIndex: index,
          bookmarkBase64: bookmark,
          remoteKind: source.kind == RemoteSourceKind.local
              ? null
              : source.kind,
          remoteConfig: source.webdavConfig,
        );
  }

  Future<void> _playVideo(WorkFile file) async {
    final source = await ref
        .read(workMediaSourceProvider)
        .sourceForWork(widget.work);
    final PlayableResolver resolver;
    switch (source.kind) {
      case RemoteSourceKind.local:
        resolver = () async => ResolvedMediaUrl(url: Uri.file(file.filePath));
      case RemoteSourceKind.webdav:
        final config = source.webdavConfig!;
        resolver = () async {
          final auth = config.authHeader;
          return ResolvedMediaUrl(
            url: Uri.parse(config.streamUrl(file.filePath)),
            headers: auth == null ? null : {'Authorization': auth},
          );
        };
      case RemoteSourceKind.p115:
        resolver = () async {
          try {
            return await ref
                .read(p115ClientProvider)
                .resolveDownloadUrl(file.filePath);
          } on P115AuthExpiredException {
            await ref.read(p115AuthServiceProvider).clearCookie();
            ref.invalidate(p115CookieProvider);
            rethrow;
          }
        };
    }
    await ref
        .read(videoControllerProvider.notifier)
        .open(
          PlayableItem(
            id: file.id,
            sourceKind: source.kind,
            sourceId: source.sourceId,
            sourceName: source.sourceName,
            path: file.filePath,
            fileName: file.fileName,
            kind: RemoteEntryKind.video,
            size: file.fileSizeBytes,
            pickcode: source.kind == RemoteSourceKind.p115
                ? file.filePath
                : null,
            resolve: resolver,
          ),
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
    final iosBlue = CupertinoColors.systemBlue.resolveFrom(context);
    final iosLabel = CupertinoColors.label.resolveFrom(context);
    final iosTertiary = CupertinoColors.tertiaryLabel.resolveFrom(context);

    Widget crumb({
      required String label,
      required bool current,
      VoidCallback? onTap,
    }) {
      final color = current ? iosLabel : iosBlue;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_rounded, color: color, size: 22),
              const SizedBox(width: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: current ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sep = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '/',
        style: theme.textTheme.titleSmall?.copyWith(color: iosTertiary),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          crumb(
            label: workId,
            current: path.isEmpty,
            onTap: path.isEmpty ? null : () => onTapSegment(-1),
          ),
          for (var i = 0; i < path.length; i++) ...[
            sep,
            crumb(
              label: path[i],
              current: i == path.length - 1,
              onTap: i == path.length - 1 ? null : () => onTapSegment(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _FooterStats extends StatelessWidget {
  const _FooterStats({required this.children});

  final List<WorkTreeNode> children;

  @override
  Widget build(BuildContext context) {
    var totalDurMs = 0;
    var audioCount = 0;
    for (final c in children) {
      if (c is WorkTreeTrack) {
        totalDurMs += c.track.durationMs;
        audioCount += 1;
      } else if (c is WorkTreeFolder) {
        totalDurMs += c.totalDurationMs;
        audioCount += c.audioCount;
      }
    }
    final theme = Theme.of(context);
    final iosSecondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final parts = <String>[
      '${children.length} 项',
      if (audioCount > 0) '$audioCount 音频',
      if (totalDurMs > 0) _formatTotalDuration(totalDurMs),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      child: Text(
        parts.join(' · '),
        style: theme.textTheme.bodySmall?.copyWith(color: iosSecondary),
      ),
    );
  }
}

class _NodeRow extends ConsumerWidget {
  const _NodeRow({
    required this.node,
    required this.onTapFolder,
    required this.onPlayTrack,
    required this.onPlayVideo,
  });

  final WorkTreeNode node;
  final void Function(String name) onTapFolder;
  final void Function(Track track) onPlayTrack;
  final void Function(WorkFile file) onPlayVideo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final iosBlue = CupertinoColors.systemBlue.resolveFrom(context);
    final iosLabel = CupertinoColors.label.resolveFrom(context);
    final iosSecondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    const rowPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 6);
    final n = node;
    if (n is WorkTreeFolder) {
      final parts = <String>[
        '${n.itemCount} 项',
        if (n.audioCount > 0) _formatTotalDuration(n.totalDurationMs),
      ];
      return ListTile(
        contentPadding: rowPadding,
        leading: Icon(Icons.folder_rounded, color: iosBlue, size: 44),
        title: Text(
          n.name,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: iosLabel,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          parts.join(', '),
          style: theme.textTheme.bodySmall?.copyWith(color: iosSecondary),
        ),
        trailing: Icon(
          CupertinoIcons.chevron_right,
          size: 14,
          color: iosSecondary,
        ),
        onTap: () => onTapFolder(n.name),
      );
    }
    if (n is WorkTreeTrack) {
      final t = n.track;
      final playback = ref.watch(playbackControllerProvider);
      final controller = ref.read(playbackControllerProvider.notifier);
      final isCurrent = playback.currentTrack?.id == t.id;
      final titleColor = isCurrent ? Colors.white : iosLabel;
      final subtitleColor = isCurrent
          ? Colors.white.withValues(alpha: 0.78)
          : iosSecondary;
      return ListTile(
        contentPadding: rowPadding,
        tileColor: isCurrent ? _kCurrentTrackBackground : null,
        leading: _TrackLeading(
          isCurrent: isCurrent,
          playingStream: isCurrent ? controller.player.playingStream : null,
        ),
        title: Text(
          t.fileName,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: t.durationMs > 0
            ? Text(
                _formatTrackDuration(t.durationMs),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: subtitleColor,
                ),
              )
            : null,
        onTap: () {
          if (isCurrent) {
            if (controller.player.playing) {
              controller.pause();
            } else {
              controller.play();
            }
          } else {
            onPlayTrack(t);
          }
        },
      );
    }
    final f = (n as WorkTreeFile).file;
    final (icon, color) = _iconForKind(f.fileKind, context);
    return ListTile(
      contentPadding: rowPadding,
      leading: Icon(icon, color: color, size: 44),
      title: Text(
        f.fileName,
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: iosLabel,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        _formatBytes(f.fileSizeBytes),
        style: theme.textTheme.bodySmall?.copyWith(color: iosSecondary),
      ),
      onTap: f.fileKind == 'video' ? () => onPlayVideo(f) : null,
    );
  }
}

class _TrackLeading extends StatelessWidget {
  const _TrackLeading({required this.isCurrent, this.playingStream});

  final bool isCurrent;
  final Stream<bool>? playingStream;

  @override
  Widget build(BuildContext context) {
    if (!isCurrent || playingStream == null) {
      return const _PlayCircle(playing: false);
    }
    return StreamBuilder<bool>(
      stream: playingStream,
      initialData: false,
      builder: (context, snapshot) =>
          _PlayCircle(playing: snapshot.data ?? false),
    );
  }
}

class _PlayCircle extends StatelessWidget {
  const _PlayCircle({required this.playing});

  final bool playing;

  @override
  Widget build(BuildContext context) {
    final iosBlue = CupertinoColors.systemBlue.resolveFrom(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: iosBlue, shape: BoxShape.circle),
      child: Icon(
        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        color: Colors.white,
        size: 30,
      ),
    );
  }
}

(IconData, Color) _iconForKind(String kind, BuildContext context) {
  return switch (kind) {
    'image' => (
      CupertinoIcons.photo_fill,
      CupertinoColors.systemPurple.resolveFrom(context),
    ),
    'text' => (
      CupertinoIcons.doc_text_fill,
      CupertinoColors.systemGrey.resolveFrom(context),
    ),
    'subtitle' => (
      CupertinoIcons.captions_bubble_fill,
      CupertinoColors.systemOrange.resolveFrom(context),
    ),
    'video' => (
      CupertinoIcons.videocam_fill,
      CupertinoColors.systemBlue.resolveFrom(context),
    ),
    _ => (
      CupertinoIcons.doc_fill,
      CupertinoColors.systemGrey.resolveFrom(context),
    ),
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
