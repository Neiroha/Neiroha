import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/catalog/llm_discovery.dart';
import 'package:neiroha/data/ai/catalog/llm_traits_catalog.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart';

import 'app_providers.dart';

/// Capability router over the enabled provider connections. Features ask it
/// for `stt`, `vad`, `vc`… instead of reading provider rows directly.
final aiCapabilityRouterProvider = StreamProvider<CapabilityRouter>(
  (ref) => ref
      .watch(databaseProvider)
      .watchAllProviders()
      .map(CapabilityRouter.fromProviders),
);

/// LLM traits from the bundled public snapshot.
final llmTraitsCatalogProvider = FutureProvider<LlmTraitsCatalog>(
  (_) => LlmTraitsCatalog.bundled(),
);

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
