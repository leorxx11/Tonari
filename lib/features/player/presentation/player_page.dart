import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../library/presentation/widgets/work_cover.dart';
import '../../settings/data/player_prefs.dart';
import '../../subtitle/data/subtitle_overlay_prefs.dart';
import '../../subtitle/data/subtitle_providers.dart';
import '../data/playback_controller.dart';

/// Sky-blue accent used for progress + volume sliders. Lighter and warmer
/// than `CupertinoColors.systemBlue`, which felt too saturated against the
/// large dark cover.
const Color _kPlayerAccent = Color(0xFF4DACF9);

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  double _speed = 1;

  @override
  void initState() {
    super.initState();
    _speed = ref.read(playbackControllerProvider.notifier).player.speed;
  }

  Future<void> _setSpeed(double speed) async {
    setState(() => _speed = speed);
    await ref.read(playbackControllerProvider.notifier).setSpeed(speed);
  }

  Future<void> _seekBy(Duration delta) async {
    final controller = ref.read(playbackControllerProvider.notifier);
    final duration = controller.player.duration ?? Duration.zero;
    final target = controller.player.position + delta;
    final clamped = Duration(
      milliseconds: target.inMilliseconds.clamp(0, duration.inMilliseconds),
    );
    await controller.seek(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playbackControllerProvider);
    final controller = ref.watch(playbackControllerProvider.notifier);
    final theme = Theme.of(context);
    final track = state.currentTrack;
    final browseItem = state.currentBrowseItem;
    final work = state.work;
    final step = ref.watch(playerPrefsProvider).seekStepSeconds;

    if (track == null && browseItem == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('未在播放')),
      );
    }

    final iosLabel = CupertinoColors.label.resolveFrom(context);
    final iosSecondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final iosTertiary = CupertinoColors.tertiaryLabel.resolveFrom(context);
    const iosBlue = _kPlayerAccent;
    final title = track?.fileName ?? browseItem!.fileName;
    final subtitle = work?.title ?? browseItem!.sourceName;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
        toolbarHeight: 44,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final s = constraints.maxWidth.clamp(220.0, 360.0);
                        return SizedBox(
                          width: s,
                          height: s,
                          child: work == null
                              ? DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    Icons.cloud_queue_rounded,
                                    size: 88,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : WorkCover(
                                  work: work,
                                  borderRadius: BorderRadius.circular(20),
                                  iconSize: 72,
                                ),
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: iosLabel,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _speed == 1.0 ? subtitle : '$subtitle · ${_speed}x',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: iosTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              _ProgressBar(
                controller: controller,
                accent: iosBlue,
                timeColor: iosSecondary,
              ),
              const SizedBox(height: 14),
              _MainControls(
                stepSeconds: step,
                primary: iosLabel,
                disabled: iosTertiary,
                playingStream: controller.player.playingStream,
                onPrev: state.hasPrevious ? controller.previous : null,
                onNext: state.hasNext ? controller.next : null,
                onSeekBackward: () => _seekBy(Duration(seconds: -step)),
                onSeekForward: () => _seekBy(Duration(seconds: step)),
                onPlay: controller.play,
                onPause: controller.pause,
              ),
              const SizedBox(height: 18),
              _VolumeRow(
                player: controller.player,
                accent: iosBlue,
                iconColor: iosSecondary,
              ),
              const SizedBox(height: 14),
              _BottomActions(
                color: iosSecondary,
                mode: ref.watch(playerPrefsProvider).playbackMode,
                onQueue: () => _showQueue(context, state, controller),
                onCycleMode: _cycleMode,
                onPickSubtitle: () => _placeholder(context, '从文件夹选择字幕 · 敬请期待'),
                onMore: () => _showMore(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _placeholder(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _cycleMode() async {
    await ref.read(playerPrefsProvider.notifier).cyclePlaybackMode();
  }

  Future<void> _showQueue(
    BuildContext context,
    PlaybackState state,
    PlaybackController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final iosBlue = CupertinoColors.systemBlue.resolveFrom(ctx);
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.65,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    '播放队列 · ${state.queueLength} 项',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                const Divider(height: 0.5, thickness: 0.5),
                Expanded(
                  child: ListView.builder(
                    itemCount: state.queueLength,
                    itemBuilder: (c, i) {
                      final title = state.isBrowseMode
                          ? state.browseItems[i].fileName
                          : state.tracks[i].fileName;
                      final isCurrent = i == state.currentIndex;
                      return ListTile(
                        leading: Icon(
                          isCurrent
                              ? CupertinoIcons.waveform
                              : CupertinoIcons.play_fill,
                          color: isCurrent ? iosBlue : iosBlue,
                          size: 22,
                        ),
                        title: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isCurrent
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        onTap: () {
                          controller.playAt(i);
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMore(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Text(
                    '播放速度',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in const [0.75, 1.0, 1.25, 1.5, 2.0])
                      ChoiceChip(
                        label: Text('${s}x'),
                        selected: _speed == s,
                        onSelected: (sel) {
                          if (sel) {
                            Navigator.of(ctx).pop();
                            _setSpeed(s);
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MainControls extends StatelessWidget {
  const _MainControls({
    required this.stepSeconds,
    required this.primary,
    required this.disabled,
    required this.playingStream,
    required this.onPrev,
    required this.onNext,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onPlay,
    required this.onPause,
  });

  final int stepSeconds;
  final Color primary;
  final Color disabled;
  final Stream<bool> playingStream;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final Future<void> Function() onPlay;
  final Future<void> Function() onPause;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          tooltip: '上一首',
          iconSize: 30,
          icon: Icon(
            CupertinoIcons.backward_end_fill,
            color: onPrev == null ? disabled : primary,
          ),
          onPressed: onPrev,
        ),
        _SeekButton(
          icon: CupertinoIcons.gobackward,
          seconds: stepSeconds,
          color: primary,
          tooltip: '后退 $stepSeconds 秒',
          onTap: onSeekBackward,
        ),
        StreamBuilder<bool>(
          stream: playingStream,
          initialData: false,
          builder: (context, snapshot) {
            final playing = snapshot.data ?? false;
            return IconButton(
              iconSize: 64,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: playing ? '暂停' : '播放',
              icon: Icon(
                playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                color: primary,
              ),
              onPressed: () => playing ? onPause() : onPlay(),
            );
          },
        ),
        _SeekButton(
          icon: CupertinoIcons.goforward,
          seconds: stepSeconds,
          color: primary,
          tooltip: '前进 $stepSeconds 秒',
          onTap: onSeekForward,
        ),
        IconButton(
          tooltip: '下一首',
          iconSize: 30,
          icon: Icon(
            CupertinoIcons.forward_end_fill,
            color: onNext == null ? disabled : primary,
          ),
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _SeekButton extends StatelessWidget {
  const _SeekButton({
    required this.icon,
    required this.seconds,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final int seconds;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 44, color: color),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '$seconds',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VolumeRow extends StatefulWidget {
  const _VolumeRow({
    required this.player,
    required this.accent,
    required this.iconColor,
  });

  final AudioPlayer player;
  final Color accent;
  final Color iconColor;

  @override
  State<_VolumeRow> createState() => _VolumeRowState();
}

class _VolumeRowState extends State<_VolumeRow> {
  late double _volume = widget.player.volume;
  StreamSubscription<double>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.player.volumeStream.listen((v) {
      if (mounted) setState(() => _volume = v);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(CupertinoIcons.volume_down, size: 22, color: widget.iconColor),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: widget.accent,
              thumbColor: widget.accent,
            ),
            child: Slider(
              value: _volume.clamp(0.0, 1.0),
              onChanged: (v) {
                setState(() => _volume = v);
                widget.player.setVolume(v);
              },
            ),
          ),
        ),
        Icon(CupertinoIcons.volume_up, size: 22, color: widget.iconColor),
      ],
    );
  }
}

class _BottomActions extends ConsumerWidget {
  const _BottomActions({
    required this.color,
    required this.mode,
    required this.onQueue,
    required this.onCycleMode,
    required this.onPickSubtitle,
    required this.onMore,
  });

  final Color color;
  final PlaybackMode mode;
  final VoidCallback onQueue;
  final VoidCallback onCycleMode;
  final VoidCallback onPickSubtitle;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSubtitle = ref.watch(currentSubtitleProvider).value != null;
    final subtitleMode = ref.watch(
      subtitleOverlayPrefsProvider.select((p) => p.mode),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          tooltip: '播放队列',
          iconSize: 22,
          icon: Icon(CupertinoIcons.music_note_list, color: color),
          onPressed: onQueue,
        ),
        IconButton(
          tooltip: mode.label,
          iconSize: 22,
          icon: Icon(_modeIcon(mode), color: color),
          onPressed: onCycleMode,
        ),
        if (hasSubtitle)
          IconButton(
            tooltip: '字幕模式：${subtitleMode.label} · 单击切换',
            iconSize: 22,
            icon: Icon(_subtitleModeIcon(subtitleMode), color: color),
            onPressed: () =>
                ref.read(subtitleOverlayPrefsProvider.notifier).cycle(),
          ),
        IconButton(
          tooltip: '手动选择字幕文件',
          iconSize: 22,
          icon: Icon(Icons.subtitles_outlined, color: color),
          onPressed: onPickSubtitle,
        ),
        IconButton(
          tooltip: '更多',
          iconSize: 22,
          icon: Icon(CupertinoIcons.ellipsis, color: color),
          onPressed: onMore,
        ),
      ],
    );
  }

  IconData _modeIcon(PlaybackMode m) => switch (m) {
    PlaybackMode.sequence => Icons.playlist_play_rounded,
    PlaybackMode.loopAll => Icons.repeat_rounded,
    PlaybackMode.loopOne => Icons.repeat_one_rounded,
    PlaybackMode.shuffle => Icons.shuffle_rounded,
  };

  IconData _subtitleModeIcon(SubtitleMode m) => switch (m) {
    SubtitleMode.off => CupertinoIcons.captions_bubble,
    SubtitleMode.appLevel => CupertinoIcons.captions_bubble_fill,
    SubtitleMode.pip => Icons.picture_in_picture_alt_rounded,
  };
}

class _ProgressBar extends StatefulWidget {
  const _ProgressBar({
    required this.controller,
    required this.accent,
    required this.timeColor,
  });

  final PlaybackController controller;
  final Color accent;
  final Color timeColor;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  double? _dragValue;

  AudioPlayer get _player => widget.controller.player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: _player.durationStream,
      initialData: _player.duration,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: _player.positionStream,
          initialData: _player.position,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final durationMs = duration.inMilliseconds;
            final livePositionMs = position.inMilliseconds.clamp(0, durationMs);
            final displayMs = _dragValue?.round() ?? livePositionMs;
            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: widget.accent,
                    thumbColor: widget.accent,
                  ),
                  child: Slider(
                    value: durationMs == 0
                        ? 0
                        : displayMs.toDouble().clamp(0, durationMs.toDouble()),
                    max: durationMs == 0 ? 1 : durationMs.toDouble(),
                    onChangeStart: durationMs == 0
                        ? null
                        : (value) => setState(() => _dragValue = value),
                    onChanged: durationMs == 0
                        ? null
                        : (value) => setState(() => _dragValue = value),
                    onChangeEnd: durationMs == 0
                        ? null
                        : (value) async {
                            await widget.controller.seek(
                              Duration(milliseconds: value.round()),
                            );
                            if (mounted) setState(() => _dragValue = null);
                          },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(Duration(milliseconds: displayMs)),
                        style: TextStyle(color: widget.timeColor, fontSize: 12),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: TextStyle(color: widget.timeColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours == 0) return '$minutes:$seconds';
  return '$hours:$minutes:$seconds';
}
