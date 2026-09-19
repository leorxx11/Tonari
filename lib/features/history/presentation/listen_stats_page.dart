import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/library_home_button.dart';
import '../../library/data/works_providers.dart';
import '../../library/presentation/open_work_detail.dart';
import '../../library/presentation/widgets/work_cover.dart';
import '../../stats/presentation/stat_chip.dart';
import '../data/listen_stats.dart';

String formatListenTime(int ms) {
  final minutes = ms ~/ 60000;
  if (minutes < 60) return '$minutes 分钟';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours 小时' : '$hours 小时 $rest 分';
}

class ListenStatsPage extends ConsumerWidget {
  const ListenStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(listenStatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('收听统计'),
        actions: const [LibraryHomeButton()],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (stats) => stats.isEmpty
            ? Center(
                child: Text(
                  '播放音声后，收听时长会记录在这里',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
                children: [
                  _Section(child: _Totals(stats: stats)),
                  _Section(
                    title: '最近 $dailyWindow 天',
                    child: _DailyBars(daily: stats.daily),
                  ),
                  if (stats.topWorks.isNotEmpty)
                    _Section(
                      title: '最常听的作品',
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final (i, r) in stats.topWorks.indexed)
                            ListTile(
                              leading: SizedBox.square(
                                dimension: 48,
                                child: WorkCover(
                                  work: r.work,
                                  borderRadius: BorderRadius.circular(4),
                                  iconSize: 20,
                                ),
                              ),
                              title: Text(
                                '${i + 1}. ${r.work.titleZh?.isNotEmpty == true ? r.work.titleZh : r.work.title}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(formatListenTime(r.ms)),
                              onTap: () => openWorkDetail(context, ref, r.work),
                            ),
                        ],
                      ),
                    ),
                  if (stats.topVoiceActors.isNotEmpty)
                    _Section(
                      title: '最常听的声优',
                      child: _NameChips(
                        kind: WorkChipKind.voiceActor,
                        entries: stats.topVoiceActors,
                      ),
                    ),
                  if (stats.topCircles.isNotEmpty)
                    _Section(
                      title: '最常听的社团',
                      child: _NameChips(
                        kind: WorkChipKind.circle,
                        entries: stats.topCircles,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    this.title,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final String? title;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Text(
                title!,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.stats});

  final ListenStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget cell(String label, int ms) => Expanded(
      child: Column(
        children: [
          Text(
            formatListenTime(ms),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    return Row(
      children: [
        cell('累计', stats.totalMs),
        cell('本周', stats.weekMs),
        cell('本月', stats.monthMs),
      ],
    );
  }
}

class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.daily});

  final List<({DateTime day, int ms})> daily;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxMs = daily.fold<int>(0, (m, d) => d.ms > m ? d.ms : m);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final first = daily.first.day;
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: Row(
            // Full-height columns so even a short bar is easy to tap.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final d in daily)
                Expanded(
                  child: Tooltip(
                    message:
                        '${d.day.month}月${d.day.day}日 · ${formatListenTime(d.ms)}',
                    triggerMode: TooltipTriggerMode.tap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: FractionallySizedBox(
                        alignment: Alignment.bottomCenter,
                        widthFactor: 1,
                        heightFactor: maxMs == 0
                            ? 0
                            : (d.ms / maxMs).clamp(0.02, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: d.ms == 0
                                ? theme.colorScheme.surfaceContainerHighest
                                : theme.colorScheme.primary,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('${first.month}月${first.day}日', style: labelStyle),
            const Spacer(),
            Text('今天', style: labelStyle),
          ],
        ),
      ],
    );
  }
}

class _NameChips extends StatelessWidget {
  const _NameChips({required this.kind, required this.entries});

  final WorkChipKind kind;
  final List<RankedName> entries;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in entries)
          StatChip(
            filter: (kind: kind, value: e.name),
            value: formatListenTime(e.ms),
          ),
      ],
    );
  }
}
