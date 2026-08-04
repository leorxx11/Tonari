import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/browse/presentation/browse_page.dart';
import '../../features/history/presentation/play_history_page.dart';
import '../../features/library/data/enrichment_queue.dart';
import '../../features/library/data/rescan_service.dart';
import '../../features/library/presentation/collections_page.dart';
import '../../features/library/presentation/library_page.dart';
import '../../features/player/data/playback_controller.dart';
import '../../features/player/presentation/mini_player.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/video/data/video_controller.dart';
import '../../features/video_library/presentation/video_library_page.dart';
import '../providers/selected_section.dart';
import 'app_drawer.dart';

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
    final hasMiniPlayer =
        ref.watch(videoControllerProvider.select((v) => v.hasVideo)) ||
        ref.watch(
          playbackControllerProvider.select(
            (s) => s.currentTrack != null || s.currentBrowseItem != null,
          ),
        );
    return Scaffold(
      key: rootScaffoldKey,
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Expanded(
            // While the mini player is visible it owns the home-indicator
            // inset; the wrapper stays unconditionally so IndexedStack
            // children never re-parent and lose state.
            child: MediaQuery.removePadding(
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
          const MiniPlayer(),
        ],
      ),
    );
  }
}
