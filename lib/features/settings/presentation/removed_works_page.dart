import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
              return ListTile(
                leading: const Icon(Icons.album_outlined),
                title: Text(work.title),
                subtitle: Text('${work.productId} · 快照已清除'),
                trailing: const TextButton(
                  onPressed: null,
                  child: Text('重新导入'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
