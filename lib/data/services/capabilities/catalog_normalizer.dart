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

/// models.dev provider → snapshot vendor key (see `catalogVendor`). Regional
/// duplicates fold into one key; earlier providers win per model id.
const modelsDevVendors = <String, List<String>>{
  'openai': ['openai'],
  'gemini': ['google'],
  'xiaomi_mimo': ['xiaomi'],
  'minimax': ['minimax', 'minimax-cn'],
  'deepseek': ['deepseek'],
  'moonshot': ['moonshotai', 'moonshotai-cn'],
  'dashscope': ['alibaba', 'alibaba-cn'],
  'zai': ['zhipuai', 'zai'],
  'xai': ['xai'],
  'mistral': ['mistral'],
  'groq': ['groq'],
};

/// models.dev `api.json` → the snapshot shape `LlmTraitsCatalog` reads.
/// Keeps chat models of the vendors Neiroha connects to directly; gateways
/// (OpenRouter) describe themselves in their own listing.
Map<String, Object?> normalizeModelsDevCatalog(
  Map<String, dynamic> source, {
  required String digest,
}) {
  final models = <String, Object?>{};
  for (final MapEntry(key: vendor, value: providers)
      in modelsDevVendors.entries) {
    for (final provider in providers) {
      final entry = source[provider];
      if (entry is! Map || entry['models'] is! Map) continue;
      for (final MapEntry(:key, :value) in (entry['models'] as Map).entries) {
        if (value is! Map) continue;
        final raw = Map<String, dynamic>.from(value);
        final key2 = '$vendor::$key';
        if (models.containsKey(key2)) continue;
        final type = raw['type'];
        final outputs = (raw['modalities'] as Map?)?['output'];
        if ((type != null && type != 'chat') ||
            (outputs is List && !outputs.contains('text'))) {
          continue;
        }
        final llm = llmTraitsFromModelsDev(raw);
        if (llm.isEmpty) continue;
        models[key2] = {
          'llm': llm,
          if (raw['name'] is String) 'name': raw['name'],
          if (raw['status'] == 'deprecated') 'deprecated': true,
          if (raw['release_date'] is String) 'released': raw['release_date'],
        };
      }
    }
  }
  if (models.isEmpty) {
    throw const FormatException('models.dev contained no usable chat models.');
  }
  return {
    'version': 1,
    'source': 'https://models.dev/api.json',
    'license': 'MIT (c) models.dev',
    'sourceSha256': digest,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'models': models,
  };
}

/// One models.dev model → `LlmTraits` JSON. Only stated fields are kept.
Map<String, Object?> llmTraitsFromModelsDev(Map<String, dynamic> raw) {
  final out = <String, Object?>{};
  const known = {'text', 'image', 'audio', 'video', 'pdf'};
  final modalities = raw['modalities'];
  if (modalities is Map) {
    for (final (from, to) in [('input', 'in'), ('output', 'out')]) {
      final list = modalities[from];
      if (list is List) {
        out[to] = [
          for (final m in list)
            if (known.contains('$m')) '$m',
        ];
      }
    }
  }
  if (raw['tool_call'] is bool) out['tools'] = raw['tool_call'];
  if (raw['structured_output'] is bool) {
    out['schema'] = raw['structured_output'];
  }
  if (raw['reasoning'] == false) {
    out['reasoning'] = {'supported': false};
  } else if (raw['reasoning'] == true) {
    final options = raw['reasoning_options'];
    final efforts = <String>{};
    var toggle = false;
    if (options is List) {
      for (final o in options.whereType<Map>()) {
        if (o['type'] == 'effort' && o['values'] is List) {
          efforts.addAll([
            for (final v in o['values'] as List)
              if (_efforts.contains('$v')) '$v',
          ]);
        }
        if (o['type'] == 'toggle') toggle = true;
      }
    }
    // A thinking switch alongside effort levels means it can be turned off.
    if (toggle && efforts.isNotEmpty) efforts.add('none');
    out['reasoning'] = {
      if (efforts.isNotEmpty)
        'levels': [
          for (final l in _efforts)
            if (efforts.contains(l)) l,
        ],
    };
  }
  final limit = raw['limit'];
  if (limit is Map) {
    if (limit['context'] case final num v when v > 0) {
      out['context'] = v.toInt();
    }
    if (limit['output'] case final num v when v > 0) out['maxOut'] = v.toInt();
  }
  return out;
}
