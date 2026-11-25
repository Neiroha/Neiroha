import 'dart:convert';

import 'package:neiroha/data/database/app_database.dart';

/// Per-character chat settings: persona prompt, the language model of the
/// AI companion, the Realtime model and voice of a call, and tool use.
/// Voice conversion is part of the character's processing chain, not here.
/// Stored in `voice_asset_settings.live_json`.
class CharacterLiveSettings {
  const CharacterLiveSettings({
    this.persona = '',
    this.realtimeVoice,
    this.realtimeConnectionId,
    this.realtimeModelId,
    this.allowInterruptions = false,
    this.llmConnectionId,
    this.llmModelId,
    this.useTools = true,
  });

  final String persona;
  final String? realtimeVoice;

  /// Realtime model to talk with; null uses the router default.
  final String? realtimeConnectionId;
  final String? realtimeModelId;
  final bool allowInterruptions;

  /// Language model for the AI companion; null uses the router default.
  final String? llmConnectionId;
  final String? llmModelId;

  /// Lets the character use its tools (time, chat memory).
  final bool useTools;

  CharacterLiveSettings _with({
    String? persona,
    bool? allowInterruptions,
    bool? useTools,
    (String?, String?)? llm,
    (String?, String?, String?)? realtime,
  }) => CharacterLiveSettings(
    persona: persona ?? this.persona,
    allowInterruptions: allowInterruptions ?? this.allowInterruptions,
    useTools: useTools ?? this.useTools,
    llmConnectionId: llm == null ? llmConnectionId : llm.$1,
    llmModelId: llm == null ? llmModelId : llm.$2,
    realtimeConnectionId: realtime == null ? realtimeConnectionId : realtime.$1,
    realtimeModelId: realtime == null ? realtimeModelId : realtime.$2,
    realtimeVoice: realtime == null ? realtimeVoice : realtime.$3,
  );

  CharacterLiveSettings withPersona(String persona) => _with(persona: persona);
  CharacterLiveSettings withTools(bool on) => _with(useTools: on);
  CharacterLiveSettings withInterruptions(bool on) =>
      _with(allowInterruptions: on);

  /// [model] is (connection, model id); null goes back to the default.
  CharacterLiveSettings withLlm((String, String)? model) =>
      _with(llm: (model?.$1, model?.$2));
  CharacterLiveSettings withRealtime((String, String)? model, String? voice) =>
      _with(realtime: (model?.$1, model?.$2, voice));

  Map<String, Object?> toJson() => {
    'persona': persona,
    'realtimeVoice': realtimeVoice,
    'realtimeConnectionId': realtimeConnectionId,
    'realtimeModelId': realtimeModelId,
    'allowInterruptions': allowInterruptions,
    'llmConnectionId': llmConnectionId,
    'llmModelId': llmModelId,
    'useTools': useTools,
  };

  factory CharacterLiveSettings.fromJson(Map<String, dynamic> json) =>
      CharacterLiveSettings(
        persona: json['persona'] as String? ?? '',
        realtimeVoice: json['realtimeVoice'] as String?,
        realtimeConnectionId: json['realtimeConnectionId'] as String?,
        realtimeModelId: json['realtimeModelId'] as String?,
        allowInterruptions: json['allowInterruptions'] as bool? ?? false,
        llmConnectionId: json['llmConnectionId'] as String?,
        llmModelId: json['llmModelId'] as String?,
        useTools: json['useTools'] as bool? ?? true,
      );

  static Future<CharacterLiveSettings> load(
    AppDatabase db,
    String voiceAssetId,
  ) async {
    final raw = await db.getVoiceAssetSetting(
      voiceAssetId,
      CharacterSettingSlot.live,
    );
    if (raw == null || raw.isEmpty) return const CharacterLiveSettings();
    try {
      return CharacterLiveSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on FormatException {
      return const CharacterLiveSettings();
    }
  }

  Future<void> save(AppDatabase db, String voiceAssetId) =>
      db.setVoiceAssetSetting(
        voiceAssetId,
        CharacterSettingSlot.live,
        jsonEncode(toJson()),
      );
}

/// Default persona when the user has not written one.
String defaultPersona({
  required String name,
  String? description,
  String? voiceInstruction,
}) => [
  'You are $name. Stay in character and talk with the user as $name would.',
  if (description?.trim().isNotEmpty ?? false) 'About you: $description',
  if (voiceInstruction?.trim().isNotEmpty ?? false)
    'How you speak: $voiceInstruction',
].join('\n');
