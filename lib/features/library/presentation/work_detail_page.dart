import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/db/database.dart';
import '../../../core/files/local_image_path.dart';
import '../../player/presentation/mini_player.dart';
import '../data/metadata_enrichment.dart';
import '../data/work_actions_provider.dart';
import '../data/works_providers.dart';
import 'widgets/sample_gallery.dart';
import 'work_files_page.dart';

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
  bool _refreshing = false;

  @override
  Widget build(BuildContext context) {
    final liveWork = ref.watch(workByIdProvider(widget.work.productId)).value;
    final work = liveWork ?? widget.work;
    final tracksAsync = ref.watch(tracksByWorkProvider(work.productId));
    final filesAsync = ref.watch(workFilesByWorkProvider(work.productId));
    return Scaffold(
      appBar: AppBar(
        title: Text(work.productId),
        actions: [
          IconButton(
            tooltip: '在 DLsite 中打开',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openOnDlsite(work.productId),
          ),
          IconButton(
            tooltip: work.isFavorite ? '取消收藏' : '添加收藏',
            icon: Icon(
              work.isFavorite ? Icons.favorite : Icons.favorite_outline,
              color: work.isFavorite
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: () async {
              final toggle = ref.read(toggleFavoriteProvider);
              await toggle(work.productId, !work.isFavorite);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _onPullToRefresh(work.productId),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _HeaderSection(work: work)),
            SliverToBoxAdapter(child: _StatsSection(work: work)),
            SliverToBoxAdapter(child: _CreditsSection(work: work)),
            SliverToBoxAdapter(child: _GenresSection(work: work)),
            SliverToBoxAdapter(child: _FileInfoLine(work: work)),
            SliverToBoxAdapter(
              child: _FilesEntry(
                work: work,
                tracksAsync: tracksAsync,
                filesAsync: filesAsync,
              ),
            ),
            SliverToBoxAdapter(child: _DescriptionSection(work: work)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  Future<void> _onPullToRefresh(String productId) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await ref
          .read(metadataEnrichmentProvider)
          .enrichOne(productId, force: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刷新失败：$e')),
      );
    } finally {
      _refreshing = false;
    }
  }
}

// ---------- Sections ----------

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final releaseDate = work.releaseDate;
    final dateText = releaseDate == null ? null : _formatDate(releaseDate);
    final subline = <String>[
      if (work.circleName != null && work.circleName!.isNotEmpty)
        work.circleName!,
      ?dateText,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: _HeaderCarousel(work: work),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            work.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          if (subline.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subline,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
                    color: _isAdult ? theme.colorScheme.errorContainer : null,
                    textColor: _isAdult
                        ? theme.colorScheme.onErrorContainer
                        : null,
                  ),
                if (work.workTypeName != null && work.workTypeName!.isNotEmpty)
                  _MetaBadge(label: work.workTypeName!),
                for (final lang in work.supportedLanguages) _MetaBadge(label: lang),
                if (work.seriesName != null && work.seriesName!.isNotEmpty)
                  _MetaBadge(label: '系列：${work.seriesName!}'),
              ],
            ),
          ],
        ],
      ),
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

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
    final hasRatingRow = rating != null || dlCount != null || wishlist != null;
    final hasPriceRow = price != null;
    if (!hasRanks && !hasRatingRow && !hasPriceRow) return const SizedBox.shrink();

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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
              ],
            ),
          if (hasRatingRow && hasPriceRow) const SizedBox(height: 8),
          if (price != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '¥${_compact(price)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (discount > 0 && official != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '¥${_compact(official)}',
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
      ('声优', work.voiceActors),
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
                    child: Text(
                      row.$1,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2.join('、'),
                      style: theme.textTheme.bodyMedium,
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

class _GenresSection extends StatelessWidget {
  const _GenresSection({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context) {
    final raw = jsonDecode(work.genresJson);
    if (raw is! List || raw.isEmpty) return const SizedBox.shrink();
    final names = <String>[
      for (final item in raw)
        if (item is Map && item['name'] is String) item['name'] as String,
    ];
    if (names.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return _Section(
      title: '标签',
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final name in names)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                name,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DescriptionSection extends StatefulWidget {
  const _DescriptionSection({required this.work});

  final Work work;

  @override
  State<_DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<_DescriptionSection> {
  static const _collapsedHeight = 280.0;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final html = widget.work.descriptionHtml;
    if (html == null || html.isEmpty) return const SizedBox.shrink();
    final blocks = _parseDescriptionBlocks(html);
    if (blocks.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final imgUrls = [
      for (final b in blocks)
        if (b is _DescImage) b.url,
    ];
    final localPaths = widget.work.descriptionImageLocalPaths;

    Widget descImage(String url) {
      final idx = imgUrls.indexOf(url);
      final stored =
          (idx >= 0 && idx < localPaths.length) ? localPaths[idx] : '';
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

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks)
          switch (block) {
            _DescHeading(text: final t) => Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
              child: Text(
                t,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
            _DescParagraph(text: final t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                t,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ),
            _DescImage(url: final u) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: GestureDetector(
                onTap: () => SampleGallery.open(
                  context,
                  samples: [
                    for (final url in imgUrls) SampleSource(url: url),
                  ],
                  initialIndex: imgUrls.indexOf(u),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: descImage(u),
                ),
              ),
            ),
          },
      ],
    );

    final paraLen = blocks
        .whereType<_DescParagraph>()
        .fold<int>(0, (sum, b) => sum + b.text.length);
    final isLong = blocks.length > 4 ||
        blocks.any((b) => b is _DescImage) ||
        paraLen > 200;

    if (!isLong) {
      return _Section(title: '简介', child: content);
    }

    return _Section(
      title: '简介',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_expanded)
            content
          else
            Stack(
              children: [
                SizedBox(
                  height: _collapsedHeight,
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: content,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 80,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            theme.colorScheme.surface.withValues(alpha: 0),
                            theme.colorScheme.surface,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(_expanded ? '收起' : '展开全部'),
            ),
          ),
        ],
      ),
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

class _DescImage extends _DescBlock {
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
  const _Section({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: child,
          ),
        ],
      ),
    );
  }
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

// ---------- Files entry: opens a drill-in WorkFilesPage ----------

class _FilesEntry extends StatelessWidget {
  const _FilesEntry({
    required this.work,
    required this.tracksAsync,
    required this.filesAsync,
  });

  final Work work;
  final AsyncValue<List<Track>> tracksAsync;
  final AsyncValue<List<WorkFile>> filesAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tracks = tracksAsync.value ?? const <Track>[];
    final files = filesAsync.value ?? const <WorkFile>[];
    final loading = tracksAsync.isLoading || filesAsync.isLoading;
    final empty = !loading && tracks.isEmpty && files.isEmpty;

    final summary = _summary(tracks, files);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: empty
              ? null
              : () => Navigator.of(context, rootNavigator: true).push(
                    CupertinoSheetRoute<void>(
                      scrollableBuilder: (_, _) => WorkFilesPage(work: work),
                      showDragHandle: true,
                    ),
                  ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.folder, color: Color(0xFFFFC857), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '文件',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loading ? '加载中…' : (empty ? '没有可显示的文件' : summary),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!empty)
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _summary(List<Track> tracks, List<WorkFile> files) {
    final totalItems = tracks.length + files.length;
    final totalDuration = tracks.fold<int>(0, (a, t) => a + t.durationMs);
    final parts = <String>[
      '$totalItems 项',
      if (totalDuration > 0) _formatTotalDuration(totalDuration),
    ];
    return parts.join(', ');
  }
}

String _formatTotalDuration(int ms) {
  if (ms <= 0) return '0s';
  final totalMinutes = ms ~/ 60000;
  if (totalMinutes >= 60) {
    final halfHours = (totalMinutes / 30).round();
    final hours = halfHours / 2;
    final text = hours == hours.truncate()
        ? hours.toStringAsFixed(0)
        : hours.toStringAsFixed(1);
    return '${text}hr';
  }
  if (totalMinutes > 0) return '${totalMinutes}min';
  return '${(ms / 1000).round()}s';
}

class _HeaderCarousel extends StatefulWidget {
  const _HeaderCarousel({required this.work});

  final Work work;

  @override
  State<_HeaderCarousel> createState() => _HeaderCarouselState();
}

class _HeaderCarouselState extends State<_HeaderCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<SampleSource> _sources() {
    final work = widget.work;
    final samples = <SampleSource>[];
    final mainLocal = LocalImagePath.resolve(work.mainImageLocalPath);
    final hasMain = mainLocal != null ||
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
    final radius = BorderRadius.circular(12);

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
            controller: _controller,
            itemCount: sources.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
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
            child: _CarouselDots(count: sources.length, current: _page),
          ),
      ],
    );
  }
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

List<_DescBlock> _parseDescriptionBlocks(String html) {
  final fragment = html_parser.parseFragment(html);
  final out = <_DescBlock>[];
  final paraBuf = StringBuffer();

  void flushParagraph() {
    final cleaned = paraBuf
        .toString()
        .replaceAll(RegExp(r'\n[ \t]+'), '\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    paraBuf.clear();
    if (cleaned.isNotEmpty) out.add(_DescParagraph(cleaned));
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
        if (text.isNotEmpty) out.add(_DescHeading(text));
      case 'img':
        flushParagraph();
        var src = node.attributes['src'] ?? node.attributes['data-src'] ?? '';
        if (src.isEmpty) return;
        if (src.startsWith('//')) src = 'https:$src';
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
