import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../translation/data/llm_provider_repository.dart';
import 'provider_edit_page.dart';

class TranslationSettingsPage extends ConsumerWidget {
  const TranslationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final providersAsync = ref.watch(llmProvidersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('翻译'),
        actions: [
          IconButton(
            tooltip: '添加 Provider',
            icon: const Icon(Icons.add),
            onPressed: () => _openCreate(context),
          ),
        ],
      ),
      body: providersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (providers) {
          if (providers.isEmpty) return _Empty(theme: theme);
          return ListView.separated(
            itemCount: providers.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) => _ProviderTile(provider: providers[i]),
          );
        },
      ),
    );
  }

  void _openCreate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ProviderEditPage(),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.translate_outlined,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              '还没配置翻译 Provider',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '点右上 + 添加 DeepSeek、Gemini 或自定义 OpenAI 兼容服务',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderTile extends ConsumerWidget {
  const _ProviderTile({required this.provider});

  final LlmProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(llmProviderRepositoryProvider);

    return ListTile(
      leading: Icon(
        provider.isDefault ? Icons.star : Icons.star_outline,
        color: provider.isDefault
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
      ),
      title: Text(provider.name),
      subtitle: Text(
        '${provider.model} · ${provider.baseUrl}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProviderEditPage(provider: provider),
          ),
        );
      },
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'default') {
            await repo.setDefault(provider.id);
          } else if (v == 'delete') {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('删除 Provider'),
                content: Text('确认删除「${provider.name}」？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
            if (confirm ?? false) await repo.delete(provider.id);
          }
        },
        itemBuilder: (_) => [
          if (!provider.isDefault)
            const PopupMenuItem(value: 'default', child: Text('设为默认')),
          const PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
    );
  }
}
