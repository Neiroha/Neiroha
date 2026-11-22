import 'package:neiroha/data/ai/core/connection_config.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/core/provider_plugin.dart';
import 'package:neiroha/data/ai/providers/elevenlabs/elevenlabs_plugin.dart';
import 'package:neiroha/data/ai/providers/legacy/legacy_options.dart';
import 'package:neiroha/data/ai/providers/legacy/legacy_tts_plugin.dart';
import 'package:neiroha/data/ai/providers/openai/openai_plugin.dart';
import 'package:neiroha/data/ai/providers/openai_compatible/openai_compatible_plugin.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/enums/adapter_type.dart';

/// Plugin serving a legacy `TtsProviders.adapterType`. Every adapter type
/// maps to exactly one plugin so v34 can migrate rows one-to-one.
ProviderPlugin pluginForAdapterType(String adapterType) {
  final type = AdapterType.values.asNameMap()[adapterType];
  if (type == null) throw ArgumentError('Unknown adapter type: $adapterType');
  return switch (type) {
    AdapterType.openaiTts => const OpenAiPlugin(),
    AdapterType.openaiCompatible => const OpenAiCompatiblePlugin(),
    AdapterType.elevenLabs => const ElevenLabsPlugin(),
    _ => LegacyTtsPlugin(type),
  };
}

ProviderConnection connectionForProvider(db.TtsProvider row) =>
    pluginForAdapterType(row.adapterType).connect(
      ConnectionConfig(
        id: row.id,
        name: row.name,
        baseUrl: row.baseUrl,
        apiKey: row.apiKey,
        options: {
          LegacyOptions.adapterType: row.adapterType,
          LegacyOptions.defaultModel: row.defaultModelName,
        },
      ),
    );
