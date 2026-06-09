import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/features/library/data/library_task_controller.dart';

void main() {
  test('run publishes progress and returns to idle', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(libraryTaskControllerProvider.notifier);
    final started = Completer<void>();
    final finish = Completer<void>();

    final future = controller.run<int>(
      kind: LibraryTaskKind.import,
      title: '导入',
      initialStage: '扫描文件',
      action: (task) async {
        task.update(
          stage: '补全元数据',
          message: 'RJ123456',
          completed: 1,
          total: 3,
        );
        started.complete();
        await finish.future;
        return 7;
      },
    );

    await started.future;
    final active = container.read(libraryTaskControllerProvider);
    expect(active.active, isTrue);
    expect(active.stage, '补全元数据');
    expect(active.message, 'RJ123456');
    expect(active.progress, closeTo(1 / 3, 0.001));

    await expectLater(
      controller.run<void>(
        kind: LibraryTaskKind.images,
        title: '刷新图片',
        initialStage: '下载图片',
        action: (_) async {},
      ),
      throwsA(isA<LibraryTaskBusyException>()),
    );

    finish.complete();
    expect(await future, 7);
    expect(container.read(libraryTaskControllerProvider).active, isFalse);
  });

  test('work tasks are isolated by product id', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(workTaskControllerProvider.notifier);
    final started = Completer<void>();
    final finish = Completer<void>();

    final first = controller.run<void>(
      productId: 'RJ1',
      kind: LibraryTaskKind.images,
      title: '刷新图片',
      initialStage: '下载图片',
      action: (task) async {
        task.update(stage: '下载图片', message: '主图', completed: 0, total: 1);
        started.complete();
        await finish.future;
      },
    );

    await started.future;
    expect(controller.taskFor('RJ1').active, isTrue);
    expect(controller.taskFor('RJ2').active, isFalse);

    await controller.run<void>(
      productId: 'RJ2',
      kind: LibraryTaskKind.images,
      title: '刷新图片',
      initialStage: '下载图片',
      action: (_) async {},
    );

    await expectLater(
      controller.run<void>(
        productId: 'RJ1',
        kind: LibraryTaskKind.metadata,
        title: '刷新元数据',
        initialStage: '获取 DLsite 元数据',
        action: (_) async {},
      ),
      throwsA(isA<LibraryTaskBusyException>()),
    );

    finish.complete();
    await first;
    expect(controller.taskFor('RJ1').active, isFalse);
  });
}
