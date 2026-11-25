import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/catalog/llm_discovery.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'llm_traits_chips.dart';

/// Traits of the chosen model, with a warning when the task needs tool
/// calling and the model lacks it (or it is unknown).
class LlmModelSummary extends ConsumerWidget {
  const LlmModelSummary({
    super.key,
    required this.providerId,
    required this.modelId,
    this.requireTools = false,
  });
  final String? providerId;
  final String modelId;
  final bool requireTools;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final id = providerId;
    final model = modelId.trim();
    if (id == null || model.isEmpty) return const SizedBox.shrink();
    final row = (ref.watch(ttsProvidersStreamProvider).value ?? const [])
        .where((r) => r.id == id)
        .firstOrNull;
    final catalog = ref.watch(llmTraitsCatalogProvider).value;
    if (row == null || catalog == null || !providerOffersLlm(row)) {
      return const SizedBox.shrink();
    }
    final offline = LlmDiscovery(catalog).offline(connectionForProvider(row));
    // Use the live list only if it was already fetched (no request here).
    final live = ref.exists(llmInventoryProvider(id))
        ? ref.watch(llmInventoryProvider(id)).value
        : null;
    final descriptor =
        live?.find(model) ??
        offline.find(model) ??
        offline.connection.describe(AiCapability.llm, model);
    final traits = descriptor?.llm ?? LlmTraits.unknown;
    final warning = !requireTools
        ? null
        : switch (traits.tools) {
            false => l.llmNeedsToolsNo,
            null => l.llmNeedsToolsUnknown,
            true => null,
          };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LlmTraitsChips(traits),
          if (warning != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                warning,
                style: TextStyle(
                  fontSize: 12,
                  color: traits.tools == false
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurface.withAlpha(160),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
