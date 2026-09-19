import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/library_home_button.dart';
import '../../library/data/works_providers.dart';
import '../../library/presentation/widgets/chip_filter_actions.dart';
import '../data/stats_providers.dart';

const _chipColor = Color(0xFF3B887C);

const _tabs = [
  (WorkChipKind.circle, '社团'),
  (WorkChipKind.voiceActor, '声优'),
  (WorkChipKind.genre, '标签'),
];

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  bool _searching = false;
  bool _byName = false;
  String _query = '';

  List<StatEntry> _visible(LibraryStats stats, WorkChipKind kind) {
    final entries = [
      for (final e in stats.of(kind))
        if (_query.isEmpty || e.name.toLowerCase().contains(_query)) e,
    ];
    if (_byName) entries.sort((a, b) => a.name.compareTo(b.name));
    return entries;
  }

  void _closeSearch() => setState(() {
    _searching = false;
    _query = '';
  });

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(libraryStatsProvider);
    final stats = statsAsync.value;
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          leading: const DrawerMenuButton(),
          title: _searching
              ? TextField(
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                    hintText: '搜索社团、声优、标签…',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                )
              : const Text('分类'),
          actions: [
            if (_searching)
              IconButton(
                tooltip: '关闭搜索',
                icon: const Icon(Icons.close),
                onPressed: _closeSearch,
              )
            else
              IconButton(
                tooltip: '搜索',
                icon: const Icon(Icons.search),
                onPressed: () => setState(() => _searching = true),
              ),
            IconButton(
              tooltip: _byName ? '按作品数排序' : '按名称排序',
              icon: Icon(_byName ? Icons.sort_by_alpha : Icons.sort),
              onPressed: () => setState(() => _byName = !_byName),
            ),
            const LibraryHomeButton(),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              for (final (kind, label) in _tabs)
                Tab(
                  text: switch (stats == null
                      ? null
                      : _visible(stats, kind).length) {
                    null || 0 => label,
                    final n => '$label $n',
                  },
                ),
            ],
          ),
        ),
        body: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败：$e')),
          data: (stats) => TabBarView(
            children: [
              for (final (kind, _) in _tabs)
                _StatsTab(
                  kind: kind,
                  entries: _visible(stats, kind),
                  emptyText: _query.isEmpty ? '没有数据，作品抓取元数据后会出现在这里' : '没有匹配的结果',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsTab extends ConsumerWidget {
  const _StatsTab({
    required this.kind,
    required this.entries,
    required this.emptyText,
  });

  final WorkChipKind kind;
  final List<StatEntry> entries;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (entries.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in entries)
                Material(
                  color: _chipColor,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () {
                      ref.read(workFilterProvider.notifier).clearSearch();
                      applyChipFilter(context, ref, (
                        kind: kind,
                        value: e.name,
                      ));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      child: Text.rich(
                        TextSpan(
                          text: e.name,
                          children: [
                            TextSpan(
                              text: '  ${e.count}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
