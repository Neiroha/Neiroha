/// A voice character's processing chain, run around its TTS like composed
/// functions: text steps rewrite the line before synthesis, audio steps
/// transform the spoken result.
///
///   text ─▶ [translate] ─▶ [rewrite] ─▶ TTS ─▶ [convert] ─▶ audio
enum VoiceChainStepKind {
  /// LLM: translate the line into [VoiceChainStep.targetLanguage].
  translate,

  /// LLM: rewrite the line by [VoiceChainStep.instruction].
  rewrite,

  /// Voice conversion: re-voice the audio as [VoiceChainStep.targetVoice].
  convert;

  bool get isText => this != convert;
}

class VoiceChainStep {
  const VoiceChainStep({
    required this.kind,
    this.connectionId,
    this.modelId,
    this.targetLanguage = '',
    this.instruction = '',
    this.targetVoice = '',
    this.enabled = true,
  });

  final VoiceChainStepKind kind;

  /// Model serving the step; null uses the router default.
  final String? connectionId;
  final String? modelId;
  final String targetLanguage;
  final String instruction;
  final String targetVoice;
  final bool enabled;

  /// Enough configuration to run.
  bool get ready => switch (kind) {
    VoiceChainStepKind.translate => targetLanguage.trim().isNotEmpty,
    VoiceChainStepKind.rewrite => instruction.trim().isNotEmpty,
    VoiceChainStepKind.convert =>
      connectionId != null && targetVoice.trim().isNotEmpty,
  };

  VoiceChainStep copyWith({
    String? connectionId,
    String? modelId,
    bool clearModel = false,
    String? targetLanguage,
    String? instruction,
    String? targetVoice,
    bool? enabled,
  }) => VoiceChainStep(
    kind: kind,
    connectionId: clearModel ? null : connectionId ?? this.connectionId,
    modelId: clearModel ? null : modelId ?? this.modelId,
    targetLanguage: targetLanguage ?? this.targetLanguage,
    instruction: instruction ?? this.instruction,
    targetVoice: targetVoice ?? this.targetVoice,
    enabled: enabled ?? this.enabled,
  );

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'connectionId': connectionId,
    'modelId': modelId,
    if (targetLanguage.isNotEmpty) 'targetLanguage': targetLanguage,
    if (instruction.isNotEmpty) 'instruction': instruction,
    if (targetVoice.isNotEmpty) 'targetVoice': targetVoice,
    'enabled': enabled,
  };

  static VoiceChainStep? fromJson(Map<String, dynamic> json) {
    final kind = VoiceChainStepKind.values.asNameMap()[json['kind']];
    if (kind == null) return null;
    return VoiceChainStep(
      kind: kind,
      connectionId: json['connectionId'] as String?,
      modelId: json['modelId'] as String?,
      targetLanguage: json['targetLanguage'] as String? ?? '',
      instruction: json['instruction'] as String? ?? '',
      targetVoice: json['targetVoice'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

class VoiceChain {
  const VoiceChain([this.steps = const []]);
  final List<VoiceChainStep> steps;

  static const empty = VoiceChain();

  Iterable<VoiceChainStep> get _active =>
      steps.where((s) => s.enabled && s.ready);

  /// Steps run before TTS, in order.
  List<VoiceChainStep> get textSteps => [
    for (final s in _active)
      if (s.kind.isText) s,
  ];

  /// Steps run on the synthesized audio, in order.
  List<VoiceChainStep> get audioSteps => [
    for (final s in _active)
      if (!s.kind.isText) s,
  ];

  bool get isActive => _active.isNotEmpty;

  /// Text steps first, then audio steps, each group in insertion order: the
  /// only order the chain can run in.
  VoiceChain normalized() => VoiceChain([
    for (final s in steps)
      if (s.kind.isText) s,
    for (final s in steps)
      if (!s.kind.isText) s,
  ]);

  static String key(String voiceAssetId) => 'voice.chain.$voiceAssetId';

  List<Object?> toJson() => [for (final s in steps) s.toJson()];

  factory VoiceChain.fromJson(Object? json) => VoiceChain([
    if (json is List)
      for (final item in json.whereType<Map>())
        ?VoiceChainStep.fromJson(Map<String, dynamic>.from(item)),
  ]);
}
