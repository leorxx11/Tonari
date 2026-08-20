import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/browse/presentation/browse_page.dart';
import '../../features/history/presentation/play_history_page.dart';
import '../../features/library/data/enrichment_queue.dart';
import '../../features/library/data/rescan_service.dart';
import '../../features/library/data/work_navigation.dart';
import '../../features/library/presentation/collections_page.dart';
import '../../features/library/presentation/library_page.dart';
import '../../features/library/presentation/work_detail_page.dart';
import '../../features/player/data/playback_controller.dart';
import '../../features/player/presentation/mini_player.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/video/data/video_controller.dart';
import '../../features/video_library/presentation/video_library_page.dart';
import '../providers/selected_section.dart';
import 'app_drawer.dart';
import 'right_edge_swipe_detector.dart';

class RootTabView extends ConsumerStatefulWidget {
  const RootTabView({super.key});

  @override
  ConsumerState<RootTabView> createState() => _RootTabViewState();
}

class _RootTabViewState extends ConsumerState<RootTabView> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(enrichmentQueueProvider.notifier).runPending());
    unawaited(_runPendingRescan());
  }

  Future<void> _runPendingRescan() async {
    try {
      await ref.read(rescanServiceProvider).runPending();
    } catch (_) {
      // Background best-effort: ignore (test env / db unavailable / etc).
    }
  }

  @override
  Widget build(BuildContext context) {
    final section = ref.watch(selectedSectionProvider);
    final forwardWork = section == AppSection.audioLibrary
        ? ref.watch(libraryForwardWorkProvider)
        : null;
    final hasMiniPlayer =
        ref.watch(videoControllerProvider.select((v) => v.hasVideo)) ||
        ref.watch(
          playbackControllerProvider.select(
            (s) => s.currentTrack != null || s.currentBrowseItem != null,
          ),
        );
    return RightEdgeSwipeDetector(
      pageBuilder: forwardWork == null
          ? null
          : (_) => WorkDetailPage(work: forwardWork),
      onNavigationCommitted: forwardWork == null
          ? null
          : () => ref
                .read(lastOpenedWorkIdProvider.notifier)
                .set(forwardWork.productId),
      child: Scaffold(
        key: rootScaffoldKey,
        drawer: const AppDrawer(),
        body: Column(
          children: [
            Expanded(
              // While the mini player is visible it owns the home-indicator
              // inset; the wrapper stays unconditionally so IndexedStack
              // children never re-parent and lose state. The Builder matters:
              // removePadding must read the MediaQuery INSIDE the scaffold
              // body (keyboard insets already consumed) — cloning from this
              // State's context re-exposed viewInsets and made the inner
              // scaffolds subtract the keyboard a second time.
              child: Builder(
                builder: (context) => MediaQuery.removePadding(
                  context: context,
                  removeBottom: hasMiniPlayer,
                  child: IndexedStack(
                    index: section.index,
                    children: const [
                      LibraryPage(),
                      VideoLibraryPage(),
                      CollectionsPage(),
                      PlayHistoryPage(),
                      BrowsePage(),
                      SettingsPage(),
                    ],
                  ),
                ),
              ),
            ),
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }
}
