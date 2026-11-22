import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/protocols/openai/openai_model_list.dart';
import 'package:neiroha/data/ai/providers/common/adapter_backed_connection.dart';
import 'package:neiroha/data/ai/providers/openai/openai_connection.dart';
import 'package:neiroha/data/ai/providers/openai/openai_endpoint.dart';
import 'package:neiroha/domain/ai/ai.dart';

import 'llm_traits_catalog.dart';

typedef ModelLister =
    Future<Map<String, Map<String, dynamic>>> Function(OpenAiEndpoint);

class LlmInventory {
  const LlmInventory(
    this.connection,
    this.models, {
    this.state = HealthState.unknown,
    this.message,
    this.listed,
  });
  final ProviderConnection connection;

  /// Catalog models first (recommended first), then models the account
  /// listed that the plugin catalog does not mount.
  final List<ModelDescriptor> models;

  /// `ok` after a successful live list; `unknown` when the vendor has no
  /// model list (catalog only); `failed` when credentials were rejected.
  final HealthState state;
  final String? message;

  /// Ids the account's model list returned; null without a live list.
  final Set<String>? listed;

  /// A catalog model the account did not list (may be unavailable to it).
  bool unlisted(ModelDescriptor m) => listed != null && !listed!.contains(m.id);

  ModelDescriptor? find(String id) =>
      models.where((m) => m.id == id).firstOrNull;
}

/// Finds a connection's language models and what each can do.
///
/// Traits come, in priority: the vendor's own listing (OpenRouter-style
/// gateways), then the bundled public snapshot for the official vendor,
/// then whatever the plugin catalog declares.
class LlmDiscovery {
  LlmDiscovery(this.catalog, {ModelLister? lister})
    : _lister = lister ?? listOpenAiModels;
  final LlmTraitsCatalog catalog;
  final ModelLister _lister;

  static OpenAiEndpoint? endpointOf(ProviderConnection c) => switch (c) {
    OpenAiConnection() => c.endpoint,
    AdapterBackedConnection() => c.llmEndpoint,
    _ => null,
  };

  /// Catalog models with traits, without any network call.
  LlmInventory offline(ProviderConnection connection) =>
      LlmInventory(connection, [
        for (final m in connection.models(AiCapability.llm))
          _withTraits(connection, m, null),
      ]);

  Future<LlmInventory> discover(ProviderConnection connection) async {
    final base = offline(connection);
    final endpoint = endpointOf(connection);
    if (endpoint == null ||
        !connection.capabilities.contains(AiCapability.llm)) {
      return base;
    }
    final Map<String, Map<String, dynamic>> listed;
    try {
      listed = await _lister(endpoint);
    } on AiProviderException catch (error) {
      final denied = error.statusCode == 401 || error.statusCode == 403;
      return LlmInventory(
        connection,
        base.models,
        state: denied ? HealthState.failed : HealthState.unknown,
        message: '$error',
      );
    } catch (error) {
      return LlmInventory(connection, base.models, message: '$error');
    }

    final vendor = catalogVendor(connection);
    final mounted = {for (final m in base.models) m.id: m};
    // `gpt-5.4-2026-03-05` duplicates `gpt-5.4`; keep pinned ids only when
    // the alias is absent.
    final dated = RegExp(r'^(.+)-\d{4}-\d{2}-\d{2}$');
    final extra = <ModelDescriptor>[];
    for (final MapEntry(key: id, value: raw) in listed.entries) {
      if (mounted.containsKey(id)) {
        mounted[id] = _withTraits(connection, mounted[id]!, raw);
        continue;
      }
      final stated = llmTraitsFromListing(raw);
      // Official vendors list TTS, embeddings and image models too; keep
      // only ids the snapshot knows as chat models, or that the listing
      // itself says produce text. Gateways without facts keep everything.
      final chat =
          catalog.isChatModel(vendor, id) ||
          (stated.outputs?.contains(Modality.text) ?? false) ||
          (vendor == null && stated.isUnknown);
      final protocol = connection.manualProtocol(AiCapability.llm, id);
      final alias = dated.firstMatch(id)?.group(1);
      if (!chat ||
          protocol == null ||
          !catalog.serves(vendor, id, protocol) ||
          (alias != null && listed.containsKey(alias))) {
        continue;
      }
      extra.add(
        _withTraits(
          connection,
          ModelDescriptor(
            id: id,
            capability: AiCapability.llm,
            protocol: protocol,
            displayName: raw['name'] is String ? raw['name'] as String : '',
            source: DescriptorSource.provider,
          ),
          raw,
        ),
      );
    }
    extra.sort((a, b) => a.id.compareTo(b.id));
    return LlmInventory(
      connection,
      [
        for (final m in base.models)
          if (listed.containsKey(m.id)) mounted[m.id]!,
        ...extra,
        // Catalog models the account does not list stay, after the rest.
        for (final m in base.models)
          if (!listed.containsKey(m.id)) m,
      ],
      state: HealthState.ok,
      listed: listed.keys.toSet(),
    );
  }

  ModelDescriptor _withTraits(
    ProviderConnection connection,
    ModelDescriptor model,
    Map<String, dynamic>? listing,
  ) {
    final stated = listing == null ? null : llmTraitsFromListing(listing);
    final known = catalog.lookup(catalogVendor(connection), model.id);
    final declared = model.llm ?? _fromFeatures(model);
    final traits = (stated ?? LlmTraits.unknown).orElse(known).orElse(declared);
    return model.copyWith(llm: traits);
  }

  static LlmTraits? _fromFeatures(ModelDescriptor m) => m.features.isEmpty
      ? null
      : LlmTraits(
          tools: m.has(AiFeature.toolCalls) ? true : null,
          structuredOutput: m.has(AiFeature.structuredOutput) ? true : null,
          reasoning: m.has(AiFeature.reasoning) ? const ReasoningSpec() : null,
        );
}
