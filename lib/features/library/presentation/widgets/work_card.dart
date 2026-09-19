import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/works_providers.dart';
import 'chip_filter_actions.dart';
import 'work_cover.dart';

class WorkCard extends StatelessWidget {
  const WorkCard({
    super.key,
    required this.work,
    this.isRemote = false,
    this.large = false,
    this.durationMs,
    this.onTap,
    this.onRemove,
    this.onToggleFavorite,
    this.onAddToCollection,
    this.onRemoveFromCollection,
  });

  final Work work;
  final bool isRemote;

  /// Full-width card with the complete info block, Kikoeru's phone default.
  final bool large;
  final int? durationMs;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onAddToCollection;
  final VoidCallback? onRemoveFromCollection;

  @override
  Widget build(BuildContext context) {
    final hasMenu =
        onRemove != null ||
        onToggleFavorite != null ||
        onAddToCollection != null ||
        onRemoveFromCollection != null;
    final displayTitle = (work.titleZh != null && work.titleZh!.isNotEmpty)
        ? work.titleZh!
        : work.title;
    return Semantics(
      button: onTap != null,
      label: displayTitle,
      child: Card(
        clipBehavior: Clip.hardEdge,
        margin: EdgeInsets.zero,
        child: GestureDetector(
          onLongPressStart: !hasMenu
              ? null
              : (details) => _showWorkMenu(
                  context,
                  details.globalPosition,
                  work: work,
                  onRemove: onRemove,
                  onToggleFavorite: onToggleFavorite,
                  onAddToCollection: onAddToCollection,
                  onRemoveFromCollection: onRemoveFromCollection,
                ),
          child: InkWell(
            onTap: onTap,
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: large ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  AspectRatio(
                    // DLsite covers are 560×420.
                    aspectRatio: large ? 4 / 3 : 1,
                    child: _CoverWithOverlays(
                      work: work,
                      isRemote: isRemote,
                      onToggleFavorite: onToggleFavorite,
                    ),
                  ),
                  if (large)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: _WorkInfo(
                        work: work,
                        title: displayTitle,
                        durationMs: durationMs,
                        large: true,
                      ),
                    )
                  else
                    Expanded(
                      child: ClipRect(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                          child: _WorkInfo(
                            work: work,
                            title: displayTitle,
                            durationMs: durationMs,
                            large: false,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showWorkMenu(
  BuildContext context,
  Offset position, {
  required Work work,
  VoidCallback? onRemove,
  VoidCallback? onToggleFavorite,
  VoidCallback? onAddToCollection,
  VoidCallback? onRemoveFromCollection,
}) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final local = overlay.globalToLocal(position);
  showMenu<_WorkCardAction>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromCenter(center: local, width: 1, height: 1),
      Offset.zero & overlay.size,
    ),
    items: [
      if (onToggleFavorite != null)
        PopupMenuItem(
          value: _WorkCardAction.toggleFavorite,
          child: Row(
            children: [
              Icon(work.isFavorite ? Icons.favorite_outline : Icons.favorite),
              const SizedBox(width: 12),
              Text(work.isFavorite ? '取消收藏' : '添加收藏'),
            ],
          ),
        ),
      if (onAddToCollection != null)
        const PopupMenuItem(
          value: _WorkCardAction.addToCollection,
          child: Row(
            children: [
              Icon(Icons.bookmark_add_outlined),
              SizedBox(width: 12),
              Text('加入分组…'),
            ],
          ),
        ),
      if (onRemoveFromCollection != null)
        const PopupMenuItem(
          value: _WorkCardAction.removeFromCollection,
          child: Row(
            children: [
              Icon(Icons.bookmark_remove_outlined),
              SizedBox(width: 12),
              Text('移出分组'),
            ],
          ),
        ),
      if (onRemove != null)
        const PopupMenuItem(
          value: _WorkCardAction.remove,
          child: Row(
            children: [
              Icon(Icons.remove_circle_outline, color: Colors.red),
              SizedBox(width: 12),
              Text('移除作品', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
    ],
  ).then((action) {
    switch (action) {
      case _WorkCardAction.remove:
        onRemove?.call();
      case _WorkCardAction.toggleFavorite:
        onToggleFavorite?.call();
      case _WorkCardAction.addToCollection:
        onAddToCollection?.call();
      case _WorkCardAction.removeFromCollection:
        onRemoveFromCollection?.call();
      case null:
        break;
    }
  });
}

const workListTileExtent = 92.0;

/// Compact list-mode counterpart of [WorkCard]: one fixed-height row with
/// clickable circle / CV names, meant for [ListView.itemExtent].
class WorkListTile extends ConsumerStatefulWidget {
  const WorkListTile({
    super.key,
    required this.work,
    this.isRemote = false,
    this.durationMs,
    this.onTap,
    this.onRemove,
    this.onToggleFavorite,
    this.onAddToCollection,
    this.onRemoveFromCollection,
  });

  final Work work;
  final bool isRemote;
  final int? durationMs;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onAddToCollection;
  final VoidCallback? onRemoveFromCollection;

  @override
  ConsumerState<WorkListTile> createState() => _WorkListTileState();
}

class _WorkListTileState extends ConsumerState<WorkListTile> {
  TapGestureRecognizer? _circleTap;
  var _cvTaps = <TapGestureRecognizer>[];

  @override
  void initState() {
    super.initState();
    _buildRecognizers();
  }

  @override
  void didUpdateWidget(WorkListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.work.circleName != widget.work.circleName ||
        oldWidget.work.voiceActors.join('\n') !=
            widget.work.voiceActors.join('\n')) {
      _disposeRecognizers();
      _buildRecognizers();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _buildRecognizers() {
    TapGestureRecognizer tapFor(WorkChipFilter filter) =>
        TapGestureRecognizer()
          ..onTap = () => applyChipFilter(context, ref, filter);
    final circle = widget.work.circleName;
    _circleTap = circle == null || circle.isEmpty
        ? null
        : tapFor((kind: WorkChipKind.circle, value: circle));
    _cvTaps = [
      for (final cv in widget.work.voiceActors)
        tapFor((kind: WorkChipKind.voiceActor, value: cv)),
    ];
  }

  void _disposeRecognizers() {
    _circleTap?.dispose();
    for (final r in _cvTaps) {
      r.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final work = widget.work;
    final title = (work.titleZh != null && work.titleZh!.isNotEmpty)
        ? work.titleZh!
        : work.title;
    final link = TextStyle(color: theme.colorScheme.primary);
    final meta = <InlineSpan>[];
    void addPart(InlineSpan part) {
      if (meta.isNotEmpty) meta.add(const TextSpan(text: '  /  '));
      meta.add(part);
    }

    if (_circleTap != null) {
      addPart(
        TextSpan(text: work.circleName, style: link, recognizer: _circleTap),
      );
    }
    if (_cvTaps.isNotEmpty) {
      addPart(
        TextSpan(
          children: [
            for (var i = 0; i < _cvTaps.length; i++) ...[
              if (i > 0) const TextSpan(text: '  '),
              TextSpan(
                text: work.voiceActors[i],
                style: link,
                recognizer: _cvTaps[i],
              ),
            ],
          ],
        ),
      );
    }
    final durationMs = widget.durationMs;
    if (durationMs != null && durationMs > 0) {
      addPart(TextSpan(text: _formatTotalDuration(durationMs)));
    }
    final hasMenu =
        widget.onRemove != null ||
        widget.onToggleFavorite != null ||
        widget.onAddToCollection != null ||
        widget.onRemoveFromCollection != null;

    return Semantics(
      button: widget.onTap != null,
      label: title,
      child: GestureDetector(
        onLongPressStart: !hasMenu
            ? null
            : (details) => _showWorkMenu(
                context,
                details.globalPosition,
                work: work,
                onRemove: widget.onRemove,
                onToggleFavorite: widget.onToggleFavorite,
                onAddToCollection: widget.onAddToCollection,
                onRemoveFromCollection: widget.onRemoveFromCollection,
              ),
        child: InkWell(
          onTap: widget.onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 72,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        WorkCover(
                          work: work,
                          borderRadius: BorderRadius.circular(6),
                          iconSize: 24,
                        ),
                        if (widget.isRemote)
                          Positioned(
                            bottom: 3,
                            left: 3,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: _overlayStrong,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.cloud,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        if (work.isFavorite)
                          const Positioned(
                            top: 3,
                            right: 3,
                            child: Icon(
                              Icons.favorite,
                              size: 14,
                              color: Colors.redAccent,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.3,
                          ),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text.rich(
                            TextSpan(children: meta),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatTotalDuration(int ms) {
  final d = Duration(milliseconds: ms);
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours == 0) return '$m:$s';
  return '${d.inHours.toString().padLeft(2, '0')}:$m:$s';
}

enum _WorkCardAction {
  remove,
  toggleFavorite,
  addToCollection,
  removeFromCollection,
}

const _overlayStrong = Color(0x8C000000);
const _overlayWeak = Color(0x73000000);
const _maxVisibleTags = 8;
const _cardChipDensity = _ChipDensity(
  fontSize: 11,
  paddingH: 6,
  paddingV: 2,
  spacing: 4,
  maxWidth: 92,
);
const _largeChipDensity = _ChipDensity(
  fontSize: 13,
  paddingH: 10,
  paddingV: 4,
  spacing: 6,
  maxWidth: 220,
);

class _CoverWithOverlays extends StatelessWidget {
  const _CoverWithOverlays({
    required this.work,
    required this.isRemote,
    required this.onToggleFavorite,
  });

  final Work work;
  final bool isRemote;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final date = work.releaseDate;
    return Stack(
      fit: StackFit.expand,
      children: [
        WorkCover(work: work),
        if (isRemote)
          Positioned(
            bottom: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _overlayStrong,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cloud, size: 12, color: Colors.white),
            ),
          ),
        Positioned(
          top: 6,
          left: 6,
          child: _Pill(
            text: work.productId,
            background: _overlayStrong,
            foreground: Colors.white,
          ),
        ),
        if (onToggleFavorite != null)
          Positioned(
            top: 4,
            right: 4,
            child: _CircleIconButton(
              icon: work.isFavorite ? Icons.favorite : Icons.add,
              filled: work.isFavorite,
              onTap: onToggleFavorite,
            ),
          ),
        if (date != null)
          Positioned(
            bottom: 6,
            right: 6,
            child: _Pill(
              text: _formatDate(date),
              background: _overlayStrong,
              foreground: Colors.white,
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = filled ? theme.colorScheme.primary : _overlayWeak;
    final fg = filled ? theme.colorScheme.onPrimary : Colors.white;
    return Material(
      color: bg,
      shape: const CircleBorder(),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, color: fg, size: 18),
        ),
      ),
    );
  }
}

class _WorkInfo extends ConsumerWidget {
  const _WorkInfo({
    required this.work,
    required this.title,
    required this.durationMs,
    required this.large,
  });

  final Work work;
  final String title;
  final int? durationMs;
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final small = theme.textTheme.bodySmall?.copyWith(color: muted);
    final circle = work.circleName;
    final rating = work.rating;
    final price = work.currentPrice ?? work.officialPrice;
    final sales = work.dlCount;
    final reviews = work.reviewCount;
    final stats = [
      if (rating != null && rating > 0) ...[
        _Stars(rating: rating, size: large ? 17 : 13),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(rating == rating.roundToDouble() ? 0 : 1),
          style: small?.copyWith(
            color: AppTheme.price,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (work.ratingCount != null)
          Text(' (${work.ratingCount})', style: small),
      ],
      if (large && reviews != null && reviews > 0) ...[
        const SizedBox(width: 10),
        Icon(Icons.chat, size: 15, color: muted),
        Text(' ($reviews)', style: small),
      ],
      if (durationMs != null && durationMs! > 0) ...[
        SizedBox(width: large ? 10 : 6),
        Icon(Icons.schedule, size: large ? 15 : 12, color: muted),
        Text(' ${_formatHours(durationMs!)}', style: small),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: large ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style:
              (large ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)
                  ?.copyWith(fontWeight: FontWeight.w600, height: 1.3),
        ),
        if (circle != null && circle.isNotEmpty) ...[
          const SizedBox(height: 3),
          GestureDetector(
            onTap: () => applyChipFilter(context, ref, (
              kind: WorkChipKind.circle,
              value: circle,
            )),
            child: Text(
              circle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (large ? theme.textTheme.bodyMedium : small)?.copyWith(
                color: muted,
              ),
            ),
          ),
        ],
        if (stats.isNotEmpty) ...[
          SizedBox(height: large ? 6 : 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(children: stats),
          ),
        ],
        if (large && (price != null || sales != null)) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (price != null)
                Text(
                  '$price JPY',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.price,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (price != null && sales != null) const SizedBox(width: 12),
              if (sales != null)
                Text('销量：$sales', style: theme.textTheme.bodyMedium),
            ],
          ),
        ],
        SizedBox(height: large ? 10 : 6),
        if (large)
          _TagWrap(work: work, large: true)
        else
          Expanded(child: _TagWrap(work: work, large: false)),
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, required this.size});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star
                : rating >= i - 0.5
                ? Icons.star_half
                : Icons.star_border,
            size: size,
            color: AppTheme.star,
          ),
      ],
    );
  }
}

String _formatHours(int ms) {
  final minutes = ms ~/ 60000;
  if (minutes < 60) return '${minutes}m';
  final hours = minutes / 60;
  return '${hours.toStringAsFixed(hours >= 10 ? 0 : 1)}h';
}

class _TagWrap extends ConsumerWidget {
  const _TagWrap({required this.work, required this.large});

  final Work work;

  /// Large cards list genres first, then series and CVs, like Kikoeru.
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final credits = <_TagEntry>[];
    final genres = <_TagEntry>[];

    if (work.seriesName != null && work.seriesName!.isNotEmpty) {
      credits.add(
        _TagEntry(
          label: work.seriesName!,
          background: const Color(0xFFFFA726),
          foreground: Colors.white,
          filter: (kind: WorkChipKind.series, value: work.seriesName!),
        ),
      );
    }
    for (final cv in work.voiceActors) {
      credits.add(
        _TagEntry(
          label: cv,
          background: const Color(0xFF26A69A),
          foreground: Colors.white,
          filter: (kind: WorkChipKind.voiceActor, value: cv),
        ),
      );
    }
    for (final g in _genreNames(work.genresJson)) {
      genres.add(
        _TagEntry(
          label: g,
          background: theme.colorScheme.surfaceContainerHighest,
          foreground: theme.colorScheme.onSurfaceVariant,
          filter: (kind: WorkChipKind.genre, value: g),
        ),
      );
    }

    final entries = large ? [...genres, ...credits] : [...credits, ...genres];
    if (entries.isEmpty) return const SizedBox.shrink();
    final density = large ? _largeChipDensity : _cardChipDensity;

    return Wrap(
      spacing: density.spacing,
      runSpacing: density.spacing,
      children: [
        for (final e in large ? entries : entries.take(_maxVisibleTags))
          _Chip(
            label: e.label,
            background: e.background,
            foreground: e.foreground,
            density: density,
            onTap: () => applyChipFilter(context, ref, e.filter),
          ),
      ],
    );
  }
}

class _TagEntry {
  const _TagEntry({
    required this.label,
    required this.background,
    required this.foreground,
    required this.filter,
  });

  final String label;
  final Color background;
  final Color foreground;
  final WorkChipFilter filter;
}

class _ChipDensity {
  const _ChipDensity({
    required this.fontSize,
    required this.paddingH,
    required this.paddingV,
    required this.spacing,
    required this.maxWidth,
  });

  final double fontSize;
  final double paddingH;
  final double paddingV;
  final double spacing;
  final double maxWidth;
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
    required this.density,
    this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final _ChipDensity density;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: density.paddingH,
          vertical: density.paddingV,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(maxWidth: density.maxWidth),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: foreground,
            fontSize: density.fontSize,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

final Map<String, List<String>> _genreNamesCache = {};

List<String> _genreNames(String genresJson) {
  final cached = _genreNamesCache[genresJson];
  if (cached != null) return cached;
  final decoded = jsonDecode(genresJson);
  final names = decoded is! List
      ? const <String>[]
      : [
          for (final item in decoded)
            if (item is Map && item['name'] is String) item['name'] as String,
        ];
  return _genreNamesCache[genresJson] = names;
}

String _formatDate(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}
