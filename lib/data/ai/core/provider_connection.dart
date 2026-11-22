import 'dart:async';

import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/core/connection_config.dart';
import 'package:neiroha/data/ai/core/provider_plugin.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';
import 'package:neiroha/domain/ai/models/language_model.dart';
import 'package:neiroha/domain/ai/models/realtime_model.dart';
import 'package:neiroha/domain/ai/models/speech_synthesizer.dart';
import 'package:neiroha/domain/ai/models/speech_translator.dart';
import 'package:neiroha/domain/ai/models/transcriber.dart';
import 'package:neiroha/domain/ai/models/voice_activity_detector.dart';
import 'package:neiroha/domain/ai/models/voice_converter.dart';

/// One configured account. Capabilities hang off the connection; models hang
/// off capabilities. [open] returns null when the model cannot serve [cap].
abstract class ProviderConnection {
  ProviderConnection(this.plugin, this.config);
  final ProviderPlugin plugin;
  final ConnectionConfig config;

  String get id => config.id;
  Set<AiCapability> get capabilities => plugin.capabilities;
  List<ModelDescriptor> models(AiCapability cap) => plugin.modelsFor(cap);

  ModelDescriptor? defaultModel(AiCapability cap) {
    final all = models(cap);
    if (all.isEmpty) return null;
    return all.firstWhere((m) => m.isDefault, orElse: () => all.first);
  }

  /// Catalog descriptor, or a manual one for ids the catalog does not know.
  ModelDescriptor? describe(AiCapability cap, String modelId) {
    if (!capabilities.contains(cap)) return null;
    for (final model in models(cap)) {
      if (model.id == modelId) return model;
    }
    final protocol = manualProtocol(cap, modelId);
    return protocol == null
        ? null
        : ModelDescriptor.manual(modelId, cap, protocol);
  }

  /// Protocol for a model id outside the catalog; null rejects the id.
  AiProtocol? manualProtocol(AiCapability cap, String modelId) => null;

  CapabilityModel? open(AiCapability cap, String modelId);

  /// Per-capability health, probed with the fewest possible requests.
  Future<Map<AiCapability, CapabilityHealth>> check();
}

extension TypedModels on ProviderConnection {
  T? typed<T extends CapabilityModel>(AiCapability cap, [String? modelId]) {
    final id = modelId ?? defaultModel(cap)?.id;
    if (id == null) return null;
    final model = open(cap, id);
    return model is T ? model : null;
  }

  LanguageModel? languageModel([String? id]) => typed(AiCapability.llm, id);
  SpeechSynthesizer? speechModel([String? id]) => typed(AiCapability.tts, id);
  Transcriber? transcriber([String? id]) => typed(AiCapability.stt, id);
  StreamingTranscriber? streamingTranscriber([String? id]) =>
      typed(AiCapability.stt, id);
  RealtimeModel? realtimeModel([String? id]) =>
      typed(AiCapability.realtime, id);
  SpeechTranslator? translator([String? id]) =>
      typed(AiCapability.translate, id);
  VoiceConverter? voiceConverter([String? id]) => typed(AiCapability.vc, id);
  VoiceActivityDetector? vad([String? id]) => typed(AiCapability.vad, id);
}
