import 'package:flutter/services.dart';

/// Thin wrapper around the `tonari/pip` method channel. Native side owns the
/// actual `AVPictureInPictureController` + display layer; this just sends
/// commands and text updates.
class PipBridge {
  PipBridge._();

  static const _channel = MethodChannel('tonari/pip');

  static Future<void> start() async {
    try {
      await _channel.invokeMethod<void>('start');
    } catch (_) {
      // Best-effort: PiP not supported / no key window yet, etc.
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {
      // ignore
    }
  }

  /// Pushes the current subtitle cue text. Empty string means "show blank".
  /// Native side dedups identical consecutive updates.
  static Future<void> update(String text) async {
    try {
      await _channel.invokeMethod<void>('update', {'text': text});
    } catch (_) {
      // ignore
    }
  }
}
