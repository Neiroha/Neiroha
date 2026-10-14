// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_binding.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ModelBinding _$ModelBindingFromJson(Map<String, dynamic> json) =>
    _ModelBinding(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      modelKey: json['modelKey'] as String,
      supportedTaskModes:
          (json['supportedTaskModes'] as List<dynamic>?)
              ?.map((e) => $enumDecode(_$TaskModeEnumMap, e))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ModelBindingToJson(_ModelBinding instance) =>
    <String, dynamic>{
      'id': instance.id,
      'providerId': instance.providerId,
      'modelKey': instance.modelKey,
      'supportedTaskModes': instance.supportedTaskModes
          .map((e) => _$TaskModeEnumMap[e]!)
          .toList(),
    };

const _$TaskModeEnumMap = {
  TaskMode.presetVoice: 'presetVoice',
  TaskMode.cloneWithPrompt: 'cloneWithPrompt',
  TaskMode.voiceDesign: 'voiceDesign',
};
