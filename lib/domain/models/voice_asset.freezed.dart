// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'voice_asset.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

VoiceAsset _$VoiceAssetFromJson(Map<String, dynamic> json) {
  return _VoiceAsset.fromJson(json);
}

/// @nodoc
mixin _$VoiceAsset {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get providerId => throw _privateConstructorUsedError;
  String get modelBindingId => throw _privateConstructorUsedError;
  TaskMode get taskMode =>
      throw _privateConstructorUsedError; // GPT-SoVITS: reference audio path
  String? get refAudioPath =>
      throw _privateConstructorUsedError; // GPT-SoVITS: prompt text for the reference audio
  String? get promptText =>
      throw _privateConstructorUsedError; // GPT-SoVITS: language of the prompt text
  String? get promptLang =>
      throw _privateConstructorUsedError; // Qwen3: voice design instruction
  String? get voiceInstruction =>
      throw _privateConstructorUsedError; // OpenAI-compatible: preset voice name
  String? get presetVoiceName => throw _privateConstructorUsedError;
  double get speed => throw _privateConstructorUsedError;
  bool get enabled => throw _privateConstructorUsedError;

  /// Serializes this VoiceAsset to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VoiceAsset
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VoiceAssetCopyWith<VoiceAsset> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VoiceAssetCopyWith<$Res> {
  factory $VoiceAssetCopyWith(
    VoiceAsset value,
    $Res Function(VoiceAsset) then,
  ) = _$VoiceAssetCopyWithImpl<$Res, VoiceAsset>;
  @useResult
  $Res call({
    String id,
    String name,
    String providerId,
    String modelBindingId,
    TaskMode taskMode,
    String? refAudioPath,
    String? promptText,
    String? promptLang,
    String? voiceInstruction,
    String? presetVoiceName,
    double speed,
    bool enabled,
  });
}

/// @nodoc
class _$VoiceAssetCopyWithImpl<$Res, $Val extends VoiceAsset>
    implements $VoiceAssetCopyWith<$Res> {
  _$VoiceAssetCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VoiceAsset
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? providerId = null,
    Object? modelBindingId = null,
    Object? taskMode = null,
    Object? refAudioPath = freezed,
    Object? promptText = freezed,
    Object? promptLang = freezed,
    Object? voiceInstruction = freezed,
    Object? presetVoiceName = freezed,
    Object? speed = null,
    Object? enabled = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            providerId: null == providerId
                ? _value.providerId
                : providerId // ignore: cast_nullable_to_non_nullable
                      as String,
            modelBindingId: null == modelBindingId
                ? _value.modelBindingId
                : modelBindingId // ignore: cast_nullable_to_non_nullable
                      as String,
            taskMode: null == taskMode
                ? _value.taskMode
                : taskMode // ignore: cast_nullable_to_non_nullable
                      as TaskMode,
            refAudioPath: freezed == refAudioPath
                ? _value.refAudioPath
                : refAudioPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            promptText: freezed == promptText
                ? _value.promptText
                : promptText // ignore: cast_nullable_to_non_nullable
                      as String?,
            promptLang: freezed == promptLang
                ? _value.promptLang
                : promptLang // ignore: cast_nullable_to_non_nullable
                      as String?,
            voiceInstruction: freezed == voiceInstruction
                ? _value.voiceInstruction
                : voiceInstruction // ignore: cast_nullable_to_non_nullable
                      as String?,
            presetVoiceName: freezed == presetVoiceName
                ? _value.presetVoiceName
                : presetVoiceName // ignore: cast_nullable_to_non_nullable
                      as String?,
            speed: null == speed
                ? _value.speed
                : speed // ignore: cast_nullable_to_non_nullable
                      as double,
            enabled: null == enabled
                ? _value.enabled
                : enabled // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$VoiceAssetImplCopyWith<$Res>
    implements $VoiceAssetCopyWith<$Res> {
  factory _$$VoiceAssetImplCopyWith(
    _$VoiceAssetImpl value,
    $Res Function(_$VoiceAssetImpl) then,
  ) = __$$VoiceAssetImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String providerId,
    String modelBindingId,
    TaskMode taskMode,
    String? refAudioPath,
    String? promptText,
    String? promptLang,
    String? voiceInstruction,
    String? presetVoiceName,
    double speed,
    bool enabled,
  });
}

