// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tts_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TtsProvider _$TtsProviderFromJson(Map<String, dynamic> json) {
  return _TtsProvider.fromJson(json);
}

/// @nodoc
mixin _$TtsProvider {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  AdapterType get adapterType => throw _privateConstructorUsedError;
  String get baseUrl => throw _privateConstructorUsedError;
  String get apiKey => throw _privateConstructorUsedError;
  bool get enabled => throw _privateConstructorUsedError;

  /// Serializes this TtsProvider to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TtsProvider
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TtsProviderCopyWith<TtsProvider> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TtsProviderCopyWith<$Res> {
  factory $TtsProviderCopyWith(
    TtsProvider value,
    $Res Function(TtsProvider) then,
  ) = _$TtsProviderCopyWithImpl<$Res, TtsProvider>;
  @useResult
  $Res call({
    String id,
    String name,
    AdapterType adapterType,
    String baseUrl,
    String apiKey,
    bool enabled,
  });
}

/// @nodoc
class _$TtsProviderCopyWithImpl<$Res, $Val extends TtsProvider>
    implements $TtsProviderCopyWith<$Res> {
  _$TtsProviderCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TtsProvider
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? adapterType = null,
    Object? baseUrl = null,
    Object? apiKey = null,
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
            adapterType: null == adapterType
                ? _value.adapterType
                : adapterType // ignore: cast_nullable_to_non_nullable
                      as AdapterType,
            baseUrl: null == baseUrl
                ? _value.baseUrl
                : baseUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            apiKey: null == apiKey
                ? _value.apiKey
                : apiKey // ignore: cast_nullable_to_non_nullable
                      as String,
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
abstract class _$$TtsProviderImplCopyWith<$Res>
    implements $TtsProviderCopyWith<$Res> {
  factory _$$TtsProviderImplCopyWith(
    _$TtsProviderImpl value,
    $Res Function(_$TtsProviderImpl) then,
  ) = __$$TtsProviderImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    AdapterType adapterType,
    String baseUrl,
    String apiKey,
    bool enabled,
  });
}

/// @nodoc
class __$$TtsProviderImplCopyWithImpl<$Res>
    extends _$TtsProviderCopyWithImpl<$Res, _$TtsProviderImpl>
    implements _$$TtsProviderImplCopyWith<$Res> {
  __$$TtsProviderImplCopyWithImpl(
    _$TtsProviderImpl _value,
    $Res Function(_$TtsProviderImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TtsProvider
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? adapterType = null,
    Object? baseUrl = null,
    Object? apiKey = null,
    Object? enabled = null,
  }) {
    return _then(
      _$TtsProviderImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        adapterType: null == adapterType
            ? _value.adapterType
            : adapterType // ignore: cast_nullable_to_non_nullable
                  as AdapterType,
        baseUrl: null == baseUrl
            ? _value.baseUrl
            : baseUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        apiKey: null == apiKey
            ? _value.apiKey
            : apiKey // ignore: cast_nullable_to_non_nullable
                  as String,
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
class _$TtsProviderImpl implements _TtsProvider {
  const _$TtsProviderImpl({
    required this.id,
    required this.name,
    required this.adapterType,
    required this.baseUrl,
    this.apiKey = '',
    this.enabled = true,
  });

  factory _$TtsProviderImpl.fromJson(Map<String, dynamic> json) =>
      _$$TtsProviderImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final AdapterType adapterType;
  @override
  final String baseUrl;
  @override
  @JsonKey()
  final String apiKey;
  @override
  @JsonKey()
  final bool enabled;

  @override
  String toString() {
    return 'TtsProvider(id: $id, name: $name, adapterType: $adapterType, baseUrl: $baseUrl, apiKey: $apiKey, enabled: $enabled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TtsProviderImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.adapterType, adapterType) ||
                other.adapterType == adapterType) &&
            (identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl) &&
            (identical(other.apiKey, apiKey) || other.apiKey == apiKey) &&
            (identical(other.enabled, enabled) || other.enabled == enabled));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, adapterType, baseUrl, apiKey, enabled);

  /// Create a copy of TtsProvider
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TtsProviderImplCopyWith<_$TtsProviderImpl> get copyWith =>
      __$$TtsProviderImplCopyWithImpl<_$TtsProviderImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TtsProviderImplToJson(this);
  }
}

abstract class _TtsProvider implements TtsProvider {
  const factory _TtsProvider({
    required final String id,
    required final String name,
    required final AdapterType adapterType,
    required final String baseUrl,
    final String apiKey,
    final bool enabled,
  }) = _$TtsProviderImpl;

  factory _TtsProvider.fromJson(Map<String, dynamic> json) =
      _$TtsProviderImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  AdapterType get adapterType;
  @override
  String get baseUrl;
  @override
  String get apiKey;
  @override
  bool get enabled;

  /// Create a copy of TtsProvider
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TtsProviderImplCopyWith<_$TtsProviderImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
