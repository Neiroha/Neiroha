// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'voice_asset.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VoiceAsset {

 String get id; String get name; String get providerId; String get modelBindingId; TaskMode get taskMode;// GPT-SoVITS: reference audio path
 String? get refAudioPath;// GPT-SoVITS: prompt text for the reference audio
 String? get promptText;// GPT-SoVITS: language of the prompt text
 String? get promptLang;// Qwen3: voice design instruction
 String? get voiceInstruction;// OpenAI-compatible: preset voice name
 String? get presetVoiceName; double get speed; bool get enabled;
/// Create a copy of VoiceAsset
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoiceAssetCopyWith<VoiceAsset> get copyWith => _$VoiceAssetCopyWithImpl<VoiceAsset>(this as VoiceAsset, _$identity);

  /// Serializes this VoiceAsset to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceAsset&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.modelBindingId, modelBindingId) || other.modelBindingId == modelBindingId)&&(identical(other.taskMode, taskMode) || other.taskMode == taskMode)&&(identical(other.refAudioPath, refAudioPath) || other.refAudioPath == refAudioPath)&&(identical(other.promptText, promptText) || other.promptText == promptText)&&(identical(other.promptLang, promptLang) || other.promptLang == promptLang)&&(identical(other.voiceInstruction, voiceInstruction) || other.voiceInstruction == voiceInstruction)&&(identical(other.presetVoiceName, presetVoiceName) || other.presetVoiceName == presetVoiceName)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,providerId,modelBindingId,taskMode,refAudioPath,promptText,promptLang,voiceInstruction,presetVoiceName,speed,enabled);

@override
String toString() {
  return 'VoiceAsset(id: $id, name: $name, providerId: $providerId, modelBindingId: $modelBindingId, taskMode: $taskMode, refAudioPath: $refAudioPath, promptText: $promptText, promptLang: $promptLang, voiceInstruction: $voiceInstruction, presetVoiceName: $presetVoiceName, speed: $speed, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class $VoiceAssetCopyWith<$Res>  {
  factory $VoiceAssetCopyWith(VoiceAsset value, $Res Function(VoiceAsset) _then) = _$VoiceAssetCopyWithImpl;
@useResult
$Res call({
 String id, String name, String providerId, String modelBindingId, TaskMode taskMode, String? refAudioPath, String? promptText, String? promptLang, String? voiceInstruction, String? presetVoiceName, double speed, bool enabled
});




}
/// @nodoc
class _$VoiceAssetCopyWithImpl<$Res>
    implements $VoiceAssetCopyWith<$Res> {
  _$VoiceAssetCopyWithImpl(this._self, this._then);

  final VoiceAsset _self;
  final $Res Function(VoiceAsset) _then;

/// Create a copy of VoiceAsset
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? providerId = null,Object? modelBindingId = null,Object? taskMode = null,Object? refAudioPath = freezed,Object? promptText = freezed,Object? promptLang = freezed,Object? voiceInstruction = freezed,Object? presetVoiceName = freezed,Object? speed = null,Object? enabled = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,modelBindingId: null == modelBindingId ? _self.modelBindingId : modelBindingId // ignore: cast_nullable_to_non_nullable
as String,taskMode: null == taskMode ? _self.taskMode : taskMode // ignore: cast_nullable_to_non_nullable
as TaskMode,refAudioPath: freezed == refAudioPath ? _self.refAudioPath : refAudioPath // ignore: cast_nullable_to_non_nullable
as String?,promptText: freezed == promptText ? _self.promptText : promptText // ignore: cast_nullable_to_non_nullable
as String?,promptLang: freezed == promptLang ? _self.promptLang : promptLang // ignore: cast_nullable_to_non_nullable
as String?,voiceInstruction: freezed == voiceInstruction ? _self.voiceInstruction : voiceInstruction // ignore: cast_nullable_to_non_nullable
as String?,presetVoiceName: freezed == presetVoiceName ? _self.presetVoiceName : presetVoiceName // ignore: cast_nullable_to_non_nullable
as String?,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VoiceAsset].
extension VoiceAssetPatterns on VoiceAsset {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VoiceAsset value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VoiceAsset() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VoiceAsset value)  $default,){
final _that = this;
switch (_that) {
case _VoiceAsset():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VoiceAsset value)?  $default,){
final _that = this;
switch (_that) {
case _VoiceAsset() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String providerId,  String modelBindingId,  TaskMode taskMode,  String? refAudioPath,  String? promptText,  String? promptLang,  String? voiceInstruction,  String? presetVoiceName,  double speed,  bool enabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VoiceAsset() when $default != null:
return $default(_that.id,_that.name,_that.providerId,_that.modelBindingId,_that.taskMode,_that.refAudioPath,_that.promptText,_that.promptLang,_that.voiceInstruction,_that.presetVoiceName,_that.speed,_that.enabled);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String providerId,  String modelBindingId,  TaskMode taskMode,  String? refAudioPath,  String? promptText,  String? promptLang,  String? voiceInstruction,  String? presetVoiceName,  double speed,  bool enabled)  $default,) {final _that = this;
switch (_that) {
case _VoiceAsset():
return $default(_that.id,_that.name,_that.providerId,_that.modelBindingId,_that.taskMode,_that.refAudioPath,_that.promptText,_that.promptLang,_that.voiceInstruction,_that.presetVoiceName,_that.speed,_that.enabled);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String providerId,  String modelBindingId,  TaskMode taskMode,  String? refAudioPath,  String? promptText,  String? promptLang,  String? voiceInstruction,  String? presetVoiceName,  double speed,  bool enabled)?  $default,) {final _that = this;
switch (_that) {
case _VoiceAsset() when $default != null:
return $default(_that.id,_that.name,_that.providerId,_that.modelBindingId,_that.taskMode,_that.refAudioPath,_that.promptText,_that.promptLang,_that.voiceInstruction,_that.presetVoiceName,_that.speed,_that.enabled);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VoiceAsset implements VoiceAsset {
  const _VoiceAsset({required this.id, required this.name, required this.providerId, required this.modelBindingId, required this.taskMode, this.refAudioPath, this.promptText, this.promptLang, this.voiceInstruction, this.presetVoiceName, this.speed = 1.0, this.enabled = true});
  factory _VoiceAsset.fromJson(Map<String, dynamic> json) => _$VoiceAssetFromJson(json);

@override final  String id;
@override final  String name;
@override final  String providerId;
@override final  String modelBindingId;
@override final  TaskMode taskMode;
// GPT-SoVITS: reference audio path
@override final  String? refAudioPath;
// GPT-SoVITS: prompt text for the reference audio
@override final  String? promptText;
// GPT-SoVITS: language of the prompt text
@override final  String? promptLang;
// Qwen3: voice design instruction
@override final  String? voiceInstruction;
// OpenAI-compatible: preset voice name
@override final  String? presetVoiceName;
@override@JsonKey() final  double speed;
@override@JsonKey() final  bool enabled;

/// Create a copy of VoiceAsset
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VoiceAssetCopyWith<_VoiceAsset> get copyWith => __$VoiceAssetCopyWithImpl<_VoiceAsset>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VoiceAssetToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VoiceAsset&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.modelBindingId, modelBindingId) || other.modelBindingId == modelBindingId)&&(identical(other.taskMode, taskMode) || other.taskMode == taskMode)&&(identical(other.refAudioPath, refAudioPath) || other.refAudioPath == refAudioPath)&&(identical(other.promptText, promptText) || other.promptText == promptText)&&(identical(other.promptLang, promptLang) || other.promptLang == promptLang)&&(identical(other.voiceInstruction, voiceInstruction) || other.voiceInstruction == voiceInstruction)&&(identical(other.presetVoiceName, presetVoiceName) || other.presetVoiceName == presetVoiceName)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,providerId,modelBindingId,taskMode,refAudioPath,promptText,promptLang,voiceInstruction,presetVoiceName,speed,enabled);

