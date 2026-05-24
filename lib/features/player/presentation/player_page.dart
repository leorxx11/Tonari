import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/db/database.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.work,
    required this.tracks,
    required this.initialIndex,
  });

  final Work work;
  final List<Track> tracks;
  final int initialIndex;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final AudioPlayer _player;
  late int _index;
  StreamSubscription<ProcessingState>? _processingSub;
  double _speed = 1;

  Track get _track => widget.tracks[_index];

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _index = widget.initialIndex;
    _processingSub = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _playNext();
    });
    _loadAndPlay();
  }

  @override
  void dispose() {
    _processingSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadAndPlay() async {
    await _player.setFilePath(_track.filePath);
    await _player.setSpeed(_speed);
    await _player.play();
    if (mounted) setState(() {});
  }

  Future<void> _playAt(int index) async {
    if (index < 0 || index >= widget.tracks.length) return;
    setState(() => _index = index);
    await _loadAndPlay();
  }

  Future<void> _playNext() async {
    if (_index + 1 < widget.tracks.length) {
      await _playAt(_index + 1);
      return;
    }
    await _player.pause();
    await _player.seek(Duration.zero);
  }

  Future<void> _playPrevious() async {
    if (_index > 0) await _playAt(_index - 1);
  }

  Future<void> _seekBy(Duration delta) async {
    final duration = _player.duration ?? Duration.zero;
    final target = _player.position + delta;
    final clamped = Duration(
      milliseconds: target.inMilliseconds.clamp(0, duration.inMilliseconds),
    );
    await _player.seek(clamped);
  }

  Future<void> _setSpeed(double speed) async {
    setState(() => _speed = speed);
    await _player.setSpeed(speed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.work.title)),
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
                      _track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_index + 1} / ${widget.tracks.length} · ${_track.parentDirName}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _ProgressBar(player: _player),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: '上一首',
                    icon: const Icon(Icons.skip_previous),
                    onPressed: _index == 0 ? null : _playPrevious,
                  ),
                  IconButton(
                    tooltip: '后退 10 秒',
                    icon: const Icon(Icons.replay_10),
                    onPressed: () => _seekBy(const Duration(seconds: -10)),
                  ),
                  StreamBuilder<bool>(
                    stream: _player.playingStream,
                    initialData: _player.playing,
                    builder: (context, snapshot) {
                      final playing = snapshot.data ?? false;
                      return FilledButton(
                        onPressed: () {
                          playing ? _player.pause() : _player.play();
                        },
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
                    onPressed: _index + 1 == widget.tracks.length
                        ? null
                        : _playNext,
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
                      : (value) {
                          player.seek(Duration(milliseconds: value.round()));
                        },
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
