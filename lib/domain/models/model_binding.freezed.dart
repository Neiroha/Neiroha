// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'model_binding.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ModelBinding {

 String get id; String get providerId; String get modelKey; List<TaskMode> get supportedTaskModes;
/// Create a copy of ModelBinding
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModelBindingCopyWith<ModelBinding> get copyWith => _$ModelBindingCopyWithImpl<ModelBinding>(this as ModelBinding, _$identity);

  /// Serializes this ModelBinding to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModelBinding&&(identical(other.id, id) || other.id == id)&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.modelKey, modelKey) || other.modelKey == modelKey)&&const DeepCollectionEquality().equals(other.supportedTaskModes, supportedTaskModes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,providerId,modelKey,const DeepCollectionEquality().hash(supportedTaskModes));

@override
String toString() {
  return 'ModelBinding(id: $id, providerId: $providerId, modelKey: $modelKey, supportedTaskModes: $supportedTaskModes)';
}


}

/// @nodoc
abstract mixin class $ModelBindingCopyWith<$Res>  {
  factory $ModelBindingCopyWith(ModelBinding value, $Res Function(ModelBinding) _then) = _$ModelBindingCopyWithImpl;
@useResult
$Res call({
 String id, String providerId, String modelKey, List<TaskMode> supportedTaskModes
});




}
/// @nodoc
class _$ModelBindingCopyWithImpl<$Res>
    implements $ModelBindingCopyWith<$Res> {
  _$ModelBindingCopyWithImpl(this._self, this._then);

  final ModelBinding _self;
  final $Res Function(ModelBinding) _then;

/// Create a copy of ModelBinding
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? providerId = null,Object? modelKey = null,Object? supportedTaskModes = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,modelKey: null == modelKey ? _self.modelKey : modelKey // ignore: cast_nullable_to_non_nullable
as String,supportedTaskModes: null == supportedTaskModes ? _self.supportedTaskModes : supportedTaskModes // ignore: cast_nullable_to_non_nullable
as List<TaskMode>,
  ));
}

}


/// Adds pattern-matching-related methods to [ModelBinding].
extension ModelBindingPatterns on ModelBinding {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ModelBinding value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ModelBinding() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ModelBinding value)  $default,){
final _that = this;
switch (_that) {
case _ModelBinding():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ModelBinding value)?  $default,){
final _that = this;
switch (_that) {
case _ModelBinding() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String providerId,  String modelKey,  List<TaskMode> supportedTaskModes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ModelBinding() when $default != null:
return $default(_that.id,_that.providerId,_that.modelKey,_that.supportedTaskModes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String providerId,  String modelKey,  List<TaskMode> supportedTaskModes)  $default,) {final _that = this;
switch (_that) {
case _ModelBinding():
return $default(_that.id,_that.providerId,_that.modelKey,_that.supportedTaskModes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String providerId,  String modelKey,  List<TaskMode> supportedTaskModes)?  $default,) {final _that = this;
switch (_that) {
case _ModelBinding() when $default != null:
return $default(_that.id,_that.providerId,_that.modelKey,_that.supportedTaskModes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ModelBinding implements ModelBinding {
  const _ModelBinding({required this.id, required this.providerId, required this.modelKey, final  List<TaskMode> supportedTaskModes = const []}): _supportedTaskModes = supportedTaskModes;
  factory _ModelBinding.fromJson(Map<String, dynamic> json) => _$ModelBindingFromJson(json);

@override final  String id;
@override final  String providerId;
@override final  String modelKey;
 final  List<TaskMode> _supportedTaskModes;
@override@JsonKey() List<TaskMode> get supportedTaskModes {
  if (_supportedTaskModes is EqualUnmodifiableListView) return _supportedTaskModes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_supportedTaskModes);
}


/// Create a copy of ModelBinding
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModelBindingCopyWith<_ModelBinding> get copyWith => __$ModelBindingCopyWithImpl<_ModelBinding>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ModelBindingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModelBinding&&(identical(other.id, id) || other.id == id)&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.modelKey, modelKey) || other.modelKey == modelKey)&&const DeepCollectionEquality().equals(other._supportedTaskModes, _supportedTaskModes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,providerId,modelKey,const DeepCollectionEquality().hash(_supportedTaskModes));

@override
String toString() {
  return 'ModelBinding(id: $id, providerId: $providerId, modelKey: $modelKey, supportedTaskModes: $supportedTaskModes)';
}


}

/// @nodoc
abstract mixin class _$ModelBindingCopyWith<$Res> implements $ModelBindingCopyWith<$Res> {
  factory _$ModelBindingCopyWith(_ModelBinding value, $Res Function(_ModelBinding) _then) = __$ModelBindingCopyWithImpl;
@override @useResult
$Res call({
 String id, String providerId, String modelKey, List<TaskMode> supportedTaskModes
});




}
/// @nodoc
class __$ModelBindingCopyWithImpl<$Res>
    implements _$ModelBindingCopyWith<$Res> {
  __$ModelBindingCopyWithImpl(this._self, this._then);

  final _ModelBinding _self;
  final $Res Function(_ModelBinding) _then;

/// Create a copy of ModelBinding
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? providerId = null,Object? modelKey = null,Object? supportedTaskModes = null,}) {
  return _then(_ModelBinding(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,modelKey: null == modelKey ? _self.modelKey : modelKey // ignore: cast_nullable_to_non_nullable
as String,supportedTaskModes: null == supportedTaskModes ? _self._supportedTaskModes : supportedTaskModes // ignore: cast_nullable_to_non_nullable
as List<TaskMode>,
  ));
}


}

// dart format on
