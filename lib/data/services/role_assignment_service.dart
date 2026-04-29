import 'dart:convert';

import 'package:neiroha/data/adapters/llm_chat_adapter.dart';

/// Result of [RoleAssignmentService.assignRoles].
class RoleAssignmentResult {
  final List<RoleAssignment> assignments;
  final String fallbackSpeaker;
  final String rawResponse;

  const RoleAssignmentResult({
    required this.assignments,
    required this.fallbackSpeaker,
    required this.rawResponse,
  });
}

/// One LLM-classified segment, with character + suggested voice mapping.
///
/// [start] / [end] are byte-stable offsets into the original document text
/// (so the UI can highlight, and so future edits know which slice the
/// segment belongs to).
class RoleAssignment {
  final int index;
  final String speakerLabel;
  final String category; // narration | dialogue | thought | system
  final String categoryDisplay; // 旁白 / 对话 / 心理 / 系统 / 未分类
  final String text;
  final double? confidence;
  final String reason;
  final int? start;
  final int? end;

  /// Voice-config name we suggest binding to [speakerLabel]. Empty when
  /// no confident match was found.
  final String suggestedVoice;

  const RoleAssignment({
    required this.index,
    required this.speakerLabel,
    required this.category,
    required this.categoryDisplay,
    required this.text,
    required this.confidence,
    required this.reason,
    required this.start,
    required this.end,
    required this.suggestedVoice,
  });
}

class RoleAssignmentError implements Exception {
  final String message;
  const RoleAssignmentError(this.message);
  @override
  String toString() => 'RoleAssignmentError: $message';
}

/// Asks an OpenAI-compatible chat model to segment a long script and label
/// each segment with `category` (旁白/对话/心理/系统) + `speaker_label`
/// (the in-text character name, NOT the local voice-config name).
///
/// Mirrors CosyVoiceDesktop's `core/role_assigner.py`, which in turn was
/// designed around three real-world failure modes the prompt explicitly
/// guards against:
///   1. The model collapses long text into a single segment.
///   2. The model picks the user's voice-config names as character names
///      (since they're listed in the request).
///   3. The model paraphrases segments instead of quoting verbatim, which
///      breaks downstream alignment.
///
/// After parsing, segments are aligned back to the source text by
/// whitespace-compacting and scanning with a moving cursor — any segment
/// that can't be located errors the whole call, since silently dropping
/// pieces is worse than no result.
class RoleAssignmentService {
  final LlmChatAdapter adapter;
  final Duration timeout;

  RoleAssignmentService({
    required this.adapter,
    this.timeout = const Duration(seconds: 60),
  });

  Future<RoleAssignmentResult> assignRoles({
    required String text,
    required List<String> availableVoiceConfigs,
    String defaultSpeakerLabel = '',
  }) async {
    if (text.trim().isEmpty) {
      throw const RoleAssignmentError('No text to analyze');
    }
    if (availableVoiceConfigs.isEmpty) {
      throw const RoleAssignmentError(
        'Add at least one voice config before running role assignment',
      );
    }

    final fallbackSpeaker = _pickFallbackSpeaker(
      availableVoiceConfigs,
      defaultSpeakerLabel,
    );
    final messages = _buildMessages(
      documentText: text,
      voiceConfigs: availableVoiceConfigs,
      fallbackSpeaker: fallbackSpeaker,
    );

    final raw = await adapter.chat(
      messages: messages,
      temperature: 0.1,
      jsonMode: true,
      timeout: timeout,
    );

    final parsed = _extractJson(raw);
    final rawSegments = _pickSegmentsArray(parsed);
    if (rawSegments.isEmpty) {
      throw const RoleAssignmentError(
          'LLM returned no usable segments');
    }

    final aligned = _alignToSource(text, rawSegments);
    if (aligned.isEmpty) {
      throw const RoleAssignmentError('LLM segments could not be aligned');
    }

    final assignments = <RoleAssignment>[];
    for (var i = 0; i < aligned.length; i++) {
      final item = aligned[i];
      final category = _normalizeCategory(item['category']?.toString() ?? '');
      var rawSpeaker =
          (item['speaker_label'] ?? item['speaker'] ?? item['character'] ?? '')
              .toString()
              .trim();

      var resolvedCategory = category;
      if (resolvedCategory.isEmpty) {
        resolvedCategory = rawSpeaker.isNotEmpty ? 'dialogue' : 'narration';
      }
      if (resolvedCategory == 'narration' && rawSpeaker.isEmpty) {
        rawSpeaker = '旁白';
      } else if ((resolvedCategory == 'dialogue' ||
              resolvedCategory == 'thought') &&
          rawSpeaker.isEmpty) {
        rawSpeaker = '未识别角色';
      } else if (resolvedCategory == 'system' && rawSpeaker.isEmpty) {
        rawSpeaker = '系统';
      }

      final confidence = _toDouble(item['confidence']);
      final reason = (item['reason'] ?? '').toString().trim();

      assignments.add(RoleAssignment(
        index: i + 1,
        speakerLabel: rawSpeaker,
        category: resolvedCategory,
        categoryDisplay: _categoryDisplay(resolvedCategory),
        text: (item['text'] ?? '').toString(),
        confidence: confidence,
        reason: _mergeReason(resolvedCategory, rawSpeaker, reason),
        start: item['start'] is int ? item['start'] as int : null,
        end: item['end'] is int ? item['end'] as int : null,
        suggestedVoice: _suggestVoice(
          rawSpeaker: rawSpeaker,
          category: resolvedCategory,
          voiceConfigs: availableVoiceConfigs,
          fallbackSpeaker: fallbackSpeaker,
        ),
      ));
    }

    return RoleAssignmentResult(
      assignments: assignments,
      fallbackSpeaker: fallbackSpeaker,
      rawResponse: raw,
    );
  }

