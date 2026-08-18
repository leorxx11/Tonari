import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../browse/data/remote_models.dart';
import '../../player/data/playback_controller.dart';
import 'work_media_source.dart';
import 'works_providers.dart';

/// Starts playback of a work's track queue, resolving the media source and
/// local bookmark the same way no matter which page initiates it.
final workPlaybackProvider = Provider<WorkPlayback>(WorkPlayback.new);

class WorkPlayback {
  WorkPlayback(this._ref);
  final Ref _ref;

  Future<void> start({
    required Work work,
    required List<Track> queue,
    required int initialIndex,
  }) async {
    if (initialIndex < 0 || initialIndex >= queue.length) return;
    final source = await _ref.read(workMediaSourceProvider).sourceForWork(work);
    final bookmark = source.kind == RemoteSourceKind.local
        ? await _ref.read(bookmarkForWorkProvider(work.productId).future)
        : null;
    await _ref
        .read(playbackControllerProvider.notifier)
        .startWork(
          work: work,
          tracks: queue,
          initialIndex: initialIndex,
          bookmarkBase64: bookmark,
          remoteKind: source.kind == RemoteSourceKind.local
              ? null
              : source.kind,
          remoteConfig: source.webdavConfig,
        );
  }
}
