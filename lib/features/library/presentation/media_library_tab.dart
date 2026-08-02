import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../history/presentation/play_history_page.dart';
import '../../video_library/presentation/video_library_page.dart';
import 'library_page.dart';

class MediaLibrarySegment extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) => state = value;
}

final mediaLibrarySegmentProvider = NotifierProvider<MediaLibrarySegment, int>(
  MediaLibrarySegment.new,
);

/// 媒体库 tab：顶部「音声 / 视频」切换 + 播放历史入口，body 用 IndexedStack
/// 保持两个库页各自的滚动与筛选状态。
class MediaLibraryTab extends ConsumerWidget {
  const MediaLibraryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = ref.watch(mediaLibrarySegmentProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Center(
                      child: CupertinoSlidingSegmentedControl<int>(
                        groupValue: segment,
                        children: const {
                          0: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text('音声'),
                          ),
                          1: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text('视频'),
                          ),
                        },
                        onValueChanged: (v) {
                          if (v != null) {
                            ref
                                .read(mediaLibrarySegmentProvider.notifier)
                                .set(v);
                          }
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '播放历史',
                    icon: const Icon(Icons.history),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PlayHistoryPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: segment,
                children: const [LibraryPage(), VideoLibraryPage()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
