import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../browse/data/remote_models.dart';
import '../../library/presentation/widgets/work_cover.dart';
import '../../video/data/video_controller.dart';
import '../../video/presentation/video_player_page.dart';
import '../data/playback_controller.dart';
import 'player_page.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final video = ref.watch(videoControllerProvider);
    if (video.hasVideo) {
      return _VideoMiniBar(
        item: video.item!,
        controller: video.controller,
        notifier: ref.read(videoControllerProvider.notifier),
      );
    }

    final state = ref.watch(playbackControllerProvider);
    final track = state.currentTrack;
    final browseItem = state.currentBrowseItem;
    final work = state.work;
    if (track == null && browseItem == null) return const SizedBox.shrink();

    final controller = ref.read(playbackControllerProvider.notifier);
    final theme = Theme.of(context);
    final title = track?.title ?? browseItem!.title;
    final subtitle = work?.title ?? browseItem!.sourceName;

    return Hero(
      tag: 'tonari-mini-player',
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        child: InkWell(
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            CupertinoSheetRoute<void>(
              scrollableBuilder: (_, _) => const PlayerPage(),
              showDragHandle: true,
            ),
          ),
          child: SizedBox(
            height: 72,
            child: Stack(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: work == null
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.cloud_queue_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          : WorkCover(
                              work: work,
                              borderRadius: BorderRadius.circular(8),
                              iconSize: 24,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StreamBuilder<bool>(
                      stream: controller.player.playingStream,
                      initialData: controller.player.playing,
                      builder: (context, snapshot) {
                        final playing = snapshot.data ?? false;
                        return IconButton(
                          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                          onPressed: () =>
                              playing ? controller.pause() : controller.play(),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      onPressed: state.hasNext ? controller.next : null,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(child: _MiniPlayerProgress()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoMiniBar extends StatelessWidget {
  const _VideoMiniBar({
    required this.item,
    required this.controller,
    required this.notifier,
  });

  final PlayableItem item;
  final VideoPlayerController? controller;
  final VideoController notifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vpc = controller;
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(builder: (_) => const VideoPlayerPage()),
        ),
        child: SizedBox(
          height: 72,
          child: Stack(
            children: [
              Row(
                children: [
                  const SizedBox(width: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(
                        CupertinoIcons.videocam_fill,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          item.sourceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (vpc == null)
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: vpc,
                      builder: (context, value, _) => IconButton(
                        icon: Icon(
                          value.isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                        onPressed: () => value.isPlaying
                            ? notifier.pause()
                            : notifier.play(),
                      ),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
              if (vpc != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: vpc,
                      builder: (context, value, _) {
                        final durationMs = value.duration.inMilliseconds;
                        final positionMs = value.position.inMilliseconds;
                        final progress = durationMs <= 0
                            ? 0.0
                            : (positionMs / durationMs).clamp(0.0, 1.0);
                        return LinearProgressIndicator(
                          value: progress,
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                          color: theme.colorScheme.primary,
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniPlayerProgress extends ConsumerWidget {
  const _MiniPlayerProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(playbackControllerProvider.notifier);
    final track = ref.watch(
      playbackControllerProvider.select((s) => s.currentTrack),
    );
    final theme = Theme.of(context);
    final fallbackMs = track?.durationMs ?? 0;

    return StreamBuilder<Duration>(
      stream: controller.player.positionStream,
      builder: (context, snapshot) {
        final positionMs = snapshot.data?.inMilliseconds ?? 0;
        final durationMs =
            controller.player.duration?.inMilliseconds ?? fallbackMs;
        final progress = durationMs <= 0
            ? 0.0
            : (positionMs / durationMs).clamp(0.0, 1.0);
        return LinearProgressIndicator(
          value: progress,
          minHeight: 2,
          backgroundColor: Colors.transparent,
          color: theme.colorScheme.primary,
        );
      },
    );
  }
}
