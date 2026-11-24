import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:neiroha/data/ai/catalog/llm_discovery.dart';
import 'package:neiroha/data/ai/catalog/llm_traits_catalog.dart';
import 'package:neiroha/data/ai/catalog/model_catalog_refresher.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart';

import 'app_providers.dart';

/// Capability router over the enabled provider connections. Features ask it
/// for `stt`, `vad`, `vc`… instead of reading provider rows directly.
/// Includes the per-connection capability switches, added models and
/// defaults of the v34 tables.
final aiCapabilityRouterProvider = FutureProvider<CapabilityRouter>((
  ref,
) async {
  final rows = await ref.watch(ttsProvidersStreamProvider.future);
  return CapabilityRouter.fromProviders(
    rows,
    defaultRows: await ref.watch(capabilityDefaultsProvider.future),
    capabilityRows: await ref.watch(connectionCapabilitiesProvider.future),
    modelRows: await ref.watch(providerModelsProvider.future),
  );
});

final connectionCapabilitiesProvider =
    StreamProvider<List<ConnectionCapability>>(
      (ref) => ref.watch(databaseProvider).watchConnectionCapabilities(),
    );

final providerModelsProvider = StreamProvider<List<ProviderModel>>(
  (ref) => ref.watch(databaseProvider).watchProviderModels(),
);

final capabilityDefaultsProvider = StreamProvider<List<CapabilityDefault>>(
  (ref) => ref.watch(databaseProvider).watchCapabilityDefaults(),
);

final modelCatalogRefresherProvider = Provider<ModelCatalogRefresher>(
  (ref) => ModelCatalogRefresher(ref.watch(databaseProvider)),
);

/// The latest models.dev download, set at app start (see
/// [startModelCatalogRefresh]); null until then or when offline.
final freshModelCatalogProvider = StateProvider<LlmTraitsCatalog?>((_) => null);

/// LLM traits: the daily models.dev download over the bundled snapshots.
final llmTraitsCatalogProvider = FutureProvider<LlmTraitsCatalog>((ref) async {
  final bundled = await LlmTraitsCatalog.bundled();
  final fresh = ref.watch(freshModelCatalogProvider);
  return fresh == null ? bundled : fresh.over(bundled);
});

/// Publishes the cached catalog, then refreshes it once a day.
Future<void> startModelCatalogRefresh(WidgetRef ref) async {
  final refresher = ref.read(modelCatalogRefresherProvider);
  void publish(LlmTraitsCatalog? fresh) {
    if (fresh != null) {
      ref.read(freshModelCatalogProvider.notifier).state = fresh;
    }
  }

  publish(await refresher.cached());
  if (await refresher.refresh()) publish(await refresher.cached());
}

/// Live LLM inventory of one provider row (any enabled state): `GET models`
/// merged with catalog traits. Invalidate to refresh.
final llmInventoryProvider = FutureProvider.family<LlmInventory?, String>((
  ref,
  providerId,
) async {
  final rows = await ref.watch(ttsProvidersStreamProvider.future);
  final row = rows.where((r) => r.id == providerId).firstOrNull;
  if (row == null || !providerOffersLlm(row)) return null;
  final catalog = await ref.watch(llmTraitsCatalogProvider.future);
  return LlmDiscovery(catalog).discover(connectionForProvider(row));
});
