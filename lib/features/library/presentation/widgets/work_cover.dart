import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/db/database.dart';

class WorkCover extends StatelessWidget {
  const WorkCover({
    super.key,
    required this.work,
    this.borderRadius,
    this.iconSize = 36,
  });

  final Work work;
  final BorderRadius? borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget placeholder() => Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.album_outlined,
        size: iconSize,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    Widget image;
    final localPath = work.mainImageLocalPath;
    if (localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync()) {
      image = Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder(),
      );
    } else if (work.mainImageUrl != null && work.mainImageUrl!.isNotEmpty) {
      image = Image.network(
        work.mainImageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return placeholder();
        },
        errorBuilder: (_, _, _) => placeholder(),
      );
    } else {
      image = placeholder();
    }

    final radius = borderRadius;
    if (radius == null) return image;
    return ClipRRect(borderRadius: radius, child: image);
  }
}
