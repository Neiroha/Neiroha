import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/protocols/openai/openai_dio.dart';
import 'package:neiroha/data/ai/providers/openai/llm/openai_language_model.dart';
import 'package:neiroha/data/ai/providers/openai/openai_endpoint.dart';
import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/capabilities/role_ai_connection.dart';
import 'package:neiroha/domain/ai/ai_exception.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';

import 'adapter_speech_synthesizer.dart';
import 'adapter_tts_plugin.dart';

/// Connection for vendors with a native TTS adapter. TTS goes through
/// `createAdapter`; LLM always uses the OpenAI Chat Completions protocol on
/// the vendor's text endpoint ([llmEndpoint]).
class AdapterBackedConnection extends ProviderConnection {
  AdapterBackedConnection(AdapterTtsPlugin super.plugin, super.config);

  AdapterTtsPlugin get adapterPlugin => plugin as AdapterTtsPlugin;
  db.TtsProvider get row => adapterPlugin.rowFor(config);

  /// Gemini `/v1beta/openai/`, MiniMax `/v1/`, MiMo `api-key` header.
  OpenAiEndpoint get llmEndpoint => OpenAiEndpoint(
    row.roleAiBaseUrl,
    config.apiKey,
    apiKeyHeader: row.roleAiKeyHeader,
  );

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
      AiCapability.tts => AdapterSpeechSynthesizer(
        descriptor,
        createAdapter(row, modelName: modelId == 'default' ? null : modelId),
      ),
      AiCapability.llm => OpenAiLanguageModel(descriptor, llmEndpoint),
      _ => null,
    };
  }

  @override
  Future<Map<AiCapability, CapabilityHealth>> check() async => {
    if (capabilities.contains(AiCapability.tts))
      AiCapability.tts: await checkTts(),
    if (capabilities.contains(AiCapability.llm))
      AiCapability.llm: await checkLlm(),
  };

  Future<CapabilityHealth> checkTts() async {
    try {
      final healthy = await createAdapter(row).healthCheck();
      return CapabilityHealth(
        healthy ? HealthState.ok : HealthState.failed,
        models: healthy ? [defaultModel(AiCapability.tts)!.id] : const [],
      );
    } catch (error) {
      return CapabilityHealth(HealthState.failed, message: '$error');
    }
  }

  /// `GET models` on the text endpoint. Rejected credentials fail; a vendor
  /// without a model list stays unknown rather than failed.
  Future<CapabilityHealth> checkLlm() async {
    final endpoint = llmEndpoint;
    final dio = openAiDio(
      endpoint.baseUrl,
      endpoint.apiKey,
      apiKeyHeader: endpoint.apiKeyHeader,
      timeout: const Duration(seconds: 30),
    );
    try {
      final ids = await withCancel(null, endpoint.apiKey, (token) async {
        final response = await dio.get<dynamic>('models', cancelToken: token);
        final data = response.data;
        return {
          if (data is Map && data['data'] is List)
            for (final item in (data['data'] as List).whereType<Map>())
              '${item['id']}'.replaceFirst('models/', ''),
        };
      });
      return CapabilityHealth(
        HealthState.ok,
        models: [
          for (final m in models(AiCapability.llm))
            if (ids.contains(m.id)) m.id,
        ],
      );
    } on AiProviderException catch (error) {
      final denied = error.statusCode == 401 || error.statusCode == 403;
      return CapabilityHealth(
        denied ? HealthState.failed : HealthState.unknown,
        message: '$error',
      );
    } catch (error) {
      return CapabilityHealth(HealthState.unknown, message: '$error');
    }
  }
}
