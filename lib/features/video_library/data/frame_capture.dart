import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fvp/fvp.dart';
import 'package:video_player/video_player.dart';

/// Grabs the currently rendered frame through fvp's snapshot (raw RGBA) and
/// encodes it as PNG. Returns null when the player can't produce a frame.
Future<Uint8List?> captureFramePng(
  VideoPlayerController controller, {
  int targetWidth = 640,
}) async {
  final size = controller.value.size;
  if (size.width <= 0 || size.height <= 0) return null;
  final width = targetWidth;
  final height = (targetWidth * size.height / size.width).round();
  final rgba = await controller.snapshot(width: width, height: height);
  if (rgba == null || rgba.length != width * height * 4) return null;
  final image = await _decodeRgba(rgba, width, height);
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return png?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

Future<ui.Image> _decodeRgba(Uint8List rgba, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
