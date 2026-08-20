import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class SampleSource {
  const SampleSource({this.localPath, this.url});

  final String? localPath;
  final String? url;
}

class SampleImage extends StatelessWidget {
  const SampleImage({
    super.key,
    required this.sample,
    this.fit = BoxFit.contain,
  });

  final SampleSource sample;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    final local = sample.localPath;
    if (local != null && local.isNotEmpty && File(local).existsSync()) {
      return Image.file(
        File(local),
        fit: fit,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    final url = sample.url;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: fit,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return ColoredBox(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return placeholder;
  }
}

class SampleGallery {
  static Future<void> open(
    BuildContext context, {
    required List<SampleSource> samples,
    required int initialIndex,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, _, _) =>
            _GalleryView(samples: samples, initialIndex: initialIndex),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

class _GalleryView extends StatefulWidget {
  const _GalleryView({required this.samples, required this.initialIndex});

  final List<SampleSource> samples;
  final int initialIndex;

  @override
  State<_GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<_GalleryView> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _page = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.samples.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) =>
                _GalleryPage(sample: widget.samples[i]),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_page + 1} / ${widget.samples.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryPage extends StatefulWidget {
  const _GalleryPage({required this.sample});

  final SampleSource sample;

  @override
  State<_GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<_GalleryPage> {
  final _imageKey = GlobalKey();
  int? _primaryPointer;
  Offset? _pointerDown;
  var _pointerCount = 0;
  var _moved = false;
  var _multiTouch = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: SampleImage(key: _imageKey, sample: widget.sample),
        ),
      ),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerCount += 1;
    if (_pointerCount == 1) {
      _primaryPointer = event.pointer;
      _pointerDown = event.position;
      _moved = false;
      _multiTouch = false;
    } else {
      _multiTouch = true;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _primaryPointer) return;
    if ((event.position - _pointerDown!).distance > kTouchSlop) {
      _moved = true;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final dismiss =
        event.pointer == _primaryPointer &&
        !_moved &&
        !_multiTouch &&
        !_imageRect.contains(event.position);
    _pointerCount -= 1;
    if (_pointerCount == 0) {
      _primaryPointer = null;
      _pointerDown = null;
    }
    if (dismiss) Navigator.of(context).pop();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerCount -= 1;
    if (_pointerCount == 0) {
      _primaryPointer = null;
      _pointerDown = null;
    }
  }

  Rect get _imageRect {
    final box = _imageKey.currentContext!.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}
