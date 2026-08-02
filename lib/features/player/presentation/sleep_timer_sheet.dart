import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/player_prefs.dart';
import '../data/sleep_timer.dart';

/// Shared by the audio player page and the video player page.
/// [forVideo] hides the track-count section (a video has no queue — playback
/// already stops when the file ends) and adjusts the finish-current wording.
Future<void> showSleepTimerSheet(
  BuildContext context, {
  bool forVideo = false,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return Consumer(
        builder: (ctx, ref, _) {
          final sleep = ref.watch(sleepTimerProvider);
          final notifier = ref.read(sleepTimerProvider.notifier);
          final finishTrack = ref.watch(
            playerPrefsProvider.select((p) => p.sleepFinishCurrentTrack),
          );
          final theme = Theme.of(ctx);
          final secondary = CupertinoColors.secondaryLabel.resolveFrom(ctx);
          final accent = CupertinoColors.activeBlue.resolveFrom(ctx);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                    child: Text(
                      _sheetTitle(sleep),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Row(
                      children: [
                        Text('按时间', style: theme.textTheme.labelLarge),
                        const Spacer(),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => ref
                              .read(playerPrefsProvider.notifier)
                              .setSleepFinishCurrentTrack(!finishTrack),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  finishTrack
                                      ? CupertinoIcons.checkmark_circle_fill
                                      : CupertinoIcons.circle,
                                  size: 18,
                                  color: finishTrack ? accent : secondary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  forVideo ? '播完当前视频再停止' : '播完当前曲目再停止',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: finishTrack ? null : secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in SleepTimerController.presetMinutes)
                        ChoiceChip(
                          label: Text('$m 分钟'),
                          selected: false,
                          onSelected: (_) {
                            Navigator.of(ctx).pop();
                            notifier.start(Duration(minutes: m));
                          },
                        ),
                      ChoiceChip(
                        label: const Text('自定义'),
                        selected: false,
                        onSelected: (_) async {
                          Navigator.of(ctx).pop();
                          final duration = await _pickCustomDuration(context);
                          if (duration != null) notifier.start(duration);
                        },
                      ),
                    ],
                  ),
                  if (!forVideo) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                      child: Text('按曲数', style: theme.textTheme.labelLarge),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final n
                            in SleepTimerController.presetTrackCounts)
                          ChoiceChip(
                            label: Text(n == 1 ? '播完本曲' : '播完 $n 曲'),
                            selected: false,
                            onSelected: (_) {
                              Navigator.of(ctx).pop();
                              notifier.stopAfterTracks(n);
                            },
                          ),
                      ],
                    ),
                  ],
                  if (sleep.isActive)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Wrap(
                        children: [
                          ActionChip(
                            label: const Text('取消定时'),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              notifier.cancel();
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

String _sheetTitle(SleepTimerState sleep) {
  if (sleep.remaining != null) {
    return '睡眠定时 · 剩余 ${formatSleepRemaining(sleep.remaining!)}';
  }
  if (sleep.waitingTrackEnd) return '睡眠定时 · 播完后停止';
  final tracks = sleep.remainingTracks;
  if (tracks != null) {
    return tracks == 1 ? '睡眠定时 · 播完本曲停' : '睡眠定时 · 还剩 $tracks 曲停';
  }
  return '睡眠定时';
}

Future<Duration?> _pickCustomDuration(BuildContext context) async {
  var picked = const Duration(minutes: 30);
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('开始'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 216,
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.hm,
                initialTimerDuration: picked,
                onTimerDurationChanged: (d) => picked = d,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
  if (confirmed != true || picked <= Duration.zero) return null;
  return picked;
}

String formatSleepRemaining(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours == 0) return '$minutes:$seconds';
  return '$hours:$minutes:$seconds';
}
