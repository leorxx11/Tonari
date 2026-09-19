import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/files/local_image_path.dart';
import '../../../core/ui/app_toast.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/library_home_button.dart';
import '../../library/presentation/widgets/collection_picker_sheet.dart';
import '../data/video_cover_store.dart';
import '../data/local_video_import.dart';
import '../data/local_video_store.dart';
import '../../video/data/video_controller.dart';
import '../data/video_library_providers.dart';

class VideoLibraryPage extends ConsumerStatefulWidget {
  const VideoLibraryPage({super.key});

  @override
  ConsumerState<VideoLibraryPage> createState() => _VideoLibraryPageState();
}

class _VideoLibraryPageState extends ConsumerState<VideoLibraryPage> {
  bool _favoritesOnly = false;
  bool _importing = false;
  int _completed = 0;
  int _total = 0;

  Future<void> _importVideos() async {
    setState(() {
      _importing = true;
      _completed = 0;
      _total = 0;
    });
    try {
      final count = await ref
          .read(localVideoImportProvider)
          .pickAndImport(
            onProgress: (completed, total) {
              if (!mounted) return;
              setState(() {
                _completed = completed;
                _total = total;
              });
            },
          );
      if (count > 0) {
        if (mounted) setState(() => _favoritesOnly = false);
        showAppToast('已导入 $count 个视频');
      }
    } catch (e) {
      showAppToast('已导入 $_completed 个，导入失败：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(videoItemsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('视频库'),
        bottom: _importing && _total > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    '正在导入 ${_completed + 1 > _total ? _total : _completed + 1} / $_total',
                  ),
                ),
              )
            : null,
        actions: [
          IconButton(
            tooltip: '导入本地视频',
            onPressed: _importing ? null : _importVideos,
            icon: _importing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
          ),
          IconButton(
            tooltip: _favoritesOnly ? '取消只看收藏' : '只看收藏',
            icon: Icon(
              _favoritesOnly ? Icons.favorite : Icons.favorite_outline,
            ),
            onPressed: () => setState(() => _favoritesOnly = !_favoritesOnly),
          ),
          const LibraryHomeButton(),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (all) {
          final items = _favoritesOnly
              ? all.where((v) => v.isFavorite).toList()
              : all;
          if (items.isEmpty) {
            return _EmptyState(
              filtered: _favoritesOnly,
              onImport: _importing ? null : _importVideos,
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.15,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => VideoCard(item: items[i]),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered, required this.onImport});

  final bool filtered;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filtered ? Icons.filter_alt_outlined : CupertinoIcons.videocam,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              filtered ? '没有收藏的视频' : '视频库还是空的',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              filtered ? '关掉"只看收藏"过滤看看' : '从「文件」导入本地视频，或在浏览页、播放历史中加入视频库',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (!filtered) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onImport,
                icon: const Icon(Icons.add),
                label: const Text('导入本地视频'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class VideoCard extends ConsumerWidget {
  const VideoCard({super.key, required this.item, this.onRemoveFromCollection});

  final VideoItem item;

  /// When set (collection detail page), the long-press menu offers
  /// "移出分组" instead of touching the library membership.
  final VoidCallback? onRemoveFromCollection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final title = videoItemTitle(item);
    return Semantics(
      button: true,
      label: title,
      child: Card(
        clipBehavior: Clip.hardEdge,
        margin: EdgeInsets.zero,
        child: GestureDetector(
          onLongPressStart: (details) =>
              _showMenu(context, ref, details.globalPosition),
          child: InkWell(
            onTap: () => ref.read(videoLibraryPlayerProvider).play(item),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoCover(coverPath: item.coverPath),
                        if (item.sourceKind != 'local')
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0x8C000000),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.cloud,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        if (item.isFavorite)
                          const Positioned(
                            top: 6,
                            right: 6,
                            child: Icon(
                              Icons.favorite,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
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

  bool get _localImport =>
      item.sourceKind == 'local' && item.sourceId == LocalVideoStore.sourceId;

  void _showMenu(BuildContext context, WidgetRef ref, Offset position) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final local = overlay.globalToLocal(position);
    showMenu<_VideoCardAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromCenter(center: local, width: 1, height: 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: _VideoCardAction.toggleFavorite,
          child: Row(
            children: [
              Icon(item.isFavorite ? Icons.favorite_outline : Icons.favorite),
              const SizedBox(width: 12),
              Text(item.isFavorite ? '取消收藏' : '添加收藏'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: _VideoCardAction.rename,
          child: Row(
            children: [
              Icon(Icons.drive_file_rename_outline),
              SizedBox(width: 12),
              Text('修改标题'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: _VideoCardAction.addToCollection,
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
            value: _VideoCardAction.removeFromCollection,
            child: Row(
              children: [
                Icon(Icons.bookmark_remove_outlined),
                SizedBox(width: 12),
                Text('移出分组'),
              ],
            ),
          ),
        PopupMenuItem(
          value: _VideoCardAction.remove,
          child: Row(
            children: [
              const Icon(Icons.remove_circle_outline, color: Colors.red),
              const SizedBox(width: 12),
              Text(
                _localImport ? '删除视频' : '从视频库移除',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    ).then((action) async {
      final repo = ref.read(videoLibraryRepositoryProvider);
      switch (action) {
        case _VideoCardAction.toggleFavorite:
          await repo.setFavorite(item.id, !item.isFavorite);
        case _VideoCardAction.rename:
          if (!context.mounted) return;
          final name = await _promptTitle(context);
          if (name != null) await repo.rename(item.id, name);
        case _VideoCardAction.addToCollection:
          if (!context.mounted) return;
          await showVideoCollectionPicker(context, item);
        case _VideoCardAction.removeFromCollection:
          onRemoveFromCollection?.call();
        case _VideoCardAction.remove:
          if (_localImport) {
            if (!context.mounted) return;
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('删除视频？'),
                content: const Text('将删除 Tonari 中的视频文件及其播放记录，原始文件不受影响。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
          }
          try {
            if (_localImport &&
                ref.read(videoControllerProvider).item?.stableId == item.id) {
              await ref.read(videoControllerProvider.notifier).stop();
            }
            await repo.remove(item.id);
            showAppToast(_localImport ? '已删除视频' : '已从视频库移除');
          } catch (e) {
            showAppToast('删除失败：$e');
          }
        case null:
          break;
      }
    });
  }

  Future<String?> _promptTitle(BuildContext context) async {
    final controller = TextEditingController(text: videoItemTitle(item));
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改标题'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '视频标题'),
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = name?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

enum _VideoCardAction {
  toggleFavorite,
  rename,
  addToCollection,
  removeFromCollection,
  remove,
}

/// 条目封面 → 默认封面 → 占位图标，三级回退。
class VideoCover extends ConsumerWidget {
  const VideoCover({super.key, this.coverPath, this.iconSize = 40});

  final String? coverPath;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final defaultCover = ref.watch(defaultVideoCoverProvider);
    final resolved =
        LocalImagePath.resolve(coverPath) ??
        LocalImagePath.resolve(defaultCover);
    if (resolved != null) {
      return Image.file(File(resolved), fit: BoxFit.cover);
    }
    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Icon(
        CupertinoIcons.videocam_fill,
        size: iconSize,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
