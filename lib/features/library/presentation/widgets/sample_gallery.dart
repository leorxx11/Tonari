import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';

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
    this.galleryPresentation = false,
  });

  final SampleSource sample;
  final BoxFit fit;
  final bool galleryPresentation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget loadingPlaceholder() {
      if (galleryPresentation) {
        return const CupertinoActivityIndicator(
          key: Key('gallery-loading-indicator'),
          color: Colors.white70,
        );
      }
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
    }

    Widget errorPlaceholder() {
      if (galleryPresentation) {
        return const Icon(
          Icons.broken_image_outlined,
          size: 32,
          color: Colors.white54,
        );
      }
      return ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final local = sample.localPath;
    if (local != null && local.isNotEmpty && File(local).existsSync()) {
      return Image.file(
        File(local),
        fit: fit,
        frameBuilder: galleryPresentation
            ? (_, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) return child;
                return loadingPlaceholder();
              }
            : null,
        errorBuilder: (_, _, _) => errorPlaceholder(),
      );
    }
    final url = sample.url;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: fit,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return loadingPlaceholder();
        },
        errorBuilder: (_, _, _) => errorPlaceholder(),
      );
    }
    return errorPlaceholder();
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
        opaque: true,
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
  bool _pagingBlocked = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        key: const Key('sample-gallery'),
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PhotoViewGestureDetectorScope(
              axis: Axis.horizontal,
              child: PageView.builder(
                controller: _controller,
                physics: _pagingBlocked
                    ? const NeverScrollableScrollPhysics()
                    : null,
                itemCount: widget.samples.length,
                onPageChanged: (i) => setState(() {
                  _page = i;
                  _pagingBlocked = false;
                }),
                itemBuilder: (context, i) => _GalleryPage(
                  sample: widget.samples[i],
                  onPagingBlockedChanged: (blocked) {
                    if (i != _page || blocked == _pagingBlocked) return;
                    setState(() => _pagingBlocked = blocked);
                  },
                ),
              ),
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
                        color: Colors.white.withValues(alpha: 0.18),
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
      ),
    );
  }
}

class _GalleryPage extends StatefulWidget {
  const _GalleryPage({
    required this.sample,
    required this.onPagingBlockedChanged,
  });

  final SampleSource sample;
  final ValueChanged<bool> onPagingBlockedChanged;

  @override
  State<_GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<_GalleryPage>
    with SingleTickerProviderStateMixin {
  final _imageKey = GlobalKey();
  final _controller = PhotoViewController();
  late final StreamSubscription<PhotoViewControllerValue> _subscription;
  late final ImageStream _imageStream;
  late final ImageStreamListener _imageListener;
  late final AnimationController _doubleTapController;
  late Tween<double> _scaleTween;
  late Tween<Offset> _positionTween;
  ImageInfo? _imageInfo;
  bool _loadFailed = false;
  Size _viewport = Size.zero;
  double _fitScale = 1;
  Offset _tapPosition = Offset.zero;
  int _pointerCount = 0;
  bool _multiTouch = false;
  bool _startedZoomed = false;

  @override
  void initState() {
    super.initState();
    _subscription = _controller.outputStateStream.listen(
      (_) => _updatePaging(),
    );
    _doubleTapController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          final progress = Curves.easeOutCubic.transform(
            _doubleTapController.value,
          );
          _controller.updateMultiple(
            scale: _scaleTween.transform(progress),
            position: _positionTween.transform(progress),
          );
        });
    final local = widget.sample.localPath;
    final ImageProvider provider = local != null
        ? FileImage(File(local))
        : NetworkImage(widget.sample.url!);
    _imageListener = ImageStreamListener(
      (info, _) {
        _imageInfo?.dispose();
        setState(() => _imageInfo = info);
      },
      onError: (Object error, StackTrace? stack) {
        setState(() => _loadFailed = true);
      },
    );
    _imageStream = provider.resolve(const ImageConfiguration())
      ..addListener(_imageListener);
  }

  @override
  void dispose() {
    _imageStream.removeListener(_imageListener);
    _imageInfo?.dispose();
    _subscription.cancel();
    _doubleTapController.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool get _zoomed =>
      _controller.scale != null && _controller.scale! > _fitScale * 1.001;

  void _updatePaging() {
    // A pinch owns the entire touch sequence, even after returning to fit size.
    widget.onPagingBlockedChanged(_zoomed || _multiTouch || _startedZoomed);
  }

  void _toggleZoom() {
    final scale = _controller.scale!;
    final target = _zoomed ? _fitScale : _fitScale * 2.5;
    final focalPoint = _tapPosition - _viewport.center(Offset.zero);
    _scaleTween = Tween(begin: scale, end: target);
    _positionTween = Tween(
      begin: _controller.position,
      end: _zoomed
          ? Offset.zero
          : focalPoint - (focalPoint - _controller.position) * (target / scale),
    );
    _doubleTapController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final info = _imageInfo;
    if (_loadFailed || info == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: _loadFailed
              ? const Icon(
                  Icons.broken_image_outlined,
                  size: 32,
                  color: Colors.white54,
                )
              : const CupertinoActivityIndicator(
                  key: Key('gallery-loading-indicator'),
                  color: Colors.white70,
                ),
        ),
      );
    }
    final imageSize = Size(
      info.image.width.toDouble(),
      info.image.height.toDouble(),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        _fitScale =
            applyBoxFit(
              BoxFit.contain,
              imageSize,
              _viewport,
            ).destination.width /
            imageSize.width;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            _doubleTapController.stop();
            _tapPosition = event.localPosition;
            _pointerCount++;
            if (_pointerCount == 1) _startedZoomed = _zoomed;
            if (_pointerCount > 1) _multiTouch = true;
            _updatePaging();
          },
          onPointerUp: (_) => _finishPointer(),
          onPointerCancel: (_) => _finishPointer(),
          child: PhotoView.customChild(
            controller: _controller,
            childSize: imageSize,
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.contained * 4,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            scaleStateCycle: (state) {
              _toggleZoom();
              return state;
            },
            onTapUp: (_, details, _) {
              if (!_imageRect.contains(details.globalPosition)) {
                Navigator.of(context).pop();
              }
            },
            child: RawImage(
              key: _imageKey,
              image: info.image,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  void _finishPointer() {
    _pointerCount--;
    if (_pointerCount == 0) {
      _multiTouch = false;
      _startedZoomed = false;
    }
    _updatePaging();
  }

  Rect get _imageRect {
    final box = _imageKey.currentContext!.findRenderObject()! as RenderBox;
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
  }
}
