import 'dart:async';

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
  bool _landscapeControlsVisible = false;
  double? _dragValue;
  int? _scrubAnchorMs;
  int _scrubStartPos = 0;
  double _scrubDx = 0;
  Timer? _hideControlsTimer;

  /// Full screen-width horizontal swipe spans this much time, so a swipe is a
  /// fine local nudge instead of the slider's whole-duration jump.
  static const _scrubRangeMs = 90000;

  /// Extra travel past the system drag slop before a swipe counts as scrubbing,
  /// so a tap (or the faintest graze) never seeks.
  static const _scrubThresholdPx = 8.0;

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    if (_landscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  Future<void> _toggleOrientation() async {
    final next = !_landscape;
    setState(() {
      _landscape = next;
      _landscapeControlsVisible = false;
    });
    await SystemChrome.setPreferredOrientations(
      next
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp],
    );
    await SystemChrome.setEnabledSystemUIMode(
      next ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  void _toggleLandscapeControls() {
    if (!_landscape) return;
    final visible = !_landscapeControlsVisible;
    _hideControlsTimer?.cancel();
    setState(() => _landscapeControlsVisible = visible);
    if (visible) _scheduleControlsHide();
  }

  void _scheduleControlsHide() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _landscape) {
        setState(() => _landscapeControlsVisible = false);
      }
    });
  }

  void _onScrubStart(DragStartDetails _) {
    _scrubStartPos =
        ref.read(videoControllerProvider).controller?.value.position.inMilliseconds ?? 0;
    _scrubDx = 0;
  }

  void _onScrubUpdate(DragUpdateDetails details) {
    final durationMs =
        ref.read(videoControllerProvider).controller?.value.duration.inMilliseconds ?? 0;
    if (durationMs == 0) return;
    _scrubDx += details.primaryDelta ?? 0;
    if (_scrubAnchorMs == null && _scrubDx.abs() < _scrubThresholdPx) return;
    if (_scrubAnchorMs == null) _hideControlsTimer?.cancel();
    final width = MediaQuery.sizeOf(context).width;
    final next = (_scrubStartPos + _scrubDx * (_scrubRangeMs / width))
        .clamp(0, durationMs.toDouble())
        .toDouble();
    setState(() {
      _scrubAnchorMs ??= _scrubStartPos;
      _dragValue = next;
    });
  }

  Future<void> _onScrubEnd(DragEndDetails _) async {
    if (_scrubAnchorMs == null) return;
    final v = _dragValue;
    setState(() => _scrubAnchorMs = null);
    if (v != null) {
      await ref
          .read(videoControllerProvider.notifier)
          .seek(Duration(milliseconds: v.round()));
    }
    if (mounted) {
      setState(() => _dragValue = null);
      if (_landscape) _scheduleControlsHide();
    }
  }

  String? get _scrubLabel {
    final v = _dragValue;
    if (_scrubAnchorMs == null || v == null) return null;
    return _fmt(Duration(milliseconds: v.round()));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(videoControllerProvider);
    final controller = ref.read(videoControllerProvider.notifier);
    final vpc = state.controller;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _landscape
          ? null
          : AppBar(
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
      body: state.error != null
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
          : _landscape
          ? _LandscapePlayer(
              controller: vpc,
              title: state.item?.fileName ?? '',
              controlsVisible: _landscapeControlsVisible,
              dragValue: _dragValue,
              scrubLabel: _scrubLabel,
              onScrubStart: _onScrubStart,
              onScrubUpdate: _onScrubUpdate,
              onScrubEnd: _onScrubEnd,
              onTap: _toggleLandscapeControls,
              onBack: () => Navigator.of(context).maybePop(),
              onDragChanged: (v) {
                _hideControlsTimer?.cancel();
                setState(() => _dragValue = v);
              },
              onDragEnd: (v) async {
                await controller.seek(Duration(milliseconds: v.round()));
                if (mounted) {
                  setState(() => _dragValue = null);
                  _scheduleControlsHide();
                }
              },
              onTogglePlay: () =>
                  vpc.value.isPlaying ? controller.pause() : controller.play(),
              onSpeed: (speed) async {
                await controller.setSpeed(speed);
                _scheduleControlsHide();
              },
              onOrientation: _toggleOrientation,
            )
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: _onScrubStart,
                      onHorizontalDragUpdate: _onScrubUpdate,
                      onHorizontalDragEnd: _onScrubEnd,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: AspectRatio(
                              aspectRatio: vpc.value.aspectRatio,
                              child: VideoPlayer(vpc),
                            ),
                          ),
                          if (_scrubLabel != null)
                            IgnorePointer(
                              child: Center(child: _ScrubBadge(label: _scrubLabel!)),
                            ),
                        ],
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

