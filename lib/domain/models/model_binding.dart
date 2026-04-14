import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:neiroha/domain/enums/task_mode.dart';

part 'model_binding.freezed.dart';
part 'model_binding.g.dart';

@freezed
class ModelBinding with _$ModelBinding {
  const factory ModelBinding({
    required String id,
    required String providerId,
    required String modelKey,
    @Default([]) List<TaskMode> supportedTaskModes,
  }) = _ModelBinding;

  factory ModelBinding.fromJson(Map<String, dynamic> json) =>
      _$ModelBindingFromJson(json);
}
