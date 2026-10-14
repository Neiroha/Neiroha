// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'voice_asset.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VoiceAsset {

 String get id; String get name; String get providerId; String get modelBindingId; TaskMode get taskMode; String? get refAudioPath; String? get promptText; String? get promptLang; String? get voiceInstruction; String? get presetVoiceName; double get speed; bool get enabled;
/// Create a copy of VoiceAsset
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoiceAssetCopyWith<VoiceAsset> get copyWith => _$VoiceAssetCopyWithImpl<VoiceAsset>(this as VoiceAsset, _$identity);

  /// Serializes this VoiceAsset to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VoiceAsset;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceAsset&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.providerId, _this.providerId) || other.providerId == _this.providerId)&&(identical(other.modelBindingId, _this.modelBindingId) || other.modelBindingId == _this.modelBindingId)&&(identical(other.taskMode, _this.taskMode) || other.taskMode == _this.taskMode)&&(identical(other.refAudioPath, _this.refAudioPath) || other.refAudioPath == _this.refAudioPath)&&(identical(other.promptText, _this.promptText) || other.promptText == _this.promptText)&&(identical(other.promptLang, _this.promptLang) || other.promptLang == _this.promptLang)&&(identical(other.voiceInstruction, _this.voiceInstruction) || other.voiceInstruction == _this.voiceInstruction)&&(identical(other.presetVoiceName, _this.presetVoiceName) || other.presetVoiceName == _this.presetVoiceName)&&(identical(other.speed, _this.speed) || other.speed == _this.speed)&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VoiceAsset;
  return Object.hash(runtimeType,_this.id,_this.name,_this.providerId,_this.modelBindingId,_this.taskMode,_this.refAudioPath,_this.promptText,_this.promptLang,_this.voiceInstruction,_this.presetVoiceName,_this.speed,_this.enabled);
}

@override
String toString() {
  final _this = this as VoiceAsset;
  return 'VoiceAsset(id: ${_this.id}, name: ${_this.name}, providerId: ${_this.providerId}, modelBindingId: ${_this.modelBindingId}, taskMode: ${_this.taskMode}, refAudioPath: ${_this.refAudioPath}, promptText: ${_this.promptText}, promptLang: ${_this.promptLang}, voiceInstruction: ${_this.voiceInstruction}, presetVoiceName: ${_this.presetVoiceName}, speed: ${_this.speed}, enabled: ${_this.enabled})';
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
  return _then(VoiceAsset(
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
@override final  String? refAudioPath;
@override final  String? promptText;
@override final  String? promptLang;
@override final  String? voiceInstruction;
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
int get hashCode {
    return Object.hash(runtimeType,id,name,providerId,modelBindingId,taskMode,refAudioPath,promptText,promptLang,voiceInstruction,presetVoiceName,speed,enabled);
}

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
