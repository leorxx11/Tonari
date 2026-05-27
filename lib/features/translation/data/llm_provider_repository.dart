import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import 'provider_key_store.dart';

class LlmProviderRepository {
  LlmProviderRepository({
    required this.db,
    required this.keyStore,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final TonariDatabase db;
  final ProviderKeyStore keyStore;
  final Uuid _uuid;

  Stream<List<LlmProvider>> watchAll() {
    return (db.select(db.llmProviders)
          ..orderBy([(p) => OrderingTerm(expression: p.createdAt)]))
        .watch();
  }

  Future<LlmProvider?> defaultProvider() {
    return (db.select(db.llmProviders)
          ..where((p) => p.isDefault.equals(true))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<String?> readKey(String providerId) => keyStore.read(providerId);

  Future<String> create({
    required String name,
    required String baseUrl,
    required String model,
    required String apiKey,
    String? systemPrompt,
    bool makeDefault = false,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    await db.transaction(() async {
      final existing = await db.select(db.llmProviders).get();
      final defaulting = makeDefault || existing.isEmpty;
      if (defaulting) {
        await db.customStatement('UPDATE llm_providers SET is_default = 0');
      }
      await db
          .into(db.llmProviders)
          .insert(
            LlmProvidersCompanion.insert(
              id: id,
              name: name,
              baseUrl: baseUrl,
              model: model,
              systemPrompt: Value(systemPrompt),
              isDefault: Value(defaulting),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
    await keyStore.write(id, apiKey);
    return id;
  }

  Future<void> update({
    required String id,
    required String name,
    required String baseUrl,
    required String model,
    String? apiKey,
    String? systemPrompt,
  }) async {
    await (db.update(db.llmProviders)..where((p) => p.id.equals(id))).write(
      LlmProvidersCompanion(
        name: Value(name),
        baseUrl: Value(baseUrl),
        model: Value(model),
        systemPrompt: Value(systemPrompt),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (apiKey != null && apiKey.isNotEmpty) {
      await keyStore.write(id, apiKey);
    }
  }

  Future<void> delete(String id) async {
    await db.transaction(() async {
      final row =
          await (db.select(
            db.llmProviders,
          )..where((p) => p.id.equals(id))).getSingleOrNull();
      await (db.delete(db.llmProviders)..where((p) => p.id.equals(id))).go();
      if (row?.isDefault ?? false) {
        // promote the oldest remaining row to default to keep one always set
        final remaining =
            await (db.select(db.llmProviders)
                  ..orderBy([(p) => OrderingTerm(expression: p.createdAt)])
                  ..limit(1))
                .getSingleOrNull();
        if (remaining != null) {
          await (db.update(
            db.llmProviders,
          )..where((p) => p.id.equals(remaining.id))).write(
            LlmProvidersCompanion(
              isDefault: const Value(true),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }
    });
    await keyStore.delete(id);
  }

  Future<void> setDefault(String id) async {
    await db.transaction(() async {
      await db.customStatement('UPDATE llm_providers SET is_default = 0');
      await (db.update(db.llmProviders)..where((p) => p.id.equals(id))).write(
        LlmProvidersCompanion(
          isDefault: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }
}

final llmProviderRepositoryProvider = Provider<LlmProviderRepository>((ref) {
  return LlmProviderRepository(
    db: ref.watch(databaseProvider),
    keyStore: ref.watch(providerKeyStoreProvider),
  );
});

final llmProvidersStreamProvider = StreamProvider<List<LlmProvider>>((ref) {
  return ref.watch(llmProviderRepositoryProvider).watchAll();
});

final defaultLlmProviderProvider = Provider<LlmProvider?>((ref) {
  final list = ref.watch(llmProvidersStreamProvider).value ?? const [];
  if (list.isEmpty) return null;
  return list.firstWhere(
    (p) => p.isDefault,
    orElse: () => list.first,
  );
});
