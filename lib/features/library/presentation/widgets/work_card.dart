import 'package:flutter/material.dart';

import '../../../../core/db/database.dart';

class WorkCard extends StatelessWidget {
  const WorkCard({super.key, required this.work, this.onTap, this.onRemove});

  final Work work;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: onTap != null,
      label: work.title,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          onLongPressStart: onRemove == null
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
                    child: Text(
                      work.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
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
      if (action == _WorkCardAction.remove) onRemove!();
    });
  }
}

enum _WorkCardAction { remove }
