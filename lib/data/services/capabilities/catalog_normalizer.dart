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
    final llm = raw['mode'] == 'chat' || raw['mode'] == 'responses'
        ? llmTraitsFromLiteLlm(raw)
        : null;
    models['$provider::$model'] = {
      'facts': facts,
      'endpoints': endpoints is List
          ? endpoints.whereType<String>().toList()
          : <String>[],
      if (llm != null && llm.isNotEmpty) 'llm': llm,
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

const _efforts = ['none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max'];

/// LiteLLM model record → `LlmTraits` JSON (see `LlmTraits.fromJson`).
/// Only explicit fields are kept; absent flags stay unknown.
Map<String, Object?> llmTraitsFromLiteLlm(Map<String, dynamic> raw) {
  bool? flag(String key) => raw[key] is bool ? raw[key] as bool : null;
  final out = <String, Object?>{};

  final modalities = raw['supported_modalities'];
  final vision = flag('supports_vision');
  final audio = flag('supports_audio_input');
  final video = flag('supports_video_input');
  final pdf = flag('supports_pdf_input');
  if (modalities is List || vision != null || audio != null || video != null) {
    out['in'] = <String>{
      'text',
      if (modalities is List)
        for (final m in modalities)
          if (const ['image', 'audio', 'video'].contains(m)) '$m',
      if (vision == true) 'image',
      if (audio == true) 'audio',
      if (video == true) 'video',
      if (pdf == true) 'pdf',
    }.toList();
  }
  final outputs = raw['supported_output_modalities'];
  if (outputs is List) {
    out['out'] = [
      for (final m in outputs)
        if (const ['text', 'image', 'audio'].contains(m)) '$m',
    ];
  }
  for (final (key, target) in [
    ('supports_function_calling', 'tools'),
    ('supports_parallel_function_calling', 'parallelTools'),
    ('supports_response_schema', 'schema'),
  ]) {
    if (flag(key) != null) out[target] = flag(key);
  }

  final reasons = flag('supports_reasoning');
  final explicit = raw['reasoning_effort_levels'];
  final fine = {
    for (final level in _efforts)
      if (flag('supports_${level}_reasoning_effort') != null)
        level: flag('supports_${level}_reasoning_effort')!,
  };
  final fallback = raw['default_reasoning_effort'];
  if (reasons == false) {
    out['reasoning'] = {'supported': false};
  } else if (reasons == true || explicit is List || fine.isNotEmpty) {
    List<String> levels;
    if (explicit is List) {
      levels = [
        for (final l in _efforts)
          if (explicit.contains(l)) l,
      ];
    } else if (fine.isNotEmpty || fallback is String) {
      // The OpenAI-style base set plus the levels flagged on or off.
      levels = [
        for (final l in _efforts)
          if (fine[l] ?? const ['low', 'medium', 'high'].contains(l)) l,
      ];
    } else {
      levels = const [];
    }
    final modes = raw['reasoning_modes'];
    out['reasoning'] = {
      if (levels.isNotEmpty) 'levels': levels,
      if (fallback is String && _efforts.contains(fallback))
        'default': fallback,
      if (modes is List && modes.length > 1)
        'modes': [for (final m in modes) '$m'],
    };
  }
  if (raw['max_input_tokens'] case final num v) out['context'] = v.toInt();
  if (raw['max_output_tokens'] case final num v) out['maxOut'] = v.toInt();
  return out;
}
