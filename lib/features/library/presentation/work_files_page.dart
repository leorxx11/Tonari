import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/diagnostics/diagnostic_log.dart';
import '../../../core/subtitle/subtitle_cue.dart';
import '../../../core/subtitle/subtitle_parser.dart';
import '../../../shared/widgets/library_home_button.dart';
import '../../browse/data/remote_models.dart';
import '../../p115/data/p115_auth_service.dart';
import '../../p115/data/p115_client.dart';
import '../../p115/data/p115_cookie_store.dart';
import '../../player/data/playback_controller.dart';
import '../../player/presentation/mini_player.dart';
import '../../settings/presentation/translation_settings_page.dart';
import '../../subtitle/data/subtitle_providers.dart';
import '../../translation/data/llm_provider_repository.dart';
import '../../translation/data/track_translation_controller.dart';
import '../../translation/data/translation_controller.dart';
import '../../video/data/video_controller.dart';
import '../data/library_task_controller.dart';
import '../data/track_duration_probe.dart';
import '../data/work_media_source.dart';
import '../data/work_playback.dart';
import '../data/work_reimport_provider.dart';
import '../data/work_tree.dart';
import '../data/works_providers.dart';
import '../../../core/ui/app_toast.dart';

/// Accent for the currently-playing track row (tint + text + eq bars).
const Color _kAccent = Color(0xFF008B7D);

Color _accentText(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF3CB5A6)
      : const Color(0xFF0B6D62);
}

class WorkFilesPage extends ConsumerStatefulWidget {
  const WorkFilesPage({super.key, required this.work});

  final Work work;

  @override
  ConsumerState<WorkFilesPage> createState() => _WorkFilesPageState();
}

class _WorkFilesPageState extends ConsumerState<WorkFilesPage> {
  final List<String> _path = [];
  bool _probeStarted = false;
  bool _autoPathApplied = false;

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(tracksByWorkProvider(widget.work.productId));
    final filesAsync = ref.watch(
      workFilesByWorkProvider(widget.work.productId),
    );
    final ingestedSubs = ref
        .watch(ingestedSubtitlePathsProvider(widget.work.productId))
        .value;
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

    if (!_autoPathApplied && tracksAsync.hasValue) {
      _autoPathApplied = true;
      _path.addAll(autoPath(roots));
    }

