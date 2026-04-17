// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_provider.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TtsProviderImpl _$$TtsProviderImplFromJson(Map<String, dynamic> json) =>
    _$TtsProviderImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      adapterType: $enumDecode(_$AdapterTypeEnumMap, json['adapterType']),
      baseUrl: json['baseUrl'] as String,
      apiKey: json['apiKey'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );

Map<String, dynamic> _$$TtsProviderImplToJson(_$TtsProviderImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'adapterType': _$AdapterTypeEnumMap[instance.adapterType]!,
      'baseUrl': instance.baseUrl,
      'apiKey': instance.apiKey,
      'enabled': instance.enabled,
    };

const _$AdapterTypeEnumMap = {
  AdapterType.openaiCompatible: 'openaiCompatible',
  AdapterType.gptSovits: 'gptSovits',
  AdapterType.cosyvoice: 'cosyvoice',
  AdapterType.chatCompletionsTts: 'chatCompletionsTts',
  AdapterType.azureTts: 'azureTts',
  AdapterType.systemTts: 'systemTts',
};
