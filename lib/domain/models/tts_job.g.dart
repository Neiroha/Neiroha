// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_job.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TtsJobImpl _$$TtsJobImplFromJson(Map<String, dynamic> json) => _$TtsJobImpl(
  id: json['id'] as String,
  voiceAssetId: json['voiceAssetId'] as String,
  inputText: json['inputText'] as String,
  status: $enumDecode(_$JobStatusEnumMap, json['status']),
  outputPath: json['outputPath'] as String?,
  errorMessage: json['errorMessage'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
);

Map<String, dynamic> _$$TtsJobImplToJson(_$TtsJobImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'voiceAssetId': instance.voiceAssetId,
      'inputText': instance.inputText,
      'status': _$JobStatusEnumMap[instance.status]!,
      'outputPath': instance.outputPath,
      'errorMessage': instance.errorMessage,
      'createdAt': instance.createdAt.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
    };

const _$JobStatusEnumMap = {
  JobStatus.pending: 'pending',
  JobStatus.running: 'running',
  JobStatus.completed: 'completed',
  JobStatus.failed: 'failed',
};
