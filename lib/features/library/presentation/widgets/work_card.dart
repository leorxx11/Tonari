import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/db/database.dart';
import 'work_cover.dart';

class WorkCard extends StatelessWidget {
  const WorkCard({
    super.key,
    required this.work,
    this.isRemote = false,
    this.onTap,
    this.onRemove,
    this.onToggleFavorite,
  });

  final Work work;
  final bool isRemote;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMenu = onRemove != null || onToggleFavorite != null;
    final displayTitle = (work.titleZh != null && work.titleZh!.isNotEmpty)
        ? work.titleZh!
        : work.title;
    return Semantics(
      button: onTap != null,
      label: displayTitle,
      child: Card(
        clipBehavior: Clip.antiAlias,
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
        case null:
          break;
      }
    });
  }
}

enum _WorkCardAction { remove, toggleFavorite }

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
                color: Colors.black.withValues(alpha: 0.55),
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
            background: Colors.black.withValues(alpha: 0.55),
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
              background: Colors.black.withValues(alpha: 0.55),
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
    final bg = filled
        ? theme.colorScheme.primary
        : Colors.black.withValues(alpha: 0.45);
    final fg = filled ? theme.colorScheme.onPrimary : Colors.white;
    return Material(
      color: bg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
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

class _TagWrap extends StatelessWidget {
  const _TagWrap({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = <_TagEntry>[];

    if (work.seriesName != null && work.seriesName!.isNotEmpty) {
      entries.add(
        _TagEntry(
          label: work.seriesName!,
          background: const Color(0xFFFFA726),
          foreground: Colors.white,
        ),
      );
    }
    for (final cv in work.voiceActors) {
      entries.add(
        _TagEntry(
          label: cv,
          background: const Color(0xFF26A69A),
          foreground: Colors.white,
        ),
      );
    }
    for (final g in _genreNames(work.genresJson)) {
      entries.add(
        _TagEntry(
          label: g,
          background: theme.colorScheme.surfaceContainerHigh,
          foreground: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    if (entries.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 200.0;
        final density = _pickDensity(entries, w, h);
        return Wrap(
          spacing: density.spacing,
          runSpacing: density.spacing,
          children: [
            for (final e in entries)
              _Chip(
                label: e.label,
                background: e.background,
                foreground: e.foreground,
                density: density,
              ),
          ],
        );
      },
    );
  }
}

class _TagEntry {
  const _TagEntry({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
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

/// Largest chip font size that lets [entries] fit inside the available
/// box (`maxWidth` × `maxHeight`). Walks from a generous max down to a
/// readable minimum in 0.5 steps so cards with few chips render large
/// and cards with many chips shrink just enough to pack everything.
_ChipDensity _pickDensity(
  List<_TagEntry> entries,
  double maxWidth,
  double maxHeight,
) {
  const maxFont = 16.0;
  const minFont = 8.0;
  for (double f = maxFont; f >= minFont; f -= 0.5) {
    final d = _density(f);
    if (_chipsFitInBox(entries, d, maxWidth, maxHeight)) return d;
  }
  return _density(minFont);
}

_ChipDensity _density(double fontSize) {
  return _ChipDensity(
    fontSize: fontSize,
    paddingH: (fontSize * 0.55).clamp(4.0, 9.0),
    paddingV: (fontSize * 0.22).clamp(1.5, 3.5),
    spacing: (fontSize * 0.4).clamp(2.5, 6.0),
    maxWidth: fontSize * 12,
  );
}

bool _chipsFitInBox(
  List<_TagEntry> entries,
  _ChipDensity d,
  double maxWidth,
  double maxHeight,
) {
  double rowW = 0;
  var rows = 1;
  final chipH = d.fontSize * 1.25 + d.paddingV * 2;
  for (final e in entries) {
    final tp = TextPainter(
      text: TextSpan(
        text: e.label,
        style: TextStyle(fontSize: d.fontSize, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final rawW = tp.width + d.paddingH * 2;
    final chipW = rawW > d.maxWidth ? d.maxWidth : rawW;
    if (rowW == 0) {
      rowW = chipW;
    } else if (rowW + d.spacing + chipW <= maxWidth) {
      rowW += d.spacing + chipW;
    } else {
      rows++;
      rowW = chipW;
    }
  }
  final totalH = rows * chipH + (rows - 1) * d.spacing;
  return totalH <= maxHeight;
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
    required this.density,
  });

  final String label;
  final Color background;
  final Color foreground;
  final _ChipDensity density;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

List<String> _genreNames(String genresJson) {
  final decoded = jsonDecode(genresJson);
  if (decoded is! List) return const [];
  return [
    for (final item in decoded)
      if (item is Map && item['name'] is String) item['name'] as String,
  ];
}

String _formatDate(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}
