// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tts_job.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TtsJob {

 String get id; String get voiceAssetId; String get inputText; JobStatus get status; String? get outputPath; String? get errorMessage; DateTime get createdAt; DateTime? get completedAt;
/// Create a copy of TtsJob
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TtsJobCopyWith<TtsJob> get copyWith => _$TtsJobCopyWithImpl<TtsJob>(this as TtsJob, _$identity);

  /// Serializes this TtsJob to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TtsJob&&(identical(other.id, id) || other.id == id)&&(identical(other.voiceAssetId, voiceAssetId) || other.voiceAssetId == voiceAssetId)&&(identical(other.inputText, inputText) || other.inputText == inputText)&&(identical(other.status, status) || other.status == status)&&(identical(other.outputPath, outputPath) || other.outputPath == outputPath)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,voiceAssetId,inputText,status,outputPath,errorMessage,createdAt,completedAt);

@override
String toString() {
  return 'TtsJob(id: $id, voiceAssetId: $voiceAssetId, inputText: $inputText, status: $status, outputPath: $outputPath, errorMessage: $errorMessage, createdAt: $createdAt, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class $TtsJobCopyWith<$Res>  {
  factory $TtsJobCopyWith(TtsJob value, $Res Function(TtsJob) _then) = _$TtsJobCopyWithImpl;
@useResult
$Res call({
 String id, String voiceAssetId, String inputText, JobStatus status, String? outputPath, String? errorMessage, DateTime createdAt, DateTime? completedAt
});




}
/// @nodoc
class _$TtsJobCopyWithImpl<$Res>
    implements $TtsJobCopyWith<$Res> {
  _$TtsJobCopyWithImpl(this._self, this._then);

  final TtsJob _self;
  final $Res Function(TtsJob) _then;

/// Create a copy of TtsJob
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? voiceAssetId = null,Object? inputText = null,Object? status = null,Object? outputPath = freezed,Object? errorMessage = freezed,Object? createdAt = null,Object? completedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,voiceAssetId: null == voiceAssetId ? _self.voiceAssetId : voiceAssetId // ignore: cast_nullable_to_non_nullable
as String,inputText: null == inputText ? _self.inputText : inputText // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as JobStatus,outputPath: freezed == outputPath ? _self.outputPath : outputPath // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [TtsJob].
extension TtsJobPatterns on TtsJob {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TtsJob value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TtsJob() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TtsJob value)  $default,){
final _that = this;
switch (_that) {
case _TtsJob():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TtsJob value)?  $default,){
final _that = this;
switch (_that) {
case _TtsJob() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String voiceAssetId,  String inputText,  JobStatus status,  String? outputPath,  String? errorMessage,  DateTime createdAt,  DateTime? completedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TtsJob() when $default != null:
return $default(_that.id,_that.voiceAssetId,_that.inputText,_that.status,_that.outputPath,_that.errorMessage,_that.createdAt,_that.completedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String voiceAssetId,  String inputText,  JobStatus status,  String? outputPath,  String? errorMessage,  DateTime createdAt,  DateTime? completedAt)  $default,) {final _that = this;
switch (_that) {
case _TtsJob():
return $default(_that.id,_that.voiceAssetId,_that.inputText,_that.status,_that.outputPath,_that.errorMessage,_that.createdAt,_that.completedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String voiceAssetId,  String inputText,  JobStatus status,  String? outputPath,  String? errorMessage,  DateTime createdAt,  DateTime? completedAt)?  $default,) {final _that = this;
switch (_that) {
case _TtsJob() when $default != null:
return $default(_that.id,_that.voiceAssetId,_that.inputText,_that.status,_that.outputPath,_that.errorMessage,_that.createdAt,_that.completedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TtsJob implements TtsJob {
  const _TtsJob({required this.id, required this.voiceAssetId, required this.inputText, required this.status, this.outputPath, this.errorMessage, required this.createdAt, this.completedAt});
  factory _TtsJob.fromJson(Map<String, dynamic> json) => _$TtsJobFromJson(json);

@override final  String id;
@override final  String voiceAssetId;
@override final  String inputText;
@override final  JobStatus status;
@override final  String? outputPath;
@override final  String? errorMessage;
@override final  DateTime createdAt;
@override final  DateTime? completedAt;

/// Create a copy of TtsJob
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TtsJobCopyWith<_TtsJob> get copyWith => __$TtsJobCopyWithImpl<_TtsJob>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TtsJobToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TtsJob&&(identical(other.id, id) || other.id == id)&&(identical(other.voiceAssetId, voiceAssetId) || other.voiceAssetId == voiceAssetId)&&(identical(other.inputText, inputText) || other.inputText == inputText)&&(identical(other.status, status) || other.status == status)&&(identical(other.outputPath, outputPath) || other.outputPath == outputPath)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,voiceAssetId,inputText,status,outputPath,errorMessage,createdAt,completedAt);

@override
String toString() {
  return 'TtsJob(id: $id, voiceAssetId: $voiceAssetId, inputText: $inputText, status: $status, outputPath: $outputPath, errorMessage: $errorMessage, createdAt: $createdAt, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class _$TtsJobCopyWith<$Res> implements $TtsJobCopyWith<$Res> {
  factory _$TtsJobCopyWith(_TtsJob value, $Res Function(_TtsJob) _then) = __$TtsJobCopyWithImpl;
@override @useResult
$Res call({
 String id, String voiceAssetId, String inputText, JobStatus status, String? outputPath, String? errorMessage, DateTime createdAt, DateTime? completedAt
});




}
/// @nodoc
class __$TtsJobCopyWithImpl<$Res>
    implements _$TtsJobCopyWith<$Res> {
  __$TtsJobCopyWithImpl(this._self, this._then);

  final _TtsJob _self;
  final $Res Function(_TtsJob) _then;

/// Create a copy of TtsJob
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? voiceAssetId = null,Object? inputText = null,Object? status = null,Object? outputPath = freezed,Object? errorMessage = freezed,Object? createdAt = null,Object? completedAt = freezed,}) {
  return _then(_TtsJob(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,voiceAssetId: null == voiceAssetId ? _self.voiceAssetId : voiceAssetId // ignore: cast_nullable_to_non_nullable
as String,inputText: null == inputText ? _self.inputText : inputText // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as JobStatus,outputPath: freezed == outputPath ? _self.outputPath : outputPath // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
