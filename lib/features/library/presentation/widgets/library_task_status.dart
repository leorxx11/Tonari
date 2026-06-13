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
    final task = ref.watch(libraryTaskControllerProvider);
    if (task.active) {
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
        onPressed: () => showLibraryTaskSheet(context),
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

Future<void> showLibraryTaskSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => const _LibraryTaskSheet(),
  );
}

/// App-bar action for background metadata enrichment. While the queue runs it
/// shows the current work + a spinner; when idle it offers a one-tap "补全 N 个"
/// for works that can still be auto-enriched, surfaces a separate error entry
/// for works that exhausted their retries, and otherwise hides.
class EnrichmentStatusAction extends ConsumerWidget {
  const EnrichmentStatusAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(enrichmentQueueProvider);
    // Also stay active while a single-work metadata task runs (detail-page
    // auto-enrich or manual refresh) so the indicator ends with the work, not
    // when the background batch happens to finish first.
    final metaBusy = ref.watch(
      workTaskControllerProvider.select(
        (tasks) => tasks.values.any(
          (t) => t.active && t.kind == LibraryTaskKind.metadata,
        ),
      ),
    );
    if (queue.active || metaBusy) {
      final message = queue.active
          ? '补全资料中 ${queue.current ?? ''}（${queue.done + 1}/${queue.total}）'
          : '补全资料中…';
      return Tooltip(
        message: message,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    final pending = ref.watch(
      pendingEnrichmentCountProvider.select((v) => v.value ?? 0),
    );
    final failures = queue.failures;
    // Works that hit the retry cap stay in [pending] (they still lack metadata)
    // but can't be auto-completed, so exclude them from the badge count —
    // otherwise the badge sticks forever on a permanently-failing fetch.
    final autoPending = (pending - failures.length).clamp(0, pending);
    if (autoPending > 0) {
      return IconButton(
        tooltip: '补全 $autoPending 个作品的资料',
        icon: Badge(
          label: Text('$autoPending'),
          child: const Icon(Icons.download_for_offline_outlined),
        ),
        // reset:false — only fetch works that haven't exhausted retries; the
        // failure sheet's "重试全部" is the way to retry the capped ones.
        onPressed: () => ref.read(enrichmentQueueProvider.notifier).runPending(),
      );
    }
    if (failures.isNotEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return IconButton(
        tooltip: '${failures.length} 个作品补全失败',
        icon: Badge(
          backgroundColor: scheme.error,
          label: Text('${failures.length}'),
          child: Icon(Icons.error_outline, color: scheme.error),
        ),
        onPressed: () => showEnrichmentFailureSheet(context),
      );
    }
    return const SizedBox.shrink();
  }
}

Future<void> showEnrichmentFailureSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => const _EnrichmentFailureSheet(),
  );
}

class _EnrichmentFailureSheet extends ConsumerWidget {
  const _EnrichmentFailureSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final failures = ref.watch(
      enrichmentQueueProvider.select((s) => s.failures),
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
              'DLsite 抓取或图片下载失败。可能是作品已下架、网络问题或被风控。',
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
                label: const Text('重试全部'),
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

class _TaskSheetBody extends StatelessWidget {
  const _TaskSheetBody({required this.task, required this.idleText});

  final LibraryTaskState task;
  final String idleText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.active ? task.title : '没有后台任务',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            if (task.active) ...[
              LinearProgressIndicator(value: task.progress),
              const SizedBox(height: 14),
              Text(
                task.stage,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (task.message.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(task.message, style: theme.textTheme.bodyMedium),
              ],
              if (task.progressText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(task.progressText, style: theme.textTheme.bodySmall),
              ],
            ] else
              Text(idleText, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
