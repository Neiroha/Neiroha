// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tts_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TtsProvider {

 String get id; String get name; AdapterType get adapterType; String get baseUrl; String get apiKey; bool get enabled;
/// Create a copy of TtsProvider
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TtsProviderCopyWith<TtsProvider> get copyWith => _$TtsProviderCopyWithImpl<TtsProvider>(this as TtsProvider, _$identity);

  /// Serializes this TtsProvider to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TtsProvider;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TtsProvider&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.adapterType, _this.adapterType) || other.adapterType == _this.adapterType)&&(identical(other.baseUrl, _this.baseUrl) || other.baseUrl == _this.baseUrl)&&(identical(other.apiKey, _this.apiKey) || other.apiKey == _this.apiKey)&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TtsProvider;
  return Object.hash(runtimeType,_this.id,_this.name,_this.adapterType,_this.baseUrl,_this.apiKey,_this.enabled);
}

@override
String toString() {
  final _this = this as TtsProvider;
  return 'TtsProvider(id: ${_this.id}, name: ${_this.name}, adapterType: ${_this.adapterType}, baseUrl: ${_this.baseUrl}, apiKey: ${_this.apiKey}, enabled: ${_this.enabled})';
}


}

/// @nodoc
abstract mixin class $TtsProviderCopyWith<$Res>  {
  factory $TtsProviderCopyWith(TtsProvider value, $Res Function(TtsProvider) _then) = _$TtsProviderCopyWithImpl;
@useResult
$Res call({
 String id, String name, AdapterType adapterType, String baseUrl, String apiKey, bool enabled
});




}
/// @nodoc
class _$TtsProviderCopyWithImpl<$Res>
    implements $TtsProviderCopyWith<$Res> {
  _$TtsProviderCopyWithImpl(this._self, this._then);

  final TtsProvider _self;
  final $Res Function(TtsProvider) _then;

/// Create a copy of TtsProvider
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? adapterType = null,Object? baseUrl = null,Object? apiKey = null,Object? enabled = null,}) {
  return _then(TtsProvider(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,adapterType: null == adapterType ? _self.adapterType : adapterType // ignore: cast_nullable_to_non_nullable
as AdapterType,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TtsProvider].
extension TtsProviderPatterns on TtsProvider {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TtsProvider value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TtsProvider() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TtsProvider value)  $default,){
final _that = this;
switch (_that) {
case _TtsProvider():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TtsProvider value)?  $default,){
final _that = this;
switch (_that) {
case _TtsProvider() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  AdapterType adapterType,  String baseUrl,  String apiKey,  bool enabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TtsProvider() when $default != null:
return $default(_that.id,_that.name,_that.adapterType,_that.baseUrl,_that.apiKey,_that.enabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  AdapterType adapterType,  String baseUrl,  String apiKey,  bool enabled)  $default,) {final _that = this;
switch (_that) {
case _TtsProvider():
return $default(_that.id,_that.name,_that.adapterType,_that.baseUrl,_that.apiKey,_that.enabled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  AdapterType adapterType,  String baseUrl,  String apiKey,  bool enabled)?  $default,) {final _that = this;
switch (_that) {
case _TtsProvider() when $default != null:
return $default(_that.id,_that.name,_that.adapterType,_that.baseUrl,_that.apiKey,_that.enabled);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TtsProvider implements TtsProvider {
  const _TtsProvider({required this.id, required this.name, required this.adapterType, required this.baseUrl, this.apiKey = '', this.enabled = true});
  factory _TtsProvider.fromJson(Map<String, dynamic> json) => _$TtsProviderFromJson(json);

@override final  String id;
@override final  String name;
@override final  AdapterType adapterType;
@override final  String baseUrl;
@override@JsonKey() final  String apiKey;
@override@JsonKey() final  bool enabled;

/// Create a copy of TtsProvider
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TtsProviderCopyWith<_TtsProvider> get copyWith => __$TtsProviderCopyWithImpl<_TtsProvider>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TtsProviderToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TtsProvider&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.adapterType, adapterType) || other.adapterType == adapterType)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,adapterType,baseUrl,apiKey,enabled);
}

@override
String toString() {
    return 'TtsProvider(id: $id, name: $name, adapterType: $adapterType, baseUrl: $baseUrl, apiKey: $apiKey, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class _$TtsProviderCopyWith<$Res> implements $TtsProviderCopyWith<$Res> {
  factory _$TtsProviderCopyWith(_TtsProvider value, $Res Function(_TtsProvider) _then) = __$TtsProviderCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, AdapterType adapterType, String baseUrl, String apiKey, bool enabled
});




}
/// @nodoc
class __$TtsProviderCopyWithImpl<$Res>
    implements _$TtsProviderCopyWith<$Res> {
  __$TtsProviderCopyWithImpl(this._self, this._then);

  final _TtsProvider _self;
  final $Res Function(_TtsProvider) _then;

/// Create a copy of TtsProvider
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? adapterType = null,Object? baseUrl = null,Object? apiKey = null,Object? enabled = null,}) {
  return _then(_TtsProvider(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,adapterType: null == adapterType ? _self.adapterType : adapterType // ignore: cast_nullable_to_non_nullable
as AdapterType,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
