import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/library/data/metadata_enrichment.dart';
import '../../features/library/data/rescan_service.dart';
import '../../features/library/presentation/library_page.dart';
import '../../features/player/presentation/mini_player.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../providers/selected_tab_index.dart';

class RootTabView extends ConsumerStatefulWidget {
  const RootTabView({super.key});

  @override
  ConsumerState<RootTabView> createState() => _RootTabViewState();
}

class _RootTabViewState extends ConsumerState<RootTabView> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(metadataEnrichmentProvider).enrichPending());
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
    final index = ref.watch(selectedTabIndexProvider);
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: index,
              children: const [
                LibraryPage(),
                SettingsPage(),
              ],
            ),
          ),
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(selectedTabIndexProvider.notifier).set(i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: '媒体库',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