    final currentChildren = _resolve(roots, _path);
    final theme = Theme.of(context);
    final titleText = _path.isEmpty ? '资源' : _path.last;
    final groupedBg = CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    );
    final cardBg = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
      context,
    );
    final separator = CupertinoColors.separator.resolveFrom(context);

    // No PopScope: the edge-swipe / system back always pops the whole page
    // back to the work detail — the highest-frequency exit. Folder-up is the
    // ‹ button and the breadcrumbs.
    return Scaffold(
      backgroundColor: groupedBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _onBack,
                    icon: const Icon(CupertinoIcons.chevron_left, size: 24),
                  ),
                  const Spacer(),
                  _TrackTranslateButton(
                    workId: widget.work.productId,
                    hasZh: tracks.any((t) => t.titleZh?.isNotEmpty ?? false),
                  ),
                  const LibraryHomeButton(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FilesHeader(
                      title: titleText,
                      workId: widget.work.productId,
                      children: currentChildren,
                    ),
                    if (_path.isNotEmpty)
                      _Breadcrumbs(
                        workId: widget.work.productId,
                        path: _path,
                        onTapSegment: _onTapBreadcrumb,
                      ),
                    if (currentChildren.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Center(
                          child: Text(
                            '此目录为空',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: CupertinoColors.secondaryLabel.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: separator, width: 0.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 14,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(18),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                for (
                                  var i = 0;
                                  i < currentChildren.length;
                                  i++
                                ) ...[
                                  if (i > 0)
                                    Divider(
                                      height: 0.5,
                                      thickness: 0.5,
                                      indent: 70,
                                      color: separator,
                                    ),
                                  _NodeRow(
                                    node: currentChildren[i],
                                    ingestedSubtitlePaths: ingestedSubs,
                                    onTapFolder: (name) =>
                                        setState(() => _path.add(name)),
                                    onPlayTrack: (t) => _play(t, playQueue),
                                    onPlayVideo: _playVideo,
                                    onOpenSubtitle: _openSubtitlePreview,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
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
    await ref
        .read(workPlaybackProvider)
        .start(work: widget.work, queue: playQueue, initialIndex: index);
  }

  Future<void> _playVideo(WorkFile file) async {
    DiagnosticLog.write('work_files', 'video_tap', {
      'workId': widget.work.productId,
      'fileId': file.id,
      'extension': _extension(file.fileName),
      'fileSize': file.fileSizeBytes,
    });
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
          DiagnosticLog.write('work_files', 'p115_resolve_start', {
            'workId': widget.work.productId,
            'fileId': file.id,
            'extension': _extension(file.fileName),
          });
          try {
            final resolved = await ref
                .read(p115ClientProvider)
                .resolveVideoUrl(file.filePath);
            DiagnosticLog.write('work_files', 'p115_resolve_done', {
              'workId': widget.work.productId,
              'fileId': file.id,
              'urlScheme': resolved.url.scheme,
              'urlHost': resolved.url.host,
            });
            return resolved;
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
            resolverSource: 'work_files_widget',
            resolve: resolver,
          ),
        );
  }

  Future<void> _openSubtitlePreview(WorkFile file) async {
    final cues = await ref.read(subtitlePreviewProvider(file.filePath).future);
    if (!mounted) return;
    if (cues != null) {
      await Navigator.of(context, rootNavigator: true).push(
        CupertinoSheetRoute<void>(
          scrollableBuilder: (_, _) =>
              _SubtitlePreviewPage(fileName: file.fileName, cues: cues),
          showDragHandle: true,
        ),
      );
      return;
    }
    final ext = _extension(file.fileName);
    if (!SubtitleParser.supports(ext)) {
      showAppToast('暂不支持 .$ext 字幕');
      return;
    }
    final rescan = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('字幕未入库'),
        content: const Text('该字幕还未下载，或未匹配到同目录下的同名音频。重新扫描此作品可尝试补齐。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('重新扫描'),
          ),
        ],
      ),
    );
    if (rescan != true || !mounted) return;
    await _rescanWork();
  }

  Future<void> _rescanWork() async {
    final taskController = ref.read(workTaskControllerProvider.notifier);
    final reimport = ref.read(reimportWorkProvider);
    try {
      await taskController.run<void>(
        productId: widget.work.productId,
        kind: LibraryTaskKind.import,
        title: '重新扫描作品',
        initialStage: '扫描文件',
        action: (task) async {
          await reimport(widget.work, task: task);
        },
      );
      if (!mounted) return;
      showAppToast('作品已重新扫描');
    } catch (e) {
      if (!mounted) return;
      showAppToast('重新扫描失败：$e');
    }
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
    final accent = _accentText(context);
    final iosSecondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final iosTertiary = CupertinoColors.tertiaryLabel.resolveFrom(context);

    Widget crumb({
      Key? key,
      required String label,
      required bool current,
      VoidCallback? onTap,
    }) {
      return GestureDetector(
        key: key,
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: current ? iosSecondary : accent,
              fontWeight: current ? FontWeight.w500 : FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final sep = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '›',
        style: theme.textTheme.labelMedium?.copyWith(color: iosTertiary),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 2),
      child: Row(
        children: [
          crumb(
            key: const ValueKey('crumb-root'),
            label: workId,
            current: false,
            onTap: () => onTapSegment(-1),
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

/// Left-aligned page header: current folder as the title, work id chip and
/// aggregate stats of the visible level below it.
class _FilesHeader extends StatelessWidget {
  const _FilesHeader({
    required this.title,
    required this.workId,
    required this.children,
  });

  final String title;
  final String workId;
  final List<WorkTreeNode> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentText(context);
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
    final parts = <String>[
      '${children.length} 项',
      if (audioCount > 0) '$audioCount 音频',
      if (totalDurMs > 0) _formatTotalDuration(totalDurMs),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  workId,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  parts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NodeRow extends ConsumerWidget {
  const _NodeRow({
    required this.node,
    required this.ingestedSubtitlePaths,
    required this.onTapFolder,
    required this.onPlayTrack,
    required this.onPlayVideo,
    required this.onOpenSubtitle,
  });

  final WorkTreeNode node;

  /// null while the subtitle set is still loading — rows render undimmed.
  final Set<String>? ingestedSubtitlePaths;
  final void Function(String name) onTapFolder;
  final void Function(Track track) onPlayTrack;
  final void Function(WorkFile file) onPlayVideo;
  final void Function(WorkFile file) onOpenSubtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final iosLabel = CupertinoColors.label.resolveFrom(context);
    final iosSecondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    const rowPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 4);
    final chevron = Icon(
      CupertinoIcons.chevron_right,
      size: 14,
      color: CupertinoColors.tertiaryLabel.resolveFrom(context),
    );
    final n = node;
    if (n is WorkTreeFolder) {
      final parts = <String>[
        '${n.itemCount} 项',
        if (n.audioCount > 0) _formatTotalDuration(n.totalDurationMs),
      ];
      return ListTile(
        contentPadding: rowPadding,
        leading: _IconSquare(
          icon: CupertinoIcons.folder_fill,
          color: CupertinoColors.systemBlue.resolveFrom(context),
        ),
        title: Text(
          n.name,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: iosLabel,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          parts.join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(color: iosSecondary),
        ),
        trailing: chevron,
        onTap: () => onTapFolder(n.name),
      );
    }
    if (n is WorkTreeTrack) {
      final t = n.track;
      final playback = ref.watch(playbackControllerProvider);
      final controller = ref.read(playbackControllerProvider.notifier);
      final isCurrent = playback.currentTrack?.id == t.id;
      final accent = _accentText(context);
      final showZh = ref.watch(trackTranslationViewProvider(t.workId)) ?? true;
      final titleZh = t.titleZh;
      final displayTitle = showZh && (titleZh?.isNotEmpty ?? false)
          ? titleZh!
          : t.fileName;
      return ListTile(
        contentPadding: rowPadding,
        tileColor: isCurrent ? _kAccent.withValues(alpha: 0.10) : null,
        leading: isCurrent
            ? _PlayingCircle(playingStream: controller.player.playingStream)
            : const _PlayTintCircle(),
        title: Text(
          displayTitle,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isCurrent ? accent : iosLabel,
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        trailing: t.durationMs > 0
            ? Text(
                _formatTrackDuration(t.durationMs),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isCurrent ? accent : iosSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
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
    final previewable = switch (f.fileKind) {
      'subtitle' => ingestedSubtitlePaths?.contains(f.filePath) ?? true,
      'video' => true,
      _ => false,
    };
    final tappable = switch (f.fileKind) {
      'video' || 'subtitle' => true,
      _ => false,
    };
    return ListTile(
      contentPadding: rowPadding,
      leading: _IconSquare(icon: icon, color: color, dimmed: !previewable),
      title: Text(
        f.fileName,
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: previewable ? iosLabel : iosSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        _formatBytes(f.fileSizeBytes),
        style: theme.textTheme.bodySmall?.copyWith(
          color: previewable
              ? iosSecondary
              : CupertinoColors.tertiaryLabel.resolveFrom(context),
        ),
      ),
      trailing: tappable && previewable ? chevron : null,
      onTap: switch (f.fileKind) {
        'video' => () => onPlayVideo(f),
        'subtitle' => () => onOpenSubtitle(f),
        _ => null,
      },
    );
  }
}

class _SubtitlePreviewPage extends StatelessWidget {
  const _SubtitlePreviewPage({required this.fileName, required this.cues});

  final String fileName;
  final List<SubtitleCue> cues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = cues.map(_formatCue).join('\n\n');
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(fileName)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SelectableText(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ),
      ),
    );
  }
}

String _formatCue(SubtitleCue cue) {
  return '${_formatCueTime(cue.startMs)} - ${_formatCueTime(cue.endMs)}\n'
      '${cue.text}';
}

String _formatCueTime(int ms) {
  final totalSeconds = ms ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  final millis = ms % 1000;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}.'
      '${millis.toString().padLeft(3, '0')}';
}

class _IconSquare extends StatelessWidget {
  const _IconSquare({
    required this.icon,
    required this.color,
    this.dimmed = false,
  });

  final IconData icon;
  final Color color;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final c = dimmed ? CupertinoColors.systemGrey3.resolveFrom(context) : color;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 19, color: c),
    );
  }
}

/// Tinted circular play affordance for non-current tracks — reads as
/// "tap to play" without needing a legend.
class _PlayTintCircle extends StatelessWidget {
  const _PlayTintCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        size: 24,
        color: _accentText(context),
      ),
    );
  }
}

