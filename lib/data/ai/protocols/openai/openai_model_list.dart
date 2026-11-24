import 'package:neiroha/data/ai/protocols/openai/openai_dio.dart';
import 'package:neiroha/data/ai/providers/openai/openai_endpoint.dart';
import 'package:neiroha/domain/ai/llm_traits.dart';

/// `GET models` on an OpenAI-shaped endpoint; raw entries keyed by id, with
/// Gemini's `models/` prefix removed.
Future<Map<String, Map<String, dynamic>>> listOpenAiModels(
  OpenAiEndpoint endpoint, {
  Duration timeout = const Duration(seconds: 30),
}) {
  final dio = openAiDio(
    endpoint.baseUrl,
    endpoint.apiKey,
    apiKeyHeader: endpoint.apiKeyHeader,
    timeout: timeout,
  );
  return withCancel(null, endpoint.apiKey, (token) async {
    final response = await dio.get<dynamic>('models', cancelToken: token);
    final data = response.data;
    final list = data is Map ? data['data'] ?? data['models'] : data;
    return {
      if (list is List)
        for (final item in list.whereType<Map>())
          if (item['id'] case final String id when id.isNotEmpty)
            id.replaceFirst('models/', ''): Map<String, dynamic>.from(item),
    };
  });
}

/// Traits a gateway states in its model list (OpenRouter-style
/// `architecture` and `supported_parameters`). OpenAI's own list carries
/// none, so this returns [LlmTraits.unknown] there.
LlmTraits llmTraitsFromListing(Map<String, dynamic> raw) {
  final architecture = raw['architecture'];
  Set<Modality>? modalities(Object? list) => list is List
      ? {
          for (final m in list)
            ?switch ('$m') {
              'text' => Modality.text,
              'image' => Modality.image,
              'audio' => Modality.audio,
              'video' => Modality.video,
              'file' || 'pdf' => Modality.pdf,
              _ => null,
            },
        }
      : null;
  final params = raw['supported_parameters'];
  bool? has(List<String> names) =>
      params is List ? names.any(params.contains) : null;
  final reasons = has(const ['reasoning', 'include_reasoning']);
  final topProvider = raw['top_provider'];
  // OpenRouter: {supported_efforts: [...], default_effort, mandatory}.
  final spec = raw['reasoning'];
  ReasoningSpec? stated;
  if (spec is Map && spec['supported_efforts'] is List) {
    final byName = ReasoningEffort.values.asNameMap();
    final levels = {
      for (final e in spec['supported_efforts'] as List) ?byName['$e'],
      // Optional thinking can be switched off even when `none` is unlisted.
      if (spec['mandatory'] == false) ReasoningEffort.none,
    }.toList()..sort((a, b) => a.index.compareTo(b.index));
    stated = ReasoningSpec(
      levels: levels,
      defaultLevel: byName['${spec['default_effort']}'],
    );
  }
  return LlmTraits(
    inputs: architecture is Map
        ? modalities(architecture['input_modalities'])
        : null,
    outputs: architecture is Map
        ? modalities(architecture['output_modalities'])
        : null,
    tools: has(const ['tools']),
    structuredOutput: has(const ['structured_outputs', 'response_format']),
    reasoning:
        stated ??
        (reasons == null
            ? null
            : reasons
            ? const ReasoningSpec()
            : ReasoningSpec.unsupported),
    contextWindow: (raw['context_length'] as num?)?.toInt(),
    maxOutputTokens: topProvider is Map
        ? (topProvider['max_completion_tokens'] as num?)?.toInt()
        : null,
  );
}

/// ISO date after which the listing says the model stops serving
/// (OpenRouter `expiration_date`), or null.
String? listedShutdown(Map<String, dynamic> raw) {
  final date = raw['expiration_date'];
  return date is String && DateTime.tryParse(date) != null
      ? date.substring(0, 10)
      : null;
}

/// Endpoint paths the listing declares (OpenRouter `endpoints`), or null.
List<String>? listedEndpoints(Map<String, dynamic> raw) {
  final endpoints = raw['endpoints'] ?? raw['supported_endpoints'];
  return endpoints is List ? [for (final e in endpoints) '$e'] : null;
}
