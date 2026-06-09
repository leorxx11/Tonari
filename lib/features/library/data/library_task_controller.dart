import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LibraryTaskKind { import, metadata, images }

class LibraryTaskState {
  const LibraryTaskState({
    required this.active,
    this.kind,
    this.title = '',
    this.stage = '',
    this.message = '',
    this.completed,
    this.total,
  });

  const LibraryTaskState.idle() : this(active: false);

  final bool active;
  final LibraryTaskKind? kind;
  final String title;
  final String stage;
  final String message;
  final int? completed;
  final int? total;

  double? get progress {
    final done = completed;
    final count = total;
    if (done == null || count == null || count <= 0) return null;
    return done.clamp(0, count) / count;
  }

  String get progressText {
    final done = completed;
    final count = total;
    if (done == null || count == null || count <= 0) return '';
    return '$done/$count';
  }
}

class LibraryTaskBusyException implements Exception {
  const LibraryTaskBusyException(this.title);

  final String title;

  @override
  String toString() => '已有后台任务正在进行：$title';
}

class LibraryTaskReporter {
  LibraryTaskReporter(this._update);

  final void Function({
    required String stage,
    String? message,
    int? completed,
    int? total,
  })
  _update;

  void update({
    required String stage,
    String? message,
    int? completed,
    int? total,
  }) {
    _update(stage: stage, message: message, completed: completed, total: total);
  }
}

class LibraryTaskController extends Notifier<LibraryTaskState> {
  @override
  LibraryTaskState build() => const LibraryTaskState.idle();

  Future<T> run<T>({
    required LibraryTaskKind kind,
    required String title,
    required String initialStage,
    required Future<T> Function(LibraryTaskReporter task) action,
  }) async {
    if (state.active) throw LibraryTaskBusyException(state.title);
    state = LibraryTaskState(
      active: true,
      kind: kind,
      title: title,
      stage: initialStage,
    );
    try {
      return await action(LibraryTaskReporter(_update));
    } finally {
      state = const LibraryTaskState.idle();
    }
  }

  void _update({
    required String stage,
    String? message,
    int? completed,
    int? total,
  }) {
    if (!state.active) return;
    state = LibraryTaskState(
      active: true,
      kind: state.kind,
      title: state.title,
      stage: stage,
      message: message ?? state.message,
      completed: completed,
      total: total,
    );
  }
}

final libraryTaskControllerProvider =
    NotifierProvider<LibraryTaskController, LibraryTaskState>(
      LibraryTaskController.new,
    );

class WorkTaskController extends Notifier<Map<String, LibraryTaskState>> {
  @override
  Map<String, LibraryTaskState> build() => const {};

  LibraryTaskState taskFor(String productId) {
    return state[productId] ?? const LibraryTaskState.idle();
  }

  Future<T> run<T>({
    required String productId,
    required LibraryTaskKind kind,
    required String title,
    required String initialStage,
    required Future<T> Function(LibraryTaskReporter task) action,
  }) async {
    final current = taskFor(productId);
    if (current.active) throw LibraryTaskBusyException(current.title);
    state = {
      ...state,
      productId: LibraryTaskState(
        active: true,
        kind: kind,
        title: title,
        stage: initialStage,
      ),
    };
    try {
      return await action(
        LibraryTaskReporter(
          ({required stage, message, completed, total}) => _update(
            productId: productId,
            stage: stage,
            message: message,
            completed: completed,
            total: total,
          ),
        ),
      );
    } finally {
      final next = {...state}..remove(productId);
      state = next;
    }
  }

  void _update({
    required String productId,
    required String stage,
    String? message,
    int? completed,
    int? total,
  }) {
    final current = taskFor(productId);
    if (!current.active) return;
    state = {
      ...state,
      productId: LibraryTaskState(
        active: true,
        kind: current.kind,
        title: current.title,
        stage: stage,
        message: message ?? current.message,
        completed: completed,
        total: total,
      ),
    };
  }
}

final workTaskControllerProvider =
    NotifierProvider<WorkTaskController, Map<String, LibraryTaskState>>(
      WorkTaskController.new,
    );
