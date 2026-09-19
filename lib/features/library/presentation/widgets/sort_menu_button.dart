import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sort_order.dart';

class SortMenuButton<F extends SortField> extends ConsumerWidget {
  const SortMenuButton({super.key, required this.provider});

  final NotifierProvider<SortOrderNotifier<F>, SortOrder<F>> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    return PopupMenuButton<F>(
      tooltip: '排序',
      icon: const Icon(Icons.sort),
      initialValue: sort.field,
      onSelected: notifier.select,
      itemBuilder: (context) => [
        for (final field in notifier.fields)
          PopupMenuItem(
            value: field,
            child: Row(
              children: [
                if (field == sort.field)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 12),
                Expanded(child: Text(field.label)),
                if (field == sort.field)
                  Icon(
                    sort.descending ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 18,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