/// @nodoc
class __$$VoiceAssetImplCopyWithImpl<$Res>
    extends _$VoiceAssetCopyWithImpl<$Res, _$VoiceAssetImpl>
    implements _$$VoiceAssetImplCopyWith<$Res> {
  __$$VoiceAssetImplCopyWithImpl(
    _$VoiceAssetImpl _value,
    $Res Function(_$VoiceAssetImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VoiceAsset
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? providerId = null,
    Object? modelBindingId = null,
    Object? taskMode = null,
    Object? refAudioPath = freezed,
    Object? promptText = freezed,
    Object? promptLang = freezed,
    Object? voiceInstruction = freezed,
    Object? presetVoiceName = freezed,
    Object? speed = null,
    Object? enabled = null,
  }) {
    return _then(
      _$VoiceAssetImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        providerId: null == providerId
            ? _value.providerId
            : providerId // ignore: cast_nullable_to_non_nullable
                  as String,
        modelBindingId: null == modelBindingId
            ? _value.modelBindingId
            : modelBindingId // ignore: cast_nullable_to_non_nullable
                  as String,
        taskMode: null == taskMode
            ? _value.taskMode
            : taskMode // ignore: cast_nullable_to_non_nullable
                  as TaskMode,
        refAudioPath: freezed == refAudioPath
            ? _value.refAudioPath
            : refAudioPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        promptText: freezed == promptText
            ? _value.promptText
            : promptText // ignore: cast_nullable_to_non_nullable
                  as String?,
        promptLang: freezed == promptLang
            ? _value.promptLang
            : promptLang // ignore: cast_nullable_to_non_nullable
                  as String?,
        voiceInstruction: freezed == voiceInstruction
            ? _value.voiceInstruction
            : voiceInstruction // ignore: cast_nullable_to_non_nullable
                  as String?,
        presetVoiceName: freezed == presetVoiceName
            ? _value.presetVoiceName
            : presetVoiceName // ignore: cast_nullable_to_non_nullable
                  as String?,
        speed: null == speed
            ? _value.speed
            : speed // ignore: cast_nullable_to_non_nullable
                  as double,
        enabled: null == enabled
            ? _value.enabled
            : enabled // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$VoiceAssetImpl implements _VoiceAsset {
  const _$VoiceAssetImpl({
    required this.id,
    required this.name,
    required this.providerId,
    required this.modelBindingId,
    required this.taskMode,
    this.refAudioPath,
    this.promptText,
    this.promptLang,
    this.voiceInstruction,
    this.presetVoiceName,
    this.speed = 1.0,
    this.enabled = true,
  });

  factory _$VoiceAssetImpl.fromJson(Map<String, dynamic> json) =>
      _$$VoiceAssetImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String providerId;
  @override
  final String modelBindingId;
  @override
  final TaskMode taskMode;
  // GPT-SoVITS: reference audio path
  @override
  final String? refAudioPath;
  // GPT-SoVITS: prompt text for the reference audio
  @override
  final String? promptText;
  // GPT-SoVITS: language of the prompt text
  @override
  final String? promptLang;
  // Qwen3: voice design instruction
  @override
  final String? voiceInstruction;
  // OpenAI-compatible: preset voice name
  @override
  final String? presetVoiceName;
  @override
  @JsonKey()
  final double speed;
  @override
  @JsonKey()
  final bool enabled;

  @override
  String toString() {
    return 'VoiceAsset(id: $id, name: $name, providerId: $providerId, modelBindingId: $modelBindingId, taskMode: $taskMode, refAudioPath: $refAudioPath, promptText: $promptText, promptLang: $promptLang, voiceInstruction: $voiceInstruction, presetVoiceName: $presetVoiceName, speed: $speed, enabled: $enabled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VoiceAssetImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.providerId, providerId) ||
                other.providerId == providerId) &&
            (identical(other.modelBindingId, modelBindingId) ||
                other.modelBindingId == modelBindingId) &&
            (identical(other.taskMode, taskMode) ||
                other.taskMode == taskMode) &&
            (identical(other.refAudioPath, refAudioPath) ||
                other.refAudioPath == refAudioPath) &&
            (identical(other.promptText, promptText) ||
                other.promptText == promptText) &&
            (identical(other.promptLang, promptLang) ||
                other.promptLang == promptLang) &&
            (identical(other.voiceInstruction, voiceInstruction) ||
                other.voiceInstruction == voiceInstruction) &&
            (identical(other.presetVoiceName, presetVoiceName) ||
                other.presetVoiceName == presetVoiceName) &&
            (identical(other.speed, speed) || other.speed == speed) &&
            (identical(other.enabled, enabled) || other.enabled == enabled));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    providerId,
    modelBindingId,
    taskMode,
    refAudioPath,
    promptText,
    promptLang,
    voiceInstruction,
    presetVoiceName,
    speed,
    enabled,
  );

  /// Create a copy of VoiceAsset
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VoiceAssetImplCopyWith<_$VoiceAssetImpl> get copyWith =>
      __$$VoiceAssetImplCopyWithImpl<_$VoiceAssetImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VoiceAssetImplToJson(this);
  }
}

abstract class _VoiceAsset implements VoiceAsset {
  const factory _VoiceAsset({
    required final String id,
    required final String name,
    required final String providerId,
    required final String modelBindingId,
    required final TaskMode taskMode,
    final String? refAudioPath,
    final String? promptText,
    final String? promptLang,
    final String? voiceInstruction,
    final String? presetVoiceName,
    final double speed,
    final bool enabled,
  }) = _$VoiceAssetImpl;

  factory _VoiceAsset.fromJson(Map<String, dynamic> json) =
      _$VoiceAssetImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get providerId;
  @override
  String get modelBindingId;
  @override
  TaskMode get taskMode; // GPT-SoVITS: reference audio path
  @override
  String? get refAudioPath; // GPT-SoVITS: prompt text for the reference audio
  @override
  String? get promptText; // GPT-SoVITS: language of the prompt text
  @override
  String? get promptLang; // Qwen3: voice design instruction
  @override
  String? get voiceInstruction; // OpenAI-compatible: preset voice name
  @override
  String? get presetVoiceName;
  @override
  double get speed;
  @override
  bool get enabled;

  /// Create a copy of VoiceAsset
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VoiceAssetImplCopyWith<_$VoiceAssetImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
