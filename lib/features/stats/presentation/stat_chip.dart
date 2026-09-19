import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/data/works_providers.dart';
import '../../library/presentation/widgets/chip_filter_actions.dart';

const _chipColor = Color(0xFF3B887C);

/// Seagreen "name  value" pill that opens the library filtered to [filter]
/// alone, dropping whatever filter was left over.
class StatChip extends ConsumerWidget {
  const StatChip({super.key, required this.filter, required this.value});

  final WorkChipFilter filter;
  final String value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: _chipColor,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () {
          ref.read(workFilterProvider.notifier).clearSearch();
          applyChipFilter(context, ref, filter);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          child: Text.rich(
            TextSpan(
              text: filter.value,
              children: [
                TextSpan(
                  text: '  $value',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
