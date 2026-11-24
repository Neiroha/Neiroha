/// What a language model can take, do and think, as far as we know. Every
/// field may be unknown (null): catalogs and `/models` lists are partial, and
/// a fact we have not seen must not be guessed.
library;

/// Reasoning effort levels in increasing order. Vendors use subsets; Gemini's
/// `thinking_level` and MiniMax's `reasoning_effort` map onto the same names.
enum ReasoningEffort { none, minimal, low, medium, high, xhigh, max }

/// Input/output kinds an agent can route to a model.
enum Modality { text, image, audio, video, pdf }

class ReasoningSpec {
  const ReasoningSpec({
    this.supported = true,
    this.levels = const [],
    this.defaultLevel,
    this.modes = const [],
  });

  /// Model does not think.
  static const unsupported = ReasoningSpec(supported: false);

  /// The model reasons. With empty [levels] the effort control is unknown.
  final bool supported;

  /// Supported effort levels, low to high.
  final List<ReasoningEffort> levels;
  final ReasoningEffort? defaultLevel;

  /// Vendor reasoning modes beyond effort, e.g. OpenAI `standard` / `pro`.
  final List<String> modes;

  /// Thinking can be switched off entirely (`none`).
  bool get canDisable => levels.contains(ReasoningEffort.none);

  /// Levels that actually think (everything but `none`).
  List<ReasoningEffort> get thinkingLevels => [
    for (final l in levels)
      if (l != ReasoningEffort.none) l,
  ];

  Map<String, Object?> toJson() => {
    if (!supported) 'supported': false,
    if (levels.isNotEmpty) 'levels': [for (final l in levels) l.name],
    if (defaultLevel != null) 'default': defaultLevel!.name,
    if (modes.isNotEmpty) 'modes': modes,
  };

  factory ReasoningSpec.fromJson(Map<String, dynamic> json) {
    final byName = ReasoningEffort.values.asNameMap();
    final levels = [
      for (final l in json['levels'] as List? ?? const []) ?byName['$l'],
    ]..sort((a, b) => a.index.compareTo(b.index));
    return ReasoningSpec(
      supported: json['supported'] as bool? ?? true,
      levels: levels,
      defaultLevel: byName['${json['default']}'],
      modes: [for (final m in json['modes'] as List? ?? const []) '$m'],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReasoningSpec && '${toJson()}' == '${other.toJson()}';
  @override
  int get hashCode => '${toJson()}'.hashCode;
}

class LlmTraits {
  const LlmTraits({
    this.inputs,
    this.outputs,
    this.tools,
    this.parallelTools,
    this.structuredOutput,
    this.reasoning,
    this.contextWindow,
    this.maxOutputTokens,
  });

  static const unknown = LlmTraits();

  /// Null = unknown; text is implied for chat models.
  final Set<Modality>? inputs;
  final Set<Modality>? outputs;

  /// Function / tool calling — required by role analysis and agents.
  final bool? tools;
  final bool? parallelTools;

  /// JSON-schema constrained output.
  final bool? structuredOutput;

  /// Null = unknown; [ReasoningSpec.unsupported] = known not to think.
  final ReasoningSpec? reasoning;
  final int? contextWindow;
  final int? maxOutputTokens;

  bool get isUnknown =>
      inputs == null &&
      tools == null &&
      structuredOutput == null &&
      reasoning == null &&
      contextWindow == null;

  bool accepts(Modality m) => inputs?.contains(m) ?? m == Modality.text;

  LlmTraits withReasoning(ReasoningSpec spec) => LlmTraits(
    inputs: inputs,
    outputs: outputs,
    tools: tools,
    parallelTools: parallelTools,
    structuredOutput: structuredOutput,
    reasoning: spec,
    contextWindow: contextWindow,
    maxOutputTokens: maxOutputTokens,
  );

  /// Fills fields this one does not know from [fallback].
  LlmTraits orElse(LlmTraits? fallback) => fallback == null
      ? this
      : LlmTraits(
          inputs: inputs ?? fallback.inputs,
          outputs: outputs ?? fallback.outputs,
          tools: tools ?? fallback.tools,
          parallelTools: parallelTools ?? fallback.parallelTools,
          structuredOutput: structuredOutput ?? fallback.structuredOutput,
          reasoning: reasoning ?? fallback.reasoning,
          contextWindow: contextWindow ?? fallback.contextWindow,
          maxOutputTokens: maxOutputTokens ?? fallback.maxOutputTokens,
        );

  Map<String, Object?> toJson() => {
    if (inputs != null) 'in': [for (final m in inputs!) m.name],
    if (outputs != null) 'out': [for (final m in outputs!) m.name],
    if (tools != null) 'tools': tools,
    if (parallelTools != null) 'parallelTools': parallelTools,
    if (structuredOutput != null) 'schema': structuredOutput,
    if (reasoning != null) 'reasoning': reasoning!.toJson(),
    if (contextWindow != null) 'context': contextWindow,
    if (maxOutputTokens != null) 'maxOut': maxOutputTokens,
  };

  factory LlmTraits.fromJson(Map<String, dynamic> json) {
    final byName = Modality.values.asNameMap();
    Set<Modality>? modalities(Object? raw) =>
        raw is List ? {for (final m in raw) ?byName['$m']} : null;
    final reasoning = json['reasoning'];
    return LlmTraits(
      inputs: modalities(json['in']),
      outputs: modalities(json['out']),
      tools: json['tools'] as bool?,
      parallelTools: json['parallelTools'] as bool?,
      structuredOutput: json['schema'] as bool?,
      reasoning: reasoning is Map
          ? ReasoningSpec.fromJson(Map<String, dynamic>.from(reasoning))
          : null,
      contextWindow: (json['context'] as num?)?.toInt(),
      maxOutputTokens: (json['maxOut'] as num?)?.toInt(),
    );
  }
}
