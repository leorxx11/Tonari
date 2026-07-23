import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../data/works_providers.dart';
import 'chip_filter_actions.dart';
import 'work_cover.dart';

class WorkCard extends StatelessWidget {
  const WorkCard({
    super.key,
    required this.work,
    this.isRemote = false,
    this.onTap,
    this.onRemove,
    this.onToggleFavorite,
    this.onAddToCollection,
    this.onRemoveFromCollection,
  });

  final Work work;
  final bool isRemote;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onAddToCollection;
  final VoidCallback? onRemoveFromCollection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              : (details) => _showMenu(context, details.globalPosition),
          child: InkWell(
            onTap: onTap,
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: _CoverWithOverlays(
                      work: work,
                      isRemote: isRemote,
                      onToggleFavorite: onToggleFavorite,
                    ),
                  ),
                  Expanded(
                    child: ClipRect(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Expanded(child: _TagWrap(work: work)),
                          ],
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

  void _showMenu(BuildContext context, Offset position) {
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

class _TagWrap extends ConsumerWidget {
  const _TagWrap({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entries = <_TagEntry>[];

    if (work.seriesName != null && work.seriesName!.isNotEmpty) {
      entries.add(
        _TagEntry(
          label: work.seriesName!,
          background: const Color(0xFFFFA726),
          foreground: Colors.white,
          filter: (kind: WorkChipKind.series, value: work.seriesName!),
        ),
      );
    }
    for (final cv in work.voiceActors) {
      entries.add(
        _TagEntry(
          label: cv,
          background: const Color(0xFF26A69A),
          foreground: Colors.white,
          filter: (kind: WorkChipKind.voiceActor, value: cv),
        ),
      );
    }
    for (final g in _genreNames(work.genresJson)) {
      entries.add(
        _TagEntry(
          label: g,
          background: theme.colorScheme.surfaceContainerHigh,
          foreground: theme.colorScheme.onSurfaceVariant,
          filter: (kind: WorkChipKind.genre, value: g),
        ),
      );
    }

    if (entries.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: _cardChipDensity.spacing,
      runSpacing: _cardChipDensity.spacing,
      children: [
        for (final e in entries.take(_maxVisibleTags))
          _Chip(
            label: e.label,
            background: e.background,
            foreground: e.foreground,
            density: _cardChipDensity,
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
          borderRadius: BorderRadius.circular(6),
        ),
        constraints: BoxConstraints(maxWidth: density.maxWidth),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: foreground,
            fontSize: density.fontSize,
            fontWeight: FontWeight.w600,
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
