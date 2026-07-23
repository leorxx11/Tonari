import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/selected_tab_index.dart';
import '../../data/works_providers.dart';

void applyChipFilter(
  BuildContext context,
  WidgetRef ref,
  WorkChipFilter filter,
) {
  ref.read(workFilterProvider.notifier).addChip(filter);
  ref.read(selectedTabIndexProvider.notifier).set(0);
  Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
}
