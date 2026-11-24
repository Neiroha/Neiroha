import 'package:neiroha/data/ai/core/connection_config.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/llm_traits.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';

/// A vendor (or local engine) and everything it can provide.
abstract class ProviderPlugin {
  const ProviderPlugin();
  String get id;
  String get displayName;
  Set<AiCapability> get capabilities;
  List<ModelDescriptor> get catalog;
  ProviderConnection connect(ConnectionConfig config);

  /// Default thinking level per LLM id, from vendor docs. Public catalogs
  /// list which levels exist but not which one the vendor applies.
  Map<String, ReasoningEffort> get reasoningDefaults => const {};

  List<ModelDescriptor> modelsFor(AiCapability capability) => [
    for (final model in catalog)
      if (model.capability == capability) model,
  ];
}
