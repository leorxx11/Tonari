import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../browse/data/remote_models.dart';
import '../../browse/data/remote_resolvers.dart';
import '../../player/data/playback_controller.dart';
import '../../video/data/video_controller.dart';

final historyPlaybackProvider = Provider<HistoryPlayback>((ref) {
  return HistoryPlayback(ref);
});

class HistoryPlayback {
  HistoryPlayback(this._ref);

  final Ref _ref;

  /// Rebuilds a playable item for a file-kind history row; null for works and
  /// rows missing source fields.
  PlayableItem? playableFrom(PlayHistoryEntry entry) {
    if (entry.kind == 'work') return null;
    final sourceKind = entry.sourceKind;
    final sourceId = entry.sourceId;
    final path = entry.path;
    final fileName = entry.fileName;
    if (sourceKind == null ||
        sourceId == null ||
        path == null ||
        fileName == null) {
      return null;
    }
    final kind = RemoteSourceKind.values.asNameMap()[sourceKind];
    if (kind == null) return null;
    final isVideo = entry.kind == 'video';
    return PlayableItem(
      id: entry.id,
      sourceKind: kind,
      sourceId: sourceId,
      sourceName: entry.sourceName ?? '',
      path: path,
      fileName: fileName,
      kind: isVideo ? RemoteEntryKind.video : RemoteEntryKind.audio,
      size: entry.size,
      pickcode: entry.pickcode,
      resolverSource: 'play_history',
      title: entry.title,
      resolve: buildRemoteResolver(
        _ref,
        sourceKind: kind,
        sourceId: sourceId,
        path: path,
        pickcode: entry.pickcode,
        isVideo: isVideo,
      ),
    );
  }

  Future<void> play(PlayHistoryEntry entry) async {
    final item = playableFrom(entry);
    if (item == null) return;
    if (item.isVideo) {
      await _ref.read(videoControllerProvider.notifier).open(item);
    } else {
      await _ref
          .read(playbackControllerProvider.notifier)
          .startBrowseQueue(items: [item], initialIndex: 0);
    }
  }
}