class _LandscapePlayer extends StatelessWidget {
  const _LandscapePlayer({
    required this.controller,
    required this.title,
    required this.controlsVisible,
    required this.dragValue,
    required this.scrubLabel,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
    required this.onTap,
    required this.onBack,
    required this.onDragChanged,
    required this.onDragEnd,
    required this.onTogglePlay,
    required this.onSpeed,
    required this.onOrientation,
  });

  final VideoPlayerController controller;
  final String title;
  final bool controlsVisible;
  final double? dragValue;
  final String? scrubLabel;
  final GestureDragStartCallback onScrubStart;
  final GestureDragUpdateCallback onScrubUpdate;
  final GestureDragEndCallback onScrubEnd;
  final VoidCallback onTap;
  final VoidCallback onBack;
  final ValueChanged<double> onDragChanged;
  final ValueChanged<double> onDragEnd;
  final Future<void> Function() onTogglePlay;
  final Future<void> Function(double speed) onSpeed;
  final Future<void> Function() onOrientation;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onHorizontalDragStart: onScrubStart,
          onHorizontalDragUpdate: onScrubUpdate,
          onHorizontalDragEnd: onScrubEnd,
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        if (scrubLabel != null)
          IgnorePointer(child: Center(child: _ScrubBadge(label: scrubLabel!))),
        if (controlsVisible) ...[
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 28),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '收起',
                        icon: const Icon(CupertinoIcons.chevron_back),
                        color: Colors.white,
                        onPressed: onBack,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _LandscapeControls(
              controller: controller,
              dragValue: dragValue,
              onDragChanged: onDragChanged,
              onDragEnd: onDragEnd,
              onTogglePlay: onTogglePlay,
              onSpeed: onSpeed,
              onOrientation: onOrientation,
            ),
          ),
        ],
      ],
    );
  }
}

class _LandscapeControls extends StatelessWidget {
  const _LandscapeControls({
    required this.controller,
    required this.dragValue,
    required this.onDragChanged,
    required this.onDragEnd,
    required this.onTogglePlay,
    required this.onSpeed,
    required this.onOrientation,
  });

  final VideoPlayerController controller;
  final double? dragValue;
  final ValueChanged<double> onDragChanged;
  final ValueChanged<double> onDragEnd;
  final Future<void> Function() onTogglePlay;
  final Future<void> Function(double speed) onSpeed;
  final Future<void> Function() onOrientation;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final durationMs = value.duration.inMilliseconds;
        final positionMs = value.position.inMilliseconds
            .clamp(0, durationMs)
            .toInt();
        final displayMs = dragValue?.round() ?? positionMs;
        final double sliderValue = durationMs == 0
            ? 0.0
            : displayMs.toDouble().clamp(0, durationMs.toDouble()).toDouble();

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18 + padding.left,
              24,
              18 + padding.right,
              8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 24,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white30,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white24,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                    ),
                    child: Slider(
                      value: sliderValue,
                      max: durationMs == 0 ? 1 : durationMs.toDouble(),
                      onChanged: durationMs == 0 ? null : onDragChanged,
                      onChangeEnd: durationMs == 0 ? null : onDragEnd,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: value.isPlaying ? '暂停' : '播放',
                      iconSize: 24,
                      color: Colors.white,
                      icon: Icon(
                        value.isPlaying
                            ? CupertinoIcons.pause_fill
                            : CupertinoIcons.play_fill,
                      ),
                      onPressed: onTogglePlay,
                    ),
                    Text(
                      '${_fmt(Duration(milliseconds: displayMs))} / '
                      '${_fmt(value.duration)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const Spacer(),
                    PopupMenuButton<double>(
                      tooltip: '倍速',
                      initialValue: value.playbackSpeed,
                      color: Colors.white,
                      onSelected: onSpeed,
                      itemBuilder: (_) => [
                        for (final s in const [1.0, 1.25, 1.5, 2.0])
                          PopupMenuItem(
                            value: s,
                            child: Text(
                              '${s}x',
                              style: const TextStyle(color: Color(0xDE000000)),
                            ),
                          ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          '${value.playbackSpeed}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '竖屏',
                      iconSize: 24,
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
                          PopupMenuItem(
                            value: s,
                            child: Text(
                              '${s}x',
                              style: const TextStyle(color: Color(0xDE000000)),
                            ),
                          ),
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

class _ScrubBadge extends StatelessWidget {
  const _ScrubBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
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