  // ─────────────────── prompt ───────────────────

  static const String _systemPrompt =
      '你是中文多角色有声书文本分析助手。'
      '你会先完整阅读整篇文本，再自动断句，最后按阅读顺序输出结构化 JSON。'
      'available_voice_configs 只是界面里的本地配音配置名称，只用于后续人工映射，不是正文角色名。'
      '除非这些名字真的出现在正文里，否则不要把正文角色写成本地配音配置名称。'
      '你要输出的是正文中的真实角色或群体标识，例如 悟空、四猴、众猴、巡海夜叉、旁白。'
      '你必须主动断句，不要把整段长文本合并成一个 item。'
      '通常应在句号、问号、感叹号、分号、说话切换、引号结束、叙述视角切换处断开；一段里有多句时，正常应拆成多个 segments。'
      '如果一段文字里既有旁白又有对白，必须继续细分，不要整段只给一个"旁白"。'
      'category 请优先使用中文标签：旁白、对话、心理、系统。'
      '带引号的台词、冒号后的发言、以及包含"说、问、答、喊、叫、笑道、低声、怒道、回应、嘀咕、说道、问道、答道、叫道、喝道"等提示词的句子，应优先判为"对话"。'
      '即使一句里夹杂少量动作描写，只要核心内容是人物发言，仍应判为"对话"。'
      '心理活动、内心独白、自语、自思、自忖优先判为"心理"，并尽量指出是谁在想。'
      '纯叙述、环境描写、动作描写判为"旁白"；系统提示、舞台说明判为"系统"。'
      '对于"对话"和"心理"，speaker_label 必须尽量填写具体人物或群体名称。'
      '如果能从前后文推断出说话人或思考人，就不要留空。'
      '如果连续多段明显属于同一角色发言或思考，应保持 speaker_label 一致。'
      '如果"对话"或"心理"实在无法判断人物，也要写 speaker_label 为"未识别角色"，不要误判成"旁白"。'
      '每个 segment.text 必须是原文中的连续原句，尽量保持字面一致，不要改写，不要总结，不要省略。'
      '所有 segment.text 按顺序拼接后，应该覆盖全文正文。'
      '请严格返回 JSON，不要附加解释。';

  static List<LlmChatMessage> _buildMessages({
    required String documentText,
    required List<String> voiceConfigs,
    required String fallbackSpeaker,
  }) {
    final userPayload = {
      'task':
          '先通读全文，自动断句，再为每个分句输出 category、speaker_label、text、reason、confidence。',
      'available_voice_configs': voiceConfigs,
      'default_narration_voice_config': fallbackSpeaker,
      'decision_rules': [
        '你必须把整篇全文作为一个连续故事来判断，再自行切成适合配音的片段。',
        '如果输入是一整段长文本，输出必须拆成多个 segments，不能只返回一个总段落。',
        'category 优先输出中文标签：旁白、对话、心理、系统。',
        '"对话"和"心理"尽量填具体 speaker_label，例如 悟空、四猴、众猴；不要直接写成本地配音配置名。',
        '如果是对话，请在 reason 里简短写出依据，并明确说话人是谁。',
        '如果是心理，请在 reason 里简短写出依据，并明确是谁的内心活动。',
        '每个 segments[i].text 都必须是原文连续摘录，不能改写。',
        'segments 数组需要覆盖全文，不能漏掉中间句子。',
      ],
      'output_schema': {
        'segments': [
          {
            'text': '俺也去。',
            'category': '对话',
            'speaker_label': '悟空',
            'confidence': 0.95,
            'reason': '说话人: 悟空 | 根据前文"悟空道"判断',
          }
        ]
      },
      'full_text': documentText.trim(),
    };

    return [
      const LlmChatMessage(role: 'system', content: _systemPrompt),
      LlmChatMessage(
        role: 'user',
        content: jsonEncode(userPayload),
      ),
    ];
  }