@override
String toString() {
  return 'VoiceAsset(id: $id, name: $name, providerId: $providerId, modelBindingId: $modelBindingId, taskMode: $taskMode, refAudioPath: $refAudioPath, promptText: $promptText, promptLang: $promptLang, voiceInstruction: $voiceInstruction, presetVoiceName: $presetVoiceName, speed: $speed, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class _$VoiceAssetCopyWith<$Res> implements $VoiceAssetCopyWith<$Res> {
  factory _$VoiceAssetCopyWith(_VoiceAsset value, $Res Function(_VoiceAsset) _then) = __$VoiceAssetCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String providerId, String modelBindingId, TaskMode taskMode, String? refAudioPath, String? promptText, String? promptLang, String? voiceInstruction, String? presetVoiceName, double speed, bool enabled
});




}
/// @nodoc
class __$VoiceAssetCopyWithImpl<$Res>
    implements _$VoiceAssetCopyWith<$Res> {
  __$VoiceAssetCopyWithImpl(this._self, this._then);

  final _VoiceAsset _self;
  final $Res Function(_VoiceAsset) _then;

/// Create a copy of VoiceAsset
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? providerId = null,Object? modelBindingId = null,Object? taskMode = null,Object? refAudioPath = freezed,Object? promptText = freezed,Object? promptLang = freezed,Object? voiceInstruction = freezed,Object? presetVoiceName = freezed,Object? speed = null,Object? enabled = null,}) {
  return _then(_VoiceAsset(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,modelBindingId: null == modelBindingId ? _self.modelBindingId : modelBindingId // ignore: cast_nullable_to_non_nullable
as String,taskMode: null == taskMode ? _self.taskMode : taskMode // ignore: cast_nullable_to_non_nullable
as TaskMode,refAudioPath: freezed == refAudioPath ? _self.refAudioPath : refAudioPath // ignore: cast_nullable_to_non_nullable
as String?,promptText: freezed == promptText ? _self.promptText : promptText // ignore: cast_nullable_to_non_nullable
as String?,promptLang: freezed == promptLang ? _self.promptLang : promptLang // ignore: cast_nullable_to_non_nullable
as String?,voiceInstruction: freezed == voiceInstruction ? _self.voiceInstruction : voiceInstruction // ignore: cast_nullable_to_non_nullable
as String?,presetVoiceName: freezed == presetVoiceName ? _self.presetVoiceName : presetVoiceName // ignore: cast_nullable_to_non_nullable
as String?,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
