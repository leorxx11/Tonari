import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/features/library/data/enrichment_queue.dart';
import 'package:tonari/features/library/presentation/widgets/library_task_status.dart';

void main() {
  testWidgets('active enrichment opens through unified task button', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          enrichmentQueueProvider.overrideWith(_ActiveEnrichmentQueue.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                const EnrichmentStatusAction(),
                LibraryTaskStatusButton(
                  idleTooltip: '导入文件夹',
                  onIdlePressed: () {},
                ),
              ],
            ),
            body: const SizedBox(),
          ),
        ),
      ),
    );

    expect(find.byTooltip('导入文件夹'), findsNothing);
    await tester.tap(find.byTooltip('补全资料中 RJ123456（1/3）'));
    await tester.pumpAndSettle();

    expect(find.text('补全资料'), findsOneWidget);
    expect(find.text('获取 DLsite 元数据'), findsOneWidget);
    expect(find.text('RJ123456'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('task sheet keeps detail layout after enrichment finishes', (
    tester,
  ) async {
    late _ControllableEnrichmentQueue queue;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          enrichmentQueueProvider.overrideWith(() {
            queue = _ControllableEnrichmentQueue();
            return queue;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                LibraryTaskStatusButton(
                  idleTooltip: '导入文件夹',
                  onIdlePressed: () {},
                ),
              ],
            ),
            body: const SizedBox(),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('补全资料中 RJ123456（1/3）'));
    await tester.pumpAndSettle();

    queue.finish();
    await tester.pumpAndSettle();

    expect(find.text('补全资料'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('3/3'), findsOneWidget);
    expect(find.text('没有后台任务'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}

class _ActiveEnrichmentQueue extends EnrichmentQueue {
  @override
  EnrichmentQueueState build() {
    return const EnrichmentQueueState(
      active: true,
      current: 'RJ123456',
      done: 0,
      total: 3,
    );
  }
}

class _ControllableEnrichmentQueue extends EnrichmentQueue {
  @override
  EnrichmentQueueState build() {
    return const EnrichmentQueueState(
      active: true,
      current: 'RJ123456',
      done: 0,
      total: 3,
    );
  }

  void finish() {
    state = const EnrichmentQueueState.idle();
  }
}
