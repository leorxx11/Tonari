import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../browse/data/remote_models.dart';

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key, required this.item});

  final PlayableItem item;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late Future<void> _future;
  VideoPlayerController? _controller;
  double _speed = 1;
  double? _dragValue;
  bool _landscape = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _load() async {
    final resolved = await widget.item.resolve();
    final controller = VideoPlayerController.networkUrl(
      resolved.url,
      httpHeaders: resolved.headers ?? const <String, String>{},
    );
    await controller.initialize();
    await controller.play();
    _controller = controller;
    controller.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final controller = _controller;
    controller?.removeListener(_onTick);
    controller?.dispose();
    if (_landscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final controller = _controller!;
    controller.value.isPlaying
        ? await controller.pause()
        : await controller.play();
  }

  Future<void> _setSpeed(double speed) async {
    setState(() => _speed = speed);
    await _controller!.setPlaybackSpeed(speed);
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_down),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.item.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: FutureBuilder<void>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }
          final controller = _controller!;
          final value = controller.value;
          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
                _Controls(
                  controller: controller,
                  speed: _speed,
                  dragValue: _dragValue,
                  onDragChanged: (v) => setState(() => _dragValue = v),
                  onDragEnd: (v) async {
                    await controller.seekTo(Duration(milliseconds: v.round()));
                    if (mounted) setState(() => _dragValue = null);
                  },
                  onTogglePlay: _togglePlay,
                  onSpeed: _setSpeed,
                  onOrientation: _toggleOrientation,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.speed,
    required this.dragValue,
    required this.onDragChanged,
    required this.onDragEnd,
    required this.onTogglePlay,
    required this.onSpeed,
    required this.onOrientation,
  });

  final VideoPlayerController controller;
  final double speed;
  final double? dragValue;
  final ValueChanged<double> onDragChanged;
  final ValueChanged<double> onDragEnd;
  final Future<void> Function() onTogglePlay;
  final Future<void> Function(double speed) onSpeed;
  final Future<void> Function() onOrientation;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
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
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  _fmt(value.duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                  initialValue: speed,
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
                        '${speed}x',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '横屏',
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
  }
}

String _fmt(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours == 0) return '$minutes:$seconds';
  return '$hours:$minutes:$seconds';
}
