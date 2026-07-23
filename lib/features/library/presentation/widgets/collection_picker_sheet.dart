import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../data/collections_providers.dart';

Future<void> showCollectionPicker(BuildContext context, Work work) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CollectionPickerSheet(work: work),
  );
}

Future<String?> promptCollectionName(
  BuildContext context, {
  String? initial,
}) async {
  final controller = TextEditingController(text: initial);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(initial == null ? '新建分组' : '重命名分组'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '分组名称'),
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

class _CollectionPickerSheet extends ConsumerWidget {
  const _CollectionPickerSheet({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final collections = ref.watch(collectionsProvider).value ?? const [];
    final memberIds =
        ref.watch(workCollectionIdsProvider(work.productId)).value ??
        const <String>{};
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('加入分组', style: theme.textTheme.titleMedium),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('新建'),
                    onPressed: () => _createAndJoin(context, ref),
                  ),
                ],
              ),
            ),
            if (collections.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  '还没有分组，点右上角新建一个',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in collections)
                      CheckboxListTile(
                        value: memberIds.contains(c.id),
                        title: Text(c.name),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (checked) {
                          ref
                              .read(collectionRepositoryProvider)
                              .setMembership(
                                work.productId,
                                c.id,
                                member: checked ?? false,
                              );
                        },
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _createAndJoin(BuildContext context, WidgetRef ref) async {
    final name = await promptCollectionName(context);
    if (name == null) return;
    final repo = ref.read(collectionRepositoryProvider);
    final id = await repo.create(name);
    await repo.setMembership(work.productId, id, member: true);
  }
}
