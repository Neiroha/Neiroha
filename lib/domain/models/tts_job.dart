import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:neiroha/domain/enums/job_status.dart';

part 'tts_job.freezed.dart';
part 'tts_job.g.dart';

@freezed
class TtsJob with _$TtsJob {
  const factory TtsJob({
    required String id,
    required String voiceAssetId,
    required String inputText,
    required JobStatus status,
    String? outputPath,
    String? errorMessage,
    required DateTime createdAt,
    DateTime? completedAt,
  }) = _TtsJob;

  factory TtsJob.fromJson(Map<String, dynamic> json) => _$TtsJobFromJson(json);
}
