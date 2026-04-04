// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tts_job.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TtsJob _$TtsJobFromJson(Map<String, dynamic> json) {
  return _TtsJob.fromJson(json);
}

/// @nodoc
mixin _$TtsJob {
  String get id => throw _privateConstructorUsedError;
  String get voiceAssetId => throw _privateConstructorUsedError;
  String get inputText => throw _privateConstructorUsedError;
  JobStatus get status => throw _privateConstructorUsedError;
  String? get outputPath => throw _privateConstructorUsedError;
  String? get errorMessage => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;

  /// Serializes this TtsJob to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TtsJob
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TtsJobCopyWith<TtsJob> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TtsJobCopyWith<$Res> {
  factory $TtsJobCopyWith(TtsJob value, $Res Function(TtsJob) then) =
      _$TtsJobCopyWithImpl<$Res, TtsJob>;
  @useResult
  $Res call({
    String id,
    String voiceAssetId,
    String inputText,
    JobStatus status,
    String? outputPath,
    String? errorMessage,
    DateTime createdAt,
    DateTime? completedAt,
  });
}

/// @nodoc
class _$TtsJobCopyWithImpl<$Res, $Val extends TtsJob>
    implements $TtsJobCopyWith<$Res> {
  _$TtsJobCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TtsJob
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? voiceAssetId = null,
    Object? inputText = null,
    Object? status = null,
    Object? outputPath = freezed,
    Object? errorMessage = freezed,
    Object? createdAt = null,
    Object? completedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            voiceAssetId: null == voiceAssetId
                ? _value.voiceAssetId
                : voiceAssetId // ignore: cast_nullable_to_non_nullable
                      as String,
            inputText: null == inputText
                ? _value.inputText
                : inputText // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as JobStatus,
            outputPath: freezed == outputPath
                ? _value.outputPath
                : outputPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            errorMessage: freezed == errorMessage
                ? _value.errorMessage
                : errorMessage // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            completedAt: freezed == completedAt
                ? _value.completedAt
                : completedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TtsJobImplCopyWith<$Res> implements $TtsJobCopyWith<$Res> {
  factory _$$TtsJobImplCopyWith(
    _$TtsJobImpl value,
    $Res Function(_$TtsJobImpl) then,
  ) = __$$TtsJobImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String voiceAssetId,
    String inputText,
    JobStatus status,
    String? outputPath,
    String? errorMessage,
    DateTime createdAt,
    DateTime? completedAt,
  });
}

/// @nodoc
class __$$TtsJobImplCopyWithImpl<$Res>
    extends _$TtsJobCopyWithImpl<$Res, _$TtsJobImpl>
    implements _$$TtsJobImplCopyWith<$Res> {
  __$$TtsJobImplCopyWithImpl(
    _$TtsJobImpl _value,
    $Res Function(_$TtsJobImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TtsJob
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? voiceAssetId = null,
    Object? inputText = null,
    Object? status = null,
    Object? outputPath = freezed,
    Object? errorMessage = freezed,
    Object? createdAt = null,
    Object? completedAt = freezed,
  }) {
    return _then(
      _$TtsJobImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        voiceAssetId: null == voiceAssetId
            ? _value.voiceAssetId
            : voiceAssetId // ignore: cast_nullable_to_non_nullable
                  as String,
        inputText: null == inputText
            ? _value.inputText
            : inputText // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as JobStatus,
        outputPath: freezed == outputPath
            ? _value.outputPath
            : outputPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        errorMessage: freezed == errorMessage
            ? _value.errorMessage
            : errorMessage // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        completedAt: freezed == completedAt
            ? _value.completedAt
            : completedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TtsJobImpl implements _TtsJob {
  const _$TtsJobImpl({
    required this.id,
    required this.voiceAssetId,
    required this.inputText,
    required this.status,
    this.outputPath,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });

  factory _$TtsJobImpl.fromJson(Map<String, dynamic> json) =>
      _$$TtsJobImplFromJson(json);

  @override
  final String id;
  @override
  final String voiceAssetId;
  @override
  final String inputText;
  @override
  final JobStatus status;
  @override
  final String? outputPath;
  @override
  final String? errorMessage;
  @override
  final DateTime createdAt;
  @override
  final DateTime? completedAt;

  @override
  String toString() {
    return 'TtsJob(id: $id, voiceAssetId: $voiceAssetId, inputText: $inputText, status: $status, outputPath: $outputPath, errorMessage: $errorMessage, createdAt: $createdAt, completedAt: $completedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TtsJobImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.voiceAssetId, voiceAssetId) ||
                other.voiceAssetId == voiceAssetId) &&
            (identical(other.inputText, inputText) ||
                other.inputText == inputText) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.outputPath, outputPath) ||
                other.outputPath == outputPath) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    voiceAssetId,
    inputText,
    status,
    outputPath,
    errorMessage,
    createdAt,
    completedAt,
  );

  /// Create a copy of TtsJob
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TtsJobImplCopyWith<_$TtsJobImpl> get copyWith =>
      __$$TtsJobImplCopyWithImpl<_$TtsJobImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TtsJobImplToJson(this);
  }
}

abstract class _TtsJob implements TtsJob {
  const factory _TtsJob({
    required final String id,
    required final String voiceAssetId,
    required final String inputText,
    required final JobStatus status,
    final String? outputPath,
    final String? errorMessage,
    required final DateTime createdAt,
    final DateTime? completedAt,
  }) = _$TtsJobImpl;

  factory _TtsJob.fromJson(Map<String, dynamic> json) = _$TtsJobImpl.fromJson;

  @override
  String get id;
  @override
  String get voiceAssetId;
  @override
  String get inputText;
  @override
  JobStatus get status;
  @override
  String? get outputPath;
  @override
  String? get errorMessage;
  @override
  DateTime get createdAt;
  @override
  DateTime? get completedAt;

  /// Create a copy of TtsJob
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TtsJobImplCopyWith<_$TtsJobImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
