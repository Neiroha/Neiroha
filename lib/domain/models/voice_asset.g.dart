// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_asset.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VoiceAssetImpl _$$VoiceAssetImplFromJson(Map<String, dynamic> json) =>
    _$VoiceAssetImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      providerId: json['providerId'] as String,
      modelBindingId: json['modelBindingId'] as String,
      taskMode: $enumDecode(_$TaskModeEnumMap, json['taskMode']),
      refAudioPath: json['refAudioPath'] as String?,
      promptText: json['promptText'] as String?,
      promptLang: json['promptLang'] as String?,
      voiceInstruction: json['voiceInstruction'] as String?,
      presetVoiceName: json['presetVoiceName'] as String?,
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      enabled: json['enabled'] as bool? ?? true,
    );

Map<String, dynamic> _$$VoiceAssetImplToJson(_$VoiceAssetImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'providerId': instance.providerId,
      'modelBindingId': instance.modelBindingId,
      'taskMode': _$TaskModeEnumMap[instance.taskMode]!,
      'refAudioPath': instance.refAudioPath,
      'promptText': instance.promptText,
      'promptLang': instance.promptLang,
      'voiceInstruction': instance.voiceInstruction,
      'presetVoiceName': instance.presetVoiceName,
      'speed': instance.speed,
      'enabled': instance.enabled,
    };

const _$TaskModeEnumMap = {
  TaskMode.presetVoice: 'presetVoice',
  TaskMode.cloneWithPrompt: 'cloneWithPrompt',
  TaskMode.voiceDesign: 'voiceDesign',
};
