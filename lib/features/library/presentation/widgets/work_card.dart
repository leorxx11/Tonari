import 'package:flutter/material.dart';

import '../../../../core/db/database.dart';

class WorkCard extends StatelessWidget {
  const WorkCard({super.key, required this.work, this.onTap});

  final Work work;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
    );
  }
}
