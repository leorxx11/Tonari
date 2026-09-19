import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/db/database.dart';
import '../../../core/files/local_image_path.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/ios_selectable_text.dart';
import '../../../shared/widgets/library_home_button.dart';
import '../../../shared/widgets/right_edge_swipe_detector.dart';
import '../../player/presentation/mini_player.dart';
import '../../settings/data/file_entry_prefs.dart';
import '../../settings/presentation/translation_settings_page.dart';
import '../../translation/data/llm_provider_repository.dart';
import '../../translation/data/translation_controller.dart';
import '../data/library_task_controller.dart';
import '../data/enrichment_queue.dart';
import '../data/metadata_enrichment.dart';
import '../data/work_actions_provider.dart';
import '../data/work_genres.dart';
import '../data/work_reimport_provider.dart';
import '../data/works_providers.dart';
import 'widgets/chip_filter_actions.dart';
import 'widgets/collection_picker_sheet.dart';
import 'widgets/library_task_status.dart';
import 'widgets/sample_gallery.dart';
import 'work_files_page.dart';
import '../../../core/ui/app_toast.dart';

class WorkDetailPage extends ConsumerWidget {
  const WorkDetailPage({super.key, required this.work});

  final Work work;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _WorkDetailView(work: work);
  }
}

class _WorkDetailView extends ConsumerStatefulWidget {
  const _WorkDetailView({required this.work});

  final Work work;

  @override
  ConsumerState<_WorkDetailView> createState() => _WorkDetailViewState();
}

