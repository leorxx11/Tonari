import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/presentation/widgets/work_cover.dart';
import '../data/playback_controller.dart';
import 'player_page.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackControllerProvider);
    final track = state.currentTrack;
    final work = state.work;
    if (track == null || work == null) return const SizedBox.shrink();

    final controller = ref.read(playbackControllerProvider.notifier);
    final theme = Theme.of(context);

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
            child: Row(
              children: [
                const SizedBox(width: 12),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: WorkCover(
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
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        work.title,
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
          ),
        ),
      ),
    );
  }
}