  // ─────────────────── parsing ───────────────────

  static dynamic _extractJson(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const RoleAssignmentError('LLM response was empty');
    }

    final candidates = <String>[];
    final fenced =
        RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false)
            .firstMatch(trimmed);
    if (fenced != null) {
      candidates.add(fenced.group(1)!.trim());
    }
    candidates.add(trimmed);

    final arrayMatch = RegExp(r'(\[[\s\S]*\])').firstMatch(trimmed);
    if (arrayMatch != null) candidates.add(arrayMatch.group(1)!);
    final objectMatch = RegExp(r'(\{[\s\S]*\})').firstMatch(trimmed);
    if (objectMatch != null) candidates.add(objectMatch.group(1)!);

    for (final candidate in candidates) {
      try {
        return jsonDecode(candidate);
      } on FormatException {
        continue;
      }
    }
    throw const RoleAssignmentError(
        'Unable to parse JSON from LLM response');
  }

  static List<Map<String, dynamic>> _pickSegmentsArray(dynamic parsed) {
    List<dynamic>? raw;
    if (parsed is List) {
      raw = parsed;
    } else if (parsed is Map) {
      for (final key in const [
        'segments',
        'items',
        'assignments',
        'results',
        'data',
      ]) {
        if (parsed[key] is List) {
          raw = parsed[key] as List;
          break;
        }
      }
    }
    if (raw == null) return const [];
    return [
      for (final entry in raw)
        if (entry is Map) entry.cast<String, dynamic>(),
    ];
  }

  // ─────────────────── alignment ───────────────────

  /// Map each LLM segment back to (start, end) offsets in [fullText] by
  /// stripping whitespace and scanning forward — matches the Python
  /// implementation byte-for-byte.
  static List<Map<String, dynamic>> _alignToSource(
    String fullText,
    List<Map<String, dynamic>> rawSegments,
  ) {
    final compactChars = StringBuffer();
    final indexMap = <int>[];
    for (var i = 0; i < fullText.length; i++) {
      final ch = fullText[i];
      if (ch.trim().isEmpty) continue;
      compactChars.write(ch);
      indexMap.add(i);
    }
    final compactFull = compactChars.toString();
    if (compactFull.isEmpty) {
      throw const RoleAssignmentError(
        'Source text is empty — nothing to align AI segments to',
      );
    }

    var cursor = 0;
    final aligned = <Map<String, dynamic>>[];
    var order = 0;

    for (final item in rawSegments) {
      order++;
      final segmentText = _extractSegmentText(item);
      final compactSegment = segmentText.replaceAll(RegExp(r'\s+'), '');
      if (compactSegment.isEmpty) continue;

      final pos = compactFull.indexOf(compactSegment, cursor);
      if (pos < 0) {
        final preview = segmentText.length > 60
            ? '${segmentText.substring(0, 60)}…'
            : segmentText;
        throw RoleAssignmentError(
          'AI segment #$order could not be located in source: $preview',
        );
      }

      final start = indexMap[pos];
      final end = indexMap[pos + compactSegment.length - 1] + 1;
      final merged = Map<String, dynamic>.from(item)
        ..['text'] = fullText.substring(start, end)
        ..['start'] = start
        ..['end'] = end
        ..['_segment_order'] = order;
      aligned.add(merged);
      cursor = pos + compactSegment.length;
    }

    return aligned;
  }

  static String _extractSegmentText(Map<String, dynamic> item) {
    for (final key in const [
      'text',
      'segment_text',
      'content',
      'quote',
      'sentence',
    ]) {
      final value = item[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  // ─────────────────── normalization ───────────────────

  static const Map<String, String> _categoryAliases = {
    '旁白': 'narration',
    '叙述': 'narration',
    '叙事': 'narration',
    '描写': 'narration',
    'narrator': 'narration',
    'narration': 'narration',
    '对白': 'dialogue',
    '对话': 'dialogue',
    '台词': 'dialogue',
    '发言': 'dialogue',
    'dialog': 'dialogue',
    'dialogue': 'dialogue',
    'speech': 'dialogue',
    '心理': 'thought',
    '心声': 'thought',
    '独白': 'thought',
    '内心独白': 'thought',
    'thought': 'thought',
    'inner': 'thought',
    'system': 'system',
    '系统': 'system',
    '说明': 'system',
    '提示': 'system',
  };

  static const Set<String> _knownCategories = {
    'narration',
    'dialogue',
    'thought',
    'system',
  };

  static String _normalizeCategory(String value) {
    final text = value.trim().toLowerCase();
    if (text.isEmpty) return '';
    if (_categoryAliases.containsKey(text)) return _categoryAliases[text]!;
    return _knownCategories.contains(text) ? text : '';
  }

  static String _categoryDisplay(String category) {
    switch (category) {
      case 'narration':
        return '旁白';
      case 'dialogue':
        return '对话';
      case 'thought':
        return '心理';
      case 'system':
        return '系统';
      default:
        return '未分类';
    }
  }

  static String _mergeReason(String category, String speaker, String reason) {
    final trimmedSpeaker = speaker.trim();
    final trimmedReason = reason.trim();
    String prefix = '';
    if (category == 'dialogue' && trimmedSpeaker.isNotEmpty) {
      prefix = '说话人: $trimmedSpeaker';
    } else if (category == 'thought' && trimmedSpeaker.isNotEmpty) {
      prefix = '思考人: $trimmedSpeaker';
    }
    if (prefix.isEmpty) return trimmedReason;
    if (trimmedReason.contains(prefix)) return trimmedReason;
    return trimmedReason.isEmpty ? prefix : '$prefix | $trimmedReason';
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  // ─────────────────── voice mapping ───────────────────

  /// Strip whitespace and a fixed set of CJK + ASCII punctuation, then
  /// lowercase. Used to compare LLM speaker labels against the user's
  /// voice-config names.
  static String _normalizeName(String input) {
    final lowered = input.trim().toLowerCase();
    return lowered.replaceAll(
      RegExp(r'[\s\-_()（）\[\]【】"' "'" r'“”‘’:：,，.。!！？?、/\\]+'),
      '',
    );
  }

  static String _pickFallbackSpeaker(
    List<String> voiceConfigs,
    String configured,
  ) {
    final wanted = configured.trim();
    if (wanted.isNotEmpty && voiceConfigs.contains(wanted)) return wanted;
    return voiceConfigs.first;
  }

  static String _matchVoiceConfig(
    String rawSpeaker,
    List<String> voiceConfigs,
  ) {
    final speaker = rawSpeaker.trim();
    if (speaker.isEmpty) return '';
    if (voiceConfigs.contains(speaker)) return speaker;

    final normalized = _normalizeName(speaker);
    if (normalized.isEmpty) return '';

    final byNormalized = {
      for (final name in voiceConfigs) _normalizeName(name): name,
    };
    if (byNormalized.containsKey(normalized)) return byNormalized[normalized]!;

    final fuzzy = <String>[];
    for (final name in voiceConfigs) {
      final n = _normalizeName(name);
      if (n.isNotEmpty &&
          (normalized.contains(n) || n.contains(normalized))) {
        fuzzy.add(name);
      }
    }
    return fuzzy.length == 1 ? fuzzy.first : '';
  }

  static String _suggestVoice({
    required String rawSpeaker,
    required String category,
    required List<String> voiceConfigs,
    required String fallbackSpeaker,
  }) {
    final matched = _matchVoiceConfig(rawSpeaker, voiceConfigs);
    if (matched.isNotEmpty) return matched;

    final normalizedCategory = category.isEmpty ? 'narration' : category;
    if ((normalizedCategory == 'narration' ||
            normalizedCategory == 'system') &&
        voiceConfigs.contains(fallbackSpeaker)) {
      return fallbackSpeaker;
    }

    final normalizedSpeaker = _normalizeName(rawSpeaker);
    const narratorAliases = {'旁白', 'narrator', 'voiceover'};
    if (narratorAliases.contains(normalizedSpeaker) &&
        voiceConfigs.contains(fallbackSpeaker)) {
      return fallbackSpeaker;
    }
    return '';
  }
}
