import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/providers.dart';
import '../../../p115/presentation/p115_login_page.dart';
import '../../../settings/presentation/diagnostic_log_page.dart';
import '../../data/app_events.dart';
import '../../data/enrichment_queue.dart';
import '../../data/library_task_controller.dart';
import '../../data/work_reimport_provider.dart';

class AppEventsAction extends ConsumerWidget {
  const AppEventsAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(
      unreadEventCountProvider.select((v) => v.value ?? 0),
    );
    final icon = unread > 0
        ? Badge(
            label: Text('$unread'),
            child: const Icon(Icons.notifications_outlined),
          )
        : const Icon(Icons.notifications_none_outlined);
    return IconButton(
      tooltip: unread > 0 ? '$unread 条未读消息' : '消息',
      icon: icon,
      onPressed: () {
        ref.read(appEventSinkProvider).markAllRead();
        showAppEventsSheet(context);
      },
    );
  }
}

Future<void> showAppEventsSheet(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    CupertinoSheetRoute<void>(
      scrollableBuilder: (_, _) => const AppEventsSheet(),
      showDragHandle: true,
    ),
  );
}

class AppEventsSheet extends ConsumerWidget {
  const AppEventsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(appEventsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        actions: [
          if ((events.value ?? const []).isNotEmpty)
            TextButton(
              onPressed: () => ref.read(appEventSinkProvider).clear(),
              child: const Text('清空'),
            ),
        ],
      ),
      body: events.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (list) => list.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                itemCount: list.length + 1,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (i == list.length) return const _DiagnosticFooter();
                  return _EventTile(event: list[i]);
                },
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text('暂无消息', style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _EventTile extends ConsumerWidget {
  const _EventTile({required this.event});

  final AppEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scanning = ref.watch(
      workTaskControllerProvider.select(
        (tasks) => event.productId != null && (tasks[event.productId]?.active ?? false),
      ),
    );
    return Dismissible(
      key: ValueKey(event.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => ref.read(appEventSinkProvider).dismiss(event.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
      ),
      child: ListTile(
        leading: _SeverityIcon(severity: event.severity),
        title: Text(event.count > 1 ? '${event.title} ×${event.count}' : event.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.detail.isNotEmpty)
              Text(event.detail, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              [
                if (event.workTitle != null) event.workTitle!,
                if (event.sourceName != null) event.sourceName!,
                _relativeTime(event.lastAt),
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: _action(context, ref, scanning),
        isThreeLine: event.detail.isNotEmpty,
      ),
    );
  }

  Widget? _action(BuildContext context, WidgetRef ref, bool scanning) {
    switch (event.actionKey) {
      case 'reimport':
        if (event.productId == null) return null;
        return TextButton(
          onPressed: scanning ? null : () => _rescan(context, ref),
          child: Text(scanning ? '扫描中' : '重新扫描'),
        );
      case 'enrich':
        return TextButton(
          onPressed: () => ref
              .read(enrichmentQueueProvider.notifier)
              .runPending(reset: true),
          child: const Text('补全资料'),
        );
      case 'reauth':
        return TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(builder: (_) => const P115LoginPage()),
          ),
          child: const Text('重新登录'),
        );
      default:
        return null;
    }
  }

  Future<void> _rescan(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(databaseProvider);
    final work = await (db.select(
      db.works,
    )..where((row) => row.productId.equals(event.productId!))).getSingleOrNull();
    if (work == null) {
      messenger.showSnackBar(const SnackBar(content: Text('作品已不存在')));
      return;
    }
    final taskController = ref.read(workTaskControllerProvider.notifier);
    final reimport = ref.read(reimportWorkProvider);
    try {
      await taskController.run<void>(
        productId: work.productId,
        kind: LibraryTaskKind.import,
        title: '重新扫描作品',
        initialStage: '扫描文件',
        action: (task) async {
          await reimport(work, task: task);
        },
      );
      await ref.read(appEventSinkProvider).dismiss(event.id);
      messenger.showSnackBar(const SnackBar(content: Text('作品已重新扫描')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('重新扫描失败：$e')));
    }
  }
}

class _SeverityIcon extends StatelessWidget {
  const _SeverityIcon({required this.severity});

  final String severity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (severity) {
      'warning' => Icon(Icons.warning_amber_rounded, color: scheme.tertiary),
      _ => Icon(Icons.error_outline, color: scheme.error),
    };
  }
}

class _DiagnosticFooter extends StatelessWidget {
  const _DiagnosticFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.center,
        child: TextButton.icon(
          onPressed: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(builder: (_) => const DiagnosticLogPage()),
          ),
          icon: const Icon(Icons.bug_report_outlined, size: 18),
          label: const Text('导出诊断日志'),
        ),
      ),
    );
  }
}

String _relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return '刚刚';
  if (d.inMinutes < 60) return '${d.inMinutes} 分钟前';
  if (d.inHours < 24) return '${d.inHours} 小时前';
  return '${d.inDays} 天前';
}
