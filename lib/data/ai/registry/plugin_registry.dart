import 'package:neiroha/data/ai/core/connection_config.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/core/provider_plugin.dart';
import 'package:neiroha/data/ai/providers/elevenlabs/elevenlabs_plugin.dart';
import 'package:neiroha/data/ai/providers/gemini/gemini_plugin.dart';
import 'package:neiroha/data/ai/providers/local/rvc/rvc_plugin.dart';
import 'package:neiroha/data/ai/providers/mimo/mimo_plugin.dart';
import 'package:neiroha/data/ai/providers/minimax/minimax_plugin.dart';
import 'package:neiroha/data/ai/providers/on_device/on_device_plugin.dart';
import 'package:neiroha/data/ai/providers/common/adapter_tts_plugin.dart';
import 'package:neiroha/data/ai/providers/openai/openai_plugin.dart';
import 'package:neiroha/data/ai/providers/openai_compatible/openai_compatible_plugin.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';

/// Plugin serving a `TtsProviders.adapterType`, so v34 can migrate rows
/// one-to-one. Vendors with more than TTS get their own plugin; TTS-only
/// engines (Azure, local servers) share [AdapterTtsPlugin]; the OS voice is
/// part of [OnDevicePlugin].
ProviderPlugin pluginForAdapterType(String adapterType, {String baseUrl = ''}) {
  final type = AdapterType.values.asNameMap()[adapterType];
  if (type == null) throw ArgumentError('Unknown adapter type: $adapterType');
  return switch (type) {
    AdapterType.openaiTts => const OpenAiPlugin(),
    AdapterType.openaiCompatible => const OpenAiCompatiblePlugin(),
    AdapterType.elevenLabs => const ElevenLabsPlugin(),
    AdapterType.geminiTts => const GeminiPlugin(),
    AdapterType.minimaxTts => const MiniMaxPlugin(),
    AdapterType.chatCompletionsTts =>
      baseUrl.trim().isEmpty ||
              Uri.tryParse(baseUrl.trim())?.host == MiMoPlugin.officialHost
          ? const MiMoPlugin()
          : const ChatCompletionsTtsPlugin(),
    AdapterType.systemTts => OnDevicePlugin(),
    AdapterType.rvc => const RvcPlugin(),
    _ => AdapterTtsPlugin(type),
  };
}

ProviderConnection connectionForProvider(db.TtsProvider row) =>
    pluginForAdapterType(row.adapterType, baseUrl: row.baseUrl).connect(
      ConnectionConfig(
        id: row.id,
        name: row.name,
        baseUrl: row.baseUrl,
        apiKey: row.apiKey,
        options: {
          AdapterOptions.adapterType: row.adapterType,
          AdapterOptions.defaultModel: row.defaultModelName,
        },
      ),
    );

/// Whether a provider row offers a language model (for pickers that list
/// "who can do LLM" before the user chooses).
bool providerOffersLlm(db.TtsProvider row) =>
    AdapterType.values.asNameMap()[row.adapterType] != null &&
    connectionForProvider(row).capabilities.contains(AiCapability.llm);
