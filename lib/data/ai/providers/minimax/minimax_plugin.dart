import 'package:neiroha/data/ai/providers/common/adapter_tts_plugin.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';

import 'minimax_catalog.dart';

/// MiniMax: native T2A speech (with cloud voice clone) plus MiniMax-M text
/// models under the same key and region.
class MiniMaxPlugin extends AdapterTtsPlugin {
  const MiniMaxPlugin() : super(AdapterType.minimaxTts);
  @override
  String get id => 'minimax';
  @override
  String get displayName => 'MiniMax';
  @override
  Set<AiCapability> get capabilities => const {
    AiCapability.tts,
    AiCapability.llm,
  };
  @override
  List<ModelDescriptor> get catalog => [ttsDescriptor, ...miniMaxLlmCatalog];
}
