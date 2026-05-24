import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../data/playback_controller.dart';

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
    final work = state.work;

    if (track == null || work == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('未在播放')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(work.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.album_outlined,
                        size: 72,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${state.currentIndex + 1} / ${state.tracks.length} · ${track.parentDirName}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _ProgressBar(player: controller.player),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: '上一首',
                    icon: const Icon(Icons.skip_previous),
                    onPressed: state.hasPrevious ? controller.previous : null,
                  ),
                  IconButton(
                    tooltip: '后退 10 秒',
                    icon: const Icon(Icons.replay_10),
                    onPressed: () => _seekBy(const Duration(seconds: -10)),
                  ),
                  StreamBuilder<bool>(
                    stream: controller.player.playingStream,
                    initialData: controller.player.playing,
                    builder: (context, snapshot) {
                      final playing = snapshot.data ?? false;
                      return FilledButton(
                        onPressed: () =>
                            playing ? controller.pause() : controller.play(),
                        child: Icon(playing ? Icons.pause : Icons.play_arrow),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: '前进 30 秒',
                    icon: const Icon(Icons.forward_30),
                    onPressed: () => _seekBy(const Duration(seconds: 30)),
                  ),
                  IconButton(
                    tooltip: '下一首',
                    icon: const Icon(Icons.skip_next),
                    onPressed: state.hasNext ? controller.next : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 0.75, label: Text('0.75x')),
                  ButtonSegment(value: 1.0, label: Text('1.0x')),
                  ButtonSegment(value: 1.25, label: Text('1.25x')),
                  ButtonSegment(value: 1.5, label: Text('1.5x')),
                  ButtonSegment(value: 2.0, label: Text('2.0x')),
                ],
                selected: {_speed},
                onSelectionChanged: (value) => _setSpeed(value.single),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.player});

  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      initialData: player.duration,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          initialData: player.position,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final durationMs = duration.inMilliseconds;
            final positionMs = position.inMilliseconds.clamp(0, durationMs);
            return Column(
              children: [
                Slider(
                  value: durationMs == 0 ? 0 : positionMs.toDouble(),
                  max: durationMs == 0 ? 1 : durationMs.toDouble(),
                  onChanged: durationMs == 0
                      ? null
                      : (value) =>
                          player.seek(Duration(milliseconds: value.round())),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(Duration(milliseconds: positionMs))),
                    Text(_formatDuration(duration)),
                  ],
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
