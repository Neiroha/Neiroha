import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:q_vox_lab/domain/enums/task_mode.dart';

part 'voice_asset.freezed.dart';
part 'voice_asset.g.dart';

@freezed
class VoiceAsset with _$VoiceAsset {
  const factory VoiceAsset({
    required String id,
    required String name,
    required String providerId,
    required String modelBindingId,
    required TaskMode taskMode,
    // GPT-SoVITS: reference audio path
    String? refAudioPath,
    // GPT-SoVITS: prompt text for the reference audio
    String? promptText,
    // GPT-SoVITS: language of the prompt text
    String? promptLang,
    // Qwen3: voice design instruction
    String? voiceInstruction,
    // OpenAI-compatible: preset voice name
    String? presetVoiceName,
    @Default(1.0) double speed,
    @Default(true) bool enabled,
  }) = _VoiceAsset;

  factory VoiceAsset.fromJson(Map<String, dynamic> json) =>
      _$VoiceAssetFromJson(json);
}
