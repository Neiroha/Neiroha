import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/llm_traits.dart';

/// LLM traits from the bundled public snapshot
/// (`assets/model_catalog/model_capabilities.snapshot.json`, normalized from
/// LiteLLM). Lookups are exact per vendor: gateway aliases are never matched
/// to official facts by name.
class LlmTraitsCatalog {
  const LlmTraitsCatalog(this._entries, [this._endpoints = const {}]);
  static const empty = LlmTraitsCatalog({});
  static const asset = 'assets/model_catalog/model_capabilities.snapshot.json';

  final Map<String, LlmTraits> _entries;
  final Map<String, List<String>> _endpoints;

  factory LlmTraitsCatalog.fromSnapshot(Map<String, dynamic> snapshot) {
    final models = snapshot['models'];
    final llms = <String, Map>{
      if (models is Map)
        for (final MapEntry(:key, :value) in models.entries)
          if (value is Map && value['llm'] is Map) '$key': value,
    };
    return LlmTraitsCatalog(
      {
        for (final MapEntry(:key, :value) in llms.entries)
          key: LlmTraits.fromJson(
            Map<String, dynamic>.from(value['llm'] as Map),
          ),
      },
      {
        for (final MapEntry(:key, :value) in llms.entries)
          if (value['endpoints'] is List &&
              (value['endpoints'] as List).isNotEmpty)
            key: [for (final e in value['endpoints'] as List) '$e'],
      },
    );
  }

  static Future<LlmTraitsCatalog>? _bundled;

  /// The bundled snapshot, parsed once.
  static Future<LlmTraitsCatalog> bundled() => _bundled ??= rootBundle
      .loadString(asset)
      .then(
        (raw) => LlmTraitsCatalog.fromSnapshot(
          jsonDecode(raw) as Map<String, dynamic>,
        ),
      );

  int get length => _entries.length;

  LlmTraits? lookup(String? vendor, String modelId) =>
      vendor == null ? null : _entries['$vendor::$modelId'];

  /// False only when the snapshot lists the model's endpoints and none of
  /// them speaks [protocol].
  bool serves(String? vendor, String modelId, AiProtocol protocol) {
    final endpoints = vendor == null ? null : _endpoints['$vendor::$modelId'];
    if (endpoints == null) return true;
    final path = switch (protocol) {
      AiProtocol.openAiResponses => '/responses',
      AiProtocol.openAiChat => '/chat/completions',
      _ => null,
    };
    return path == null || endpoints.any((e) => e.endsWith(path));
  }

  /// Whether the snapshot knows [modelId] as a chat model at [vendor].
  /// Models that only produce audio (TTS, music) are not.
  bool isChatModel(String? vendor, String modelId) {
    final traits = lookup(vendor, modelId);
    if (traits == null) return false;
    return traits.outputs?.contains(Modality.text) ?? true;
  }
}

/// Snapshot vendor key for a connection, or null for custom gateways whose
/// model ids may be aliases.
String? catalogVendor(ProviderConnection connection) {
  final base = connection.config.baseUrl.trim();
  final host = base.isEmpty ? null : Uri.tryParse(base)?.host;
  bool official(String expected) => host == null || host == expected;
  return switch (connection.plugin.id) {
    'openai' => official('api.openai.com') ? 'openai' : null,
    'gemini' => official('generativelanguage.googleapis.com') ? 'gemini' : null,
    'minimax' =>
      host == null || host.startsWith('api.minimax') ? 'minimax' : null,
    'mimo' => official('api.xiaomimimo.com') ? 'xiaomi_mimo' : null,
    'openai-compatible' => switch (host) {
      'openrouter.ai' => 'openrouter',
      'api.deepseek.com' => 'deepseek',
      'api.moonshot.ai' || 'api.moonshot.cn' => 'moonshot',
      'dashscope.aliyuncs.com' || 'dashscope-intl.aliyuncs.com' => 'dashscope',
      'open.bigmodel.cn' => 'zai',
      'api.x.ai' => 'xai',
      'api.mistral.ai' => 'mistral',
      'api.groq.com' => 'groq',
      _ => null,
    },
    _ => null,
  };
}
