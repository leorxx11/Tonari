import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../data/video_controller.dart';

class VideoPlayerPage extends ConsumerStatefulWidget {
  const VideoPlayerPage({super.key});

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage> {
  bool _landscape = false;
  double? _dragValue;

  @override
  void dispose() {
    if (_landscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    super.dispose();
  }

  Future<void> _toggleOrientation() async {
    _landscape = !_landscape;
    await SystemChrome.setPreferredOrientations(
      _landscape
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp],
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(videoControllerProvider);
    final controller = ref.read(videoControllerProvider.notifier);
    final vpc = state.controller;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: '收起',
          icon: const Icon(CupertinoIcons.chevron_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          state.item?.fileName ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: state.error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '${state.error}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            : vpc == null || !vpc.value.isInitialized
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: vpc.value.aspectRatio,
                        child: VideoPlayer(vpc),
                      ),
                    ),
                  ),
                  _Controls(
                    controller: vpc,
                    landscape: _landscape,
                    dragValue: _dragValue,
                    onDragChanged: (v) => setState(() => _dragValue = v),
                    onDragEnd: (v) async {
                      await controller.seek(Duration(milliseconds: v.round()));
                      if (mounted) setState(() => _dragValue = null);
                    },
                    onTogglePlay: () => vpc.value.isPlaying
                        ? controller.pause()
                        : controller.play(),
                    onSpeed: controller.setSpeed,
                    onOrientation: _toggleOrientation,
                  ),
                ],
              ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.landscape,
    required this.dragValue,
    required this.onDragChanged,
    required this.onDragEnd,
    required this.onTogglePlay,
    required this.onSpeed,
    required this.onOrientation,
  });

  final VideoPlayerController controller;
  final bool landscape;
  final double? dragValue;
  final ValueChanged<double> onDragChanged;
  final ValueChanged<double> onDragEnd;
  final Future<void> Function() onTogglePlay;
  final Future<void> Function(double speed) onSpeed;
  final Future<void> Function() onOrientation;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final durationMs = value.duration.inMilliseconds;
        final positionMs = value.position.inMilliseconds
            .clamp(0, durationMs)
            .toInt();
        final displayMs = dragValue?.round() ?? positionMs;
        return Material(
          color: Colors.black,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: durationMs == 0
                        ? 0
                        : displayMs.toDouble().clamp(0, durationMs.toDouble()),
                    max: durationMs == 0 ? 1 : durationMs.toDouble(),
                    onChanged: durationMs == 0 ? null : onDragChanged,
                    onChangeEnd: durationMs == 0 ? null : onDragEnd,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _fmt(Duration(milliseconds: displayMs)),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _fmt(value.duration),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      tooltip: value.isPlaying ? '暂停' : '播放',
                      iconSize: 34,
                      color: Colors.white,
                      icon: Icon(
                        value.isPlaying
                            ? CupertinoIcons.pause_fill
                            : CupertinoIcons.play_fill,
                      ),
                      onPressed: onTogglePlay,
                    ),
                    PopupMenuButton<double>(
                      tooltip: '倍速',
                      initialValue: value.playbackSpeed,
                      color: Colors.white,
                      onSelected: onSpeed,
                      itemBuilder: (_) => [
                        for (final s in const [1.0, 1.25, 1.5, 2.0])
                          PopupMenuItem(value: s, child: Text('${s}x')),
                      ],
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Text(
                            '${value.playbackSpeed}x',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: landscape ? '竖屏' : '横屏',
                      iconSize: 28,
                      color: Colors.white,
                      icon: const Icon(Icons.screen_rotation_alt_outlined),
                      onPressed: onOrientation,
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

String _fmt(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours == 0) return '$minutes:$seconds';
  return '$hours:$minutes:$seconds';
}
