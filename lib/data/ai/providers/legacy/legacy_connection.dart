import 'dart:async';

import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/providers/legacy/legacy_tts_plugin.dart';
import 'package:neiroha/data/ai/providers/legacy/llm/legacy_language_model.dart';
import 'package:neiroha/data/ai/providers/legacy/tts/legacy_speech_synthesizer.dart';
import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';

class LegacyConnection extends ProviderConnection {
  LegacyConnection(LegacyTtsPlugin super.plugin, super.config);

  LegacyTtsPlugin get legacy => plugin as LegacyTtsPlugin;
  db.TtsProvider get row => legacy.rowFor(config);

  @override
  AiProtocol? manualProtocol(AiCapability cap, String modelId) => switch (cap) {
    AiCapability.tts => AiProtocol.native,
    AiCapability.llm => AiProtocol.openAiChat,
    _ => null,
  };

  @override
  CapabilityModel? open(AiCapability cap, String modelId) {
    final descriptor = describe(cap, modelId);
    if (descriptor == null) return null;
    return switch (cap) {
      AiCapability.tts => LegacySpeechSynthesizer(
        descriptor,
        createAdapter(row, modelName: modelId == 'default' ? null : modelId),
      ),
      AiCapability.llm => LegacyLanguageModel(descriptor, row),
      _ => null,
    };
  }

  @override
  Future<Map<AiCapability, CapabilityHealth>> check() async {
    final tts = defaultModel(AiCapability.tts)!;
    bool healthy;
    String? message;
    try {
      healthy = await createAdapter(row).healthCheck();
    } catch (error) {
      healthy = false;
      message = '$error';
    }
    final state = healthy ? HealthState.ok : HealthState.failed;
    return {
      AiCapability.tts: CapabilityHealth(
        state,
        models: healthy ? [tts.id] : const [],
        message: message,
      ),
      if (capabilities.contains(AiCapability.llm))
        AiCapability.llm: CapabilityHealth(
          healthy ? HealthState.unknown : HealthState.failed,
        ),
    };
  }
}