/// Solid accent circle with three white equalizer bars marking the current
/// track; animates while playing, freezes when paused.
class _PlayingCircle extends StatefulWidget {
  const _PlayingCircle({required this.playingStream});

  final Stream<bool> playingStream;

  @override
  State<_PlayingCircle> createState() => _PlayingCircleState();
}

class _PlayingCircleState extends State<_PlayingCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  StreamSubscription<bool>? _sub;

  static const _baseHeights = [0.55, 0.95, 0.7];
  static const _phases = [0.0, 0.3, 0.6];

  @override
  void initState() {
    super.initState();
    _sub = widget.playingStream.listen((playing) {
      if (playing) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 2.5),
                Expanded(
                  child: FractionallySizedBox(
                    heightFactor: _barHeight(i),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  double _barHeight(int i) {
    if (!_controller.isAnimating) return _baseHeights[i];
    final t = _controller.value + _phases[i];
    final wave = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
    return 0.3 + (_baseHeights[i] - 0.3 + 0.35) * wave;
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

String _extension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}

/// Translate/toggle button for track titles, mirroring the detail page's
/// translation button: tap translates (or toggles once cached), long-press
/// force-retranslates everything.
class _TrackTranslateButton extends ConsumerWidget {
  const _TrackTranslateButton({required this.workId, required this.hasZh});

  final String workId;
  final bool hasZh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final defaultProvider = ref.watch(defaultLlmProviderProvider);
    final stateAsync = ref.watch(trackTranslationControllerProvider(workId));
    final showZh = ref.watch(trackTranslationViewProvider(workId)) ?? true;

    ref.listen<AsyncValue<TranslationState>>(
      trackTranslationControllerProvider(workId),
      (prev, next) {
        final s = next.value;
        if (s is TranslationDone) {
          ref.read(trackTranslationViewProvider(workId).notifier).show(true);
        } else if (s is TranslationFailed) {
          showAppToast(s.message);
        }
      },
    );

    final state = stateAsync.value ?? const TranslationIdle();
    if (state is TranslationLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (state is TranslationFailed) {
      return IconButton(
        tooltip: '翻译失败 · 点击重试',
        icon: Icon(Icons.error_outline, color: theme.colorScheme.error),
        onPressed: () {
          final controller = ref.read(
            trackTranslationControllerProvider(workId).notifier,
          );
          controller.clearFailure();
          controller.translate();
        },
      );
    }
    if (defaultProvider == null) {
      return IconButton(
        tooltip: '翻译音轨名（未配置 Provider）',
        icon: Icon(Icons.translate_outlined, color: theme.disabledColor),
        onPressed: () {
          showAppToast('请先在设置中配置翻译 Provider');
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const TranslationSettingsPage(),
            ),
          );
        },
      );
    }
    return GestureDetector(
      onLongPress: () => ref
          .read(trackTranslationControllerProvider(workId).notifier)
          .translate(force: true),
      child: IconButton(
        tooltip: hasZh ? (showZh ? '隐藏译名' : '显示译名') : '翻译音轨名',
        icon: Icon(
          hasZh && showZh ? Icons.translate : Icons.translate_outlined,
          size: 21,
          color: hasZh && showZh ? _accentText(context) : null,
        ),
        onPressed: () {
          if (hasZh) {
            ref
                .read(trackTranslationViewProvider(workId).notifier)
                .toggleFrom(showZh);
          } else {
            ref
                .read(trackTranslationControllerProvider(workId).notifier)
                .translate();
          }
        },
      ),
    );
  }
}
