// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'model_binding.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ModelBinding _$ModelBindingFromJson(Map<String, dynamic> json) {
  return _ModelBinding.fromJson(json);
}

/// @nodoc
mixin _$ModelBinding {
  String get id => throw _privateConstructorUsedError;
  String get providerId => throw _privateConstructorUsedError;
  String get modelKey => throw _privateConstructorUsedError;
  List<TaskMode> get supportedTaskModes => throw _privateConstructorUsedError;

  /// Serializes this ModelBinding to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ModelBinding
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ModelBindingCopyWith<ModelBinding> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ModelBindingCopyWith<$Res> {
  factory $ModelBindingCopyWith(
    ModelBinding value,
    $Res Function(ModelBinding) then,
  ) = _$ModelBindingCopyWithImpl<$Res, ModelBinding>;
  @useResult
  $Res call({
    String id,
    String providerId,
    String modelKey,
    List<TaskMode> supportedTaskModes,
  });
}

/// @nodoc
class _$ModelBindingCopyWithImpl<$Res, $Val extends ModelBinding>
    implements $ModelBindingCopyWith<$Res> {
  _$ModelBindingCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ModelBinding
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? providerId = null,
    Object? modelKey = null,
    Object? supportedTaskModes = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            providerId: null == providerId
                ? _value.providerId
                : providerId // ignore: cast_nullable_to_non_nullable
                      as String,
            modelKey: null == modelKey
                ? _value.modelKey
                : modelKey // ignore: cast_nullable_to_non_nullable
                      as String,
            supportedTaskModes: null == supportedTaskModes
                ? _value.supportedTaskModes
                : supportedTaskModes // ignore: cast_nullable_to_non_nullable
                      as List<TaskMode>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ModelBindingImplCopyWith<$Res>
    implements $ModelBindingCopyWith<$Res> {
  factory _$$ModelBindingImplCopyWith(
    _$ModelBindingImpl value,
    $Res Function(_$ModelBindingImpl) then,
  ) = __$$ModelBindingImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String providerId,
    String modelKey,
    List<TaskMode> supportedTaskModes,
  });
}

/// @nodoc
class __$$ModelBindingImplCopyWithImpl<$Res>
    extends _$ModelBindingCopyWithImpl<$Res, _$ModelBindingImpl>
    implements _$$ModelBindingImplCopyWith<$Res> {
  __$$ModelBindingImplCopyWithImpl(
    _$ModelBindingImpl _value,
    $Res Function(_$ModelBindingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ModelBinding
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? providerId = null,
    Object? modelKey = null,
    Object? supportedTaskModes = null,
  }) {
    return _then(
      _$ModelBindingImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        providerId: null == providerId
            ? _value.providerId
            : providerId // ignore: cast_nullable_to_non_nullable
                  as String,
        modelKey: null == modelKey
            ? _value.modelKey
            : modelKey // ignore: cast_nullable_to_non_nullable
                  as String,
        supportedTaskModes: null == supportedTaskModes
            ? _value._supportedTaskModes
            : supportedTaskModes // ignore: cast_nullable_to_non_nullable
                  as List<TaskMode>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ModelBindingImpl implements _ModelBinding {
  const _$ModelBindingImpl({
    required this.id,
    required this.providerId,
    required this.modelKey,
    final List<TaskMode> supportedTaskModes = const [],
  }) : _supportedTaskModes = supportedTaskModes;

  factory _$ModelBindingImpl.fromJson(Map<String, dynamic> json) =>
      _$$ModelBindingImplFromJson(json);

  @override
  final String id;
  @override
  final String providerId;
  @override
  final String modelKey;
  final List<TaskMode> _supportedTaskModes;
  @override
  @JsonKey()
  List<TaskMode> get supportedTaskModes {
    if (_supportedTaskModes is EqualUnmodifiableListView)
      return _supportedTaskModes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_supportedTaskModes);
  }

  @override
  String toString() {
    return 'ModelBinding(id: $id, providerId: $providerId, modelKey: $modelKey, supportedTaskModes: $supportedTaskModes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ModelBindingImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.providerId, providerId) ||
                other.providerId == providerId) &&
            (identical(other.modelKey, modelKey) ||
                other.modelKey == modelKey) &&
            const DeepCollectionEquality().equals(
              other._supportedTaskModes,
              _supportedTaskModes,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    providerId,
    modelKey,
    const DeepCollectionEquality().hash(_supportedTaskModes),
  );

  /// Create a copy of ModelBinding
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ModelBindingImplCopyWith<_$ModelBindingImpl> get copyWith =>
      __$$ModelBindingImplCopyWithImpl<_$ModelBindingImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ModelBindingImplToJson(this);
  }
}

abstract class _ModelBinding implements ModelBinding {
  const factory _ModelBinding({
    required final String id,
    required final String providerId,
    required final String modelKey,
    final List<TaskMode> supportedTaskModes,
  }) = _$ModelBindingImpl;

  factory _ModelBinding.fromJson(Map<String, dynamic> json) =
      _$ModelBindingImpl.fromJson;

  @override
  String get id;
  @override
  String get providerId;
  @override
  String get modelKey;
  @override
  List<TaskMode> get supportedTaskModes;

  /// Create a copy of ModelBinding
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ModelBindingImplCopyWith<_$ModelBindingImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
