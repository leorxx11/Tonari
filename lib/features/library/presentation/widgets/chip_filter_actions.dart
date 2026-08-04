import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/selected_section.dart';
import '../../data/works_providers.dart';

void applyChipFilter(
  BuildContext context,
  WidgetRef ref,
  WorkChipFilter filter,
) {
  ref.read(workFilterProvider.notifier).addChip(filter);
  ref.read(selectedSectionProvider.notifier).set(AppSection.audioLibrary);
  Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
}
