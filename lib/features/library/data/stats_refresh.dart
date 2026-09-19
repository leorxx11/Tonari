import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'metadata_enrichment.dart';

typedef StatsRefreshProgress = ({int done, int total});

/// Library-wide stats refresh; lives outside the settings page so it keeps
/// running (and reporting progress) after the user navigates away.
class StatsRefreshController extends Notifier<StatsRefreshProgress?> {
  @override
  StatsRefreshProgress? build() => null;

  /// Returns how many works failed, or null when a run is already going.
  Future<int?> run() async {
    if (state != null) return null;
    state = (done: 0, total: 0);
    try {
      return await ref
          .read(metadataEnrichmentProvider)
          .refreshAllStats(
            onProgress: (done, total, _) => state = (done: done, total: total),
          );
    } finally {
      state = null;
    }
  }
}

final statsRefreshProvider =
    NotifierProvider<StatsRefreshController, StatsRefreshProgress?>(
      StatsRefreshController.new,
    );
