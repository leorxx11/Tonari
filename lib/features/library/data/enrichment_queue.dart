import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../../core/files/local_image_path.dart';
import 'metadata_enrichment.dart';

class EnrichmentQueueState {
  const EnrichmentQueueState({
    this.active = false,
    this.current,
    this.done = 0,
    this.total = 0,
    this.failures = const {},
  });

  const EnrichmentQueueState.idle() : this();

  final bool active;
  final String? current;
  final int done;
  final int total;

  /// Works that exhausted their retries this session, keyed by product id with
  /// a short failure reason. Kept across idle so the indicator can surface them
  /// instead of silently dropping the work.
  final Map<String, String> failures;

  double? get progress => total > 0 ? done / total : null;
}

/// Background metadata enrichment. Walks works missing metadata (no scrapedAt
/// or no cached cover) one at a time, retrying each at most twice per session
/// so a permanently-failing fetch can't loop forever. Drives the library's
/// enrichment indicator; [runPending] is also the manual "一键补全" action.
class EnrichmentQueue extends Notifier<EnrichmentQueueState> {
  final Map<String, int> _attempts = {};
  final Map<String, String> _failures = {};
  bool _running = false;

  static const _maxAttempts = 2;

  @override
  EnrichmentQueueState build() => const EnrichmentQueueState.idle();

  bool _needsEnrich(Work w) =>
      w.scrapedAt == null ||
      LocalImagePath.resolve(w.mainImageLocalPath) == null;

  /// Enriches every work still missing metadata, re-querying after each pass so
  /// works imported mid-run are picked up too. [reset] clears the per-work
  /// retry counters and recorded failures first — used by the manual action so
  /// the user can re-try works that already hit the cap.
  Future<void> runPending({bool reset = false}) async {
    if (reset) {
      _attempts.clear();
      _failures.clear();
    }
    if (_running) return;
    _running = true;
    try {
      final db = ref.read(databaseProvider);
      final enrichment = ref.read(metadataEnrichmentProvider);
      while (true) {
        final rows = await (db.select(
          db.works,
        )..where((r) => r.isRemoved.equals(false))).get();
        final pending = rows
            .where(
              (r) =>
                  _needsEnrich(r) &&
                  (_attempts[r.productId] ?? 0) < _maxAttempts,
            )
            .map((r) => r.productId)
            .toList();
        if (pending.isEmpty) break;
        for (var i = 0; i < pending.length; i++) {
          final id = pending[i];
          state = EnrichmentQueueState(
            active: true,
            current: id,
            done: i,
            total: pending.length,
            failures: Map.unmodifiable(_failures),
          );
          final attempt = (_attempts[id] ?? 0) + 1;
          _attempts[id] = attempt;
          try {
            await enrichment.enrichOne(id);
            _failures.remove(id);
          } catch (e) {
            // Record the reason once retries are exhausted so the indicator can
            // surface it; otherwise leave pending for the next pass.
            if (attempt >= _maxAttempts) _failures[id] = _reason(e);
          }
        }
      }
    } catch (_) {
      // best-effort background; ignore db-unavailable (tests) / transient errors
    } finally {
      _running = false;
      state = EnrichmentQueueState(failures: Map.unmodifiable(_failures));
    }
  }

  void clearFailure(String productId) {
    _attempts.remove(productId);
    _failures.remove(productId);
    state = EnrichmentQueueState(
      active: state.active,
      current: state.current,
      done: state.done,
      total: state.total,
      failures: Map.unmodifiable(_failures),
    );
  }

  static String _reason(Object e) {
    final s = e.toString();
    return s.length > 200 ? '${s.substring(0, 200)}…' : s;
  }
}

final enrichmentQueueProvider =
    NotifierProvider<EnrichmentQueue, EnrichmentQueueState>(
      EnrichmentQueue.new,
    );

/// Reactive count of works still missing metadata (no scrapedAt or no cover).
/// Single source of truth for the idle "补全 N 个" affordance.
final pendingEnrichmentCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.works,
  )..where((r) => r.isRemoved.equals(false))).watch().map(
    (rows) => rows
        .where(
          (r) =>
              r.scrapedAt == null ||
              LocalImagePath.resolve(r.mainImageLocalPath) == null,
        )
        .length,
  );
});
