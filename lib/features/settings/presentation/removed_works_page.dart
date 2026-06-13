import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../library/data/library_task_controller.dart';
import '../../library/data/work_actions_provider.dart';
import '../../library/data/work_reimport_provider.dart';
import '../../library/data/works_providers.dart';

class RemovedWorksPage extends ConsumerWidget {
  const RemovedWorksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worksAsync = ref.watch(removedWorksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('已移除作品')),
      body: worksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (works) {
          if (works.isEmpty) return const Center(child: Text('没有已移除作品'));
          return ListView.separated(
            itemCount: works.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final work = works[index];
              return _RemovedWorkTile(work: work);
            },
          );
        },
      ),
    );
  }
}

class _RemovedWorkTile extends ConsumerWidget {
  const _RemovedWorkTile({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      workTaskControllerProvider.select(
        (tasks) => tasks[work.productId]?.active ?? false,
      ),
    );
    return ListTile(
      leading: const Icon(Icons.album_outlined),
      title: Text(work.title),
      subtitle: Text('${work.productId} · 快照已清除'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: active ? null : () => _reimport(context, ref),
            child: Text(active ? '导入中' : '重新导入'),
          ),
          IconButton(
            tooltip: '彻底移除',
            icon: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: active ? null : () => _deleteForever(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _reimport(BuildContext context, WidgetRef ref) async {
    final taskController = ref.read(workTaskControllerProvider.notifier);
    final reimport = ref.read(reimportWorkProvider);
    try {
      await taskController.run<void>(
        productId: work.productId,
        kind: LibraryTaskKind.import,
        title: '重新导入作品',
        initialStage: '扫描文件',
        action: (task) async {
          await reimport(work, task: task);
        },
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已重新导入 ${work.title}')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('重新导入失败：$e')));
    }
  }

  Future<void> _deleteForever(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('彻底移除'),
        content: Text('将永久删除「${work.title}」的移除记录。下次导入会作为新作品加入。确定？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('彻底移除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(deleteWorkPermanentlyProvider)(work.productId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已彻底移除 ${work.title}')));
  }
}
