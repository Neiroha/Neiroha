import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/llm_traits.dart';

/// LLM traits from public catalogs, layered: a fresh models.dev download,
/// the bundled models.dev snapshot (official vendors), then the bundled
/// LiteLLM snapshot as fallback. Lookups are exact per vendor: gateway
/// aliases are never matched to official facts by name.
class LlmTraitsCatalog {
  const LlmTraitsCatalog(
    this._entries, [
    this._endpoints = const {},
    this._deprecated = const {},
    this.sources = const [],
    this._meta = const {},
  ]);
  static const empty = LlmTraitsCatalog({});
  static const asset = 'assets/model_catalog/model_capabilities.snapshot.json';
  static const modelsDevAsset = 'assets/model_catalog/models_dev.snapshot.json';

  final Map<String, LlmTraits> _entries;
  final Map<String, List<String>> _endpoints;
  final Set<String> _deprecated;

  /// Where the facts came from, most trusted first (`models.dev 2026-11-23`).
  final List<String> sources;

  /// key → (display name, release date) for catalogs that list them.
  final Map<String, (String, String)> _meta;

  factory LlmTraitsCatalog.fromSnapshot(Map<String, dynamic> snapshot) {
    final models = snapshot['models'];
    final llms = <String, Map>{
      if (models is Map)
        for (final MapEntry(:key, :value) in models.entries)
          if (value is Map && value['llm'] is Map) '$key': value,
    };
    final source = snapshot['source'];
    final generated = '${snapshot['generatedAt'] ?? ''}';
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
      {
        for (final MapEntry(:key, :value) in llms.entries)
          if (value['deprecated'] == true) key,
      },
      [
        if (source is String)
          '${Uri.tryParse(source)?.host ?? source}'
              '${generated.length >= 10 ? ' ${generated.substring(0, 10)}' : ''}',
      ],
      {
        for (final MapEntry(:key, :value) in llms.entries)
          if (value['name'] is String)
            key: ('${value['name']}', '${value['released'] ?? ''}'),
      },
    );
  }

  /// This catalog's facts, with gaps filled from [fallback] per model.
  LlmTraitsCatalog over(LlmTraitsCatalog fallback) => LlmTraitsCatalog(
    {
      ...fallback._entries,
      for (final MapEntry(:key, :value) in _entries.entries)
        key: value.orElse(fallback._entries[key]),
    },
    {...fallback._endpoints, ..._endpoints},
    // A newer source decides deprecation for models it knows.
    {
      for (final k in fallback._deprecated)
        if (!_entries.containsKey(k)) k,
      ..._deprecated,
    },
    [...sources, ...fallback.sources],
    {...fallback._meta, ..._meta},
  );

  static Future<LlmTraitsCatalog>? _bundled;

  /// Bundled models.dev over bundled LiteLLM, parsed once.
  static Future<LlmTraitsCatalog> bundled() => _bundled ??= () async {
    Future<LlmTraitsCatalog> load(String path) async {
      try {
        return LlmTraitsCatalog.fromSnapshot(
          jsonDecode(await rootBundle.loadString(path)) as Map<String, dynamic>,
        );
      } catch (_) {
        return empty;
      }
    }

    return (await load(modelsDevAsset)).over(await load(asset));
  }();

  int get length => _entries.length;

  /// Chat models a vendor publishes (catalogs with names only), newest
  /// first, deprecated ones left out: the offline model list for official
  /// connections, replacing hand-written plugin entries.
  List<({String id, String name})> vendorModels(String? vendor) {
    if (vendor == null) return const [];
    final prefix = '$vendor::';
    final rows =
        [
          for (final MapEntry(:key, :value) in _meta.entries)
            if (key.startsWith(prefix) &&
                !_deprecated.contains(key) &&
                isChatModel(vendor, key.substring(prefix.length)))
              (
                id: key.substring(prefix.length),
                name: value.$1,
                released: value.$2,
              ),
        ]..sort((a, b) {
          final byDate = b.released.compareTo(a.released);
          return byDate != 0 ? byDate : a.id.compareTo(b.id);
        });
    return [for (final r in rows) (id: r.id, name: r.name)];
  }

  /// The catalog marks the model deprecated (models.dev `status`).
  bool isDeprecated(String? vendor, String modelId) =>
      vendor != null && _deprecated.contains('$vendor::$modelId');

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
