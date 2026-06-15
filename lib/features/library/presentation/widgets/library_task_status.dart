import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/enrichment_queue.dart';
import '../../data/library_task_controller.dart';

class LibraryTaskStatusButton extends ConsumerWidget {
  const LibraryTaskStatusButton({
    super.key,
    this.idleTooltip,
    this.idleIcon,
    this.onIdlePressed,
    this.showWhenIdle = true,
  });

  final String? idleTooltip;
  final Widget? idleIcon;
  final VoidCallback? onIdlePressed;
  final bool showWhenIdle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryTask = ref.watch(libraryTaskControllerProvider);
    final queue = ref.watch(enrichmentQueueProvider);
    final metadataTask = ref.watch(
      workTaskControllerProvider.select(_firstActiveMetadataTask),
    );
    if (libraryTask.active) {
      return _TaskStatusIconButton(
        task: libraryTask,
        onPressed: () => showLibraryTaskSheet(context),
      );
    }
    if (queue.active) {
      return _TaskStatusIconButton(
        task: _taskFromEnrichmentQueue(queue),
        tooltip: _enrichmentTaskTooltip(queue),
        onPressed: () => showEnrichmentTaskSheet(context),
      );
    }
    if (metadataTask != null) {
      return _TaskStatusIconButton(
        task: metadataTask.task,
        onPressed: () => showWorkTaskSheet(context, metadataTask.productId),
      );
    }
    if (!showWhenIdle) return const SizedBox.shrink();
    return IconButton(
      tooltip: idleTooltip,
      icon: idleIcon ?? const Icon(Icons.create_new_folder_outlined),
      onPressed: onIdlePressed,
    );
  }
}

class _TaskStatusIconButton extends StatelessWidget {
  const _TaskStatusIconButton({
    required this.task,
    required this.onPressed,
    this.tooltip,
  });

  final LibraryTaskState task;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip ?? task.title,
      icon: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          value: task.progress,
          strokeWidth: 2.4,
        ),
      ),
      onPressed: onPressed,
    );
  }
}

Future<void> showLibraryTaskSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => const _LibraryTaskSheet(),
  );
}

/// App-bar action for background metadata enrichment. Active tasks are shown by
/// [LibraryTaskStatusButton]; this action only exposes idle affordances.
class EnrichmentStatusAction extends ConsumerWidget {
  const EnrichmentStatusAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(enrichmentQueueProvider);
    final taskActive =
        ref.watch(libraryTaskControllerProvider.select((s) => s.active)) ||
        queue.active ||
        ref.watch(
          workTaskControllerProvider.select(
            (tasks) => _firstActiveMetadataTask(tasks) != null,
          ),
        );
    if (taskActive) return const SizedBox.shrink();
    final pending = ref.watch(
      pendingEnrichmentCountProvider.select((v) => v.value ?? 0),
    );
    final failures = queue.failures;
    if (failures.isNotEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return IconButton(
        tooltip: '${failures.length} 个作品补全失败，点开重试',
        icon: Badge(
          backgroundColor: scheme.error,
          label: Text('${failures.length}'),
          child: Icon(Icons.error_outline, color: scheme.error),
        ),
        onPressed: () => showEnrichmentFailureSheet(context),
      );
    }
    if (pending > 0) {
      return IconButton(
        tooltip: '补全 $pending 个作品的资料',
        icon: Badge(
          label: Text('$pending'),
          child: const Icon(Icons.download_for_offline_outlined),
        ),
        onPressed: () =>
            ref.read(enrichmentQueueProvider.notifier).runPending(),
      );
    }
    return const SizedBox.shrink();
  }
}

Future<void> showEnrichmentTaskSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => const _EnrichmentTaskSheet(),
  );
}

Future<void> showEnrichmentFailureSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => const _EnrichmentFailureSheet(),
  );
}

class _EnrichmentTaskSheet extends ConsumerWidget {
  const _EnrichmentTaskSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(enrichmentQueueProvider);
    final task = queue.active
        ? _taskFromEnrichmentQueue(queue)
        : const LibraryTaskState.idle();
    return _TaskSheetBody(task: task, idleText: '当前没有元数据补全任务。');
  }
}

