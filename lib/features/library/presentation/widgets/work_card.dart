import 'package:flutter/material.dart';

import '../../../../core/db/database.dart';

class WorkCard extends StatelessWidget {
  const WorkCard({
    super.key,
    required this.work,
    this.onTap,
    this.onRemove,
    this.onToggleFavorite,
  });

  final Work work;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMenu = onRemove != null || onToggleFavorite != null;
    return Semantics(
      button: onTap != null,
      label: work.title,
      child: Card(
        clipBehavior: Clip.antiAlias,
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
                  Expanded(
                    child: Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.album_outlined,
                        size: 36,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            work.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        if (work.isFavorite) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.favorite,
                            size: 12,
                            color: theme.colorScheme.primary,
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
                Icon(
                  work.isFavorite
                      ? Icons.favorite_outline
                      : Icons.favorite,
                ),
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
