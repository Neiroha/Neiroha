import 'dart:async';

import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/protocols/openai/openai_dio.dart';
import 'package:neiroha/data/ai/providers/openai/openai_endpoint.dart';
import 'package:neiroha/data/ai/providers/openai/openai_model_factory.dart';
import 'package:neiroha/data/ai/providers/openai/tts/openai_tts_adapter.dart';
import 'package:neiroha/domain/ai/ai_exception.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';

class OpenAiConnection extends ProviderConnection {
  OpenAiConnection(super.plugin, super.config);

  OpenAiEndpoint get endpoint => OpenAiEndpoint(
    config.baseUrl.trim().isEmpty
        ? OpenAiTtsAdapter.defaultBaseUrl
        : config.baseUrl,
    config.apiKey,
  );

  @override
  AiProtocol? manualProtocol(AiCapability cap, String modelId) => switch (cap) {
    AiCapability.llm => AiProtocol.openAiResponses,
    AiCapability.tts =>
      OpenAiTtsAdapter.usesRealtime(modelId)
          ? AiProtocol.openAiRealtime
          : AiProtocol.openAiSpeech,
    AiCapability.stt => AiProtocol.openAiTranscription,
    AiCapability.realtime => AiProtocol.openAiRealtime,
    AiCapability.translate => AiProtocol.openAiRealtimeTranslation,
    _ => null,
  };

  @override
  CapabilityModel? open(AiCapability cap, String modelId) {
    final descriptor = describe(cap, modelId);
    return descriptor == null ? null : openOpenAiModel(descriptor, endpoint);
  }

  /// One `GET /models` call answers every capability.
  @override
  Future<Map<AiCapability, CapabilityHealth>> check() async {
    try {
      final visible = await listModelIds();
      return {
        for (final cap in capabilities)
          cap: () {
            final seen = [
              for (final m in models(cap))
                if (visible.contains(m.id)) m.id,
            ];
            return CapabilityHealth(
              seen.isEmpty ? HealthState.unavailable : HealthState.ok,
              models: seen,
            );
          }(),
      };
    } on AiProviderException catch (error) {
      return {
        for (final cap in capabilities)
          cap: CapabilityHealth(HealthState.failed, message: '$error'),
      };
    }
  }

  Future<Set<String>> listModelIds() async {
    final dio = openAiDio(endpoint.baseUrl, endpoint.apiKey);
    return withCancel(null, endpoint.apiKey, (token) async {
      final response = await dio.get<dynamic>('models', cancelToken: token);
      final data = response.data;
      return {
        if (data is Map && data['data'] is List)
          for (final item in (data['data'] as List).whereType<Map>())
            '${item['id']}',
      };
    });
  }
}
