import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../data/work_navigation.dart';
import 'work_detail_page.dart';

Future<void> openWorkDetail(
  BuildContext context,
  WidgetRef ref,
  Work work, {
  bool closeCurrentRoute = false,
}) {
  ref.read(lastOpenedWorkIdProvider.notifier).set(work.productId);
  final navigator = Navigator.of(context, rootNavigator: true);
  if (closeCurrentRoute) navigator.pop();
  return navigator.push(
    MaterialPageRoute<void>(builder: (_) => WorkDetailPage(work: work)),
  );
}
