import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import 'llm_provider_repository.dart';
import 'translation_controller.dart';
import 'translation_service.dart';

/// Translates all untranslated track titles of one work and caches the
/// results on the tracks themselves (tracks.titleZh survives rescans).
class TrackTranslationController extends AsyncNotifier<TranslationState> {
  TrackTranslationController(this.productId);

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

    var query = db.select(db.tracks)
      ..where((t) => t.workId.equals(productId))
      ..orderBy([(t) => OrderingTerm.asc(t.filePath)]);
    if (!force) {
      query = query..where((t) => t.titleZh.isNull());
    }
    final tracks = await query.get();
    if (tracks.isEmpty) {
      state = const AsyncData(TranslationDone());
      return;
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

      final names = tracks.map((t) => t.title).toList();
      final translated = await svc.translateTrackNames(
        cfg,
        names,
        cancelToken: token,
      );

      await db.batch((b) {
        for (var i = 0; i < tracks.length; i++) {
          b.update(
            db.tracks,
            TracksCompanion(
              titleZh: Value(translated[i]),
              updatedAt: Value(DateTime.now()),
            ),
            where: (t) => t.id.equals(tracks[i].id),
          );
        }
      });
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

final trackTranslationControllerProvider =
    AsyncNotifierProvider.family<
      TrackTranslationController,
      TranslationState,
      String
    >(TrackTranslationController.new);

/// Whether the files page shows translated track names for one work.
/// null = no explicit choice — default to showing when translations exist.
final trackTranslationViewProvider =
    NotifierProvider.family<TranslationViewMode, bool?, String>(
      TranslationViewMode.new,
    );
