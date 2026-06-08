import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import 'llm_provider_repository.dart';
import 'translation_service.dart';

sealed class TranslationState {
  const TranslationState();
}

class TranslationIdle extends TranslationState {
  const TranslationIdle();
}

class TranslationLoading extends TranslationState {
  const TranslationLoading();
}

class TranslationDone extends TranslationState {
  const TranslationDone();
}

class TranslationFailed extends TranslationState {
  const TranslationFailed(this.message);
  final String message;
}

class TranslationController extends AsyncNotifier<TranslationState> {
  TranslationController(this.productId);

  final String productId;
  CancelToken? _cancelToken;

  @override
  Future<TranslationState> build() async {
    ref.onDispose(() {
      _cancelToken?.cancel('disposed');
    });
    return const TranslationIdle();
  }

  Future<void> translate({bool force = false}) async {
    _cancelToken?.cancel('superseded');
    _cancelToken = null;

    final db = ref.read(databaseProvider);
    final repo = ref.read(llmProviderRepositoryProvider);

    final provider = await repo.defaultProvider();
    if (provider == null) {
      state = const AsyncData(TranslationFailed('未配置翻译 Provider'));
      return;
    }
    final apiKey = await repo.readKey(provider.id);
    if (apiKey == null || apiKey.isEmpty) {
      state = const AsyncData(TranslationFailed('Provider 缺少 API Key'));
      return;
    }

    final work = await (db.select(
      db.works,
    )..where((w) => w.productId.equals(productId))).getSingleOrNull();
    if (work == null) {
      state = const AsyncData(TranslationFailed('作品不存在'));
      return;
    }

    if (force) {
      await (db.update(
        db.works,
      )..where((w) => w.productId.equals(productId))).write(
        const WorksCompanion(
          titleZh: Value(null),
          descriptionHtmlZh: Value(null),
        ),
      );
    }

    state = const AsyncData(TranslationLoading());
    final token = CancelToken();
    _cancelToken = token;

    try {
      final svc = ref.read(translationServiceProvider);
      final cfg = LlmProviderConfig(
        baseUrl: provider.baseUrl,
        model: provider.model,
        apiKey: apiKey,
        systemPrompt: provider.systemPrompt,
      );

      final titleZh = await svc.translateTitle(
        cfg,
        work.title,
        cancelToken: token,
      );

      String? descZh;
      final descHtml = work.descriptionHtml;
      if (descHtml != null && descHtml.isNotEmpty) {
        descZh = await svc.translateDescriptionHtml(
          cfg,
          descHtml,
          cancelToken: token,
        );
      }

      await (db.update(
        db.works,
      )..where((w) => w.productId.equals(productId))).write(
        WorksCompanion(
          titleZh: Value(titleZh),
          descriptionHtmlZh: Value(descZh),
          updatedAt: Value(DateTime.now()),
        ),
      );
      state = const AsyncData(TranslationDone());
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        state = const AsyncData(TranslationIdle());
        return;
      }
      state = AsyncData(TranslationFailed('翻译失败：$e'));
    } finally {
      if (_cancelToken == token) _cancelToken = null;
    }
  }

  void clearFailure() {
    if (state.value is TranslationFailed) {
      state = const AsyncData(TranslationIdle());
    }
  }
}

final translationControllerProvider =
    AsyncNotifierProvider.family<
      TranslationController,
      TranslationState,
      String
    >(TranslationController.new);

/// Whether the user is currently viewing the translated content in the
/// detail page. Local UI state, scoped per work via family.
///
/// null = user hasn't toggled this work — caller decides default (typically
/// "show translation if cached exists"). true/false = explicit user choice.
class TranslationViewMode extends Notifier<bool?> {
  TranslationViewMode(this.productId);

  final String productId;

  @override
  bool? build() => null;

  void show(bool value) => state = value;
  void toggleFrom(bool current) => state = !current;
}

final translationViewModeProvider =
    NotifierProvider.family<TranslationViewMode, bool?, String>(
      TranslationViewMode.new,
    );