class _WorkDetailViewState extends ConsumerState<_WorkDetailView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoEnrichIfNeeded());
  }

  // Opening a work that hasn't been enriched yet kicks off its metadata fetch
  // right away (non-force), so the user doesn't have to hit refresh manually.
  // Progress shows on the app-bar WorkTaskStatusButton; the page is reactive,
  // so cover/metadata fill in when it lands.
  Future<void> _autoEnrichIfNeeded() async {
    if (!mounted) return;
    final w =
        ref.read(workByIdProvider(widget.work.productId)).value ?? widget.work;
    final needs =
        w.scrapedAt == null ||
        LocalImagePath.resolve(w.mainImageLocalPath) == null;
    if (!needs) return;
    if (ref.read(workTaskControllerProvider)[w.productId]?.active ?? false) {
      return;
    }
    final taskController = ref.read(workTaskControllerProvider.notifier);
    final enrichment = ref.read(metadataEnrichmentProvider);
    try {
      await taskController.run<void>(
        productId: w.productId,
        kind: LibraryTaskKind.metadata,
        title: '补全资料',
        initialStage: '获取 DLsite 元数据',
        action: (task) async {
          task.update(stage: '获取 DLsite 元数据', message: w.productId);
          await enrichment.enrichOne(
            w.productId,
            onImageProgress: (completed, total, current) {
              task.update(
                stage: '下载图片',
                message: current,
                completed: completed,
                total: total,
              );
            },
          );
          ref.read(enrichmentQueueProvider.notifier).clearFailure(w.productId);
        },
      );
    } catch (_) {
      // silent: leave pending; top-right batch or manual refresh can retry
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveWork = ref.watch(workByIdProvider(widget.work.productId)).value;
    final work = liveWork ?? widget.work;
    return RightEdgeSwipeDetector(
      pageBuilder: (_) => WorkFilesPage(work: work),
      child: Scaffold(
        appBar: AppBar(
          title: Text(work.productId),
          actions: [
            IconButton(
              tooltip: work.isFavorite ? '取消收藏' : '添加收藏',
              icon: Icon(
                work.isFavorite ? Icons.favorite : Icons.favorite_outline,
                color: work.isFavorite ? Colors.pinkAccent[100] : null,
              ),
              onPressed: () async {
                final toggle = ref.read(toggleFavoriteProvider);
                await toggle(work.productId, !work.isFavorite);
              },
            ),
            IconButton(
              tooltip: '在 DLsite 中打开',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _openOnDlsite(work.productId),
            ),
            _TranslationButton(work: work),
            WorkTaskStatusButton(productId: work.productId),
            _MoreMenu(work: work, state: this),
            const LibraryHomeButton(),
          ],
        ),
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _DetailCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderSection(work: work),
                    _StatsSection(work: work),
                    _GenresSection(work: work),
                    _FileInfoLine(work: work),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _ActionRow(work: work)),
            SliverToBoxAdapter(child: _CreditsSection(work: work)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              sliver: DecoratedSliver(
                decoration: _cardDecoration(context),
                sliver: _DescriptionSection(work: work),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
        bottomNavigationBar: const MiniPlayer(),
      ),
    );
  }

  Future<void> refreshStats(String productId) async {
    final taskController = ref.read(workTaskControllerProvider.notifier);
    final enrichment = ref.read(metadataEnrichmentProvider);
    try {
      await taskController.run<void>(
        productId: productId,
        kind: LibraryTaskKind.metadata,
        title: '更新统计数据',
        initialStage: '获取 DLsite 统计',
        action: (task) => enrichment.refreshStats(productId),
      );
      if (!mounted) return;
      showAppToast('统计数据已更新');
    } catch (e) {
      if (!mounted) return;
      showAppToast('更新失败：$e');
    }
  }

  Future<void> refreshMetadata(String productId) async {
    final taskController = ref.read(workTaskControllerProvider.notifier);
    final enrichment = ref.read(metadataEnrichmentProvider);
    try {
      await taskController.run<void>(
        productId: productId,
        kind: LibraryTaskKind.metadata,
        title: '刷新元数据',
        initialStage: '获取 DLsite 元数据',
        action: (task) async {
          task.update(stage: '获取 DLsite 元数据', message: productId);
          await enrichment.refreshMetadata(
            productId,
            onImageProgress: (completed, total, current) {
              task.update(
                stage: '下载图片',
                message: current,
                completed: completed,
                total: total,
              );
            },
          );
          ref.read(enrichmentQueueProvider.notifier).clearFailure(productId);
        },
      );
      if (!mounted) return;
      showAppToast('元数据已刷新');
    } catch (e) {
      if (!mounted) return;
      showAppToast('刷新失败：$e');
    }
  }

  Future<void> refreshImages(String productId) async {
    final before = ref.read(workByIdProvider(productId)).value;
    final taskController = ref.read(workTaskControllerProvider.notifier);
    final enrichment = ref.read(metadataEnrichmentProvider);
    try {
      await taskController.run<void>(
        productId: productId,
        kind: LibraryTaskKind.images,
        title: '刷新图片',
        initialStage: '下载图片',
        action: (task) async {
          task.update(stage: '下载图片', message: productId);
          await enrichment.refreshImages(
            productId,
            onImageProgress: (completed, total, current) {
              task.update(
                stage: '下载图片',
                message: current,
                completed: completed,
                total: total,
              );
            },
          );
        },
      );
      _evictWorkImages(before);
      final after = ref.read(workByIdProvider(productId)).value;
      if (after != null) _evictWorkImages(after);
      if (!mounted) return;
      showAppToast('图片已刷新');
    } catch (e) {
      if (!mounted) return;
      showAppToast('刷新图片失败：$e');
    }
  }

  void _evictWorkImages(Work? work) {
    if (work == null) return;
    final cache = PaintingBinding.instance.imageCache;
    final stored = <String>[
      ?work.mainImageLocalPath,
      ...work.sampleImageLocalPaths,
      ...work.descriptionImageLocalPaths,
    ];
    for (final s in stored) {
      final resolved = LocalImagePath.resolve(s);
      if (resolved == null) continue;
      cache.evict(FileImage(File(resolved)));
    }
  }

  Future<void> removeWork(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('从媒体库移除'),
        content: const Text(
          '将清除该作品在 App 内的快照（音轨、文件、字幕），云盘/本地的原文件不受影响。重新导入可找回。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(removeWorkProvider)(productId);
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> rescanWork(Work work) async {
    final taskController = ref.read(workTaskControllerProvider.notifier);
    final reimport = ref.read(reimportWorkProvider);
    try {
      await taskController.run<void>(
        productId: work.productId,
        kind: LibraryTaskKind.import,
        title: '重新扫描作品',
        initialStage: '扫描文件',
        action: (task) async {
          await reimport(work, task: task);
        },
      );
      if (!mounted) return;
      showAppToast('作品已重新扫描');
    } catch (e) {
      if (!mounted) return;
      showAppToast('重新扫描失败：$e');
    }
  }
}

// ---------- Sections ----------

class _HeaderSection extends ConsumerWidget {
  const _HeaderSection({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final viewRaw = ref.watch(translationViewModeProvider(work.productId));
    final hasZh = (work.titleZh?.isNotEmpty ?? false);
    final showZh = viewRaw ?? hasZh;
    final displayTitle = showZh && hasZh ? work.titleZh! : work.title;
    final releaseDate = work.releaseDate;
    final dateText = releaseDate == null ? null : _formatDate(releaseDate);
    final fileEntryPosition = ref.watch(fileEntryPositionProvider);
    final circle = work.circleName?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          // DLsite covers are 560×420.
          aspectRatio: 4 / 3,
          child: Stack(
            children: [
              Positioned.fill(child: _HeaderCarousel(work: work)),
              // 落款印: the files entry, stamped on the cover corner.
              Positioned(
                left: fileEntryPosition == FileEntryPosition.bottomLeft
                    ? 10
                    : null,
                right: fileEntryPosition == FileEntryPosition.bottomRight
                    ? 10
                    : null,
                bottom: 10,
                child: _FilesTile(work: work),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IosSelectableText(
                displayTitle,
                key: const Key('selectable-work-title'),
                style: theme.textTheme.titleLarge!.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              if (circle.isNotEmpty || dateText != null) ...[
                const SizedBox(height: 6),
                DefaultTextStyle.merge(
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: Wrap(
                    children: [
                      if (circle.isNotEmpty)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => applyChipFilter(context, ref, (
                            kind: WorkChipKind.circle,
                            value: circle,
                          )),
                          child: Text(
                            circle,
                            style: TextStyle(color: theme.colorScheme.primary),
                          ),
                        ),
                      if (circle.isNotEmpty && dateText != null)
                        const Text(' · '),
                      ?dateText == null ? null : Text(dateText),
                    ],
                  ),
                ),
              ],
              if (work.originalProductId != null) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openOnDlsite(work.originalProductId!),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.translate,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '翻译自 ${work.originalProductId}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_hasBadges) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (work.ageRating != null && work.ageRating!.isNotEmpty)
                      _MetaBadge(
                        label: work.ageRating!,
                        color: _isAdult
                            ? theme.colorScheme.errorContainer
                            : null,
                        textColor: _isAdult
                            ? theme.colorScheme.onErrorContainer
                            : null,
                      ),
                    if (work.workTypeName != null &&
                        work.workTypeName!.isNotEmpty)
                      _MetaBadge(label: work.workTypeName!),
                    for (final lang in work.supportedLanguages)
                      _MetaBadge(label: lang),
                    if (work.seriesName != null && work.seriesName!.isNotEmpty)
                      _MetaBadge(label: '系列：${work.seriesName!}'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool get _hasBadges =>
      (work.ageRating != null && work.ageRating!.isNotEmpty) ||
      (work.workTypeName != null && work.workTypeName!.isNotEmpty) ||
      work.supportedLanguages.isNotEmpty ||
      (work.seriesName != null && work.seriesName!.isNotEmpty);

  bool get _isAdult {
    final r = work.ageRating;
    if (r == null) return false;
    return r.contains('R18') || r.contains('18禁') || r.contains('成人');
  }
}

class _StatsSection extends ConsumerWidget {
  const _StatsSection({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final durationMs = ref.watch(
      workDurationsProvider.select((d) => d.value?[work.productId]),
    );
    final rating = work.rating;
    final dlCount = work.dlCount;
    final wishlist = work.wishlistCount;
    final price = work.currentPrice;
    final official = work.officialPrice;
    final discount = work.discountRate ?? 0;
    final rankDay = work.rankDay;
    final rankWeek = work.rankWeek;
    final rankMonth = work.rankMonth;

    final hasRanks = rankDay != null || rankWeek != null || rankMonth != null;
    final hasRatingRow =
        rating != null ||
        dlCount != null ||
        wishlist != null ||
        (durationMs != null && durationMs > 0);
    final hasPriceRow = price != null;
    if (!hasRanks && !hasRatingRow && !hasPriceRow) {
      return const SizedBox.shrink();
    }

    final divider = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text('·', style: TextStyle(color: theme.colorScheme.outline)),
    );

    final rankSpans = <Widget>[
      if (rankDay != null) _RankSpan(label: '24h', rank: rankDay),
      if (rankWeek != null) _RankSpan(label: '7日', rank: rankWeek),
      if (rankMonth != null) _RankSpan(label: '30日', rank: rankMonth),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasRanks)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.emoji_events_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  for (var i = 0; i < rankSpans.length; i++) ...[
                    if (i > 0) divider,
                    rankSpans[i],
                  ],
                ],
              ),
            ),
          if (hasRatingRow)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (rating != null) ...[
                  _StarRow(rating: rating),
                  const SizedBox(width: 8),
                  Text(
                    rating.toStringAsFixed(2),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.price,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (work.ratingCount != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(${work.ratingCount})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
                if (rating != null && dlCount != null) divider,
                if (dlCount != null)
                  Text(
                    '售出 ${_compact(dlCount)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if ((rating != null || dlCount != null) && wishlist != null)
                  divider,
                if (wishlist != null)
                  Text(
                    '收藏 ${_compact(wishlist)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (durationMs != null && durationMs > 0) ...[
                  if (rating != null || dlCount != null || wishlist != null)
                    divider,
                  Icon(
                    Icons.schedule,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  Text(
                    ' ${_formatClock(durationMs)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          if (hasRatingRow && hasPriceRow) const SizedBox(height: 8),
          if (price != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$price JPY',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppTheme.price,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (discount > 0 && official != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '$official JPY',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '-$discount%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _RankSpan extends StatelessWidget {
  const _RankSpan({required this.label, required this.rank});

  final String label;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$label 第',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          '$rank',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          '名',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = rating.clamp(0.0, 5.0);
    final full = clamped.floor();
    final half = (clamped - full) >= 0.25 && (clamped - full) < 0.75;
    final ceil = (clamped - full) >= 0.75 ? 1 : 0;
    final fullCount = full + ceil;
    final emptyCount = 5 - fullCount - (half ? 1 : 0);
    const color = Color(0xFFFFB300);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < fullCount; i++)
          const Icon(Icons.star, size: 18, color: color),
        if (half) const Icon(Icons.star_half, size: 18, color: color),
        for (var i = 0; i < emptyCount; i++)
          Icon(Icons.star_border, size: 18, color: theme.colorScheme.outline),
      ],
    );
  }
}

class _CreditsSection extends StatelessWidget {
  const _CreditsSection({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, List<String>)>[
      ('剧情', work.scenarioWriters),
      ('插画', work.illustrators),
      ('音乐', work.musicians),
    ].where((r) => r.$2.isNotEmpty).toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return _Section(
      title: '演职员',
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 72,
                    child: IosSelectableText(
                      row.$1,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: IosSelectableText(
                      row.$2.join('、'),
                      style: theme.textTheme.bodyMedium!,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Red-seal entry into the work's file browser, stamped on the cover like a
/// collector's mark (落款印).
class _FilesTile extends ConsumerWidget {
  const _FilesTile({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(tracksByWorkProvider(work.productId));
    final filesAsync = ref.watch(workFilesByWorkProvider(work.productId));
    final tracks = tracksAsync.value ?? const <Track>[];
    final files = filesAsync.value ?? const <WorkFile>[];
    final loading = tracksAsync.isLoading || filesAsync.isLoading;
    final count = tracks.length + files.length;
    if (!loading && count == 0) return const SizedBox.shrink();

    return GestureDetector(
      key: const Key('files-entry'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _openWorkFiles(context, work),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Shadow sits behind the seal's visible bounds (the PNG has a
            // transparent margin), peeking out at the edges for depth.
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.40),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            Image.asset('assets/icons/files_seal.png', width: 64, height: 64),
          ],
        ),
      ),
    );
  }
}

void _openWorkFiles(BuildContext context, Work work) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(CupertinoPageRoute<void>(builder: (_) => WorkFilesPage(work: work)));
}

class _GenresSection extends ConsumerWidget {
  const _GenresSection({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final series = work.seriesName;
    final chips = <(String, WorkChipFilter, Color?, Color?)>[
      for (final name in genreNamesOf(work))
        (name, (kind: WorkChipKind.genre, value: name), null, null),
      if (series != null && series.isNotEmpty)
        (
          series,
          (kind: WorkChipKind.series, value: series),
          const Color(0xFFFFA726),
          Colors.white,
        ),
      for (final cv in work.voiceActors)
        (
          cv,
          (kind: WorkChipKind.voiceActor, value: cv),
          AppTheme.secondary,
          Colors.white,
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (label, filter, bg, fg) in chips)
            Material(
              color: bg ?? theme.colorScheme.surfaceContainerHighest,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => applyChipFilter(context, ref, filter),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: fg ?? theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DescriptionSection extends ConsumerStatefulWidget {
  const _DescriptionSection({required this.work});

  final Work work;

  @override
  ConsumerState<_DescriptionSection> createState() =>
      _DescriptionSectionState();
}

class _DescriptionSectionState extends ConsumerState<_DescriptionSection> {
  String? _html;
  List<_DescItem> _items = const [];
  List<String> _imageUrls = const [];

  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    final viewRaw = ref.watch(translationViewModeProvider(work.productId));
    final hasZh = (work.descriptionHtmlZh?.isNotEmpty ?? false);
    final showZh = viewRaw ?? hasZh;
    final html = showZh && hasZh
        ? work.descriptionHtmlZh!
        : work.descriptionHtml;
    if (_html != html) {
      _html = html;
      _items = html == null ? const [] : _parseDescriptionBlocks(html);
      _imageUrls = [
        for (final item in _items)
          if (item is _DescImage) item.url,
      ];
    }
    if (_items.isEmpty) return const SliverToBoxAdapter();

    final theme = Theme.of(context);
    final localPaths = work.descriptionImageLocalPaths;
    final gallerySamples = [
      for (var i = 0; i < _imageUrls.length; i++)
        SampleSource(
          localPath: i < localPaths.length
              ? LocalImagePath.resolve(localPaths[i])
              : null,
          url: _imageUrls[i],
        ),
    ];

    Widget descImage(String url) {
      final idx = _imageUrls.indexOf(url);
      final stored = idx < localPaths.length ? localPaths[idx] : '';
      final resolved = LocalImagePath.resolve(stored);
      if (resolved != null) {
        return Image.file(
          File(resolved),
          fit: BoxFit.fitWidth,
          width: double.infinity,
          errorBuilder: (_, _, _) => _networkDescImage(url, theme),
        );
      }
      return _networkDescImage(url, theme);
    }

    final headingStyle = theme.textTheme.titleSmall!.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.4,
    );
    final paragraphStyle = theme.textTheme.bodyMedium!.copyWith(height: 1.6);

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Text('简介', style: theme.textTheme.titleMedium),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          sliver: SliverList.builder(
            key: ValueKey(html),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              switch (_items[index]) {
                case _DescTextGroup(blocks: final blocks):
                  return IosSelectableText.rich([
                    for (final block in blocks)
                      switch (block) {
                        _DescHeading(text: final text) => SelectableTextRun(
                          text,
                          style: headingStyle,
                          spacingBefore: 14,
                          spacingAfter: 8,
                        ),
                        _DescParagraph(text: final text) => SelectableTextRun(
                          text,
                          style: paragraphStyle,
                          spacingBefore: 4,
                          spacingAfter: 4,
                        ),
                      },
                  ]);
                case _DescImage(url: final url):
                  final imageIndex = _imageUrls.indexOf(url);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: GestureDetector(
                      key: ValueKey('description-image-$imageIndex'),
                      onTap: () => SampleGallery.open(
                        context,
                        samples: gallerySamples,
                        initialIndex: imageIndex,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: descImage(url),
                      ),
                    ),
                  );
              }
            },
          ),
        ),
      ],
    );
  }
}

Widget _networkDescImage(String url, ThemeData theme) {
  return Image.network(
    url,
    fit: BoxFit.fitWidth,
    width: double.infinity,
    loadingBuilder: (ctx, child, progress) {
      if (progress == null) return child;
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    },
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}

sealed class _DescItem {
  const _DescItem();
}

class _DescTextGroup extends _DescItem {
  const _DescTextGroup(this.blocks);
  final List<_DescBlock> blocks;
}

sealed class _DescBlock {
  const _DescBlock();
}

class _DescHeading extends _DescBlock {
  const _DescHeading(this.text);
  final String text;
}

class _DescParagraph extends _DescBlock {
  const _DescParagraph(this.text);
  final String text;
}

class _DescImage extends _DescItem {
  const _DescImage(this.url);
  final String url;
}

class _FileInfoLine extends StatelessWidget {
  const _FileInfoLine({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context) {
    final size = work.fileSize;
    final formats = work.fileFormats;
    final parts = <String>[
      if (size != null && size.isNotEmpty) size,
      if (formats.isNotEmpty) formats.join(' + '),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            parts.join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Layout helpers ----------

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _DetailCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context) {
  final theme = Theme.of(context);
  return BoxDecoration(
    color: theme.cardTheme.color,
    borderRadius: BorderRadius.circular(4),
    boxShadow: const [
      BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
    ],
  );
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Kikoeru's row of coloured action buttons under the info card.
class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget button(
      IconData icon,
      String label,
      Color color,
      VoidCallback onPressed,
    ) => FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        elevation: 2,
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 2),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          button(
            Icons.folder_open,
            '浏览文件',
            AppTheme.primary,
            () => _openWorkFiles(context, work),
          ),
          button(
            Icons.playlist_add,
            '加入分组',
            AppTheme.secondary,
            () => showCollectionPicker(context, work),
          ),
          button(
            work.isFavorite ? Icons.favorite : Icons.favorite_border,
            work.isFavorite ? '已收藏' : '收藏',
            const Color(0xFFEC407A),
            () => ref.read(toggleFavoriteProvider)(
              work.productId,
              !work.isFavorite,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatClock(int ms) {
  final d = Duration(milliseconds: ms);
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${d.inHours.toString().padLeft(2, '0')}:$m:$s';
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.label, this.color, this.textColor});

  final String label;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor ?? theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HeaderCarousel extends StatefulWidget {
  const _HeaderCarousel({required this.work});

  final Work work;

  @override
  State<_HeaderCarousel> createState() => _HeaderCarouselState();
}

class _HeaderCarouselState extends State<_HeaderCarousel> {
  static const _loopStartPage = 10000;

  final _controller = PageController(initialPage: _loopStartPage);
  int _physicalPage = _loopStartPage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<SampleSource> _sources() {
    final work = widget.work;
    final samples = <SampleSource>[];
    final mainLocal = LocalImagePath.resolve(work.mainImageLocalPath);
    final hasMain =
        mainLocal != null ||
        (work.mainImageUrl != null && work.mainImageUrl!.isNotEmpty);
    if (hasMain) {
      samples.add(SampleSource(localPath: mainLocal, url: work.mainImageUrl));
    }
    final localPaths = work.sampleImageLocalPaths;
    for (var i = 0; i < work.sampleImageUrls.length; i++) {
      final url = work.sampleImageUrls[i];
      final local = i < localPaths.length
          ? LocalImagePath.resolve(localPaths[i])
          : null;
      if (local == null && url.isEmpty) continue;
      samples.add(SampleSource(localPath: local, url: url));
    }
    return samples;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sources = _sources();
    const radius = BorderRadius.zero;

    if (sources.isEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Container(
          color: theme.colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(
            Icons.album_outlined,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: radius,
          child: PageView.builder(
            key: const Key('header-carousel'),
            controller: _controller,
            physics: sources.length == 1
                ? const NeverScrollableScrollPhysics()
                : null,
            onPageChanged: (page) => setState(() => _physicalPage = page),
            itemBuilder: (_, page) {
              final i = _logicalPage(page, sources.length);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => SampleGallery.open(
                  context,
                  samples: sources,
                  initialIndex: i,
                ),
                child: SampleImage(sample: sources[i], fit: BoxFit.cover),
              );
            },
          ),
        ),
        if (sources.length > 1)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: _CarouselDots(
              count: sources.length,
              current: _logicalPage(_physicalPage, sources.length),
            ),
          ),
      ],
    );
  }

  int _logicalPage(int page, int count) =>
      ((page - _loopStartPage) % count + count) % count;
}

class _CarouselDots extends StatelessWidget {
  const _CarouselDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            key: ValueKey('header-carousel-dot-$i'),
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: i == current ? 0.95 : 0.5),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

// ---------- Pure helpers ----------

List<_DescItem> _parseDescriptionBlocks(String html) {
  final fragment = html_parser.parseFragment(html);
  final out = <_DescItem>[];
  var textBlocks = <_DescBlock>[];

  void flushText() {
    if (textBlocks.isEmpty) return;
    out.add(_DescTextGroup(textBlocks));
    textBlocks = [];
  }

  final paraBuf = StringBuffer();

  void flushParagraph() {
    final cleaned = paraBuf
        .toString()
        .replaceAll(RegExp(r'\n[ \t]+'), '\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    paraBuf.clear();
    if (cleaned.isNotEmpty) textBlocks.add(_DescParagraph(cleaned));
  }

  void walk(dom.Node node) {
    if (node is dom.Text) {
      paraBuf.write(node.text);
      return;
    }
    if (node is! dom.Element) return;
    switch (node.localName) {
      case 'br':
        paraBuf.write('\n');
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
        flushParagraph();
        final text = node.text.trim();
        if (text.isNotEmpty) textBlocks.add(_DescHeading(text));
      case 'img':
        flushParagraph();
        var src = node.attributes['src'] ?? node.attributes['data-src'] ?? '';
        if (src.isEmpty) return;
        if (src.startsWith('//')) src = 'https:$src';
        flushText();
        out.add(_DescImage(src));
      case 'p':
      case 'div':
        flushParagraph();
        for (final child in node.nodes) {
          walk(child);
        }
        flushParagraph();
      case 'script':
      case 'style':
        return;
      default:
        for (final child in node.nodes) {
          walk(child);
        }
    }
  }

  for (final n in fragment.nodes) {
    walk(n);
  }
  flushParagraph();
  flushText();
  return out;
}

String _compact(int n) {
  if (n < 1000) return n.toString();
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _formatDate(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

Future<void> _openOnDlsite(String productId) async {
  final uri = Uri.parse(
    'https://www.dlsite.com/maniax/work/=/product_id/$productId.html/?locale=zh_CN',
  );
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _TranslationButton extends ConsumerWidget {
  const _TranslationButton({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final defaultProvider = ref.watch(defaultLlmProviderProvider);
    final stateAsync = ref.watch(translationControllerProvider(work.productId));
    final viewRaw = ref.watch(translationViewModeProvider(work.productId));
    final hasZh = (work.titleZh?.isNotEmpty ?? false);
    final showZh = viewRaw ?? hasZh;

    ref.listen<AsyncValue<TranslationState>>(
      translationControllerProvider(work.productId),
      (prev, next) {
        final s = next.value;
        if (s is TranslationDone) {
          ref
              .read(translationViewModeProvider(work.productId).notifier)
              .show(true);
        } else if (s is TranslationFailed) {
          showAppToast(s.message);
        }
      },
    );

    final state = stateAsync.value ?? const TranslationIdle();
    final loading = state is TranslationLoading;
    final failed = state is TranslationFailed;

    if (defaultProvider == null) {
      return IconButton(
        tooltip: '翻译（未配置 Provider）',
        icon: Icon(Icons.translate_outlined, color: theme.disabledColor),
        onPressed: () => _promptConfigure(context),
      );
    }

    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (failed) {
      return IconButton(
        tooltip: '翻译失败 · 点击重试',
        icon: Icon(Icons.error_outline, color: theme.colorScheme.error),
        onPressed: () {
          ref
              .read(translationControllerProvider(work.productId).notifier)
              .clearFailure();
          ref
              .read(translationControllerProvider(work.productId).notifier)
              .translate();
        },
      );
    }

    return IconButton(
      tooltip: showZh ? '显示原文' : '翻译为中文',
      icon: Icon(
        showZh ? Icons.translate : Icons.translate_outlined,
        color: showZh ? Colors.amberAccent : null,
      ),
      onPressed: () {
        if (hasZh) {
          ref
              .read(translationViewModeProvider(work.productId).notifier)
              .toggleFrom(showZh);
        } else {
          ref
              .read(translationControllerProvider(work.productId).notifier)
              .translate();
        }
      },
    );
  }

  void _promptConfigure(BuildContext context) {
    showAppToast('请先在设置中配置翻译 Provider');
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TranslationSettingsPage()),
    );
  }
}

class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.work, required this.state});

  final Work work;
  final _WorkDetailViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultProvider = ref.watch(defaultLlmProviderProvider);
    final hasZh =
        (work.titleZh?.isNotEmpty ?? false) ||
        (work.descriptionHtmlZh?.isNotEmpty ?? false);
    final stateAsync = ref.watch(translationControllerProvider(work.productId));
    final translating = stateAsync.value is TranslationLoading;
    final taskActive = ref.watch(
      workTaskControllerProvider.select(
        (tasks) => tasks[work.productId]?.active ?? false,
      ),
    );
    final canRetranslate = defaultProvider != null && hasZh && !translating;
    final canRefresh = !taskActive && !translating;

    return PopupMenuButton<String>(
      tooltip: '更多',
      onSelected: (v) {
        switch (v) {
          case 'add_to_collection':
            showCollectionPicker(context, work);
          case 'retranslate':
            ref
                .read(translationControllerProvider(work.productId).notifier)
                .translate(force: true);
          case 'refresh_stats':
            state.refreshStats(work.productId);
          case 'refresh_metadata':
            state.refreshMetadata(work.productId);
          case 'refresh_images':
            state.refreshImages(work.productId);
          case 'rescan':
            state.rescanWork(work);
          case 'remove':
            state.removeWork(work.productId);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'add_to_collection',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.bookmark_add_outlined),
            title: Text('加入分组…'),
          ),
        ),
        PopupMenuItem(
          value: 'retranslate',
          enabled: canRetranslate,
          child: const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.translate),
            title: Text('重新翻译'),
          ),
        ),
        PopupMenuItem(
          value: 'refresh_stats',
          enabled: canRefresh,
          child: const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.bar_chart),
            title: Text('更新统计数据'),
            subtitle: Text('售出、评分、价格、排名'),
          ),
        ),
        PopupMenuItem(
          value: 'refresh_metadata',
          enabled: canRefresh,
          child: const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.refresh),
            title: Text('刷新元数据'),
            subtitle: Text('标题、CV、标签、简介等，不重新下载图片'),
          ),
        ),
        PopupMenuItem(
          value: 'refresh_images',
          enabled: canRefresh,
          child: const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.image_outlined),
            title: Text('只刷新图片'),
          ),
        ),
        PopupMenuItem(
          value: 'rescan',
          enabled: canRefresh,
          child: const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.manage_search),
            title: Text('重新扫描此作品'),
            subtitle: Text('重新读取文件和音轨'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'remove',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              '从媒体库移除',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      ],
    );
  }
}
