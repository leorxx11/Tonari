import 'package:flutter/services.dart';

enum NowPlayingCommand { play, pause, next, previous, seek }

class NowPlayingSnapshot {
  const NowPlayingSnapshot({
    required this.title,
    required this.album,
    required this.artist,
    required this.artworkPath,
    required this.position,
    required this.duration,
    required this.playing,
    required this.speed,
    required this.hasPrevious,
    required this.hasNext,
  });

  final String title;
  final String album;
  final String artist;
  final String? artworkPath;
  final Duration position;
  final Duration duration;
  final bool playing;
  final double speed;
  final bool hasPrevious;
  final bool hasNext;

  Map<String, Object?> toMap() => {
    'title': title,
    'album': album,
    'artist': artist,
    'artworkPath': artworkPath,
    'positionMs': position.inMilliseconds,
    'durationMs': duration.inMilliseconds,
    'playing': playing,
    'speed': speed,
    'hasPrevious': hasPrevious,
    'hasNext': hasNext,
  };
}

class NowPlayingBridge {
  NowPlayingBridge._();

  static const _channel = MethodChannel('tonari/now_playing');

  static Future<void> update(NowPlayingSnapshot snapshot) async {
    await _channel.invokeMethod<void>('update', snapshot.toMap());
  }

  static Future<void> clear() async {
    await _channel.invokeMethod<void>('clear');
  }

  static void setCommandHandler(
    Future<void> Function(NowPlayingCommand command, Object? arguments) handler,
  ) {
    _channel.setMethodCallHandler((call) async {
      final command = NowPlayingCommand.values.byName(call.method);
      await handler(command, call.arguments);
    });
  }

  static void clearCommandHandler() {
    _channel.setMethodCallHandler(null);
  }
}
