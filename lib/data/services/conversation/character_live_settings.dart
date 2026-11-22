import 'dart:convert';

import 'package:neiroha/data/database/app_database.dart';

/// Per-character settings for live dialog: persona prompt, Realtime voice and
/// an optional VC target that restores the character's timbre. Stored in
/// app settings until the v34 provider tables land.
class CharacterLiveSettings {
  const CharacterLiveSettings({
    this.persona = '',
    this.realtimeVoice,
    this.vcConnectionId,
    this.vcModelId,
    this.vcVoice,
    this.allowInterruptions = false,
  });

  final String persona;
  final String? realtimeVoice;
  final String? vcConnectionId;
  final String? vcModelId;
  final String? vcVoice;
  final bool allowInterruptions;

  bool get usesVoiceConversion =>
      vcConnectionId != null && (vcVoice?.trim().isNotEmpty ?? false);

  static String key(String voiceAssetId) => 'dialog.live.$voiceAssetId';

  Map<String, Object?> toJson() => {
    'persona': persona,
    'realtimeVoice': realtimeVoice,
    'vcConnectionId': vcConnectionId,
    'vcModelId': vcModelId,
    'vcVoice': vcVoice,
    'allowInterruptions': allowInterruptions,
  };

  factory CharacterLiveSettings.fromJson(Map<String, dynamic> json) =>
      CharacterLiveSettings(
        persona: json['persona'] as String? ?? '',
        realtimeVoice: json['realtimeVoice'] as String?,
        vcConnectionId: json['vcConnectionId'] as String?,
        vcModelId: json['vcModelId'] as String?,
        vcVoice: json['vcVoice'] as String?,
        allowInterruptions: json['allowInterruptions'] as bool? ?? false,
      );

  static Future<CharacterLiveSettings> load(
    AppDatabase db,
    String voiceAssetId,
  ) async {
    final raw = await db.getSetting(key(voiceAssetId));
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
      db.setSetting(key(voiceAssetId), jsonEncode(toJson()));
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