class _EnrichmentFailureSheet extends ConsumerWidget {
  const _EnrichmentFailureSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final failures = ref.watch(
      enrichmentQueueProvider.select((s) => s.failures),
    );
    final pending = ref.watch(
      pendingEnrichmentCountProvider.select((v) => v.value ?? 0),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '补全失败（${failures.length}）',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              pending > failures.length
                  ? '还有 $pending 个作品资料不完整。重试会重新补全全部缺失资料。'
                  : 'DLsite 抓取或图片下载失败。可能是作品已下架、网络问题或被风控。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final entry in failures.entries)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.key),
                      subtitle: Text(
                        entry.value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.refresh),
                label: const Text('重试并补全全部'),
                onPressed: () {
                  Navigator.of(context).pop();
                  ref
                      .read(enrichmentQueueProvider.notifier)
                      .runPending(reset: true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkTaskStatusButton extends ConsumerWidget {
  const WorkTaskStatusButton({
    super.key,
    required this.productId,
    this.showWhenIdle = false,
  });

  final String productId;
  final bool showWhenIdle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(
      workTaskControllerProvider.select(
        (tasks) => tasks[productId] ?? const LibraryTaskState.idle(),
      ),
    );
    if (!task.active) {
      return showWhenIdle ? const SizedBox(width: 48) : const SizedBox.shrink();
    }
    return IconButton(
      tooltip: task.title,
      icon: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          value: task.progress,
          strokeWidth: 2.4,
        ),
      ),
      onPressed: () => showWorkTaskSheet(context, productId),
    );
  }
}

({String productId, LibraryTaskState task})? _firstActiveMetadataTask(
  Map<String, LibraryTaskState> tasks,
) {
  for (final entry in tasks.entries) {
    final task = entry.value;
    if (task.active && task.kind == LibraryTaskKind.metadata) {
      return (productId: entry.key, task: task);
    }
  }
  return null;
}

String _enrichmentTaskTooltip(EnrichmentQueueState queue) {
  return '补全资料中 ${queue.current ?? ''}（${queue.done + 1}/${queue.total}）';
}

LibraryTaskState _taskFromEnrichmentQueue(EnrichmentQueueState queue) {
  return LibraryTaskState(
    active: true,
    kind: LibraryTaskKind.metadata,
    title: '补全资料',
    stage: '获取 DLsite 元数据',
    message: queue.current ?? '',
    completed: queue.done + 1,
    total: queue.total,
  );
}

Future<void> showWorkTaskSheet(BuildContext context, String productId) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => _WorkTaskSheet(productId: productId),
  );
}

class _LibraryTaskSheet extends ConsumerWidget {
  const _LibraryTaskSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(libraryTaskControllerProvider);
    return _TaskSheetBody(task: task, idleText: '导入、元数据刷新和图片刷新会显示在这里。');
  }
}

class _WorkTaskSheet extends ConsumerWidget {
  const _WorkTaskSheet({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(
      workTaskControllerProvider.select(
        (tasks) => tasks[productId] ?? const LibraryTaskState.idle(),
      ),
    );
    return _TaskSheetBody(task: task, idleText: '这个作品当前没有刷新任务。');
  }
}

class _TaskSheetBody extends StatefulWidget {
  const _TaskSheetBody({required this.task, required this.idleText});

  final LibraryTaskState task;
  final String idleText;

  @override
  State<_TaskSheetBody> createState() => _TaskSheetBodyState();
}

class _TaskSheetBodyState extends State<_TaskSheetBody> {
  LibraryTaskState? _lastActiveTask;

  @override
  void initState() {
    super.initState();
    if (widget.task.active) _lastActiveTask = widget.task;
  }

  @override
  void didUpdateWidget(covariant _TaskSheetBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.active) _lastActiveTask = widget.task;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = widget.task.active ? widget.task : _lastActiveTask;
    final finished = !widget.task.active && task != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task != null ? task.title : '没有后台任务',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            if (task != null) ...[
              LinearProgressIndicator(value: finished ? 1 : task.progress),
              const SizedBox(height: 14),
              Text(
                finished ? '已完成' : task.stage,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!finished && task.message.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(task.message, style: theme.textTheme.bodyMedium),
              ],
              if (_progressText(task, finished).isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _progressText(task, finished),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ] else
              Text(widget.idleText, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  String _progressText(LibraryTaskState task, bool finished) {
    if (!finished) return task.progressText;
    final total = task.total;
    if (total == null || total <= 0) return '';
    return '$total/$total';
  }
}
