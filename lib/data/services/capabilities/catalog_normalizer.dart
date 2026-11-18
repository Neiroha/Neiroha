/// Pure Dart normalization shared by the maintenance tool and runtime refresh.
/// Missing fields remain unknown; a catalog never proves account availability.
Map<String, Object?> normalizeLiteLlmCatalog(
  Map<String, dynamic> source, {
  required String digest,
}) {
  final models = <String, Object?>{};
  for (final entry in source.entries) {
    if (entry.key == 'sample_spec' || entry.value is! Map) continue;
    final raw = Map<String, dynamic>.from(entry.value as Map);
    final provider = raw['litellm_provider'];
    if (provider is! String || provider.isEmpty) continue;
    final model = entry.key.startsWith('$provider/')
        ? entry.key.substring(provider.length + 1)
        : entry.key;
    final facts = <String, String>{};
    if (raw['mode'] == 'chat' || raw['mode'] == 'completion') {
      facts['text'] = 'supported';
    }
    if (raw['mode'] == 'audio_speech') facts['speech'] = 'supported';
    for (final (key, target) in [
      ('supports_response_schema', 'structuredOutput'),
      ('supports_function_calling', 'functionCalling'),
      ('supports_audio_output', 'audioOutput'),
    ]) {
      if (raw[key] is bool) {
        facts[target] = raw[key] == true ? 'supported' : 'unsupported';
      }
    }
    final endpoints = raw['supported_endpoints'];
    models['$provider::$model'] = {
      'facts': facts,
      'endpoints': endpoints is List
          ? endpoints.whereType<String>().toList()
          : <String>[],
    };
  }
  if (models.isEmpty) {
    throw const FormatException(
      'Public catalog contained no valid model records.',
    );
  }
  return {
    'version': 1,
    'source':
        'https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json',
    'sourceSha256': digest,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'models': models,
  };
}
