// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TtsProvidersTable extends TtsProviders
    with TableInfo<$TtsProvidersTable, TtsProvider> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TtsProvidersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _adapterTypeMeta = const VerificationMeta(
    'adapterType',
  );
  @override
  late final GeneratedColumn<String> adapterType = GeneratedColumn<String>(
    'adapter_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _apiKeyMeta = const VerificationMeta('apiKey');
  @override
  late final GeneratedColumn<String> apiKey = GeneratedColumn<String>(
    'api_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _defaultModelNameMeta = const VerificationMeta(
    'defaultModelName',
  );
  @override
  late final GeneratedColumn<String> defaultModelName = GeneratedColumn<String>(
    'default_model_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('tts-1'),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    adapterType,
    baseUrl,
    apiKey,
    defaultModelName,
    enabled,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tts_providers';
  @override
  VerificationContext validateIntegrity(
    Insertable<TtsProvider> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('adapter_type')) {
      context.handle(
        _adapterTypeMeta,
        adapterType.isAcceptableOrUnknown(
          data['adapter_type']!,
          _adapterTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_adapterTypeMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('api_key')) {
      context.handle(
        _apiKeyMeta,
        apiKey.isAcceptableOrUnknown(data['api_key']!, _apiKeyMeta),
      );
    }
    if (data.containsKey('default_model_name')) {
      context.handle(
        _defaultModelNameMeta,
        defaultModelName.isAcceptableOrUnknown(
          data['default_model_name']!,
          _defaultModelNameMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TtsProvider map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TtsProvider(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      adapterType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}adapter_type'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      apiKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}api_key'],
      )!,
      defaultModelName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_model_name'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $TtsProvidersTable createAlias(String alias) {
    return $TtsProvidersTable(attachedDatabase, alias);
  }
}

class TtsProvider extends DataClass implements Insertable<TtsProvider> {
  final String id;
  final String name;
  final String adapterType;
  final String baseUrl;
  final String apiKey;
  final String defaultModelName;
  final bool enabled;
  final int position;
  const TtsProvider({
    required this.id,
    required this.name,
    required this.adapterType,
    required this.baseUrl,
    required this.apiKey,
    required this.defaultModelName,
    required this.enabled,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['adapter_type'] = Variable<String>(adapterType);
    map['base_url'] = Variable<String>(baseUrl);
    map['api_key'] = Variable<String>(apiKey);
    map['default_model_name'] = Variable<String>(defaultModelName);
    map['enabled'] = Variable<bool>(enabled);
    map['position'] = Variable<int>(position);
    return map;
  }

  TtsProvidersCompanion toCompanion(bool nullToAbsent) {
    return TtsProvidersCompanion(
      id: Value(id),
      name: Value(name),
      adapterType: Value(adapterType),
      baseUrl: Value(baseUrl),
      apiKey: Value(apiKey),
      defaultModelName: Value(defaultModelName),
      enabled: Value(enabled),
      position: Value(position),
    );
  }

  factory TtsProvider.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TtsProvider(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      adapterType: serializer.fromJson<String>(json['adapterType']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      apiKey: serializer.fromJson<String>(json['apiKey']),
      defaultModelName: serializer.fromJson<String>(json['defaultModelName']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'adapterType': serializer.toJson<String>(adapterType),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'apiKey': serializer.toJson<String>(apiKey),
      'defaultModelName': serializer.toJson<String>(defaultModelName),
      'enabled': serializer.toJson<bool>(enabled),
      'position': serializer.toJson<int>(position),
    };
  }

  TtsProvider copyWith({
    String? id,
    String? name,
    String? adapterType,
    String? baseUrl,
    String? apiKey,
    String? defaultModelName,
    bool? enabled,
    int? position,
  }) => TtsProvider(
    id: id ?? this.id,
    name: name ?? this.name,
    adapterType: adapterType ?? this.adapterType,
    baseUrl: baseUrl ?? this.baseUrl,
    apiKey: apiKey ?? this.apiKey,
    defaultModelName: defaultModelName ?? this.defaultModelName,
    enabled: enabled ?? this.enabled,
    position: position ?? this.position,
  );
  TtsProvider copyWithCompanion(TtsProvidersCompanion data) {
    return TtsProvider(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      adapterType: data.adapterType.present
          ? data.adapterType.value
          : this.adapterType,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      apiKey: data.apiKey.present ? data.apiKey.value : this.apiKey,
      defaultModelName: data.defaultModelName.present
          ? data.defaultModelName.value
          : this.defaultModelName,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TtsProvider(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('adapterType: $adapterType, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('apiKey: $apiKey, ')
          ..write('defaultModelName: $defaultModelName, ')
          ..write('enabled: $enabled, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    adapterType,
    baseUrl,
    apiKey,
    defaultModelName,
    enabled,
    position,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TtsProvider &&
          other.id == this.id &&
          other.name == this.name &&
          other.adapterType == this.adapterType &&
          other.baseUrl == this.baseUrl &&
          other.apiKey == this.apiKey &&
          other.defaultModelName == this.defaultModelName &&
          other.enabled == this.enabled &&
          other.position == this.position);
}

class TtsProvidersCompanion extends UpdateCompanion<TtsProvider> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> adapterType;
  final Value<String> baseUrl;
  final Value<String> apiKey;
  final Value<String> defaultModelName;
  final Value<bool> enabled;
  final Value<int> position;
  final Value<int> rowid;
  const TtsProvidersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.adapterType = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.apiKey = const Value.absent(),
    this.defaultModelName = const Value.absent(),
    this.enabled = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TtsProvidersCompanion.insert({
    required String id,
    required String name,
    required String adapterType,
    required String baseUrl,
    this.apiKey = const Value.absent(),
    this.defaultModelName = const Value.absent(),
    this.enabled = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       adapterType = Value(adapterType),
       baseUrl = Value(baseUrl);
  static Insertable<TtsProvider> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? adapterType,
    Expression<String>? baseUrl,
    Expression<String>? apiKey,
    Expression<String>? defaultModelName,
    Expression<bool>? enabled,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (adapterType != null) 'adapter_type': adapterType,
      if (baseUrl != null) 'base_url': baseUrl,
      if (apiKey != null) 'api_key': apiKey,
      if (defaultModelName != null) 'default_model_name': defaultModelName,
      if (enabled != null) 'enabled': enabled,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TtsProvidersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? adapterType,
    Value<String>? baseUrl,
    Value<String>? apiKey,
    Value<String>? defaultModelName,
    Value<bool>? enabled,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return TtsProvidersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      adapterType: adapterType ?? this.adapterType,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      defaultModelName: defaultModelName ?? this.defaultModelName,
      enabled: enabled ?? this.enabled,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (adapterType.present) {
      map['adapter_type'] = Variable<String>(adapterType.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (apiKey.present) {
      map['api_key'] = Variable<String>(apiKey.value);
    }
    if (defaultModelName.present) {
      map['default_model_name'] = Variable<String>(defaultModelName.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TtsProvidersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('adapterType: $adapterType, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('apiKey: $apiKey, ')
          ..write('defaultModelName: $defaultModelName, ')
          ..write('enabled: $enabled, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModelBindingsTable extends ModelBindings
    with TableInfo<$ModelBindingsTable, ModelBinding> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelBindingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tts_providers (id)',
    ),
  );
  static const VerificationMeta _modelKeyMeta = const VerificationMeta(
    'modelKey',
  );
  @override
  late final GeneratedColumn<String> modelKey = GeneratedColumn<String>(
    'model_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _supportedTaskModesMeta =
      const VerificationMeta('supportedTaskModes');
  @override
  late final GeneratedColumn<String> supportedTaskModes =
      GeneratedColumn<String>(
        'supported_task_modes',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    providerId,
    modelKey,
    supportedTaskModes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'model_bindings';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModelBinding> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('model_key')) {
      context.handle(
        _modelKeyMeta,
        modelKey.isAcceptableOrUnknown(data['model_key']!, _modelKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_modelKeyMeta);
    }
    if (data.containsKey('supported_task_modes')) {
      context.handle(
        _supportedTaskModesMeta,
        supportedTaskModes.isAcceptableOrUnknown(
          data['supported_task_modes']!,
          _supportedTaskModesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ModelBinding map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModelBinding(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      modelKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_key'],
      )!,
      supportedTaskModes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supported_task_modes'],
      )!,
    );
  }

  @override
  $ModelBindingsTable createAlias(String alias) {
    return $ModelBindingsTable(attachedDatabase, alias);
  }
}

class ModelBinding extends DataClass implements Insertable<ModelBinding> {
  final String id;
  final String providerId;
  final String modelKey;
  final String supportedTaskModes;
  const ModelBinding({
    required this.id,
    required this.providerId,
    required this.modelKey,
    required this.supportedTaskModes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['provider_id'] = Variable<String>(providerId);
    map['model_key'] = Variable<String>(modelKey);
    map['supported_task_modes'] = Variable<String>(supportedTaskModes);
    return map;
  }

  ModelBindingsCompanion toCompanion(bool nullToAbsent) {
    return ModelBindingsCompanion(
      id: Value(id),
      providerId: Value(providerId),
      modelKey: Value(modelKey),
      supportedTaskModes: Value(supportedTaskModes),
    );
  }

  factory ModelBinding.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModelBinding(
      id: serializer.fromJson<String>(json['id']),
      providerId: serializer.fromJson<String>(json['providerId']),
      modelKey: serializer.fromJson<String>(json['modelKey']),
      supportedTaskModes: serializer.fromJson<String>(
        json['supportedTaskModes'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'providerId': serializer.toJson<String>(providerId),
      'modelKey': serializer.toJson<String>(modelKey),
      'supportedTaskModes': serializer.toJson<String>(supportedTaskModes),
    };
  }

  ModelBinding copyWith({
    String? id,
    String? providerId,
    String? modelKey,
    String? supportedTaskModes,
  }) => ModelBinding(
    id: id ?? this.id,
    providerId: providerId ?? this.providerId,
    modelKey: modelKey ?? this.modelKey,
    supportedTaskModes: supportedTaskModes ?? this.supportedTaskModes,
  );
  ModelBinding copyWithCompanion(ModelBindingsCompanion data) {
    return ModelBinding(
      id: data.id.present ? data.id.value : this.id,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      modelKey: data.modelKey.present ? data.modelKey.value : this.modelKey,
      supportedTaskModes: data.supportedTaskModes.present
          ? data.supportedTaskModes.value
          : this.supportedTaskModes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModelBinding(')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('modelKey: $modelKey, ')
          ..write('supportedTaskModes: $supportedTaskModes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, providerId, modelKey, supportedTaskModes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelBinding &&
          other.id == this.id &&
          other.providerId == this.providerId &&
          other.modelKey == this.modelKey &&
          other.supportedTaskModes == this.supportedTaskModes);
}

class ModelBindingsCompanion extends UpdateCompanion<ModelBinding> {
  final Value<String> id;
  final Value<String> providerId;
  final Value<String> modelKey;
  final Value<String> supportedTaskModes;
  final Value<int> rowid;
  const ModelBindingsCompanion({
    this.id = const Value.absent(),
    this.providerId = const Value.absent(),
    this.modelKey = const Value.absent(),
    this.supportedTaskModes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelBindingsCompanion.insert({
    required String id,
    required String providerId,
    required String modelKey,
    this.supportedTaskModes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       providerId = Value(providerId),
       modelKey = Value(modelKey);
  static Insertable<ModelBinding> custom({
    Expression<String>? id,
    Expression<String>? providerId,
    Expression<String>? modelKey,
    Expression<String>? supportedTaskModes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (providerId != null) 'provider_id': providerId,
      if (modelKey != null) 'model_key': modelKey,
      if (supportedTaskModes != null)
        'supported_task_modes': supportedTaskModes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelBindingsCompanion copyWith({
    Value<String>? id,
    Value<String>? providerId,
    Value<String>? modelKey,
    Value<String>? supportedTaskModes,
    Value<int>? rowid,
  }) {
    return ModelBindingsCompanion(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      modelKey: modelKey ?? this.modelKey,
      supportedTaskModes: supportedTaskModes ?? this.supportedTaskModes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (modelKey.present) {
      map['model_key'] = Variable<String>(modelKey.value);
    }
    if (supportedTaskModes.present) {
      map['supported_task_modes'] = Variable<String>(supportedTaskModes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelBindingsCompanion(')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('modelKey: $modelKey, ')
          ..write('supportedTaskModes: $supportedTaskModes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VoiceAssetsTable extends VoiceAssets
    with TableInfo<$VoiceAssetsTable, VoiceAsset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VoiceAssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tts_providers (id)',
    ),
  );
  static const VerificationMeta _modelBindingIdMeta = const VerificationMeta(
    'modelBindingId',
  );
  @override
  late final GeneratedColumn<String> modelBindingId = GeneratedColumn<String>(
    'model_binding_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelNameMeta = const VerificationMeta(
    'modelName',
  );
  @override
  late final GeneratedColumn<String> modelName = GeneratedColumn<String>(
    'model_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taskModeMeta = const VerificationMeta(
    'taskMode',
  );
  @override
  late final GeneratedColumn<String> taskMode = GeneratedColumn<String>(
    'task_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _refAudioPathMeta = const VerificationMeta(
    'refAudioPath',
  );
  @override
  late final GeneratedColumn<String> refAudioPath = GeneratedColumn<String>(
    'ref_audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _refAudioTrimStartMeta = const VerificationMeta(
    'refAudioTrimStart',
  );
  @override
  late final GeneratedColumn<double> refAudioTrimStart =
      GeneratedColumn<double>(
        'ref_audio_trim_start',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _refAudioTrimEndMeta = const VerificationMeta(
    'refAudioTrimEnd',
  );
  @override
  late final GeneratedColumn<double> refAudioTrimEnd = GeneratedColumn<double>(
    'ref_audio_trim_end',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _promptTextMeta = const VerificationMeta(
    'promptText',
  );
  @override
  late final GeneratedColumn<String> promptText = GeneratedColumn<String>(
    'prompt_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _promptLangMeta = const VerificationMeta(
    'promptLang',
  );
  @override
  late final GeneratedColumn<String> promptLang = GeneratedColumn<String>(
    'prompt_lang',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voiceInstructionMeta = const VerificationMeta(
    'voiceInstruction',
  );
  @override
  late final GeneratedColumn<String> voiceInstruction = GeneratedColumn<String>(
    'voice_instruction',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _presetVoiceNameMeta = const VerificationMeta(
    'presetVoiceName',
  );
  @override
  late final GeneratedColumn<String> presetVoiceName = GeneratedColumn<String>(
    'preset_voice_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarPathMeta = const VerificationMeta(
    'avatarPath',
  );
  @override
  late final GeneratedColumn<String> avatarPath = GeneratedColumn<String>(
    'avatar_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<double> speed = GeneratedColumn<double>(
    'speed',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _folderSlugMeta = const VerificationMeta(
    'folderSlug',
  );
  @override
  late final GeneratedColumn<String> folderSlug = GeneratedColumn<String>(
    'folder_slug',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    providerId,
    modelBindingId,
    modelName,
    taskMode,
    refAudioPath,
    refAudioTrimStart,
    refAudioTrimEnd,
    promptText,
    promptLang,
    voiceInstruction,
    presetVoiceName,
    avatarPath,
    speed,
    enabled,
    folderSlug,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'voice_assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<VoiceAsset> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('model_binding_id')) {
      context.handle(
        _modelBindingIdMeta,
        modelBindingId.isAcceptableOrUnknown(
          data['model_binding_id']!,
          _modelBindingIdMeta,
        ),
      );
    }
    if (data.containsKey('model_name')) {
      context.handle(
        _modelNameMeta,
        modelName.isAcceptableOrUnknown(data['model_name']!, _modelNameMeta),
      );
    }
    if (data.containsKey('task_mode')) {
      context.handle(
        _taskModeMeta,
        taskMode.isAcceptableOrUnknown(data['task_mode']!, _taskModeMeta),
      );
    } else if (isInserting) {
      context.missing(_taskModeMeta);
    }
    if (data.containsKey('ref_audio_path')) {
      context.handle(
        _refAudioPathMeta,
        refAudioPath.isAcceptableOrUnknown(
          data['ref_audio_path']!,
          _refAudioPathMeta,
        ),
      );
    }
    if (data.containsKey('ref_audio_trim_start')) {
      context.handle(
        _refAudioTrimStartMeta,
        refAudioTrimStart.isAcceptableOrUnknown(
          data['ref_audio_trim_start']!,
          _refAudioTrimStartMeta,
        ),
      );
    }
    if (data.containsKey('ref_audio_trim_end')) {
      context.handle(
        _refAudioTrimEndMeta,
        refAudioTrimEnd.isAcceptableOrUnknown(
          data['ref_audio_trim_end']!,
          _refAudioTrimEndMeta,
        ),
      );
    }
    if (data.containsKey('prompt_text')) {
      context.handle(
        _promptTextMeta,
        promptText.isAcceptableOrUnknown(data['prompt_text']!, _promptTextMeta),
      );
    }
    if (data.containsKey('prompt_lang')) {
      context.handle(
        _promptLangMeta,
        promptLang.isAcceptableOrUnknown(data['prompt_lang']!, _promptLangMeta),
      );
    }
    if (data.containsKey('voice_instruction')) {
      context.handle(
        _voiceInstructionMeta,
        voiceInstruction.isAcceptableOrUnknown(
          data['voice_instruction']!,
          _voiceInstructionMeta,
        ),
      );
    }
    if (data.containsKey('preset_voice_name')) {
      context.handle(
        _presetVoiceNameMeta,
        presetVoiceName.isAcceptableOrUnknown(
          data['preset_voice_name']!,
          _presetVoiceNameMeta,
        ),
      );
    }
    if (data.containsKey('avatar_path')) {
      context.handle(
        _avatarPathMeta,
        avatarPath.isAcceptableOrUnknown(data['avatar_path']!, _avatarPathMeta),
      );
    }
    if (data.containsKey('speed')) {
      context.handle(
        _speedMeta,
        speed.isAcceptableOrUnknown(data['speed']!, _speedMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('folder_slug')) {
      context.handle(
        _folderSlugMeta,
        folderSlug.isAcceptableOrUnknown(data['folder_slug']!, _folderSlugMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VoiceAsset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VoiceAsset(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      modelBindingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_binding_id'],
      ),
      modelName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_name'],
      ),
      taskMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_mode'],
      )!,
      refAudioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref_audio_path'],
      ),
      refAudioTrimStart: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ref_audio_trim_start'],
      ),
      refAudioTrimEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ref_audio_trim_end'],
      ),
      promptText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt_text'],
      ),
      promptLang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt_lang'],
      ),
      voiceInstruction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_instruction'],
      ),
      presetVoiceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preset_voice_name'],
      ),
      avatarPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_path'],
      ),
      speed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      folderSlug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_slug'],
      ),
    );
  }

  @override
  $VoiceAssetsTable createAlias(String alias) {
    return $VoiceAssetsTable(attachedDatabase, alias);
  }
}

class VoiceAsset extends DataClass implements Insertable<VoiceAsset> {
  final String id;
  final String name;
  final String? description;
  final String providerId;
  final String? modelBindingId;
  final String? modelName;
  final String taskMode;
  final String? refAudioPath;
  final double? refAudioTrimStart;
  final double? refAudioTrimEnd;
  final String? promptText;
  final String? promptLang;
  final String? voiceInstruction;
  final String? presetVoiceName;
  final String? avatarPath;
  final double speed;
  final bool enabled;
  final String? folderSlug;
  const VoiceAsset({
    required this.id,
    required this.name,
    this.description,
    required this.providerId,
    this.modelBindingId,
    this.modelName,
    required this.taskMode,
    this.refAudioPath,
    this.refAudioTrimStart,
    this.refAudioTrimEnd,
    this.promptText,
    this.promptLang,
    this.voiceInstruction,
    this.presetVoiceName,
    this.avatarPath,
    required this.speed,
    required this.enabled,
    this.folderSlug,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['provider_id'] = Variable<String>(providerId);
    if (!nullToAbsent || modelBindingId != null) {
      map['model_binding_id'] = Variable<String>(modelBindingId);
    }
    if (!nullToAbsent || modelName != null) {
      map['model_name'] = Variable<String>(modelName);
    }
    map['task_mode'] = Variable<String>(taskMode);
    if (!nullToAbsent || refAudioPath != null) {
      map['ref_audio_path'] = Variable<String>(refAudioPath);
    }
    if (!nullToAbsent || refAudioTrimStart != null) {
      map['ref_audio_trim_start'] = Variable<double>(refAudioTrimStart);
    }
    if (!nullToAbsent || refAudioTrimEnd != null) {
      map['ref_audio_trim_end'] = Variable<double>(refAudioTrimEnd);
    }
    if (!nullToAbsent || promptText != null) {
      map['prompt_text'] = Variable<String>(promptText);
    }
    if (!nullToAbsent || promptLang != null) {
      map['prompt_lang'] = Variable<String>(promptLang);
    }
    if (!nullToAbsent || voiceInstruction != null) {
      map['voice_instruction'] = Variable<String>(voiceInstruction);
    }
    if (!nullToAbsent || presetVoiceName != null) {
      map['preset_voice_name'] = Variable<String>(presetVoiceName);
    }
    if (!nullToAbsent || avatarPath != null) {
      map['avatar_path'] = Variable<String>(avatarPath);
    }
    map['speed'] = Variable<double>(speed);
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || folderSlug != null) {
      map['folder_slug'] = Variable<String>(folderSlug);
    }
    return map;
  }

  VoiceAssetsCompanion toCompanion(bool nullToAbsent) {
    return VoiceAssetsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      providerId: Value(providerId),
      modelBindingId: modelBindingId == null && nullToAbsent
          ? const Value.absent()
          : Value(modelBindingId),
      modelName: modelName == null && nullToAbsent
          ? const Value.absent()
          : Value(modelName),
      taskMode: Value(taskMode),
      refAudioPath: refAudioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(refAudioPath),
      refAudioTrimStart: refAudioTrimStart == null && nullToAbsent
          ? const Value.absent()
          : Value(refAudioTrimStart),
      refAudioTrimEnd: refAudioTrimEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(refAudioTrimEnd),
      promptText: promptText == null && nullToAbsent
          ? const Value.absent()
          : Value(promptText),
      promptLang: promptLang == null && nullToAbsent
          ? const Value.absent()
          : Value(promptLang),
      voiceInstruction: voiceInstruction == null && nullToAbsent
          ? const Value.absent()
          : Value(voiceInstruction),
      presetVoiceName: presetVoiceName == null && nullToAbsent
          ? const Value.absent()
          : Value(presetVoiceName),
      avatarPath: avatarPath == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarPath),
      speed: Value(speed),
      enabled: Value(enabled),
      folderSlug: folderSlug == null && nullToAbsent
          ? const Value.absent()
          : Value(folderSlug),
    );
  }

  factory VoiceAsset.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VoiceAsset(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      providerId: serializer.fromJson<String>(json['providerId']),
      modelBindingId: serializer.fromJson<String?>(json['modelBindingId']),
      modelName: serializer.fromJson<String?>(json['modelName']),
      taskMode: serializer.fromJson<String>(json['taskMode']),
      refAudioPath: serializer.fromJson<String?>(json['refAudioPath']),
      refAudioTrimStart: serializer.fromJson<double?>(
        json['refAudioTrimStart'],
      ),
      refAudioTrimEnd: serializer.fromJson<double?>(json['refAudioTrimEnd']),
      promptText: serializer.fromJson<String?>(json['promptText']),
      promptLang: serializer.fromJson<String?>(json['promptLang']),
      voiceInstruction: serializer.fromJson<String?>(json['voiceInstruction']),
      presetVoiceName: serializer.fromJson<String?>(json['presetVoiceName']),
      avatarPath: serializer.fromJson<String?>(json['avatarPath']),
      speed: serializer.fromJson<double>(json['speed']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      folderSlug: serializer.fromJson<String?>(json['folderSlug']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'providerId': serializer.toJson<String>(providerId),
      'modelBindingId': serializer.toJson<String?>(modelBindingId),
      'modelName': serializer.toJson<String?>(modelName),
      'taskMode': serializer.toJson<String>(taskMode),
      'refAudioPath': serializer.toJson<String?>(refAudioPath),
      'refAudioTrimStart': serializer.toJson<double?>(refAudioTrimStart),
      'refAudioTrimEnd': serializer.toJson<double?>(refAudioTrimEnd),
      'promptText': serializer.toJson<String?>(promptText),
      'promptLang': serializer.toJson<String?>(promptLang),
      'voiceInstruction': serializer.toJson<String?>(voiceInstruction),
      'presetVoiceName': serializer.toJson<String?>(presetVoiceName),
      'avatarPath': serializer.toJson<String?>(avatarPath),
      'speed': serializer.toJson<double>(speed),
      'enabled': serializer.toJson<bool>(enabled),
      'folderSlug': serializer.toJson<String?>(folderSlug),
    };
  }

  VoiceAsset copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    String? providerId,
    Value<String?> modelBindingId = const Value.absent(),
    Value<String?> modelName = const Value.absent(),
    String? taskMode,
    Value<String?> refAudioPath = const Value.absent(),
    Value<double?> refAudioTrimStart = const Value.absent(),
    Value<double?> refAudioTrimEnd = const Value.absent(),
    Value<String?> promptText = const Value.absent(),
    Value<String?> promptLang = const Value.absent(),
    Value<String?> voiceInstruction = const Value.absent(),
    Value<String?> presetVoiceName = const Value.absent(),
    Value<String?> avatarPath = const Value.absent(),
    double? speed,
    bool? enabled,
    Value<String?> folderSlug = const Value.absent(),
  }) => VoiceAsset(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    providerId: providerId ?? this.providerId,
    modelBindingId: modelBindingId.present
        ? modelBindingId.value
        : this.modelBindingId,
    modelName: modelName.present ? modelName.value : this.modelName,
    taskMode: taskMode ?? this.taskMode,
    refAudioPath: refAudioPath.present ? refAudioPath.value : this.refAudioPath,
    refAudioTrimStart: refAudioTrimStart.present
        ? refAudioTrimStart.value
        : this.refAudioTrimStart,
    refAudioTrimEnd: refAudioTrimEnd.present
        ? refAudioTrimEnd.value
        : this.refAudioTrimEnd,
    promptText: promptText.present ? promptText.value : this.promptText,
    promptLang: promptLang.present ? promptLang.value : this.promptLang,
    voiceInstruction: voiceInstruction.present
        ? voiceInstruction.value
        : this.voiceInstruction,
    presetVoiceName: presetVoiceName.present
        ? presetVoiceName.value
        : this.presetVoiceName,
    avatarPath: avatarPath.present ? avatarPath.value : this.avatarPath,
    speed: speed ?? this.speed,
    enabled: enabled ?? this.enabled,
    folderSlug: folderSlug.present ? folderSlug.value : this.folderSlug,
  );
  VoiceAsset copyWithCompanion(VoiceAssetsCompanion data) {
    return VoiceAsset(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      modelBindingId: data.modelBindingId.present
          ? data.modelBindingId.value
          : this.modelBindingId,
      modelName: data.modelName.present ? data.modelName.value : this.modelName,
      taskMode: data.taskMode.present ? data.taskMode.value : this.taskMode,
      refAudioPath: data.refAudioPath.present
          ? data.refAudioPath.value
          : this.refAudioPath,
      refAudioTrimStart: data.refAudioTrimStart.present
          ? data.refAudioTrimStart.value
          : this.refAudioTrimStart,
      refAudioTrimEnd: data.refAudioTrimEnd.present
          ? data.refAudioTrimEnd.value
          : this.refAudioTrimEnd,
      promptText: data.promptText.present
          ? data.promptText.value
          : this.promptText,
      promptLang: data.promptLang.present
          ? data.promptLang.value
          : this.promptLang,
      voiceInstruction: data.voiceInstruction.present
          ? data.voiceInstruction.value
          : this.voiceInstruction,
      presetVoiceName: data.presetVoiceName.present
          ? data.presetVoiceName.value
          : this.presetVoiceName,
      avatarPath: data.avatarPath.present
          ? data.avatarPath.value
          : this.avatarPath,
      speed: data.speed.present ? data.speed.value : this.speed,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      folderSlug: data.folderSlug.present
          ? data.folderSlug.value
          : this.folderSlug,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VoiceAsset(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('providerId: $providerId, ')
          ..write('modelBindingId: $modelBindingId, ')
          ..write('modelName: $modelName, ')
          ..write('taskMode: $taskMode, ')
          ..write('refAudioPath: $refAudioPath, ')
          ..write('refAudioTrimStart: $refAudioTrimStart, ')
          ..write('refAudioTrimEnd: $refAudioTrimEnd, ')
          ..write('promptText: $promptText, ')
          ..write('promptLang: $promptLang, ')
          ..write('voiceInstruction: $voiceInstruction, ')
          ..write('presetVoiceName: $presetVoiceName, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('speed: $speed, ')
          ..write('enabled: $enabled, ')
          ..write('folderSlug: $folderSlug')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    providerId,
    modelBindingId,
    modelName,
    taskMode,
    refAudioPath,
    refAudioTrimStart,
    refAudioTrimEnd,
    promptText,
    promptLang,
    voiceInstruction,
    presetVoiceName,
    avatarPath,
    speed,
    enabled,
    folderSlug,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VoiceAsset &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.providerId == this.providerId &&
          other.modelBindingId == this.modelBindingId &&
          other.modelName == this.modelName &&
          other.taskMode == this.taskMode &&
          other.refAudioPath == this.refAudioPath &&
          other.refAudioTrimStart == this.refAudioTrimStart &&
          other.refAudioTrimEnd == this.refAudioTrimEnd &&
          other.promptText == this.promptText &&
          other.promptLang == this.promptLang &&
          other.voiceInstruction == this.voiceInstruction &&
          other.presetVoiceName == this.presetVoiceName &&
          other.avatarPath == this.avatarPath &&
          other.speed == this.speed &&
          other.enabled == this.enabled &&
          other.folderSlug == this.folderSlug);
}

class VoiceAssetsCompanion extends UpdateCompanion<VoiceAsset> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String> providerId;
  final Value<String?> modelBindingId;
  final Value<String?> modelName;
  final Value<String> taskMode;
  final Value<String?> refAudioPath;
  final Value<double?> refAudioTrimStart;
  final Value<double?> refAudioTrimEnd;
  final Value<String?> promptText;
  final Value<String?> promptLang;
  final Value<String?> voiceInstruction;
  final Value<String?> presetVoiceName;
  final Value<String?> avatarPath;
  final Value<double> speed;
  final Value<bool> enabled;
  final Value<String?> folderSlug;
  final Value<int> rowid;
  const VoiceAssetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.providerId = const Value.absent(),
    this.modelBindingId = const Value.absent(),
    this.modelName = const Value.absent(),
    this.taskMode = const Value.absent(),
    this.refAudioPath = const Value.absent(),
    this.refAudioTrimStart = const Value.absent(),
    this.refAudioTrimEnd = const Value.absent(),
    this.promptText = const Value.absent(),
    this.promptLang = const Value.absent(),
    this.voiceInstruction = const Value.absent(),
    this.presetVoiceName = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.speed = const Value.absent(),
    this.enabled = const Value.absent(),
    this.folderSlug = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VoiceAssetsCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    required String providerId,
    this.modelBindingId = const Value.absent(),
    this.modelName = const Value.absent(),
    required String taskMode,
    this.refAudioPath = const Value.absent(),
    this.refAudioTrimStart = const Value.absent(),
    this.refAudioTrimEnd = const Value.absent(),
    this.promptText = const Value.absent(),
    this.promptLang = const Value.absent(),
    this.voiceInstruction = const Value.absent(),
    this.presetVoiceName = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.speed = const Value.absent(),
    this.enabled = const Value.absent(),
    this.folderSlug = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       providerId = Value(providerId),
       taskMode = Value(taskMode);
  static Insertable<VoiceAsset> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? providerId,
    Expression<String>? modelBindingId,
    Expression<String>? modelName,
    Expression<String>? taskMode,
    Expression<String>? refAudioPath,
    Expression<double>? refAudioTrimStart,
    Expression<double>? refAudioTrimEnd,
    Expression<String>? promptText,
    Expression<String>? promptLang,
    Expression<String>? voiceInstruction,
    Expression<String>? presetVoiceName,
    Expression<String>? avatarPath,
    Expression<double>? speed,
    Expression<bool>? enabled,
    Expression<String>? folderSlug,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (providerId != null) 'provider_id': providerId,
      if (modelBindingId != null) 'model_binding_id': modelBindingId,
      if (modelName != null) 'model_name': modelName,
      if (taskMode != null) 'task_mode': taskMode,
      if (refAudioPath != null) 'ref_audio_path': refAudioPath,
      if (refAudioTrimStart != null) 'ref_audio_trim_start': refAudioTrimStart,
      if (refAudioTrimEnd != null) 'ref_audio_trim_end': refAudioTrimEnd,
      if (promptText != null) 'prompt_text': promptText,
      if (promptLang != null) 'prompt_lang': promptLang,
      if (voiceInstruction != null) 'voice_instruction': voiceInstruction,
      if (presetVoiceName != null) 'preset_voice_name': presetVoiceName,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (speed != null) 'speed': speed,
      if (enabled != null) 'enabled': enabled,
      if (folderSlug != null) 'folder_slug': folderSlug,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VoiceAssetsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<String>? providerId,
    Value<String?>? modelBindingId,
    Value<String?>? modelName,
    Value<String>? taskMode,
    Value<String?>? refAudioPath,
    Value<double?>? refAudioTrimStart,
    Value<double?>? refAudioTrimEnd,
    Value<String?>? promptText,
    Value<String?>? promptLang,
    Value<String?>? voiceInstruction,
    Value<String?>? presetVoiceName,
    Value<String?>? avatarPath,
    Value<double>? speed,
    Value<bool>? enabled,
    Value<String?>? folderSlug,
    Value<int>? rowid,
  }) {
    return VoiceAssetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      providerId: providerId ?? this.providerId,
      modelBindingId: modelBindingId ?? this.modelBindingId,
      modelName: modelName ?? this.modelName,
      taskMode: taskMode ?? this.taskMode,
      refAudioPath: refAudioPath ?? this.refAudioPath,
      refAudioTrimStart: refAudioTrimStart ?? this.refAudioTrimStart,
      refAudioTrimEnd: refAudioTrimEnd ?? this.refAudioTrimEnd,
      promptText: promptText ?? this.promptText,
      promptLang: promptLang ?? this.promptLang,
      voiceInstruction: voiceInstruction ?? this.voiceInstruction,
      presetVoiceName: presetVoiceName ?? this.presetVoiceName,
      avatarPath: avatarPath ?? this.avatarPath,
      speed: speed ?? this.speed,
      enabled: enabled ?? this.enabled,
      folderSlug: folderSlug ?? this.folderSlug,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (modelBindingId.present) {
      map['model_binding_id'] = Variable<String>(modelBindingId.value);
    }
    if (modelName.present) {
      map['model_name'] = Variable<String>(modelName.value);
    }
    if (taskMode.present) {
      map['task_mode'] = Variable<String>(taskMode.value);
    }
    if (refAudioPath.present) {
      map['ref_audio_path'] = Variable<String>(refAudioPath.value);
    }
    if (refAudioTrimStart.present) {
      map['ref_audio_trim_start'] = Variable<double>(refAudioTrimStart.value);
    }
    if (refAudioTrimEnd.present) {
      map['ref_audio_trim_end'] = Variable<double>(refAudioTrimEnd.value);
    }
    if (promptText.present) {
      map['prompt_text'] = Variable<String>(promptText.value);
    }
    if (promptLang.present) {
      map['prompt_lang'] = Variable<String>(promptLang.value);
    }
    if (voiceInstruction.present) {
      map['voice_instruction'] = Variable<String>(voiceInstruction.value);
    }
    if (presetVoiceName.present) {
      map['preset_voice_name'] = Variable<String>(presetVoiceName.value);
    }
    if (avatarPath.present) {
      map['avatar_path'] = Variable<String>(avatarPath.value);
    }
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (folderSlug.present) {
      map['folder_slug'] = Variable<String>(folderSlug.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VoiceAssetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('providerId: $providerId, ')
          ..write('modelBindingId: $modelBindingId, ')
          ..write('modelName: $modelName, ')
          ..write('taskMode: $taskMode, ')
          ..write('refAudioPath: $refAudioPath, ')
          ..write('refAudioTrimStart: $refAudioTrimStart, ')
          ..write('refAudioTrimEnd: $refAudioTrimEnd, ')
          ..write('promptText: $promptText, ')
          ..write('promptLang: $promptLang, ')
          ..write('voiceInstruction: $voiceInstruction, ')
          ..write('presetVoiceName: $presetVoiceName, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('speed: $speed, ')
          ..write('enabled: $enabled, ')
          ..write('folderSlug: $folderSlug, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VoiceBanksTable extends VoiceBanks
    with TableInfo<$VoiceBanksTable, VoiceBank> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VoiceBanksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    isActive,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'voice_banks';
  @override
  VerificationContext validateIntegrity(
    Insertable<VoiceBank> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VoiceBank map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VoiceBank(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $VoiceBanksTable createAlias(String alias) {
    return $VoiceBanksTable(attachedDatabase, alias);
  }
}

class VoiceBank extends DataClass implements Insertable<VoiceBank> {
  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  const VoiceBank({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  VoiceBanksCompanion toCompanion(bool nullToAbsent) {
    return VoiceBanksCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
    );
  }

  factory VoiceBank.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VoiceBank(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  VoiceBank copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    bool? isActive,
    DateTime? createdAt,
  }) => VoiceBank(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
  );
  VoiceBank copyWithCompanion(VoiceBanksCompanion data) {
    return VoiceBank(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VoiceBank(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, description, isActive, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VoiceBank &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt);
}

class VoiceBanksCompanion extends UpdateCompanion<VoiceBank> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const VoiceBanksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VoiceBanksCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<VoiceBank> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VoiceBanksCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return VoiceBanksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VoiceBanksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VoiceBankMembersTable extends VoiceBankMembers
    with TableInfo<$VoiceBankMembersTable, VoiceBankMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VoiceBankMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bankIdMeta = const VerificationMeta('bankId');
  @override
  late final GeneratedColumn<String> bankId = GeneratedColumn<String>(
    'bank_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES voice_banks (id)',
    ),
  );
  static const VerificationMeta _voiceAssetIdMeta = const VerificationMeta(
    'voiceAssetId',
  );
  @override
  late final GeneratedColumn<String> voiceAssetId = GeneratedColumn<String>(
    'voice_asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES voice_assets (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [id, bankId, voiceAssetId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'voice_bank_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<VoiceBankMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('bank_id')) {
      context.handle(
        _bankIdMeta,
        bankId.isAcceptableOrUnknown(data['bank_id']!, _bankIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bankIdMeta);
    }
    if (data.containsKey('voice_asset_id')) {
      context.handle(
        _voiceAssetIdMeta,
        voiceAssetId.isAcceptableOrUnknown(
          data['voice_asset_id']!,
          _voiceAssetIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_voiceAssetIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VoiceBankMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VoiceBankMember(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bankId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_id'],
      )!,
      voiceAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_asset_id'],
      )!,
    );
  }

  @override
  $VoiceBankMembersTable createAlias(String alias) {
    return $VoiceBankMembersTable(attachedDatabase, alias);
  }
}

class VoiceBankMember extends DataClass implements Insertable<VoiceBankMember> {
  final String id;
  final String bankId;
  final String voiceAssetId;
  const VoiceBankMember({
    required this.id,
    required this.bankId,
    required this.voiceAssetId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['bank_id'] = Variable<String>(bankId);
    map['voice_asset_id'] = Variable<String>(voiceAssetId);
    return map;
  }

  VoiceBankMembersCompanion toCompanion(bool nullToAbsent) {
    return VoiceBankMembersCompanion(
      id: Value(id),
      bankId: Value(bankId),
      voiceAssetId: Value(voiceAssetId),
    );
  }

  factory VoiceBankMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VoiceBankMember(
      id: serializer.fromJson<String>(json['id']),
      bankId: serializer.fromJson<String>(json['bankId']),
      voiceAssetId: serializer.fromJson<String>(json['voiceAssetId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bankId': serializer.toJson<String>(bankId),
      'voiceAssetId': serializer.toJson<String>(voiceAssetId),
    };
  }

  VoiceBankMember copyWith({
    String? id,
    String? bankId,
    String? voiceAssetId,
  }) => VoiceBankMember(
    id: id ?? this.id,
    bankId: bankId ?? this.bankId,
    voiceAssetId: voiceAssetId ?? this.voiceAssetId,
  );
  VoiceBankMember copyWithCompanion(VoiceBankMembersCompanion data) {
    return VoiceBankMember(
      id: data.id.present ? data.id.value : this.id,
      bankId: data.bankId.present ? data.bankId.value : this.bankId,
      voiceAssetId: data.voiceAssetId.present
          ? data.voiceAssetId.value
          : this.voiceAssetId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VoiceBankMember(')
          ..write('id: $id, ')
          ..write('bankId: $bankId, ')
          ..write('voiceAssetId: $voiceAssetId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, bankId, voiceAssetId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VoiceBankMember &&
          other.id == this.id &&
          other.bankId == this.bankId &&
          other.voiceAssetId == this.voiceAssetId);
}

class VoiceBankMembersCompanion extends UpdateCompanion<VoiceBankMember> {
  final Value<String> id;
  final Value<String> bankId;
  final Value<String> voiceAssetId;
  final Value<int> rowid;
  const VoiceBankMembersCompanion({
    this.id = const Value.absent(),
    this.bankId = const Value.absent(),
    this.voiceAssetId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VoiceBankMembersCompanion.insert({
    required String id,
    required String bankId,
    required String voiceAssetId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bankId = Value(bankId),
       voiceAssetId = Value(voiceAssetId);
  static Insertable<VoiceBankMember> custom({
    Expression<String>? id,
    Expression<String>? bankId,
    Expression<String>? voiceAssetId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bankId != null) 'bank_id': bankId,
      if (voiceAssetId != null) 'voice_asset_id': voiceAssetId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VoiceBankMembersCompanion copyWith({
    Value<String>? id,
    Value<String>? bankId,
    Value<String>? voiceAssetId,
    Value<int>? rowid,
  }) {
    return VoiceBankMembersCompanion(
      id: id ?? this.id,
      bankId: bankId ?? this.bankId,
      voiceAssetId: voiceAssetId ?? this.voiceAssetId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bankId.present) {
      map['bank_id'] = Variable<String>(bankId.value);
    }
    if (voiceAssetId.present) {
      map['voice_asset_id'] = Variable<String>(voiceAssetId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VoiceBankMembersCompanion(')
          ..write('id: $id, ')
          ..write('bankId: $bankId, ')
          ..write('voiceAssetId: $voiceAssetId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TtsJobsTable extends TtsJobs with TableInfo<$TtsJobsTable, TtsJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TtsJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voiceAssetIdMeta = const VerificationMeta(
    'voiceAssetId',
  );
  @override
  late final GeneratedColumn<String> voiceAssetId = GeneratedColumn<String>(
    'voice_asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES voice_assets (id)',
    ),
  );
  static const VerificationMeta _inputTextMeta = const VerificationMeta(
    'inputText',
  );
  @override
  late final GeneratedColumn<String> inputText = GeneratedColumn<String>(
    'input_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outputPathMeta = const VerificationMeta(
    'outputPath',
  );
  @override
  late final GeneratedColumn<String> outputPath = GeneratedColumn<String>(
    'output_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    voiceAssetId,
    inputText,
    status,
    outputPath,
    errorMessage,
    createdAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tts_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<TtsJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('voice_asset_id')) {
      context.handle(
        _voiceAssetIdMeta,
        voiceAssetId.isAcceptableOrUnknown(
          data['voice_asset_id']!,
          _voiceAssetIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_voiceAssetIdMeta);
    }
    if (data.containsKey('input_text')) {
      context.handle(
        _inputTextMeta,
        inputText.isAcceptableOrUnknown(data['input_text']!, _inputTextMeta),
      );
    } else if (isInserting) {
      context.missing(_inputTextMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('output_path')) {
      context.handle(
        _outputPathMeta,
        outputPath.isAcceptableOrUnknown(data['output_path']!, _outputPathMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TtsJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TtsJob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      voiceAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_asset_id'],
      )!,
      inputText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_text'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      outputPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_path'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $TtsJobsTable createAlias(String alias) {
    return $TtsJobsTable(attachedDatabase, alias);
  }
}

class TtsJob extends DataClass implements Insertable<TtsJob> {
  final String id;
  final String voiceAssetId;
  final String inputText;
  final String status;
  final String? outputPath;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;
  const TtsJob({
    required this.id,
    required this.voiceAssetId,
    required this.inputText,
    required this.status,
    this.outputPath,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['voice_asset_id'] = Variable<String>(voiceAssetId);
    map['input_text'] = Variable<String>(inputText);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || outputPath != null) {
      map['output_path'] = Variable<String>(outputPath);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  TtsJobsCompanion toCompanion(bool nullToAbsent) {
    return TtsJobsCompanion(
      id: Value(id),
      voiceAssetId: Value(voiceAssetId),
      inputText: Value(inputText),
      status: Value(status),
      outputPath: outputPath == null && nullToAbsent
          ? const Value.absent()
          : Value(outputPath),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory TtsJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TtsJob(
      id: serializer.fromJson<String>(json['id']),
      voiceAssetId: serializer.fromJson<String>(json['voiceAssetId']),
      inputText: serializer.fromJson<String>(json['inputText']),
      status: serializer.fromJson<String>(json['status']),
      outputPath: serializer.fromJson<String?>(json['outputPath']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'voiceAssetId': serializer.toJson<String>(voiceAssetId),
      'inputText': serializer.toJson<String>(inputText),
      'status': serializer.toJson<String>(status),
      'outputPath': serializer.toJson<String?>(outputPath),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  TtsJob copyWith({
    String? id,
    String? voiceAssetId,
    String? inputText,
    String? status,
    Value<String?> outputPath = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => TtsJob(
    id: id ?? this.id,
    voiceAssetId: voiceAssetId ?? this.voiceAssetId,
    inputText: inputText ?? this.inputText,
    status: status ?? this.status,
    outputPath: outputPath.present ? outputPath.value : this.outputPath,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  TtsJob copyWithCompanion(TtsJobsCompanion data) {
    return TtsJob(
      id: data.id.present ? data.id.value : this.id,
      voiceAssetId: data.voiceAssetId.present
          ? data.voiceAssetId.value
          : this.voiceAssetId,
      inputText: data.inputText.present ? data.inputText.value : this.inputText,
      status: data.status.present ? data.status.value : this.status,
      outputPath: data.outputPath.present
          ? data.outputPath.value
          : this.outputPath,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TtsJob(')
          ..write('id: $id, ')
          ..write('voiceAssetId: $voiceAssetId, ')
          ..write('inputText: $inputText, ')
          ..write('status: $status, ')
          ..write('outputPath: $outputPath, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    voiceAssetId,
    inputText,
    status,
    outputPath,
    errorMessage,
    createdAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TtsJob &&
          other.id == this.id &&
          other.voiceAssetId == this.voiceAssetId &&
          other.inputText == this.inputText &&
          other.status == this.status &&
          other.outputPath == this.outputPath &&
          other.errorMessage == this.errorMessage &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt);
}

class TtsJobsCompanion extends UpdateCompanion<TtsJob> {
  final Value<String> id;
  final Value<String> voiceAssetId;
  final Value<String> inputText;
  final Value<String> status;
  final Value<String?> outputPath;
  final Value<String?> errorMessage;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const TtsJobsCompanion({
    this.id = const Value.absent(),
    this.voiceAssetId = const Value.absent(),
    this.inputText = const Value.absent(),
    this.status = const Value.absent(),
    this.outputPath = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TtsJobsCompanion.insert({
    required String id,
    required String voiceAssetId,
    required String inputText,
    required String status,
    this.outputPath = const Value.absent(),
    this.errorMessage = const Value.absent(),
    required DateTime createdAt,
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       voiceAssetId = Value(voiceAssetId),
       inputText = Value(inputText),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<TtsJob> custom({
    Expression<String>? id,
    Expression<String>? voiceAssetId,
    Expression<String>? inputText,
    Expression<String>? status,
    Expression<String>? outputPath,
    Expression<String>? errorMessage,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (voiceAssetId != null) 'voice_asset_id': voiceAssetId,
      if (inputText != null) 'input_text': inputText,
      if (status != null) 'status': status,
      if (outputPath != null) 'output_path': outputPath,
      if (errorMessage != null) 'error_message': errorMessage,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TtsJobsCompanion copyWith({
    Value<String>? id,
    Value<String>? voiceAssetId,
    Value<String>? inputText,
    Value<String>? status,
    Value<String?>? outputPath,
    Value<String?>? errorMessage,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return TtsJobsCompanion(
      id: id ?? this.id,
      voiceAssetId: voiceAssetId ?? this.voiceAssetId,
      inputText: inputText ?? this.inputText,
      status: status ?? this.status,
      outputPath: outputPath ?? this.outputPath,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (voiceAssetId.present) {
      map['voice_asset_id'] = Variable<String>(voiceAssetId.value);
    }
    if (inputText.present) {
      map['input_text'] = Variable<String>(inputText.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (outputPath.present) {
      map['output_path'] = Variable<String>(outputPath.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TtsJobsCompanion(')
          ..write('id: $id, ')
          ..write('voiceAssetId: $voiceAssetId, ')
          ..write('inputText: $inputText, ')
          ..write('status: $status, ')
          ..write('outputPath: $outputPath, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuickTtsHistoriesTable extends QuickTtsHistories
    with TableInfo<$QuickTtsHistoriesTable, QuickTtsHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuickTtsHistoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voiceAssetIdMeta = const VerificationMeta(
    'voiceAssetId',
  );
  @override
  late final GeneratedColumn<String> voiceAssetId = GeneratedColumn<String>(
    'voice_asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES voice_assets (id)',
    ),
  );
  static const VerificationMeta _voiceNameMeta = const VerificationMeta(
    'voiceName',
  );
  @override
  late final GeneratedColumn<String> voiceName = GeneratedColumn<String>(
    'voice_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputTextMeta = const VerificationMeta(
    'inputText',
  );
  @override
  late final GeneratedColumn<String> inputText = GeneratedColumn<String>(
    'input_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioDurationMeta = const VerificationMeta(
    'audioDuration',
  );
  @override
  late final GeneratedColumn<double> audioDuration = GeneratedColumn<double>(
    'audio_duration',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _missingMeta = const VerificationMeta(
    'missing',
  );
  @override
  late final GeneratedColumn<bool> missing = GeneratedColumn<bool>(
    'missing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("missing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    voiceAssetId,
    voiceName,
    inputText,
    audioPath,
    audioDuration,
    error,
    createdAt,
    missing,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quick_tts_histories';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuickTtsHistory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('voice_asset_id')) {
      context.handle(
        _voiceAssetIdMeta,
        voiceAssetId.isAcceptableOrUnknown(
          data['voice_asset_id']!,
          _voiceAssetIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_voiceAssetIdMeta);
    }
    if (data.containsKey('voice_name')) {
      context.handle(
        _voiceNameMeta,
        voiceName.isAcceptableOrUnknown(data['voice_name']!, _voiceNameMeta),
      );
    } else if (isInserting) {
      context.missing(_voiceNameMeta);
    }
    if (data.containsKey('input_text')) {
      context.handle(
        _inputTextMeta,
        inputText.isAcceptableOrUnknown(data['input_text']!, _inputTextMeta),
      );
    } else if (isInserting) {
      context.missing(_inputTextMeta);
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    if (data.containsKey('audio_duration')) {
      context.handle(
        _audioDurationMeta,
        audioDuration.isAcceptableOrUnknown(
          data['audio_duration']!,
          _audioDurationMeta,
        ),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('missing')) {
      context.handle(
        _missingMeta,
        missing.isAcceptableOrUnknown(data['missing']!, _missingMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QuickTtsHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuickTtsHistory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      voiceAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_asset_id'],
      )!,
      voiceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_name'],
      )!,
      inputText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_text'],
      )!,
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
      audioDuration: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}audio_duration'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      missing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}missing'],
      )!,
    );
  }

  @override
  $QuickTtsHistoriesTable createAlias(String alias) {
    return $QuickTtsHistoriesTable(attachedDatabase, alias);
  }
}

class QuickTtsHistory extends DataClass implements Insertable<QuickTtsHistory> {
  final String id;
  final String voiceAssetId;
  final String voiceName;
  final String inputText;
  final String? audioPath;
  final double? audioDuration;
  final String? error;
  final DateTime createdAt;
  final bool missing;
  const QuickTtsHistory({
    required this.id,
    required this.voiceAssetId,
    required this.voiceName,
    required this.inputText,
    this.audioPath,
    this.audioDuration,
    this.error,
    required this.createdAt,
    required this.missing,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['voice_asset_id'] = Variable<String>(voiceAssetId);
    map['voice_name'] = Variable<String>(voiceName);
    map['input_text'] = Variable<String>(inputText);
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    if (!nullToAbsent || audioDuration != null) {
      map['audio_duration'] = Variable<double>(audioDuration);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['missing'] = Variable<bool>(missing);
    return map;
  }

  QuickTtsHistoriesCompanion toCompanion(bool nullToAbsent) {
    return QuickTtsHistoriesCompanion(
      id: Value(id),
      voiceAssetId: Value(voiceAssetId),
      voiceName: Value(voiceName),
      inputText: Value(inputText),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
      audioDuration: audioDuration == null && nullToAbsent
          ? const Value.absent()
          : Value(audioDuration),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      createdAt: Value(createdAt),
      missing: Value(missing),
    );
  }

  factory QuickTtsHistory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuickTtsHistory(
      id: serializer.fromJson<String>(json['id']),
      voiceAssetId: serializer.fromJson<String>(json['voiceAssetId']),
      voiceName: serializer.fromJson<String>(json['voiceName']),
      inputText: serializer.fromJson<String>(json['inputText']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      audioDuration: serializer.fromJson<double?>(json['audioDuration']),
      error: serializer.fromJson<String?>(json['error']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      missing: serializer.fromJson<bool>(json['missing']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'voiceAssetId': serializer.toJson<String>(voiceAssetId),
      'voiceName': serializer.toJson<String>(voiceName),
      'inputText': serializer.toJson<String>(inputText),
      'audioPath': serializer.toJson<String?>(audioPath),
      'audioDuration': serializer.toJson<double?>(audioDuration),
      'error': serializer.toJson<String?>(error),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'missing': serializer.toJson<bool>(missing),
    };
  }

  QuickTtsHistory copyWith({
    String? id,
    String? voiceAssetId,
    String? voiceName,
    String? inputText,
    Value<String?> audioPath = const Value.absent(),
    Value<double?> audioDuration = const Value.absent(),
    Value<String?> error = const Value.absent(),
    DateTime? createdAt,
    bool? missing,
  }) => QuickTtsHistory(
    id: id ?? this.id,
    voiceAssetId: voiceAssetId ?? this.voiceAssetId,
    voiceName: voiceName ?? this.voiceName,
    inputText: inputText ?? this.inputText,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    audioDuration: audioDuration.present
        ? audioDuration.value
        : this.audioDuration,
    error: error.present ? error.value : this.error,
    createdAt: createdAt ?? this.createdAt,
    missing: missing ?? this.missing,
  );
  QuickTtsHistory copyWithCompanion(QuickTtsHistoriesCompanion data) {
    return QuickTtsHistory(
      id: data.id.present ? data.id.value : this.id,
      voiceAssetId: data.voiceAssetId.present
          ? data.voiceAssetId.value
          : this.voiceAssetId,
      voiceName: data.voiceName.present ? data.voiceName.value : this.voiceName,
      inputText: data.inputText.present ? data.inputText.value : this.inputText,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      audioDuration: data.audioDuration.present
          ? data.audioDuration.value
          : this.audioDuration,
      error: data.error.present ? data.error.value : this.error,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      missing: data.missing.present ? data.missing.value : this.missing,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuickTtsHistory(')
          ..write('id: $id, ')
          ..write('voiceAssetId: $voiceAssetId, ')
          ..write('voiceName: $voiceName, ')
          ..write('inputText: $inputText, ')
          ..write('audioPath: $audioPath, ')
          ..write('audioDuration: $audioDuration, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('missing: $missing')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    voiceAssetId,
    voiceName,
    inputText,
    audioPath,
    audioDuration,
    error,
    createdAt,
    missing,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuickTtsHistory &&
          other.id == this.id &&
          other.voiceAssetId == this.voiceAssetId &&
          other.voiceName == this.voiceName &&
          other.inputText == this.inputText &&
          other.audioPath == this.audioPath &&
          other.audioDuration == this.audioDuration &&
          other.error == this.error &&
          other.createdAt == this.createdAt &&
          other.missing == this.missing);
}

class QuickTtsHistoriesCompanion extends UpdateCompanion<QuickTtsHistory> {
  final Value<String> id;
  final Value<String> voiceAssetId;
  final Value<String> voiceName;
  final Value<String> inputText;
  final Value<String?> audioPath;
  final Value<double?> audioDuration;
  final Value<String?> error;
  final Value<DateTime> createdAt;
  final Value<bool> missing;
  final Value<int> rowid;
  const QuickTtsHistoriesCompanion({
    this.id = const Value.absent(),
    this.voiceAssetId = const Value.absent(),
    this.voiceName = const Value.absent(),
    this.inputText = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.audioDuration = const Value.absent(),
    this.error = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.missing = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuickTtsHistoriesCompanion.insert({
    required String id,
    required String voiceAssetId,
    required String voiceName,
    required String inputText,
    this.audioPath = const Value.absent(),
    this.audioDuration = const Value.absent(),
    this.error = const Value.absent(),
    required DateTime createdAt,
    this.missing = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       voiceAssetId = Value(voiceAssetId),
       voiceName = Value(voiceName),
       inputText = Value(inputText),
       createdAt = Value(createdAt);
  static Insertable<QuickTtsHistory> custom({
    Expression<String>? id,
    Expression<String>? voiceAssetId,
    Expression<String>? voiceName,
    Expression<String>? inputText,
    Expression<String>? audioPath,
    Expression<double>? audioDuration,
    Expression<String>? error,
    Expression<DateTime>? createdAt,
    Expression<bool>? missing,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (voiceAssetId != null) 'voice_asset_id': voiceAssetId,
      if (voiceName != null) 'voice_name': voiceName,
      if (inputText != null) 'input_text': inputText,
      if (audioPath != null) 'audio_path': audioPath,
      if (audioDuration != null) 'audio_duration': audioDuration,
      if (error != null) 'error': error,
      if (createdAt != null) 'created_at': createdAt,
      if (missing != null) 'missing': missing,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuickTtsHistoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? voiceAssetId,
    Value<String>? voiceName,
    Value<String>? inputText,
    Value<String?>? audioPath,
    Value<double?>? audioDuration,
    Value<String?>? error,
    Value<DateTime>? createdAt,
    Value<bool>? missing,
    Value<int>? rowid,
  }) {
    return QuickTtsHistoriesCompanion(
      id: id ?? this.id,
      voiceAssetId: voiceAssetId ?? this.voiceAssetId,
      voiceName: voiceName ?? this.voiceName,
      inputText: inputText ?? this.inputText,
      audioPath: audioPath ?? this.audioPath,
      audioDuration: audioDuration ?? this.audioDuration,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      missing: missing ?? this.missing,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (voiceAssetId.present) {
      map['voice_asset_id'] = Variable<String>(voiceAssetId.value);
    }
    if (voiceName.present) {
      map['voice_name'] = Variable<String>(voiceName.value);
    }
    if (inputText.present) {
      map['input_text'] = Variable<String>(inputText.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (audioDuration.present) {
      map['audio_duration'] = Variable<double>(audioDuration.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (missing.present) {
      map['missing'] = Variable<bool>(missing.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuickTtsHistoriesCompanion(')
          ..write('id: $id, ')
          ..write('voiceAssetId: $voiceAssetId, ')
          ..write('voiceName: $voiceName, ')
          ..write('inputText: $inputText, ')
          ..write('audioPath: $audioPath, ')
          ..write('audioDuration: $audioDuration, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('missing: $missing, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhaseTtsProjectsTable extends PhaseTtsProjects
    with TableInfo<$PhaseTtsProjectsTable, PhaseTtsProject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhaseTtsProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bankIdMeta = const VerificationMeta('bankId');
  @override
  late final GeneratedColumn<String> bankId = GeneratedColumn<String>(
    'bank_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES voice_banks (id)',
    ),
  );
  static const VerificationMeta _scriptTextMeta = const VerificationMeta(
    'scriptText',
  );
  @override
  late final GeneratedColumn<String> scriptText = GeneratedColumn<String>(
    'script_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderSlugMeta = const VerificationMeta(
    'folderSlug',
  );
  @override
  late final GeneratedColumn<String> folderSlug = GeneratedColumn<String>(
    'folder_slug',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    bankId,
    scriptText,
    createdAt,
    updatedAt,
    folderSlug,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'phase_tts_projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhaseTtsProject> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('bank_id')) {
      context.handle(
        _bankIdMeta,
        bankId.isAcceptableOrUnknown(data['bank_id']!, _bankIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bankIdMeta);
    }
    if (data.containsKey('script_text')) {
      context.handle(
        _scriptTextMeta,
        scriptText.isAcceptableOrUnknown(data['script_text']!, _scriptTextMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('folder_slug')) {
      context.handle(
        _folderSlugMeta,
        folderSlug.isAcceptableOrUnknown(data['folder_slug']!, _folderSlugMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhaseTtsProject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhaseTtsProject(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      bankId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_id'],
      )!,
      scriptText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}script_text'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      folderSlug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_slug'],
      ),
    );
  }

  @override
  $PhaseTtsProjectsTable createAlias(String alias) {
    return $PhaseTtsProjectsTable(attachedDatabase, alias);
  }
}

class PhaseTtsProject extends DataClass implements Insertable<PhaseTtsProject> {
  final String id;
  final String name;
  final String bankId;
  final String scriptText;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? folderSlug;
  const PhaseTtsProject({
    required this.id,
    required this.name,
    required this.bankId,
    required this.scriptText,
    required this.createdAt,
    required this.updatedAt,
    this.folderSlug,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['bank_id'] = Variable<String>(bankId);
    map['script_text'] = Variable<String>(scriptText);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || folderSlug != null) {
      map['folder_slug'] = Variable<String>(folderSlug);
    }
    return map;
  }

  PhaseTtsProjectsCompanion toCompanion(bool nullToAbsent) {
    return PhaseTtsProjectsCompanion(
      id: Value(id),
      name: Value(name),
      bankId: Value(bankId),
      scriptText: Value(scriptText),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      folderSlug: folderSlug == null && nullToAbsent
          ? const Value.absent()
          : Value(folderSlug),
    );
  }

  factory PhaseTtsProject.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhaseTtsProject(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      bankId: serializer.fromJson<String>(json['bankId']),
      scriptText: serializer.fromJson<String>(json['scriptText']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      folderSlug: serializer.fromJson<String?>(json['folderSlug']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'bankId': serializer.toJson<String>(bankId),
      'scriptText': serializer.toJson<String>(scriptText),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'folderSlug': serializer.toJson<String?>(folderSlug),
    };
  }

  PhaseTtsProject copyWith({
    String? id,
    String? name,
    String? bankId,
    String? scriptText,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> folderSlug = const Value.absent(),
  }) => PhaseTtsProject(
    id: id ?? this.id,
    name: name ?? this.name,
    bankId: bankId ?? this.bankId,
    scriptText: scriptText ?? this.scriptText,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    folderSlug: folderSlug.present ? folderSlug.value : this.folderSlug,
  );
  PhaseTtsProject copyWithCompanion(PhaseTtsProjectsCompanion data) {
    return PhaseTtsProject(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      bankId: data.bankId.present ? data.bankId.value : this.bankId,
      scriptText: data.scriptText.present
          ? data.scriptText.value
          : this.scriptText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      folderSlug: data.folderSlug.present
          ? data.folderSlug.value
          : this.folderSlug,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhaseTtsProject(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('bankId: $bankId, ')
          ..write('scriptText: $scriptText, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('folderSlug: $folderSlug')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    bankId,
    scriptText,
    createdAt,
    updatedAt,
    folderSlug,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhaseTtsProject &&
          other.id == this.id &&
          other.name == this.name &&
          other.bankId == this.bankId &&
          other.scriptText == this.scriptText &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.folderSlug == this.folderSlug);
}

class PhaseTtsProjectsCompanion extends UpdateCompanion<PhaseTtsProject> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> bankId;
  final Value<String> scriptText;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> folderSlug;
  final Value<int> rowid;
  const PhaseTtsProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.bankId = const Value.absent(),
    this.scriptText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.folderSlug = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhaseTtsProjectsCompanion.insert({
    required String id,
    required String name,
    required String bankId,
    this.scriptText = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.folderSlug = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       bankId = Value(bankId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PhaseTtsProject> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? bankId,
    Expression<String>? scriptText,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? folderSlug,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (bankId != null) 'bank_id': bankId,
      if (scriptText != null) 'script_text': scriptText,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (folderSlug != null) 'folder_slug': folderSlug,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhaseTtsProjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? bankId,
    Value<String>? scriptText,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? folderSlug,
    Value<int>? rowid,
  }) {
    return PhaseTtsProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      bankId: bankId ?? this.bankId,
      scriptText: scriptText ?? this.scriptText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      folderSlug: folderSlug ?? this.folderSlug,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (bankId.present) {
      map['bank_id'] = Variable<String>(bankId.value);
    }
    if (scriptText.present) {
      map['script_text'] = Variable<String>(scriptText.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (folderSlug.present) {
      map['folder_slug'] = Variable<String>(folderSlug.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhaseTtsProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('bankId: $bankId, ')
          ..write('scriptText: $scriptText, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('folderSlug: $folderSlug, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhaseTtsSegmentsTable extends PhaseTtsSegments
    with TableInfo<$PhaseTtsSegmentsTable, PhaseTtsSegment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhaseTtsSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES phase_tts_projects (id)',
    ),
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _segmentTextMeta = const VerificationMeta(
    'segmentText',
  );
  @override
  late final GeneratedColumn<String> segmentText = GeneratedColumn<String>(
    'segment_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voiceAssetIdMeta = const VerificationMeta(
    'voiceAssetId',
  );
  @override
  late final GeneratedColumn<String> voiceAssetId = GeneratedColumn<String>(
    'voice_asset_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioDurationMeta = const VerificationMeta(
    'audioDuration',
  );
  @override
  late final GeneratedColumn<double> audioDuration = GeneratedColumn<double>(
    'audio_duration',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _missingMeta = const VerificationMeta(
    'missing',
  );
  @override
  late final GeneratedColumn<bool> missing = GeneratedColumn<bool>(
    'missing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("missing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    orderIndex,
    segmentText,
    voiceAssetId,
    audioPath,
    audioDuration,
    error,
    missing,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'phase_tts_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhaseTtsSegment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('segment_text')) {
      context.handle(
        _segmentTextMeta,
        segmentText.isAcceptableOrUnknown(
          data['segment_text']!,
          _segmentTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_segmentTextMeta);
    }
    if (data.containsKey('voice_asset_id')) {
      context.handle(
        _voiceAssetIdMeta,
        voiceAssetId.isAcceptableOrUnknown(
          data['voice_asset_id']!,
          _voiceAssetIdMeta,
        ),
      );
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    if (data.containsKey('audio_duration')) {
      context.handle(
        _audioDurationMeta,
        audioDuration.isAcceptableOrUnknown(
          data['audio_duration']!,
          _audioDurationMeta,
        ),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('missing')) {
      context.handle(
        _missingMeta,
        missing.isAcceptableOrUnknown(data['missing']!, _missingMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhaseTtsSegment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhaseTtsSegment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      segmentText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}segment_text'],
      )!,
      voiceAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_asset_id'],
      ),
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
      audioDuration: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}audio_duration'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      missing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}missing'],
      )!,
    );
  }

  @override
  $PhaseTtsSegmentsTable createAlias(String alias) {
    return $PhaseTtsSegmentsTable(attachedDatabase, alias);
  }
}

class PhaseTtsSegment extends DataClass implements Insertable<PhaseTtsSegment> {
  final String id;
  final String projectId;
  final int orderIndex;
  final String segmentText;
  final String? voiceAssetId;
  final String? audioPath;
  final double? audioDuration;
  final String? error;
  final bool missing;
  const PhaseTtsSegment({
    required this.id,
    required this.projectId,
    required this.orderIndex,
    required this.segmentText,
    this.voiceAssetId,
    this.audioPath,
    this.audioDuration,
    this.error,
    required this.missing,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['order_index'] = Variable<int>(orderIndex);
    map['segment_text'] = Variable<String>(segmentText);
    if (!nullToAbsent || voiceAssetId != null) {
      map['voice_asset_id'] = Variable<String>(voiceAssetId);
    }
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    if (!nullToAbsent || audioDuration != null) {
      map['audio_duration'] = Variable<double>(audioDuration);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['missing'] = Variable<bool>(missing);
    return map;
  }

  PhaseTtsSegmentsCompanion toCompanion(bool nullToAbsent) {
    return PhaseTtsSegmentsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      orderIndex: Value(orderIndex),
      segmentText: Value(segmentText),
      voiceAssetId: voiceAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(voiceAssetId),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
      audioDuration: audioDuration == null && nullToAbsent
          ? const Value.absent()
          : Value(audioDuration),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      missing: Value(missing),
    );
  }

  factory PhaseTtsSegment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhaseTtsSegment(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      segmentText: serializer.fromJson<String>(json['segmentText']),
      voiceAssetId: serializer.fromJson<String?>(json['voiceAssetId']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      audioDuration: serializer.fromJson<double?>(json['audioDuration']),
      error: serializer.fromJson<String?>(json['error']),
      missing: serializer.fromJson<bool>(json['missing']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'segmentText': serializer.toJson<String>(segmentText),
      'voiceAssetId': serializer.toJson<String?>(voiceAssetId),
      'audioPath': serializer.toJson<String?>(audioPath),
      'audioDuration': serializer.toJson<double?>(audioDuration),
      'error': serializer.toJson<String?>(error),
      'missing': serializer.toJson<bool>(missing),
    };
  }

  PhaseTtsSegment copyWith({
    String? id,
    String? projectId,
    int? orderIndex,
    String? segmentText,
    Value<String?> voiceAssetId = const Value.absent(),
    Value<String?> audioPath = const Value.absent(),
    Value<double?> audioDuration = const Value.absent(),
    Value<String?> error = const Value.absent(),
    bool? missing,
  }) => PhaseTtsSegment(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    orderIndex: orderIndex ?? this.orderIndex,
    segmentText: segmentText ?? this.segmentText,
    voiceAssetId: voiceAssetId.present ? voiceAssetId.value : this.voiceAssetId,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    audioDuration: audioDuration.present
        ? audioDuration.value
        : this.audioDuration,
    error: error.present ? error.value : this.error,
    missing: missing ?? this.missing,
  );
  PhaseTtsSegment copyWithCompanion(PhaseTtsSegmentsCompanion data) {
    return PhaseTtsSegment(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      segmentText: data.segmentText.present
          ? data.segmentText.value
          : this.segmentText,
      voiceAssetId: data.voiceAssetId.present
          ? data.voiceAssetId.value
          : this.voiceAssetId,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      audioDuration: data.audioDuration.present
          ? data.audioDuration.value
          : this.audioDuration,
      error: data.error.present ? data.error.value : this.error,
      missing: data.missing.present ? data.missing.value : this.missing,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhaseTtsSegment(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('segmentText: $segmentText, ')
          ..write('voiceAssetId: $voiceAssetId, ')
          ..write('audioPath: $audioPath, ')
          ..write('audioDuration: $audioDuration, ')
          ..write('error: $error, ')
          ..write('missing: $missing')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    orderIndex,
    segmentText,
    voiceAssetId,
    audioPath,
    audioDuration,
    error,
    missing,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhaseTtsSegment &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.orderIndex == this.orderIndex &&
          other.segmentText == this.segmentText &&
          other.voiceAssetId == this.voiceAssetId &&
          other.audioPath == this.audioPath &&
          other.audioDuration == this.audioDuration &&
          other.error == this.error &&
          other.missing == this.missing);
}

class PhaseTtsSegmentsCompanion extends UpdateCompanion<PhaseTtsSegment> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<int> orderIndex;
  final Value<String> segmentText;
  final Value<String?> voiceAssetId;
  final Value<String?> audioPath;
  final Value<double?> audioDuration;
  final Value<String?> error;
  final Value<bool> missing;
  final Value<int> rowid;
  const PhaseTtsSegmentsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.segmentText = const Value.absent(),
    this.voiceAssetId = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.audioDuration = const Value.absent(),
    this.error = const Value.absent(),
    this.missing = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhaseTtsSegmentsCompanion.insert({
    required String id,
    required String projectId,
    required int orderIndex,
    required String segmentText,
    this.voiceAssetId = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.audioDuration = const Value.absent(),
    this.error = const Value.absent(),
    this.missing = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       orderIndex = Value(orderIndex),
       segmentText = Value(segmentText);
  static Insertable<PhaseTtsSegment> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<int>? orderIndex,
    Expression<String>? segmentText,
    Expression<String>? voiceAssetId,
    Expression<String>? audioPath,
    Expression<double>? audioDuration,
    Expression<String>? error,
    Expression<bool>? missing,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (orderIndex != null) 'order_index': orderIndex,
      if (segmentText != null) 'segment_text': segmentText,
      if (voiceAssetId != null) 'voice_asset_id': voiceAssetId,
      if (audioPath != null) 'audio_path': audioPath,
      if (audioDuration != null) 'audio_duration': audioDuration,
      if (error != null) 'error': error,
      if (missing != null) 'missing': missing,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhaseTtsSegmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<int>? orderIndex,
    Value<String>? segmentText,
    Value<String?>? voiceAssetId,
    Value<String?>? audioPath,
    Value<double?>? audioDuration,
    Value<String?>? error,
    Value<bool>? missing,
    Value<int>? rowid,
  }) {
    return PhaseTtsSegmentsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      orderIndex: orderIndex ?? this.orderIndex,
      segmentText: segmentText ?? this.segmentText,
      voiceAssetId: voiceAssetId ?? this.voiceAssetId,
      audioPath: audioPath ?? this.audioPath,
      audioDuration: audioDuration ?? this.audioDuration,
      error: error ?? this.error,
      missing: missing ?? this.missing,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (segmentText.present) {
      map['segment_text'] = Variable<String>(segmentText.value);
    }
    if (voiceAssetId.present) {
      map['voice_asset_id'] = Variable<String>(voiceAssetId.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (audioDuration.present) {
      map['audio_duration'] = Variable<double>(audioDuration.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (missing.present) {
      map['missing'] = Variable<bool>(missing.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhaseTtsSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('segmentText: $segmentText, ')
          ..write('voiceAssetId: $voiceAssetId, ')
          ..write('audioPath: $audioPath, ')
          ..write('audioDuration: $audioDuration, ')
          ..write('error: $error, ')
          ..write('missing: $missing, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DialogTtsProjectsTable extends DialogTtsProjects
    with TableInfo<$DialogTtsProjectsTable, DialogTtsProject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DialogTtsProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bankIdMeta = const VerificationMeta('bankId');
  @override
  late final GeneratedColumn<String> bankId = GeneratedColumn<String>(
    'bank_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES voice_banks (id)',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderSlugMeta = const VerificationMeta(
    'folderSlug',
  );
  @override
  late final GeneratedColumn<String> folderSlug = GeneratedColumn<String>(
    'folder_slug',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    bankId,
    createdAt,
    updatedAt,
    folderSlug,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dialog_tts_projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<DialogTtsProject> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('bank_id')) {
      context.handle(
        _bankIdMeta,
        bankId.isAcceptableOrUnknown(data['bank_id']!, _bankIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bankIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('folder_slug')) {
      context.handle(
        _folderSlugMeta,
        folderSlug.isAcceptableOrUnknown(data['folder_slug']!, _folderSlugMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DialogTtsProject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DialogTtsProject(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      bankId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      folderSlug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_slug'],
      ),
    );
  }

  @override
  $DialogTtsProjectsTable createAlias(String alias) {
    return $DialogTtsProjectsTable(attachedDatabase, alias);
  }
}

class DialogTtsProject extends DataClass
    implements Insertable<DialogTtsProject> {
  final String id;
  final String name;
  final String bankId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? folderSlug;
  const DialogTtsProject({
    required this.id,
    required this.name,
    required this.bankId,
    required this.createdAt,
    required this.updatedAt,
    this.folderSlug,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['bank_id'] = Variable<String>(bankId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || folderSlug != null) {
      map['folder_slug'] = Variable<String>(folderSlug);
    }
    return map;
  }

  DialogTtsProjectsCompanion toCompanion(bool nullToAbsent) {
    return DialogTtsProjectsCompanion(
      id: Value(id),
      name: Value(name),
      bankId: Value(bankId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      folderSlug: folderSlug == null && nullToAbsent
          ? const Value.absent()
          : Value(folderSlug),
    );
  }

  factory DialogTtsProject.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DialogTtsProject(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      bankId: serializer.fromJson<String>(json['bankId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      folderSlug: serializer.fromJson<String?>(json['folderSlug']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'bankId': serializer.toJson<String>(bankId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'folderSlug': serializer.toJson<String?>(folderSlug),
    };
  }

  DialogTtsProject copyWith({
    String? id,
    String? name,
    String? bankId,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> folderSlug = const Value.absent(),
  }) => DialogTtsProject(
    id: id ?? this.id,
    name: name ?? this.name,
    bankId: bankId ?? this.bankId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    folderSlug: folderSlug.present ? folderSlug.value : this.folderSlug,
  );
  DialogTtsProject copyWithCompanion(DialogTtsProjectsCompanion data) {
    return DialogTtsProject(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      bankId: data.bankId.present ? data.bankId.value : this.bankId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      folderSlug: data.folderSlug.present
          ? data.folderSlug.value
          : this.folderSlug,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DialogTtsProject(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('bankId: $bankId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('folderSlug: $folderSlug')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, bankId, createdAt, updatedAt, folderSlug);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DialogTtsProject &&
          other.id == this.id &&
          other.name == this.name &&
          other.bankId == this.bankId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.folderSlug == this.folderSlug);
}

class DialogTtsProjectsCompanion extends UpdateCompanion<DialogTtsProject> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> bankId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> folderSlug;
  final Value<int> rowid;
  const DialogTtsProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.bankId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.folderSlug = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DialogTtsProjectsCompanion.insert({
    required String id,
    required String name,
    required String bankId,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.folderSlug = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       bankId = Value(bankId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DialogTtsProject> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? bankId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? folderSlug,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (bankId != null) 'bank_id': bankId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (folderSlug != null) 'folder_slug': folderSlug,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DialogTtsProjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? bankId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? folderSlug,
    Value<int>? rowid,
  }) {
    return DialogTtsProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      bankId: bankId ?? this.bankId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      folderSlug: folderSlug ?? this.folderSlug,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (bankId.present) {
      map['bank_id'] = Variable<String>(bankId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (folderSlug.present) {
      map['folder_slug'] = Variable<String>(folderSlug.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DialogTtsProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('bankId: $bankId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('folderSlug: $folderSlug, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DialogTtsLinesTable extends DialogTtsLines
    with TableInfo<$DialogTtsLinesTable, DialogTtsLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DialogTtsLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES dialog_tts_projects (id)',
    ),
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineTextMeta = const VerificationMeta(
    'lineText',
  );
  @override
  late final GeneratedColumn<String> lineText = GeneratedColumn<String>(
    'line_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voiceAssetIdMeta = const VerificationMeta(
    'voiceAssetId',
  );
  @override
  late final GeneratedColumn<String> voiceAssetId = GeneratedColumn<String>(
    'voice_asset_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioDurationMeta = const VerificationMeta(
    'audioDuration',
  );
  @override
  late final GeneratedColumn<double> audioDuration = GeneratedColumn<double>(
    'audio_duration',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _missingMeta = const VerificationMeta(
    'missing',
  );
  @override
  late final GeneratedColumn<bool> missing = GeneratedColumn<bool>(
    'missing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("missing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    orderIndex,
    lineText,
    voiceAssetId,
    audioPath,
    audioDuration,
    error,
    missing,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dialog_tts_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<DialogTtsLine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('line_text')) {
      context.handle(
        _lineTextMeta,
        lineText.isAcceptableOrUnknown(data['line_text']!, _lineTextMeta),
      );
    } else if (isInserting) {
      context.missing(_lineTextMeta);
    }
    if (data.containsKey('voice_asset_id')) {
      context.handle(
        _voiceAssetIdMeta,
        voiceAssetId.isAcceptableOrUnknown(
          data['voice_asset_id']!,
          _voiceAssetIdMeta,
        ),
      );
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    if (data.containsKey('audio_duration')) {
      context.handle(
        _audioDurationMeta,
        audioDuration.isAcceptableOrUnknown(
          data['audio_duration']!,
          _audioDurationMeta,
        ),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('missing')) {
      context.handle(
        _missingMeta,
        missing.isAcceptableOrUnknown(data['missing']!, _missingMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DialogTtsLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DialogTtsLine(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      lineText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}line_text'],
      )!,
      voiceAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_asset_id'],
      ),
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
      audioDuration: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}audio_duration'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      missing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}missing'],
      )!,
    );
  }

  @override
  $DialogTtsLinesTable createAlias(String alias) {
    return $DialogTtsLinesTable(attachedDatabase, alias);
  }
}

class DialogTtsLine extends DataClass implements Insertable<DialogTtsLine> {
  final String id;
  final String projectId;
  final int orderIndex;
  final String lineText;
  final String? voiceAssetId;
  final String? audioPath;
  final double? audioDuration;
  final String? error;
  final bool missing;
  const DialogTtsLine({
    required this.id,
    required this.projectId,
    required this.orderIndex,
    required this.lineText,
    this.voiceAssetId,
    this.audioPath,
    this.audioDuration,
    this.error,
    required this.missing,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['order_index'] = Variable<int>(orderIndex);
    map['line_text'] = Variable<String>(lineText);
    if (!nullToAbsent || voiceAssetId != null) {
      map['voice_asset_id'] = Variable<String>(voiceAssetId);
    }
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    if (!nullToAbsent || audioDuration != null) {
      map['audio_duration'] = Variable<double>(audioDuration);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['missing'] = Variable<bool>(missing);
    return map;
  }

  DialogTtsLinesCompanion toCompanion(bool nullToAbsent) {
    return DialogTtsLinesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      orderIndex: Value(orderIndex),
      lineText: Value(lineText),
      voiceAssetId: voiceAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(voiceAssetId),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
      audioDuration: audioDuration == null && nullToAbsent
          ? const Value.absent()
          : Value(audioDuration),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      missing: Value(missing),
    );
  }

  factory DialogTtsLine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DialogTtsLine(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      lineText: serializer.fromJson<String>(json['lineText']),
      voiceAssetId: serializer.fromJson<String?>(json['voiceAssetId']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      audioDuration: serializer.fromJson<double?>(json['audioDuration']),
      error: serializer.fromJson<String?>(json['error']),
      missing: serializer.fromJson<bool>(json['missing']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'lineText': serializer.toJson<String>(lineText),
      'voiceAssetId': serializer.toJson<String?>(voiceAssetId),
      'audioPath': serializer.toJson<String?>(audioPath),
      'audioDuration': serializer.toJson<double?>(audioDuration),
      'error': serializer.toJson<String?>(error),
      'missing': serializer.toJson<bool>(missing),
    };
  }

  DialogTtsLine copyWith({
    String? id,
    String? projectId,
    int? orderIndex,
    String? lineText,
    Value<String?> voiceAssetId = const Value.absent(),
    Value<String?> audioPath = const Value.absent(),
    Value<double?> audioDuration = const Value.absent(),
    Value<String?> error = const Value.absent(),
    bool? missing,
  }) => DialogTtsLine(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    orderIndex: orderIndex ?? this.orderIndex,
    lineText: lineText ?? this.lineText,
    voiceAssetId: voiceAssetId.present ? voiceAssetId.value : this.voiceAssetId,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    audioDuration: audioDuration.present
        ? audioDuration.value
        : this.audioDuration,
    error: error.present ? error.value : this.error,
    missing: missing ?? this.missing,
  );
  DialogTtsLine copyWithCompanion(DialogTtsLinesCompanion data) {
    return DialogTtsLine(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      lineText: data.lineText.present ? data.lineText.value : this.lineText,
      voiceAssetId: data.voiceAssetId.present
          ? data.voiceAssetId.value
          : this.voiceAssetId,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      audioDuration: data.audioDuration.present
          ? data.audioDuration.value
          : this.audioDuration,
      error: data.error.present ? data.error.value : this.error,
      missing: data.missing.present ? data.missing.value : this.missing,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DialogTtsLine(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('lineText: $lineText, ')
          ..write('voiceAssetId: $voiceAssetId, ')
          ..write('audioPath: $audioPath, ')
          ..write('audioDuration: $audioDuration, ')
          ..write('error: $error, ')
          ..write('missing: $missing')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    orderIndex,
    lineText,
    voiceAssetId,
    audioPath,
    audioDuration,
    error,
    missing,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DialogTtsLine &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.orderIndex == this.orderIndex &&
          other.lineText == this.lineText &&
          other.voiceAssetId == this.voiceAssetId &&
          other.audioPath == this.audioPath &&
          other.audioDuration == this.audioDuration &&
          other.error == this.error &&
          other.missing == this.missing);
}

class DialogTtsLinesCompanion extends UpdateCompanion<DialogTtsLine> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<int> orderIndex;
  final Value<String> lineText;
  final Value<String?> voiceAssetId;
  final Value<String?> audioPath;
  final Value<double?> audioDuration;
  final Value<String?> error;
  final Value<bool> missing;
  final Value<int> rowid;
  const DialogTtsLinesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.lineText = const Value.absent(),
    this.voiceAssetId = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.audioDuration = const Value.absent(),
    this.error = const Value.absent(),
    this.missing = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DialogTtsLinesCompanion.insert({
    required String id,
    required String projectId,
    required int orderIndex,
    required String lineText,
    this.voiceAssetId = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.audioDuration = const Value.absent(),
    this.error = const Value.absent(),
    this.missing = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       orderIndex = Value(orderIndex),
       lineText = Value(lineText);
  static Insertable<DialogTtsLine> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<int>? orderIndex,
    Expression<String>? lineText,
    Expression<String>? voiceAssetId,
    Expression<String>? audioPath,
    Expression<double>? audioDuration,
    Expression<String>? error,
    Expression<bool>? missing,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (orderIndex != null) 'order_index': orderIndex,
      if (lineText != null) 'line_text': lineText,
      if (voiceAssetId != null) 'voice_asset_id': voiceAssetId,
      if (audioPath != null) 'audio_path': audioPath,
      if (audioDuration != null) 'audio_duration': audioDuration,
      if (error != null) 'error': error,
      if (missing != null) 'missing': missing,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DialogTtsLinesCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<int>? orderIndex,
    Value<String>? lineText,
    Value<String?>? voiceAssetId,
    Value<String?>? audioPath,
    Value<double?>? audioDuration,
    Value<String?>? error,
    Value<bool>? missing,
    Value<int>? rowid,
  }) {
    return DialogTtsLinesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      orderIndex: orderIndex ?? this.orderIndex,
      lineText: lineText ?? this.lineText,
      voiceAssetId: voiceAssetId ?? this.voiceAssetId,
      audioPath: audioPath ?? this.audioPath,
      audioDuration: audioDuration ?? this.audioDuration,
      error: error ?? this.error,
      missing: missing ?? this.missing,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (lineText.present) {
      map['line_text'] = Variable<String>(lineText.value);
    }
    if (voiceAssetId.present) {
      map['voice_asset_id'] = Variable<String>(voiceAssetId.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (audioDuration.present) {
      map['audio_duration'] = Variable<double>(audioDuration.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (missing.present) {
      map['missing'] = Variable<bool>(missing.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DialogTtsLinesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('lineText: $lineText, ')
          ..write('voiceAssetId: $voiceAssetId, ')
          ..write('audioPath: $audioPath, ')
          ..write('audioDuration: $audioDuration, ')
          ..write('error: $error, ')
          ..write('missing: $missing, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VideoDubProjectsTable extends VideoDubProjects
    with TableInfo<$VideoDubProjectsTable, VideoDubProject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VideoDubProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bankIdMeta = const VerificationMeta('bankId');
  @override
  late final GeneratedColumn<String> bankId = GeneratedColumn<String>(
    'bank_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES voice_banks (id)',
    ),
  );
  static const VerificationMeta _videoPathMeta = const VerificationMeta(
    'videoPath',
  );
  @override
  late final GeneratedColumn<String> videoPath = GeneratedColumn<String>(
    'video_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _videoDurationSecMeta = const VerificationMeta(
    'videoDurationSec',
  );
  @override
  late final GeneratedColumn<double> videoDurationSec = GeneratedColumn<double>(
    'video_duration_sec',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderSlugMeta = const VerificationMeta(
    'folderSlug',
  );
  @override
  late final GeneratedColumn<String> folderSlug = GeneratedColumn<String>(
    'folder_slug',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    bankId,
    videoPath,
    videoDurationSec,
    createdAt,
    updatedAt,
    folderSlug,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'video_dub_projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<VideoDubProject> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('bank_id')) {
      context.handle(
        _bankIdMeta,
        bankId.isAcceptableOrUnknown(data['bank_id']!, _bankIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bankIdMeta);
    }
    if (data.containsKey('video_path')) {
      context.handle(
        _videoPathMeta,
        videoPath.isAcceptableOrUnknown(data['video_path']!, _videoPathMeta),
      );
    }
    if (data.containsKey('video_duration_sec')) {
      context.handle(
        _videoDurationSecMeta,
        videoDurationSec.isAcceptableOrUnknown(
          data['video_duration_sec']!,
          _videoDurationSecMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('folder_slug')) {
      context.handle(
        _folderSlugMeta,
        folderSlug.isAcceptableOrUnknown(data['folder_slug']!, _folderSlugMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VideoDubProject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VideoDubProject(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      bankId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_id'],
      )!,
      videoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_path'],
      ),
      videoDurationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}video_duration_sec'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      folderSlug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_slug'],
      ),
    );
  }

  @override
  $VideoDubProjectsTable createAlias(String alias) {
    return $VideoDubProjectsTable(attachedDatabase, alias);
  }
}

class VideoDubProject extends DataClass implements Insertable<VideoDubProject> {
  final String id;
  final String name;
  final String bankId;
  final String? videoPath;
  final double? videoDurationSec;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? folderSlug;
  const VideoDubProject({
    required this.id,
    required this.name,
    required this.bankId,
    this.videoPath,
    this.videoDurationSec,
    required this.createdAt,
    required this.updatedAt,
    this.folderSlug,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['bank_id'] = Variable<String>(bankId);
    if (!nullToAbsent || videoPath != null) {
      map['video_path'] = Variable<String>(videoPath);
    }
    if (!nullToAbsent || videoDurationSec != null) {
      map['video_duration_sec'] = Variable<double>(videoDurationSec);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || folderSlug != null) {
      map['folder_slug'] = Variable<String>(folderSlug);
    }
    return map;
  }

  VideoDubProjectsCompanion toCompanion(bool nullToAbsent) {
    return VideoDubProjectsCompanion(
      id: Value(id),
      name: Value(name),
      bankId: Value(bankId),
      videoPath: videoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(videoPath),
      videoDurationSec: videoDurationSec == null && nullToAbsent
          ? const Value.absent()
          : Value(videoDurationSec),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      folderSlug: folderSlug == null && nullToAbsent
          ? const Value.absent()
          : Value(folderSlug),
    );
  }

  factory VideoDubProject.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VideoDubProject(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      bankId: serializer.fromJson<String>(json['bankId']),
      videoPath: serializer.fromJson<String?>(json['videoPath']),
      videoDurationSec: serializer.fromJson<double?>(json['videoDurationSec']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      folderSlug: serializer.fromJson<String?>(json['folderSlug']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'bankId': serializer.toJson<String>(bankId),
      'videoPath': serializer.toJson<String?>(videoPath),
      'videoDurationSec': serializer.toJson<double?>(videoDurationSec),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'folderSlug': serializer.toJson<String?>(folderSlug),
    };
  }

  VideoDubProject copyWith({
    String? id,
    String? name,
    String? bankId,
    Value<String?> videoPath = const Value.absent(),
    Value<double?> videoDurationSec = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> folderSlug = const Value.absent(),
  }) => VideoDubProject(
    id: id ?? this.id,
    name: name ?? this.name,
    bankId: bankId ?? this.bankId,
    videoPath: videoPath.present ? videoPath.value : this.videoPath,
    videoDurationSec: videoDurationSec.present
        ? videoDurationSec.value
        : this.videoDurationSec,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    folderSlug: folderSlug.present ? folderSlug.value : this.folderSlug,
  );
  VideoDubProject copyWithCompanion(VideoDubProjectsCompanion data) {
    return VideoDubProject(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      bankId: data.bankId.present ? data.bankId.value : this.bankId,
      videoPath: data.videoPath.present ? data.videoPath.value : this.videoPath,
      videoDurationSec: data.videoDurationSec.present
          ? data.videoDurationSec.value
          : this.videoDurationSec,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      folderSlug: data.folderSlug.present
          ? data.folderSlug.value
          : this.folderSlug,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VideoDubProject(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('bankId: $bankId, ')
          ..write('videoPath: $videoPath, ')
          ..write('videoDurationSec: $videoDurationSec, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('folderSlug: $folderSlug')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    bankId,
    videoPath,
    videoDurationSec,
    createdAt,
    updatedAt,
    folderSlug,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VideoDubProject &&
          other.id == this.id &&
          other.name == this.name &&
          other.bankId == this.bankId &&
          other.videoPath == this.videoPath &&
          other.videoDurationSec == this.videoDurationSec &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.folderSlug == this.folderSlug);
}

class VideoDubProjectsCompanion extends UpdateCompanion<VideoDubProject> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> bankId;
  final Value<String?> videoPath;
  final Value<double?> videoDurationSec;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> folderSlug;
  final Value<int> rowid;
  const VideoDubProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.bankId = const Value.absent(),
    this.videoPath = const Value.absent(),
    this.videoDurationSec = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.folderSlug = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VideoDubProjectsCompanion.insert({
    required String id,
    required String name,
    required String bankId,
    this.videoPath = const Value.absent(),
    this.videoDurationSec = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.folderSlug = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       bankId = Value(bankId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<VideoDubProject> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? bankId,
    Expression<String>? videoPath,
    Expression<double>? videoDurationSec,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? folderSlug,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (bankId != null) 'bank_id': bankId,
      if (videoPath != null) 'video_path': videoPath,
      if (videoDurationSec != null) 'video_duration_sec': videoDurationSec,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (folderSlug != null) 'folder_slug': folderSlug,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VideoDubProjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? bankId,
    Value<String?>? videoPath,
    Value<double?>? videoDurationSec,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? folderSlug,
    Value<int>? rowid,
  }) {
    return VideoDubProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      bankId: bankId ?? this.bankId,
      videoPath: videoPath ?? this.videoPath,
      videoDurationSec: videoDurationSec ?? this.videoDurationSec,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      folderSlug: folderSlug ?? this.folderSlug,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (bankId.present) {
      map['bank_id'] = Variable<String>(bankId.value);
    }
    if (videoPath.present) {
      map['video_path'] = Variable<String>(videoPath.value);
    }
    if (videoDurationSec.present) {
      map['video_duration_sec'] = Variable<double>(videoDurationSec.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (folderSlug.present) {
      map['folder_slug'] = Variable<String>(folderSlug.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VideoDubProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('bankId: $bankId, ')
          ..write('videoPath: $videoPath, ')
          ..write('videoDurationSec: $videoDurationSec, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('folderSlug: $folderSlug, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubtitleCuesTable extends SubtitleCues
    with TableInfo<$SubtitleCuesTable, SubtitleCue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubtitleCuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES video_dub_projects (id)',
    ),
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta(
    'startMs',
  );
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  @override
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
    'end_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cueTextMeta = const VerificationMeta(
    'cueText',
  );
  @override
  late final GeneratedColumn<String> cueText = GeneratedColumn<String>(
    'cue_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voiceAssetIdMeta = const VerificationMeta(
    'voiceAssetId',
  );
  @override
  late final GeneratedColumn<String> voiceAssetId = GeneratedColumn<String>(
    'voice_asset_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioDurationMeta = const VerificationMeta(
    'audioDuration',
  );
  @override
  late final GeneratedColumn<double> audioDuration = GeneratedColumn<double>(
    'audio_duration',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _missingMeta = const VerificationMeta(
    'missing',
  );
  @override
  late final GeneratedColumn<bool> missing = GeneratedColumn<bool>(
    'missing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("missing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    orderIndex,
    startMs,
    endMs,
    cueText,
    voiceAssetId,
    audioPath,
    audioDuration,
    error,
    missing,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subtitle_cues';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubtitleCue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('start_ms')) {
      context.handle(
        _startMsMeta,
        startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta),
      );
    } else if (isInserting) {
      context.missing(_startMsMeta);
    }
    if (data.containsKey('end_ms')) {
      context.handle(
        _endMsMeta,
        endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta),
      );
    } else if (isInserting) {
      context.missing(_endMsMeta);
    }
    if (data.containsKey('cue_text')) {
      context.handle(
        _cueTextMeta,
        cueText.isAcceptableOrUnknown(data['cue_text']!, _cueTextMeta),
      );
    } else if (isInserting) {
      context.missing(_cueTextMeta);
    }
    if (data.containsKey('voice_asset_id')) {
      context.handle(
        _voiceAssetIdMeta,
        voiceAssetId.isAcceptableOrUnknown(
          data['voice_asset_id']!,
          _voiceAssetIdMeta,
        ),
      );
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    if (data.containsKey('audio_duration')) {
      context.handle(
        _audioDurationMeta,
        audioDuration.isAcceptableOrUnknown(
          data['audio_duration']!,
          _audioDurationMeta,
        ),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('missing')) {
      context.handle(
        _missingMeta,
        missing.isAcceptableOrUnknown(data['missing']!, _missingMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SubtitleCue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubtitleCue(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      )!,
      endMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_ms'],
      )!,
      cueText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cue_text'],
      )!,
      voiceAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_asset_id'],
      ),
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
      audioDuration: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}audio_duration'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      missing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}missing'],
      )!,
    );
  }

  @override
  $SubtitleCuesTable createAlias(String alias) {
    return $SubtitleCuesTable(attachedDatabase, alias);
  }
}

class SubtitleCue extends DataClass implements Insertable<SubtitleCue> {
  final String id;
  final String projectId;
  final int orderIndex;
  final int startMs;
  final int endMs;
  final String cueText;
  final String? voiceAssetId;
  final String? audioPath;
  final double? audioDuration;
  final String? error;
  final bool missing;
  const SubtitleCue({
    required this.id,
    required this.projectId,
    required this.orderIndex,
    required this.startMs,
    required this.endMs,
    required this.cueText,
    this.voiceAssetId,
    this.audioPath,
    this.audioDuration,
    this.error,
    required this.missing,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['order_index'] = Variable<int>(orderIndex);
    map['start_ms'] = Variable<int>(startMs);
    map['end_ms'] = Variable<int>(endMs);
    map['cue_text'] = Variable<String>(cueText);
    if (!nullToAbsent || voiceAssetId != null) {
      map['voice_asset_id'] = Variable<String>(voiceAssetId);
    }
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    if (!nullToAbsent || audioDuration != null) {
      map['audio_duration'] = Variable<double>(audioDuration);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['missing'] = Variable<bool>(missing);
    return map;
  }

  SubtitleCuesCompanion toCompanion(bool nullToAbsent) {
    return SubtitleCuesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      orderIndex: Value(orderIndex),
      startMs: Value(startMs),
      endMs: Value(endMs),
      cueText: Value(cueText),
      voiceAssetId: voiceAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(voiceAssetId),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
      audioDuration: audioDuration == null && nullToAbsent
          ? const Value.absent()
          : Value(audioDuration),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      missing: Value(missing),
    );
  }

  factory SubtitleCue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubtitleCue(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      startMs: serializer.fromJson<int>(json['startMs']),
      endMs: serializer.fromJson<int>(json['endMs']),
      cueText: serializer.fromJson<String>(json['cueText']),
      voiceAssetId: serializer.fromJson<String?>(json['voiceAssetId']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      audioDuration: serializer.fromJson<double?>(json['audioDuration']),
      error: serializer.fromJson<String?>(json['error']),
      missing: serializer.fromJson<bool>(json['missing']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'startMs': serializer.toJson<int>(startMs),
      'endMs': serializer.toJson<int>(endMs),
      'cueText': serializer.toJson<String>(cueText),
      'voiceAssetId': serializer.toJson<String?>(voiceAssetId),
      'audioPath': serializer.toJson<String?>(audioPath),
      'audioDuration': serializer.toJson<double?>(audioDuration),
      'error': serializer.toJson<String?>(error),
      'missing': serializer.toJson<bool>(missing),
    };
  }

  SubtitleCue copyWith({
    String? id,
    String? projectId,
    int? orderIndex,
    int? startMs,
    int? endMs,
    String? cueText,
    Value<String?> voiceAssetId = const Value.absent(),
    Value<String?> audioPath = const Value.absent(),
    Value<double?> audioDuration = const Value.absent(),
    Value<String?> error = const Value.absent(),
    bool? missing,
  }) => SubtitleCue(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    orderIndex: orderIndex ?? this.orderIndex,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    cueText: cueText ?? this.cueText,
    voiceAssetId: voiceAssetId.present ? voiceAssetId.value : this.voiceAssetId,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    audioDuration: audioDuration.present
        ? audioDuration.value
        : this.audioDuration,
    error: error.present ? error.value : this.error,
    missing: missing ?? this.missing,
  );
  SubtitleCue copyWithCompanion(SubtitleCuesCompanion data) {
    return SubtitleCue(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      cueText: data.cueText.present ? data.cueText.value : this.cueText,
      voiceAssetId: data.voiceAssetId.present
          ? data.voiceAssetId.value
          : this.voiceAssetId,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      audioDuration: data.audioDuration.present
          ? data.audioDuration.value
          : this.audioDuration,
      error: data.error.present ? data.error.value : this.error,
      missing: data.missing.present ? data.missing.value : this.missing,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubtitleCue(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('cueText: $cueText, ')
          ..write('voiceAssetId: $voiceAssetId, ')
          ..write('audioPath: $audioPath, ')
          ..write('audioDuration: $audioDuration, ')
          ..write('error: $error, ')
          ..write('missing: $missing')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    orderIndex,
    startMs,
    endMs,
    cueText,
    voiceAssetId,
    audioPath,
    audioDuration,
    error,
    missing,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubtitleCue &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.orderIndex == this.orderIndex &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.cueText == this.cueText &&
          other.voiceAssetId == this.voiceAssetId &&
          other.audioPath == this.audioPath &&
          other.audioDuration == this.audioDuration &&
          other.error == this.error &&
          other.missing == this.missing);
}

class SubtitleCuesCompanion extends UpdateCompanion<SubtitleCue> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<int> orderIndex;
  final Value<int> startMs;
  final Value<int> endMs;
  final Value<String> cueText;
  final Value<String?> voiceAssetId;
  final Value<String?> audioPath;
  final Value<double?> audioDuration;
  final Value<String?> error;
  final Value<bool> missing;
  final Value<int> rowid;
  const SubtitleCuesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.cueText = const Value.absent(),
    this.voiceAssetId = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.audioDuration = const Value.absent(),
    this.error = const Value.absent(),
    this.missing = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubtitleCuesCompanion.insert({
    required String id,
    required String projectId,
    required int orderIndex,
    required int startMs,
    required int endMs,
    required String cueText,
    this.voiceAssetId = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.audioDuration = const Value.absent(),
    this.error = const Value.absent(),
    this.missing = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       orderIndex = Value(orderIndex),
       startMs = Value(startMs),
       endMs = Value(endMs),
       cueText = Value(cueText);
  static Insertable<SubtitleCue> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<int>? orderIndex,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<String>? cueText,
    Expression<String>? voiceAssetId,
    Expression<String>? audioPath,
    Expression<double>? audioDuration,
    Expression<String>? error,
    Expression<bool>? missing,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (orderIndex != null) 'order_index': orderIndex,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (cueText != null) 'cue_text': cueText,
      if (voiceAssetId != null) 'voice_asset_id': voiceAssetId,
      if (audioPath != null) 'audio_path': audioPath,
      if (audioDuration != null) 'audio_duration': audioDuration,
      if (error != null) 'error': error,
      if (missing != null) 'missing': missing,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubtitleCuesCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<int>? orderIndex,
    Value<int>? startMs,
    Value<int>? endMs,
    Value<String>? cueText,
    Value<String?>? voiceAssetId,
    Value<String?>? audioPath,
    Value<double?>? audioDuration,
    Value<String?>? error,
    Value<bool>? missing,
    Value<int>? rowid,
  }) {
    return SubtitleCuesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      orderIndex: orderIndex ?? this.orderIndex,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      cueText: cueText ?? this.cueText,
      voiceAssetId: voiceAssetId ?? this.voiceAssetId,
      audioPath: audioPath ?? this.audioPath,
      audioDuration: audioDuration ?? this.audioDuration,
      error: error ?? this.error,
      missing: missing ?? this.missing,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (cueText.present) {
      map['cue_text'] = Variable<String>(cueText.value);
    }
    if (voiceAssetId.present) {
      map['voice_asset_id'] = Variable<String>(voiceAssetId.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (audioDuration.present) {
      map['audio_duration'] = Variable<double>(audioDuration.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (missing.present) {
      map['missing'] = Variable<bool>(missing.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubtitleCuesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('cueText: $cueText, ')
          ..write('voiceAssetId: $voiceAssetId, ')
          ..write('audioPath: $audioPath, ')
          ..write('audioDuration: $audioDuration, ')
          ..write('error: $error, ')
          ..write('missing: $missing, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AudioTracksTable extends AudioTracks
    with TableInfo<$AudioTracksTable, AudioTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudioTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarPathMeta = const VerificationMeta(
    'avatarPath',
  );
  @override
  late final GeneratedColumn<String> avatarPath = GeneratedColumn<String>(
    'avatar_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _refTextMeta = const VerificationMeta(
    'refText',
  );
  @override
  late final GeneratedColumn<String> refText = GeneratedColumn<String>(
    'ref_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _refLangMeta = const VerificationMeta(
    'refLang',
  );
  @override
  late final GeneratedColumn<String> refLang = GeneratedColumn<String>(
    'ref_lang',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecMeta = const VerificationMeta(
    'durationSec',
  );
  @override
  late final GeneratedColumn<double> durationSec = GeneratedColumn<double>(
    'duration_sec',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('upload'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _missingMeta = const VerificationMeta(
    'missing',
  );
  @override
  late final GeneratedColumn<bool> missing = GeneratedColumn<bool>(
    'missing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("missing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    audioPath,
    avatarPath,
    refText,
    refLang,
    durationSec,
    sourceType,
    createdAt,
    missing,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audio_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<AudioTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    } else if (isInserting) {
      context.missing(_audioPathMeta);
    }
    if (data.containsKey('avatar_path')) {
      context.handle(
        _avatarPathMeta,
        avatarPath.isAcceptableOrUnknown(data['avatar_path']!, _avatarPathMeta),
      );
    }
    if (data.containsKey('ref_text')) {
      context.handle(
        _refTextMeta,
        refText.isAcceptableOrUnknown(data['ref_text']!, _refTextMeta),
      );
    }
    if (data.containsKey('ref_lang')) {
      context.handle(
        _refLangMeta,
        refLang.isAcceptableOrUnknown(data['ref_lang']!, _refLangMeta),
      );
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
        _durationSecMeta,
        durationSec.isAcceptableOrUnknown(
          data['duration_sec']!,
          _durationSecMeta,
        ),
      );
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('missing')) {
      context.handle(
        _missingMeta,
        missing.isAcceptableOrUnknown(data['missing']!, _missingMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AudioTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AudioTrack(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      )!,
      avatarPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_path'],
      ),
      refText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref_text'],
      ),
      refLang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref_lang'],
      ),
      durationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}duration_sec'],
      ),
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      missing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}missing'],
      )!,
    );
  }

  @override
  $AudioTracksTable createAlias(String alias) {
    return $AudioTracksTable(attachedDatabase, alias);
  }
}

class AudioTrack extends DataClass implements Insertable<AudioTrack> {
  final String id;
  final String name;
  final String? description;
  final String audioPath;
  final String? avatarPath;
  final String? refText;
  final String? refLang;
  final double? durationSec;
  final String sourceType;
  final DateTime createdAt;
  final bool missing;
  const AudioTrack({
    required this.id,
    required this.name,
    this.description,
    required this.audioPath,
    this.avatarPath,
    this.refText,
    this.refLang,
    this.durationSec,
    required this.sourceType,
    required this.createdAt,
    required this.missing,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['audio_path'] = Variable<String>(audioPath);
    if (!nullToAbsent || avatarPath != null) {
      map['avatar_path'] = Variable<String>(avatarPath);
    }
    if (!nullToAbsent || refText != null) {
      map['ref_text'] = Variable<String>(refText);
    }
    if (!nullToAbsent || refLang != null) {
      map['ref_lang'] = Variable<String>(refLang);
    }
    if (!nullToAbsent || durationSec != null) {
      map['duration_sec'] = Variable<double>(durationSec);
    }
    map['source_type'] = Variable<String>(sourceType);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['missing'] = Variable<bool>(missing);
    return map;
  }

  AudioTracksCompanion toCompanion(bool nullToAbsent) {
    return AudioTracksCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      audioPath: Value(audioPath),
      avatarPath: avatarPath == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarPath),
      refText: refText == null && nullToAbsent
          ? const Value.absent()
          : Value(refText),
      refLang: refLang == null && nullToAbsent
          ? const Value.absent()
          : Value(refLang),
      durationSec: durationSec == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSec),
      sourceType: Value(sourceType),
      createdAt: Value(createdAt),
      missing: Value(missing),
    );
  }

  factory AudioTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AudioTrack(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      audioPath: serializer.fromJson<String>(json['audioPath']),
      avatarPath: serializer.fromJson<String?>(json['avatarPath']),
      refText: serializer.fromJson<String?>(json['refText']),
      refLang: serializer.fromJson<String?>(json['refLang']),
      durationSec: serializer.fromJson<double?>(json['durationSec']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      missing: serializer.fromJson<bool>(json['missing']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'audioPath': serializer.toJson<String>(audioPath),
      'avatarPath': serializer.toJson<String?>(avatarPath),
      'refText': serializer.toJson<String?>(refText),
      'refLang': serializer.toJson<String?>(refLang),
      'durationSec': serializer.toJson<double?>(durationSec),
      'sourceType': serializer.toJson<String>(sourceType),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'missing': serializer.toJson<bool>(missing),
    };
  }

  AudioTrack copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    String? audioPath,
    Value<String?> avatarPath = const Value.absent(),
    Value<String?> refText = const Value.absent(),
    Value<String?> refLang = const Value.absent(),
    Value<double?> durationSec = const Value.absent(),
    String? sourceType,
    DateTime? createdAt,
    bool? missing,
  }) => AudioTrack(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    audioPath: audioPath ?? this.audioPath,
    avatarPath: avatarPath.present ? avatarPath.value : this.avatarPath,
    refText: refText.present ? refText.value : this.refText,
    refLang: refLang.present ? refLang.value : this.refLang,
    durationSec: durationSec.present ? durationSec.value : this.durationSec,
    sourceType: sourceType ?? this.sourceType,
    createdAt: createdAt ?? this.createdAt,
    missing: missing ?? this.missing,
  );
  AudioTrack copyWithCompanion(AudioTracksCompanion data) {
    return AudioTrack(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      avatarPath: data.avatarPath.present
          ? data.avatarPath.value
          : this.avatarPath,
      refText: data.refText.present ? data.refText.value : this.refText,
      refLang: data.refLang.present ? data.refLang.value : this.refLang,
      durationSec: data.durationSec.present
          ? data.durationSec.value
          : this.durationSec,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      missing: data.missing.present ? data.missing.value : this.missing,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AudioTrack(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('audioPath: $audioPath, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('refText: $refText, ')
          ..write('refLang: $refLang, ')
          ..write('durationSec: $durationSec, ')
          ..write('sourceType: $sourceType, ')
          ..write('createdAt: $createdAt, ')
          ..write('missing: $missing')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    audioPath,
    avatarPath,
    refText,
    refLang,
    durationSec,
    sourceType,
    createdAt,
    missing,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioTrack &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.audioPath == this.audioPath &&
          other.avatarPath == this.avatarPath &&
          other.refText == this.refText &&
          other.refLang == this.refLang &&
          other.durationSec == this.durationSec &&
          other.sourceType == this.sourceType &&
          other.createdAt == this.createdAt &&
          other.missing == this.missing);
}

class AudioTracksCompanion extends UpdateCompanion<AudioTrack> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String> audioPath;
  final Value<String?> avatarPath;
  final Value<String?> refText;
  final Value<String?> refLang;
  final Value<double?> durationSec;
  final Value<String> sourceType;
  final Value<DateTime> createdAt;
  final Value<bool> missing;
  final Value<int> rowid;
  const AudioTracksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.refText = const Value.absent(),
    this.refLang = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.missing = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudioTracksCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    required String audioPath,
    this.avatarPath = const Value.absent(),
    this.refText = const Value.absent(),
    this.refLang = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.sourceType = const Value.absent(),
    required DateTime createdAt,
    this.missing = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       audioPath = Value(audioPath),
       createdAt = Value(createdAt);
  static Insertable<AudioTrack> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? audioPath,
    Expression<String>? avatarPath,
    Expression<String>? refText,
    Expression<String>? refLang,
    Expression<double>? durationSec,
    Expression<String>? sourceType,
    Expression<DateTime>? createdAt,
    Expression<bool>? missing,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (audioPath != null) 'audio_path': audioPath,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (refText != null) 'ref_text': refText,
      if (refLang != null) 'ref_lang': refLang,
      if (durationSec != null) 'duration_sec': durationSec,
      if (sourceType != null) 'source_type': sourceType,
      if (createdAt != null) 'created_at': createdAt,
      if (missing != null) 'missing': missing,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudioTracksCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<String>? audioPath,
    Value<String?>? avatarPath,
    Value<String?>? refText,
    Value<String?>? refLang,
    Value<double?>? durationSec,
    Value<String>? sourceType,
    Value<DateTime>? createdAt,
    Value<bool>? missing,
    Value<int>? rowid,
  }) {
    return AudioTracksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      audioPath: audioPath ?? this.audioPath,
      avatarPath: avatarPath ?? this.avatarPath,
      refText: refText ?? this.refText,
      refLang: refLang ?? this.refLang,
      durationSec: durationSec ?? this.durationSec,
      sourceType: sourceType ?? this.sourceType,
      createdAt: createdAt ?? this.createdAt,
      missing: missing ?? this.missing,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (avatarPath.present) {
      map['avatar_path'] = Variable<String>(avatarPath.value);
    }
    if (refText.present) {
      map['ref_text'] = Variable<String>(refText.value);
    }
    if (refLang.present) {
      map['ref_lang'] = Variable<String>(refLang.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<double>(durationSec.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (missing.present) {
      map['missing'] = Variable<bool>(missing.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudioTracksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('audioPath: $audioPath, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('refText: $refText, ')
          ..write('refLang: $refLang, ')
          ..write('durationSec: $durationSec, ')
          ..write('sourceType: $sourceType, ')
          ..write('createdAt: $createdAt, ')
          ..write('missing: $missing, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TimelineClipsTable extends TimelineClips
    with TableInfo<$TimelineClipsTable, TimelineClip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimelineClipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectTypeMeta = const VerificationMeta(
    'projectType',
  );
  @override
  late final GeneratedColumn<String> projectType = GeneratedColumn<String>(
    'project_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _laneIndexMeta = const VerificationMeta(
    'laneIndex',
  );
  @override
  late final GeneratedColumn<int> laneIndex = GeneratedColumn<int>(
    'lane_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _startTimeMsMeta = const VerificationMeta(
    'startTimeMs',
  );
  @override
  late final GeneratedColumn<int> startTimeMs = GeneratedColumn<int>(
    'start_time_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationSecMeta = const VerificationMeta(
    'durationSec',
  );
  @override
  late final GeneratedColumn<double> durationSec = GeneratedColumn<double>(
    'duration_sec',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('generated'),
  );
  static const VerificationMeta _sourceLineIdMeta = const VerificationMeta(
    'sourceLineId',
  );
  @override
  late final GeneratedColumn<String> sourceLineId = GeneratedColumn<String>(
    'source_line_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _missingMeta = const VerificationMeta(
    'missing',
  );
  @override
  late final GeneratedColumn<bool> missing = GeneratedColumn<bool>(
    'missing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("missing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _linkGroupIdMeta = const VerificationMeta(
    'linkGroupId',
  );
  @override
  late final GeneratedColumn<String> linkGroupId = GeneratedColumn<String>(
    'link_group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    projectType,
    laneIndex,
    startTimeMs,
    durationSec,
    audioPath,
    sourceType,
    sourceLineId,
    label,
    missing,
    linkGroupId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'timeline_clips';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimelineClip> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('project_type')) {
      context.handle(
        _projectTypeMeta,
        projectType.isAcceptableOrUnknown(
          data['project_type']!,
          _projectTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_projectTypeMeta);
    }
    if (data.containsKey('lane_index')) {
      context.handle(
        _laneIndexMeta,
        laneIndex.isAcceptableOrUnknown(data['lane_index']!, _laneIndexMeta),
      );
    }
    if (data.containsKey('start_time_ms')) {
      context.handle(
        _startTimeMsMeta,
        startTimeMs.isAcceptableOrUnknown(
          data['start_time_ms']!,
          _startTimeMsMeta,
        ),
      );
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
        _durationSecMeta,
        durationSec.isAcceptableOrUnknown(
          data['duration_sec']!,
          _durationSecMeta,
        ),
      );
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    } else if (isInserting) {
      context.missing(_audioPathMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    }
    if (data.containsKey('source_line_id')) {
      context.handle(
        _sourceLineIdMeta,
        sourceLineId.isAcceptableOrUnknown(
          data['source_line_id']!,
          _sourceLineIdMeta,
        ),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('missing')) {
      context.handle(
        _missingMeta,
        missing.isAcceptableOrUnknown(data['missing']!, _missingMeta),
      );
    }
    if (data.containsKey('link_group_id')) {
      context.handle(
        _linkGroupIdMeta,
        linkGroupId.isAcceptableOrUnknown(
          data['link_group_id']!,
          _linkGroupIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TimelineClip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimelineClip(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      projectType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_type'],
      )!,
      laneIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lane_index'],
      )!,
      startTimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_time_ms'],
      )!,
      durationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}duration_sec'],
      ),
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      sourceLineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_line_id'],
      ),
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      missing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}missing'],
      )!,
      linkGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link_group_id'],
      ),
    );
  }

  @override
  $TimelineClipsTable createAlias(String alias) {
    return $TimelineClipsTable(attachedDatabase, alias);
  }
}

class TimelineClip extends DataClass implements Insertable<TimelineClip> {
  final String id;
  final String projectId;
  final String projectType;
  final int laneIndex;
  final int startTimeMs;
  final double? durationSec;
  final String audioPath;
  final String sourceType;
  final String? sourceLineId;
  final String label;
  final bool missing;
  final String? linkGroupId;
  const TimelineClip({
    required this.id,
    required this.projectId,
    required this.projectType,
    required this.laneIndex,
    required this.startTimeMs,
    this.durationSec,
    required this.audioPath,
    required this.sourceType,
    this.sourceLineId,
    required this.label,
    required this.missing,
    this.linkGroupId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['project_type'] = Variable<String>(projectType);
    map['lane_index'] = Variable<int>(laneIndex);
    map['start_time_ms'] = Variable<int>(startTimeMs);
    if (!nullToAbsent || durationSec != null) {
      map['duration_sec'] = Variable<double>(durationSec);
    }
    map['audio_path'] = Variable<String>(audioPath);
    map['source_type'] = Variable<String>(sourceType);
    if (!nullToAbsent || sourceLineId != null) {
      map['source_line_id'] = Variable<String>(sourceLineId);
    }
    map['label'] = Variable<String>(label);
    map['missing'] = Variable<bool>(missing);
    if (!nullToAbsent || linkGroupId != null) {
      map['link_group_id'] = Variable<String>(linkGroupId);
    }
    return map;
  }

  TimelineClipsCompanion toCompanion(bool nullToAbsent) {
    return TimelineClipsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      projectType: Value(projectType),
      laneIndex: Value(laneIndex),
      startTimeMs: Value(startTimeMs),
      durationSec: durationSec == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSec),
      audioPath: Value(audioPath),
      sourceType: Value(sourceType),
      sourceLineId: sourceLineId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceLineId),
      label: Value(label),
      missing: Value(missing),
      linkGroupId: linkGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkGroupId),
    );
  }

  factory TimelineClip.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimelineClip(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      projectType: serializer.fromJson<String>(json['projectType']),
      laneIndex: serializer.fromJson<int>(json['laneIndex']),
      startTimeMs: serializer.fromJson<int>(json['startTimeMs']),
      durationSec: serializer.fromJson<double?>(json['durationSec']),
      audioPath: serializer.fromJson<String>(json['audioPath']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      sourceLineId: serializer.fromJson<String?>(json['sourceLineId']),
      label: serializer.fromJson<String>(json['label']),
      missing: serializer.fromJson<bool>(json['missing']),
      linkGroupId: serializer.fromJson<String?>(json['linkGroupId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'projectType': serializer.toJson<String>(projectType),
      'laneIndex': serializer.toJson<int>(laneIndex),
      'startTimeMs': serializer.toJson<int>(startTimeMs),
      'durationSec': serializer.toJson<double?>(durationSec),
      'audioPath': serializer.toJson<String>(audioPath),
      'sourceType': serializer.toJson<String>(sourceType),
      'sourceLineId': serializer.toJson<String?>(sourceLineId),
      'label': serializer.toJson<String>(label),
      'missing': serializer.toJson<bool>(missing),
      'linkGroupId': serializer.toJson<String?>(linkGroupId),
    };
  }

  TimelineClip copyWith({
    String? id,
    String? projectId,
    String? projectType,
    int? laneIndex,
    int? startTimeMs,
    Value<double?> durationSec = const Value.absent(),
    String? audioPath,
    String? sourceType,
    Value<String?> sourceLineId = const Value.absent(),
    String? label,
    bool? missing,
    Value<String?> linkGroupId = const Value.absent(),
  }) => TimelineClip(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    projectType: projectType ?? this.projectType,
    laneIndex: laneIndex ?? this.laneIndex,
    startTimeMs: startTimeMs ?? this.startTimeMs,
    durationSec: durationSec.present ? durationSec.value : this.durationSec,
    audioPath: audioPath ?? this.audioPath,
    sourceType: sourceType ?? this.sourceType,
    sourceLineId: sourceLineId.present ? sourceLineId.value : this.sourceLineId,
    label: label ?? this.label,
    missing: missing ?? this.missing,
    linkGroupId: linkGroupId.present ? linkGroupId.value : this.linkGroupId,
  );
  TimelineClip copyWithCompanion(TimelineClipsCompanion data) {
    return TimelineClip(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      projectType: data.projectType.present
          ? data.projectType.value
          : this.projectType,
      laneIndex: data.laneIndex.present ? data.laneIndex.value : this.laneIndex,
      startTimeMs: data.startTimeMs.present
          ? data.startTimeMs.value
          : this.startTimeMs,
      durationSec: data.durationSec.present
          ? data.durationSec.value
          : this.durationSec,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      sourceLineId: data.sourceLineId.present
          ? data.sourceLineId.value
          : this.sourceLineId,
      label: data.label.present ? data.label.value : this.label,
      missing: data.missing.present ? data.missing.value : this.missing,
      linkGroupId: data.linkGroupId.present
          ? data.linkGroupId.value
          : this.linkGroupId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimelineClip(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('projectType: $projectType, ')
          ..write('laneIndex: $laneIndex, ')
          ..write('startTimeMs: $startTimeMs, ')
          ..write('durationSec: $durationSec, ')
          ..write('audioPath: $audioPath, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceLineId: $sourceLineId, ')
          ..write('label: $label, ')
          ..write('missing: $missing, ')
          ..write('linkGroupId: $linkGroupId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    projectType,
    laneIndex,
    startTimeMs,
    durationSec,
    audioPath,
    sourceType,
    sourceLineId,
    label,
    missing,
    linkGroupId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimelineClip &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.projectType == this.projectType &&
          other.laneIndex == this.laneIndex &&
          other.startTimeMs == this.startTimeMs &&
          other.durationSec == this.durationSec &&
          other.audioPath == this.audioPath &&
          other.sourceType == this.sourceType &&
          other.sourceLineId == this.sourceLineId &&
          other.label == this.label &&
          other.missing == this.missing &&
          other.linkGroupId == this.linkGroupId);
}

class TimelineClipsCompanion extends UpdateCompanion<TimelineClip> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> projectType;
  final Value<int> laneIndex;
  final Value<int> startTimeMs;
  final Value<double?> durationSec;
  final Value<String> audioPath;
  final Value<String> sourceType;
  final Value<String?> sourceLineId;
  final Value<String> label;
  final Value<bool> missing;
  final Value<String?> linkGroupId;
  final Value<int> rowid;
  const TimelineClipsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.projectType = const Value.absent(),
    this.laneIndex = const Value.absent(),
    this.startTimeMs = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.sourceLineId = const Value.absent(),
    this.label = const Value.absent(),
    this.missing = const Value.absent(),
    this.linkGroupId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TimelineClipsCompanion.insert({
    required String id,
    required String projectId,
    required String projectType,
    this.laneIndex = const Value.absent(),
    this.startTimeMs = const Value.absent(),
    this.durationSec = const Value.absent(),
    required String audioPath,
    this.sourceType = const Value.absent(),
    this.sourceLineId = const Value.absent(),
    this.label = const Value.absent(),
    this.missing = const Value.absent(),
    this.linkGroupId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       projectType = Value(projectType),
       audioPath = Value(audioPath);
  static Insertable<TimelineClip> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? projectType,
    Expression<int>? laneIndex,
    Expression<int>? startTimeMs,
    Expression<double>? durationSec,
    Expression<String>? audioPath,
    Expression<String>? sourceType,
    Expression<String>? sourceLineId,
    Expression<String>? label,
    Expression<bool>? missing,
    Expression<String>? linkGroupId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (projectType != null) 'project_type': projectType,
      if (laneIndex != null) 'lane_index': laneIndex,
      if (startTimeMs != null) 'start_time_ms': startTimeMs,
      if (durationSec != null) 'duration_sec': durationSec,
      if (audioPath != null) 'audio_path': audioPath,
      if (sourceType != null) 'source_type': sourceType,
      if (sourceLineId != null) 'source_line_id': sourceLineId,
      if (label != null) 'label': label,
      if (missing != null) 'missing': missing,
      if (linkGroupId != null) 'link_group_id': linkGroupId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TimelineClipsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? projectType,
    Value<int>? laneIndex,
    Value<int>? startTimeMs,
    Value<double?>? durationSec,
    Value<String>? audioPath,
    Value<String>? sourceType,
    Value<String?>? sourceLineId,
    Value<String>? label,
    Value<bool>? missing,
    Value<String?>? linkGroupId,
    Value<int>? rowid,
  }) {
    return TimelineClipsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      projectType: projectType ?? this.projectType,
      laneIndex: laneIndex ?? this.laneIndex,
      startTimeMs: startTimeMs ?? this.startTimeMs,
      durationSec: durationSec ?? this.durationSec,
      audioPath: audioPath ?? this.audioPath,
      sourceType: sourceType ?? this.sourceType,
      sourceLineId: sourceLineId ?? this.sourceLineId,
      label: label ?? this.label,
      missing: missing ?? this.missing,
      linkGroupId: linkGroupId ?? this.linkGroupId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (projectType.present) {
      map['project_type'] = Variable<String>(projectType.value);
    }
    if (laneIndex.present) {
      map['lane_index'] = Variable<int>(laneIndex.value);
    }
    if (startTimeMs.present) {
      map['start_time_ms'] = Variable<int>(startTimeMs.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<double>(durationSec.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (sourceLineId.present) {
      map['source_line_id'] = Variable<String>(sourceLineId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (missing.present) {
      map['missing'] = Variable<bool>(missing.value);
    }
    if (linkGroupId.present) {
      map['link_group_id'] = Variable<String>(linkGroupId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimelineClipsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('projectType: $projectType, ')
          ..write('laneIndex: $laneIndex, ')
          ..write('startTimeMs: $startTimeMs, ')
          ..write('durationSec: $durationSec, ')
          ..write('audioPath: $audioPath, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceLineId: $sourceLineId, ')
          ..write('label: $label, ')
          ..write('missing: $missing, ')
          ..write('linkGroupId: $linkGroupId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $TtsProvidersTable ttsProviders = $TtsProvidersTable(this);
  late final $ModelBindingsTable modelBindings = $ModelBindingsTable(this);
  late final $VoiceAssetsTable voiceAssets = $VoiceAssetsTable(this);
  late final $VoiceBanksTable voiceBanks = $VoiceBanksTable(this);
  late final $VoiceBankMembersTable voiceBankMembers = $VoiceBankMembersTable(
    this,
  );
  late final $TtsJobsTable ttsJobs = $TtsJobsTable(this);
  late final $QuickTtsHistoriesTable quickTtsHistories =
      $QuickTtsHistoriesTable(this);
  late final $PhaseTtsProjectsTable phaseTtsProjects = $PhaseTtsProjectsTable(
    this,
  );
  late final $PhaseTtsSegmentsTable phaseTtsSegments = $PhaseTtsSegmentsTable(
    this,
  );
  late final $DialogTtsProjectsTable dialogTtsProjects =
      $DialogTtsProjectsTable(this);
  late final $DialogTtsLinesTable dialogTtsLines = $DialogTtsLinesTable(this);
  late final $VideoDubProjectsTable videoDubProjects = $VideoDubProjectsTable(
    this,
  );
  late final $SubtitleCuesTable subtitleCues = $SubtitleCuesTable(this);
  late final $AudioTracksTable audioTracks = $AudioTracksTable(this);
  late final $TimelineClipsTable timelineClips = $TimelineClipsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appSettings,
    ttsProviders,
    modelBindings,
    voiceAssets,
    voiceBanks,
    voiceBankMembers,
    ttsJobs,
    quickTtsHistories,
    phaseTtsProjects,
    phaseTtsSegments,
    dialogTtsProjects,
    dialogTtsLines,
    videoDubProjects,
    subtitleCues,
    audioTracks,
    timelineClips,
  ];
}

typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$TtsProvidersTableCreateCompanionBuilder =
    TtsProvidersCompanion Function({
      required String id,
      required String name,
      required String adapterType,
      required String baseUrl,
      Value<String> apiKey,
      Value<String> defaultModelName,
      Value<bool> enabled,
      Value<int> position,
      Value<int> rowid,
    });
typedef $$TtsProvidersTableUpdateCompanionBuilder =
    TtsProvidersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> adapterType,
      Value<String> baseUrl,
      Value<String> apiKey,
      Value<String> defaultModelName,
      Value<bool> enabled,
      Value<int> position,
      Value<int> rowid,
    });

final class $$TtsProvidersTableReferences
    extends BaseReferences<_$AppDatabase, $TtsProvidersTable, TtsProvider> {
  $$TtsProvidersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ModelBindingsTable, List<ModelBinding>>
  _modelBindingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.modelBindings,
    aliasName: $_aliasNameGenerator(
      db.ttsProviders.id,
      db.modelBindings.providerId,
    ),
  );

  $$ModelBindingsTableProcessedTableManager get modelBindingsRefs {
    final manager = $$ModelBindingsTableTableManager(
      $_db,
      $_db.modelBindings,
    ).filter((f) => f.providerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_modelBindingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$VoiceAssetsTable, List<VoiceAsset>>
  _voiceAssetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.voiceAssets,
    aliasName: $_aliasNameGenerator(
      db.ttsProviders.id,
      db.voiceAssets.providerId,
    ),
  );

  $$VoiceAssetsTableProcessedTableManager get voiceAssetsRefs {
    final manager = $$VoiceAssetsTableTableManager(
      $_db,
      $_db.voiceAssets,
    ).filter((f) => f.providerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_voiceAssetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TtsProvidersTableFilterComposer
    extends Composer<_$AppDatabase, $TtsProvidersTable> {
  $$TtsProvidersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get adapterType => $composableBuilder(
    column: $table.adapterType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apiKey => $composableBuilder(
    column: $table.apiKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultModelName => $composableBuilder(
    column: $table.defaultModelName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> modelBindingsRefs(
    Expression<bool> Function($$ModelBindingsTableFilterComposer f) f,
  ) {
    final $$ModelBindingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.modelBindings,
      getReferencedColumn: (t) => t.providerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelBindingsTableFilterComposer(
            $db: $db,
            $table: $db.modelBindings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> voiceAssetsRefs(
    Expression<bool> Function($$VoiceAssetsTableFilterComposer f) f,
  ) {
    final $$VoiceAssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.voiceAssets,
      getReferencedColumn: (t) => t.providerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceAssetsTableFilterComposer(
            $db: $db,
            $table: $db.voiceAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TtsProvidersTableOrderingComposer
    extends Composer<_$AppDatabase, $TtsProvidersTable> {
  $$TtsProvidersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get adapterType => $composableBuilder(
    column: $table.adapterType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apiKey => $composableBuilder(
    column: $table.apiKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultModelName => $composableBuilder(
    column: $table.defaultModelName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TtsProvidersTableAnnotationComposer
    extends Composer<_$AppDatabase, $TtsProvidersTable> {
  $$TtsProvidersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get adapterType => $composableBuilder(
    column: $table.adapterType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get apiKey =>
      $composableBuilder(column: $table.apiKey, builder: (column) => column);

  GeneratedColumn<String> get defaultModelName => $composableBuilder(
    column: $table.defaultModelName,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  Expression<T> modelBindingsRefs<T extends Object>(
    Expression<T> Function($$ModelBindingsTableAnnotationComposer a) f,
  ) {
    final $$ModelBindingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.modelBindings,
      getReferencedColumn: (t) => t.providerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelBindingsTableAnnotationComposer(
            $db: $db,
            $table: $db.modelBindings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> voiceAssetsRefs<T extends Object>(
    Expression<T> Function($$VoiceAssetsTableAnnotationComposer a) f,
  ) {
    final $$VoiceAssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.voiceAssets,
      getReferencedColumn: (t) => t.providerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceAssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.voiceAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TtsProvidersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TtsProvidersTable,
          TtsProvider,
          $$TtsProvidersTableFilterComposer,
          $$TtsProvidersTableOrderingComposer,
          $$TtsProvidersTableAnnotationComposer,
          $$TtsProvidersTableCreateCompanionBuilder,
          $$TtsProvidersTableUpdateCompanionBuilder,
          (TtsProvider, $$TtsProvidersTableReferences),
          TtsProvider,
          PrefetchHooks Function({bool modelBindingsRefs, bool voiceAssetsRefs})
        > {
  $$TtsProvidersTableTableManager(_$AppDatabase db, $TtsProvidersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TtsProvidersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TtsProvidersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TtsProvidersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> adapterType = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<String> apiKey = const Value.absent(),
                Value<String> defaultModelName = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TtsProvidersCompanion(
                id: id,
                name: name,
                adapterType: adapterType,
                baseUrl: baseUrl,
                apiKey: apiKey,
                defaultModelName: defaultModelName,
                enabled: enabled,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String adapterType,
                required String baseUrl,
                Value<String> apiKey = const Value.absent(),
                Value<String> defaultModelName = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TtsProvidersCompanion.insert(
                id: id,
                name: name,
                adapterType: adapterType,
                baseUrl: baseUrl,
                apiKey: apiKey,
                defaultModelName: defaultModelName,
                enabled: enabled,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TtsProvidersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({modelBindingsRefs = false, voiceAssetsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (modelBindingsRefs) db.modelBindings,
                    if (voiceAssetsRefs) db.voiceAssets,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (modelBindingsRefs)
                        await $_getPrefetchedData<
                          TtsProvider,
                          $TtsProvidersTable,
                          ModelBinding
                        >(
                          currentTable: table,
                          referencedTable: $$TtsProvidersTableReferences
                              ._modelBindingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TtsProvidersTableReferences(
                                db,
                                table,
                                p0,
                              ).modelBindingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.providerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (voiceAssetsRefs)
                        await $_getPrefetchedData<
                          TtsProvider,
                          $TtsProvidersTable,
                          VoiceAsset
                        >(
                          currentTable: table,
                          referencedTable: $$TtsProvidersTableReferences
                              ._voiceAssetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TtsProvidersTableReferences(
                                db,
                                table,
                                p0,
                              ).voiceAssetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.providerId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TtsProvidersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TtsProvidersTable,
      TtsProvider,
      $$TtsProvidersTableFilterComposer,
      $$TtsProvidersTableOrderingComposer,
      $$TtsProvidersTableAnnotationComposer,
      $$TtsProvidersTableCreateCompanionBuilder,
      $$TtsProvidersTableUpdateCompanionBuilder,
      (TtsProvider, $$TtsProvidersTableReferences),
      TtsProvider,
      PrefetchHooks Function({bool modelBindingsRefs, bool voiceAssetsRefs})
    >;
typedef $$ModelBindingsTableCreateCompanionBuilder =
    ModelBindingsCompanion Function({
      required String id,
      required String providerId,
      required String modelKey,
      Value<String> supportedTaskModes,
      Value<int> rowid,
    });
typedef $$ModelBindingsTableUpdateCompanionBuilder =
    ModelBindingsCompanion Function({
      Value<String> id,
      Value<String> providerId,
      Value<String> modelKey,
      Value<String> supportedTaskModes,
      Value<int> rowid,
    });

final class $$ModelBindingsTableReferences
    extends BaseReferences<_$AppDatabase, $ModelBindingsTable, ModelBinding> {
  $$ModelBindingsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TtsProvidersTable _providerIdTable(_$AppDatabase db) =>
      db.ttsProviders.createAlias(
        $_aliasNameGenerator(db.modelBindings.providerId, db.ttsProviders.id),
      );

  $$TtsProvidersTableProcessedTableManager get providerId {
    final $_column = $_itemColumn<String>('provider_id')!;

    final manager = $$TtsProvidersTableTableManager(
      $_db,
      $_db.ttsProviders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_providerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ModelBindingsTableFilterComposer
    extends Composer<_$AppDatabase, $ModelBindingsTable> {
  $$ModelBindingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelKey => $composableBuilder(
    column: $table.modelKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supportedTaskModes => $composableBuilder(
    column: $table.supportedTaskModes,
    builder: (column) => ColumnFilters(column),
  );

  $$TtsProvidersTableFilterComposer get providerId {
    final $$TtsProvidersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.ttsProviders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TtsProvidersTableFilterComposer(
            $db: $db,
            $table: $db.ttsProviders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModelBindingsTableOrderingComposer
    extends Composer<_$AppDatabase, $ModelBindingsTable> {
  $$ModelBindingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelKey => $composableBuilder(
    column: $table.modelKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supportedTaskModes => $composableBuilder(
    column: $table.supportedTaskModes,
    builder: (column) => ColumnOrderings(column),
  );

  $$TtsProvidersTableOrderingComposer get providerId {
    final $$TtsProvidersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.ttsProviders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TtsProvidersTableOrderingComposer(
            $db: $db,
            $table: $db.ttsProviders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModelBindingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModelBindingsTable> {
  $$ModelBindingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get modelKey =>
      $composableBuilder(column: $table.modelKey, builder: (column) => column);

  GeneratedColumn<String> get supportedTaskModes => $composableBuilder(
    column: $table.supportedTaskModes,
    builder: (column) => column,
  );

  $$TtsProvidersTableAnnotationComposer get providerId {
    final $$TtsProvidersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.ttsProviders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TtsProvidersTableAnnotationComposer(
            $db: $db,
            $table: $db.ttsProviders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModelBindingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ModelBindingsTable,
          ModelBinding,
          $$ModelBindingsTableFilterComposer,
          $$ModelBindingsTableOrderingComposer,
          $$ModelBindingsTableAnnotationComposer,
          $$ModelBindingsTableCreateCompanionBuilder,
          $$ModelBindingsTableUpdateCompanionBuilder,
          (ModelBinding, $$ModelBindingsTableReferences),
          ModelBinding,
          PrefetchHooks Function({bool providerId})
        > {
  $$ModelBindingsTableTableManager(_$AppDatabase db, $ModelBindingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelBindingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModelBindingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModelBindingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> modelKey = const Value.absent(),
                Value<String> supportedTaskModes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelBindingsCompanion(
                id: id,
                providerId: providerId,
                modelKey: modelKey,
                supportedTaskModes: supportedTaskModes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String providerId,
                required String modelKey,
                Value<String> supportedTaskModes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelBindingsCompanion.insert(
                id: id,
                providerId: providerId,
                modelKey: modelKey,
                supportedTaskModes: supportedTaskModes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ModelBindingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({providerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (providerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.providerId,
                                referencedTable: $$ModelBindingsTableReferences
                                    ._providerIdTable(db),
                                referencedColumn: $$ModelBindingsTableReferences
                                    ._providerIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ModelBindingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ModelBindingsTable,
      ModelBinding,
      $$ModelBindingsTableFilterComposer,
      $$ModelBindingsTableOrderingComposer,
      $$ModelBindingsTableAnnotationComposer,
      $$ModelBindingsTableCreateCompanionBuilder,
      $$ModelBindingsTableUpdateCompanionBuilder,
      (ModelBinding, $$ModelBindingsTableReferences),
      ModelBinding,
      PrefetchHooks Function({bool providerId})
    >;
typedef $$VoiceAssetsTableCreateCompanionBuilder =
    VoiceAssetsCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      required String providerId,
      Value<String?> modelBindingId,
      Value<String?> modelName,
      required String taskMode,
      Value<String?> refAudioPath,
      Value<double?> refAudioTrimStart,
      Value<double?> refAudioTrimEnd,
      Value<String?> promptText,
      Value<String?> promptLang,
      Value<String?> voiceInstruction,
      Value<String?> presetVoiceName,
      Value<String?> avatarPath,
      Value<double> speed,
      Value<bool> enabled,
      Value<String?> folderSlug,
      Value<int> rowid,
    });
typedef $$VoiceAssetsTableUpdateCompanionBuilder =
    VoiceAssetsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<String> providerId,
      Value<String?> modelBindingId,
      Value<String?> modelName,
      Value<String> taskMode,
      Value<String?> refAudioPath,
      Value<double?> refAudioTrimStart,
      Value<double?> refAudioTrimEnd,
      Value<String?> promptText,
      Value<String?> promptLang,
      Value<String?> voiceInstruction,
      Value<String?> presetVoiceName,
      Value<String?> avatarPath,
      Value<double> speed,
      Value<bool> enabled,
      Value<String?> folderSlug,
      Value<int> rowid,
    });

final class $$VoiceAssetsTableReferences
    extends BaseReferences<_$AppDatabase, $VoiceAssetsTable, VoiceAsset> {
  $$VoiceAssetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TtsProvidersTable _providerIdTable(_$AppDatabase db) =>
      db.ttsProviders.createAlias(
        $_aliasNameGenerator(db.voiceAssets.providerId, db.ttsProviders.id),
      );

  $$TtsProvidersTableProcessedTableManager get providerId {
    final $_column = $_itemColumn<String>('provider_id')!;

    final manager = $$TtsProvidersTableTableManager(
      $_db,
      $_db.ttsProviders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_providerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$VoiceBankMembersTable, List<VoiceBankMember>>
  _voiceBankMembersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.voiceBankMembers,
    aliasName: $_aliasNameGenerator(
      db.voiceAssets.id,
      db.voiceBankMembers.voiceAssetId,
    ),
  );

  $$VoiceBankMembersTableProcessedTableManager get voiceBankMembersRefs {
    final manager = $$VoiceBankMembersTableTableManager(
      $_db,
      $_db.voiceBankMembers,
    ).filter((f) => f.voiceAssetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _voiceBankMembersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TtsJobsTable, List<TtsJob>> _ttsJobsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.ttsJobs,
    aliasName: $_aliasNameGenerator(db.voiceAssets.id, db.ttsJobs.voiceAssetId),
  );

  $$TtsJobsTableProcessedTableManager get ttsJobsRefs {
    final manager = $$TtsJobsTableTableManager(
      $_db,
      $_db.ttsJobs,
    ).filter((f) => f.voiceAssetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_ttsJobsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$QuickTtsHistoriesTable, List<QuickTtsHistory>>
  _quickTtsHistoriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.quickTtsHistories,
        aliasName: $_aliasNameGenerator(
          db.voiceAssets.id,
          db.quickTtsHistories.voiceAssetId,
        ),
      );

  $$QuickTtsHistoriesTableProcessedTableManager get quickTtsHistoriesRefs {
    final manager = $$QuickTtsHistoriesTableTableManager(
      $_db,
      $_db.quickTtsHistories,
    ).filter((f) => f.voiceAssetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _quickTtsHistoriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VoiceAssetsTableFilterComposer
    extends Composer<_$AppDatabase, $VoiceAssetsTable> {
  $$VoiceAssetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelBindingId => $composableBuilder(
    column: $table.modelBindingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelName => $composableBuilder(
    column: $table.modelName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskMode => $composableBuilder(
    column: $table.taskMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refAudioPath => $composableBuilder(
    column: $table.refAudioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get refAudioTrimStart => $composableBuilder(
    column: $table.refAudioTrimStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get refAudioTrimEnd => $composableBuilder(
    column: $table.refAudioTrimEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get promptText => $composableBuilder(
    column: $table.promptText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get promptLang => $composableBuilder(
    column: $table.promptLang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voiceInstruction => $composableBuilder(
    column: $table.voiceInstruction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get presetVoiceName => $composableBuilder(
    column: $table.presetVoiceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderSlug => $composableBuilder(
    column: $table.folderSlug,
    builder: (column) => ColumnFilters(column),
  );

  $$TtsProvidersTableFilterComposer get providerId {
    final $$TtsProvidersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.ttsProviders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TtsProvidersTableFilterComposer(
            $db: $db,
            $table: $db.ttsProviders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> voiceBankMembersRefs(
    Expression<bool> Function($$VoiceBankMembersTableFilterComposer f) f,
  ) {
    final $$VoiceBankMembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.voiceBankMembers,
      getReferencedColumn: (t) => t.voiceAssetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceBankMembersTableFilterComposer(
            $db: $db,
            $table: $db.voiceBankMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> ttsJobsRefs(
    Expression<bool> Function($$TtsJobsTableFilterComposer f) f,
  ) {
    final $$TtsJobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ttsJobs,
      getReferencedColumn: (t) => t.voiceAssetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TtsJobsTableFilterComposer(
            $db: $db,
            $table: $db.ttsJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> quickTtsHistoriesRefs(
    Expression<bool> Function($$QuickTtsHistoriesTableFilterComposer f) f,
  ) {
    final $$QuickTtsHistoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.quickTtsHistories,
      getReferencedColumn: (t) => t.voiceAssetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuickTtsHistoriesTableFilterComposer(
            $db: $db,
            $table: $db.quickTtsHistories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VoiceAssetsTableOrderingComposer
    extends Composer<_$AppDatabase, $VoiceAssetsTable> {
  $$VoiceAssetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelBindingId => $composableBuilder(
    column: $table.modelBindingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelName => $composableBuilder(
    column: $table.modelName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskMode => $composableBuilder(
    column: $table.taskMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refAudioPath => $composableBuilder(
    column: $table.refAudioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get refAudioTrimStart => $composableBuilder(
    column: $table.refAudioTrimStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get refAudioTrimEnd => $composableBuilder(
    column: $table.refAudioTrimEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get promptText => $composableBuilder(
    column: $table.promptText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get promptLang => $composableBuilder(
    column: $table.promptLang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voiceInstruction => $composableBuilder(
    column: $table.voiceInstruction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get presetVoiceName => $composableBuilder(
    column: $table.presetVoiceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderSlug => $composableBuilder(
    column: $table.folderSlug,
    builder: (column) => ColumnOrderings(column),
  );

  $$TtsProvidersTableOrderingComposer get providerId {
    final $$TtsProvidersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.ttsProviders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TtsProvidersTableOrderingComposer(
            $db: $db,
            $table: $db.ttsProviders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VoiceAssetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VoiceAssetsTable> {
  $$VoiceAssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelBindingId => $composableBuilder(
    column: $table.modelBindingId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelName =>
      $composableBuilder(column: $table.modelName, builder: (column) => column);

  GeneratedColumn<String> get taskMode =>
      $composableBuilder(column: $table.taskMode, builder: (column) => column);

  GeneratedColumn<String> get refAudioPath => $composableBuilder(
    column: $table.refAudioPath,
    builder: (column) => column,
  );

  GeneratedColumn<double> get refAudioTrimStart => $composableBuilder(
    column: $table.refAudioTrimStart,
    builder: (column) => column,
  );

  GeneratedColumn<double> get refAudioTrimEnd => $composableBuilder(
    column: $table.refAudioTrimEnd,
    builder: (column) => column,
  );

  GeneratedColumn<String> get promptText => $composableBuilder(
    column: $table.promptText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get promptLang => $composableBuilder(
    column: $table.promptLang,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voiceInstruction => $composableBuilder(
    column: $table.voiceInstruction,
    builder: (column) => column,
  );

  GeneratedColumn<String> get presetVoiceName => $composableBuilder(
    column: $table.presetVoiceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => column,
  );

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get folderSlug => $composableBuilder(
    column: $table.folderSlug,
    builder: (column) => column,
  );

  $$TtsProvidersTableAnnotationComposer get providerId {
    final $$TtsProvidersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.ttsProviders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TtsProvidersTableAnnotationComposer(
            $db: $db,
            $table: $db.ttsProviders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> voiceBankMembersRefs<T extends Object>(
    Expression<T> Function($$VoiceBankMembersTableAnnotationComposer a) f,
  ) {
    final $$VoiceBankMembersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.voiceBankMembers,
      getReferencedColumn: (t) => t.voiceAssetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceBankMembersTableAnnotationComposer(
            $db: $db,
            $table: $db.voiceBankMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> ttsJobsRefs<T extends Object>(
    Expression<T> Function($$TtsJobsTableAnnotationComposer a) f,
  ) {
    final $$TtsJobsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ttsJobs,
      getReferencedColumn: (t) => t.voiceAssetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TtsJobsTableAnnotationComposer(
            $db: $db,
            $table: $db.ttsJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> quickTtsHistoriesRefs<T extends Object>(
    Expression<T> Function($$QuickTtsHistoriesTableAnnotationComposer a) f,
  ) {
    final $$QuickTtsHistoriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.quickTtsHistories,
          getReferencedColumn: (t) => t.voiceAssetId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$QuickTtsHistoriesTableAnnotationComposer(
                $db: $db,
                $table: $db.quickTtsHistories,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$VoiceAssetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VoiceAssetsTable,
          VoiceAsset,
          $$VoiceAssetsTableFilterComposer,
          $$VoiceAssetsTableOrderingComposer,
          $$VoiceAssetsTableAnnotationComposer,
          $$VoiceAssetsTableCreateCompanionBuilder,
          $$VoiceAssetsTableUpdateCompanionBuilder,
          (VoiceAsset, $$VoiceAssetsTableReferences),
          VoiceAsset,
          PrefetchHooks Function({
            bool providerId,
            bool voiceBankMembersRefs,
            bool ttsJobsRefs,
            bool quickTtsHistoriesRefs,
          })
        > {
  $$VoiceAssetsTableTableManager(_$AppDatabase db, $VoiceAssetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VoiceAssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VoiceAssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VoiceAssetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String?> modelBindingId = const Value.absent(),
                Value<String?> modelName = const Value.absent(),
                Value<String> taskMode = const Value.absent(),
                Value<String?> refAudioPath = const Value.absent(),
                Value<double?> refAudioTrimStart = const Value.absent(),
                Value<double?> refAudioTrimEnd = const Value.absent(),
                Value<String?> promptText = const Value.absent(),
                Value<String?> promptLang = const Value.absent(),
                Value<String?> voiceInstruction = const Value.absent(),
                Value<String?> presetVoiceName = const Value.absent(),
                Value<String?> avatarPath = const Value.absent(),
                Value<double> speed = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String?> folderSlug = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VoiceAssetsCompanion(
                id: id,
                name: name,
                description: description,
                providerId: providerId,
                modelBindingId: modelBindingId,
                modelName: modelName,
                taskMode: taskMode,
                refAudioPath: refAudioPath,
                refAudioTrimStart: refAudioTrimStart,
                refAudioTrimEnd: refAudioTrimEnd,
                promptText: promptText,
                promptLang: promptLang,
                voiceInstruction: voiceInstruction,
                presetVoiceName: presetVoiceName,
                avatarPath: avatarPath,
                speed: speed,
                enabled: enabled,
                folderSlug: folderSlug,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                required String providerId,
                Value<String?> modelBindingId = const Value.absent(),
                Value<String?> modelName = const Value.absent(),
                required String taskMode,
                Value<String?> refAudioPath = const Value.absent(),
                Value<double?> refAudioTrimStart = const Value.absent(),
                Value<double?> refAudioTrimEnd = const Value.absent(),
                Value<String?> promptText = const Value.absent(),
                Value<String?> promptLang = const Value.absent(),
                Value<String?> voiceInstruction = const Value.absent(),
                Value<String?> presetVoiceName = const Value.absent(),
                Value<String?> avatarPath = const Value.absent(),
                Value<double> speed = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String?> folderSlug = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VoiceAssetsCompanion.insert(
                id: id,
                name: name,
                description: description,
                providerId: providerId,
                modelBindingId: modelBindingId,
                modelName: modelName,
                taskMode: taskMode,
                refAudioPath: refAudioPath,
                refAudioTrimStart: refAudioTrimStart,
                refAudioTrimEnd: refAudioTrimEnd,
                promptText: promptText,
                promptLang: promptLang,
                voiceInstruction: voiceInstruction,
                presetVoiceName: presetVoiceName,
                avatarPath: avatarPath,
                speed: speed,
                enabled: enabled,
                folderSlug: folderSlug,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VoiceAssetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                providerId = false,
                voiceBankMembersRefs = false,
                ttsJobsRefs = false,
                quickTtsHistoriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (voiceBankMembersRefs) db.voiceBankMembers,
                    if (ttsJobsRefs) db.ttsJobs,
                    if (quickTtsHistoriesRefs) db.quickTtsHistories,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (providerId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.providerId,
                                    referencedTable:
                                        $$VoiceAssetsTableReferences
                                            ._providerIdTable(db),
                                    referencedColumn:
                                        $$VoiceAssetsTableReferences
                                            ._providerIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (voiceBankMembersRefs)
                        await $_getPrefetchedData<
                          VoiceAsset,
                          $VoiceAssetsTable,
                          VoiceBankMember
                        >(
                          currentTable: table,
                          referencedTable: $$VoiceAssetsTableReferences
                              ._voiceBankMembersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VoiceAssetsTableReferences(
                                db,
                                table,
                                p0,
                              ).voiceBankMembersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.voiceAssetId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (ttsJobsRefs)
                        await $_getPrefetchedData<
                          VoiceAsset,
                          $VoiceAssetsTable,
                          TtsJob
                        >(
                          currentTable: table,
                          referencedTable: $$VoiceAssetsTableReferences
                              ._ttsJobsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VoiceAssetsTableReferences(
                                db,
                                table,
                                p0,
                              ).ttsJobsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.voiceAssetId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (quickTtsHistoriesRefs)
                        await $_getPrefetchedData<
                          VoiceAsset,
                          $VoiceAssetsTable,
                          QuickTtsHistory
                        >(
                          currentTable: table,
                          referencedTable: $$VoiceAssetsTableReferences
                              ._quickTtsHistoriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VoiceAssetsTableReferences(
                                db,
                                table,
                                p0,
                              ).quickTtsHistoriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.voiceAssetId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$VoiceAssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VoiceAssetsTable,
      VoiceAsset,
      $$VoiceAssetsTableFilterComposer,
      $$VoiceAssetsTableOrderingComposer,
      $$VoiceAssetsTableAnnotationComposer,
      $$VoiceAssetsTableCreateCompanionBuilder,
      $$VoiceAssetsTableUpdateCompanionBuilder,
      (VoiceAsset, $$VoiceAssetsTableReferences),
      VoiceAsset,
      PrefetchHooks Function({
        bool providerId,
        bool voiceBankMembersRefs,
        bool ttsJobsRefs,
        bool quickTtsHistoriesRefs,
      })
    >;
typedef $$VoiceBanksTableCreateCompanionBuilder =
    VoiceBanksCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      Value<bool> isActive,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$VoiceBanksTableUpdateCompanionBuilder =
    VoiceBanksCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$VoiceBanksTableReferences
    extends BaseReferences<_$AppDatabase, $VoiceBanksTable, VoiceBank> {
  $$VoiceBanksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$VoiceBankMembersTable, List<VoiceBankMember>>
  _voiceBankMembersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.voiceBankMembers,
    aliasName: $_aliasNameGenerator(
      db.voiceBanks.id,
      db.voiceBankMembers.bankId,
    ),
  );

  $$VoiceBankMembersTableProcessedTableManager get voiceBankMembersRefs {
    final manager = $$VoiceBankMembersTableTableManager(
      $_db,
      $_db.voiceBankMembers,
    ).filter((f) => f.bankId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _voiceBankMembersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PhaseTtsProjectsTable, List<PhaseTtsProject>>
  _phaseTtsProjectsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.phaseTtsProjects,
    aliasName: $_aliasNameGenerator(
      db.voiceBanks.id,
      db.phaseTtsProjects.bankId,
    ),
  );

  $$PhaseTtsProjectsTableProcessedTableManager get phaseTtsProjectsRefs {
    final manager = $$PhaseTtsProjectsTableTableManager(
      $_db,
      $_db.phaseTtsProjects,
    ).filter((f) => f.bankId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _phaseTtsProjectsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DialogTtsProjectsTable, List<DialogTtsProject>>
  _dialogTtsProjectsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.dialogTtsProjects,
        aliasName: $_aliasNameGenerator(
          db.voiceBanks.id,
          db.dialogTtsProjects.bankId,
        ),
      );

  $$DialogTtsProjectsTableProcessedTableManager get dialogTtsProjectsRefs {
    final manager = $$DialogTtsProjectsTableTableManager(
      $_db,
      $_db.dialogTtsProjects,
    ).filter((f) => f.bankId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _dialogTtsProjectsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$VideoDubProjectsTable, List<VideoDubProject>>
  _videoDubProjectsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.videoDubProjects,
    aliasName: $_aliasNameGenerator(
      db.voiceBanks.id,
      db.videoDubProjects.bankId,
    ),
  );

  $$VideoDubProjectsTableProcessedTableManager get videoDubProjectsRefs {
    final manager = $$VideoDubProjectsTableTableManager(
      $_db,
      $_db.videoDubProjects,
    ).filter((f) => f.bankId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _videoDubProjectsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VoiceBanksTableFilterComposer
    extends Composer<_$AppDatabase, $VoiceBanksTable> {
  $$VoiceBanksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> voiceBankMembersRefs(
    Expression<bool> Function($$VoiceBankMembersTableFilterComposer f) f,
  ) {
    final $$VoiceBankMembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.voiceBankMembers,
      getReferencedColumn: (t) => t.bankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceBankMembersTableFilterComposer(
            $db: $db,
            $table: $db.voiceBankMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> phaseTtsProjectsRefs(
    Expression<bool> Function($$PhaseTtsProjectsTableFilterComposer f) f,
  ) {
    final $$PhaseTtsProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.phaseTtsProjects,
      getReferencedColumn: (t) => t.bankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhaseTtsProjectsTableFilterComposer(
            $db: $db,
            $table: $db.phaseTtsProjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dialogTtsProjectsRefs(
    Expression<bool> Function($$DialogTtsProjectsTableFilterComposer f) f,
  ) {
    final $$DialogTtsProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dialogTtsProjects,
      getReferencedColumn: (t) => t.bankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DialogTtsProjectsTableFilterComposer(
            $db: $db,
            $table: $db.dialogTtsProjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> videoDubProjectsRefs(
    Expression<bool> Function($$VideoDubProjectsTableFilterComposer f) f,
  ) {
    final $$VideoDubProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.videoDubProjects,
      getReferencedColumn: (t) => t.bankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VideoDubProjectsTableFilterComposer(
            $db: $db,
            $table: $db.videoDubProjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VoiceBanksTableOrderingComposer
    extends Composer<_$AppDatabase, $VoiceBanksTable> {
  $$VoiceBanksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VoiceBanksTableAnnotationComposer
    extends Composer<_$AppDatabase, $VoiceBanksTable> {
  $$VoiceBanksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> voiceBankMembersRefs<T extends Object>(
    Expression<T> Function($$VoiceBankMembersTableAnnotationComposer a) f,
  ) {
    final $$VoiceBankMembersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.voiceBankMembers,
      getReferencedColumn: (t) => t.bankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceBankMembersTableAnnotationComposer(
            $db: $db,
            $table: $db.voiceBankMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> phaseTtsProjectsRefs<T extends Object>(
    Expression<T> Function($$PhaseTtsProjectsTableAnnotationComposer a) f,
  ) {
    final $$PhaseTtsProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.phaseTtsProjects,
      getReferencedColumn: (t) => t.bankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhaseTtsProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.phaseTtsProjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dialogTtsProjectsRefs<T extends Object>(
    Expression<T> Function($$DialogTtsProjectsTableAnnotationComposer a) f,
  ) {
    final $$DialogTtsProjectsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.dialogTtsProjects,
          getReferencedColumn: (t) => t.bankId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DialogTtsProjectsTableAnnotationComposer(
                $db: $db,
                $table: $db.dialogTtsProjects,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> videoDubProjectsRefs<T extends Object>(
    Expression<T> Function($$VideoDubProjectsTableAnnotationComposer a) f,
  ) {
    final $$VideoDubProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.videoDubProjects,
      getReferencedColumn: (t) => t.bankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VideoDubProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.videoDubProjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VoiceBanksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VoiceBanksTable,
          VoiceBank,
          $$VoiceBanksTableFilterComposer,
          $$VoiceBanksTableOrderingComposer,
          $$VoiceBanksTableAnnotationComposer,
          $$VoiceBanksTableCreateCompanionBuilder,
          $$VoiceBanksTableUpdateCompanionBuilder,
          (VoiceBank, $$VoiceBanksTableReferences),
          VoiceBank,
          PrefetchHooks Function({
            bool voiceBankMembersRefs,
            bool phaseTtsProjectsRefs,
            bool dialogTtsProjectsRefs,
            bool videoDubProjectsRefs,
          })
        > {
  $$VoiceBanksTableTableManager(_$AppDatabase db, $VoiceBanksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VoiceBanksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VoiceBanksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VoiceBanksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VoiceBanksCompanion(
                id: id,
                name: name,
                description: description,
                isActive: isActive,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => VoiceBanksCompanion.insert(
                id: id,
                name: name,
                description: description,
                isActive: isActive,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VoiceBanksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                voiceBankMembersRefs = false,
                phaseTtsProjectsRefs = false,
                dialogTtsProjectsRefs = false,
                videoDubProjectsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (voiceBankMembersRefs) db.voiceBankMembers,
                    if (phaseTtsProjectsRefs) db.phaseTtsProjects,
                    if (dialogTtsProjectsRefs) db.dialogTtsProjects,
                    if (videoDubProjectsRefs) db.videoDubProjects,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (voiceBankMembersRefs)
                        await $_getPrefetchedData<
                          VoiceBank,
                          $VoiceBanksTable,
                          VoiceBankMember
                        >(
                          currentTable: table,
                          referencedTable: $$VoiceBanksTableReferences
                              ._voiceBankMembersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VoiceBanksTableReferences(
                                db,
                                table,
                                p0,
                              ).voiceBankMembersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bankId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (phaseTtsProjectsRefs)
                        await $_getPrefetchedData<
                          VoiceBank,
                          $VoiceBanksTable,
                          PhaseTtsProject
                        >(
                          currentTable: table,
                          referencedTable: $$VoiceBanksTableReferences
                              ._phaseTtsProjectsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VoiceBanksTableReferences(
                                db,
                                table,
                                p0,
                              ).phaseTtsProjectsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bankId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (dialogTtsProjectsRefs)
                        await $_getPrefetchedData<
                          VoiceBank,
                          $VoiceBanksTable,
                          DialogTtsProject
                        >(
                          currentTable: table,
                          referencedTable: $$VoiceBanksTableReferences
                              ._dialogTtsProjectsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VoiceBanksTableReferences(
                                db,
                                table,
                                p0,
                              ).dialogTtsProjectsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bankId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (videoDubProjectsRefs)
                        await $_getPrefetchedData<
                          VoiceBank,
                          $VoiceBanksTable,
                          VideoDubProject
                        >(
                          currentTable: table,
                          referencedTable: $$VoiceBanksTableReferences
                              ._videoDubProjectsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VoiceBanksTableReferences(
                                db,
                                table,
                                p0,
                              ).videoDubProjectsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bankId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$VoiceBanksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VoiceBanksTable,
      VoiceBank,
      $$VoiceBanksTableFilterComposer,
      $$VoiceBanksTableOrderingComposer,
      $$VoiceBanksTableAnnotationComposer,
      $$VoiceBanksTableCreateCompanionBuilder,
      $$VoiceBanksTableUpdateCompanionBuilder,
      (VoiceBank, $$VoiceBanksTableReferences),
      VoiceBank,
      PrefetchHooks Function({
        bool voiceBankMembersRefs,
        bool phaseTtsProjectsRefs,
        bool dialogTtsProjectsRefs,
        bool videoDubProjectsRefs,
      })
    >;
typedef $$VoiceBankMembersTableCreateCompanionBuilder =
    VoiceBankMembersCompanion Function({
      required String id,
      required String bankId,
      required String voiceAssetId,
      Value<int> rowid,
    });
typedef $$VoiceBankMembersTableUpdateCompanionBuilder =
    VoiceBankMembersCompanion Function({
      Value<String> id,
      Value<String> bankId,
      Value<String> voiceAssetId,
      Value<int> rowid,
    });

final class $$VoiceBankMembersTableReferences
    extends
        BaseReferences<_$AppDatabase, $VoiceBankMembersTable, VoiceBankMember> {
  $$VoiceBankMembersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $VoiceBanksTable _bankIdTable(_$AppDatabase db) =>
      db.voiceBanks.createAlias(
        $_aliasNameGenerator(db.voiceBankMembers.bankId, db.voiceBanks.id),
      );

  $$VoiceBanksTableProcessedTableManager get bankId {
    final $_column = $_itemColumn<String>('bank_id')!;

    final manager = $$VoiceBanksTableTableManager(
      $_db,
      $_db.voiceBanks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bankIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $VoiceAssetsTable _voiceAssetIdTable(_$AppDatabase db) =>
      db.voiceAssets.createAlias(
        $_aliasNameGenerator(
          db.voiceBankMembers.voiceAssetId,
          db.voiceAssets.id,
        ),
      );

  $$VoiceAssetsTableProcessedTableManager get voiceAssetId {
    final $_column = $_itemColumn<String>('voice_asset_id')!;

    final manager = $$VoiceAssetsTableTableManager(
      $_db,
      $_db.voiceAssets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_voiceAssetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$VoiceBankMembersTableFilterComposer
    extends Composer<_$AppDatabase, $VoiceBankMembersTable> {
  $$VoiceBankMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  $$VoiceBanksTableFilterComposer get bankId {
    final $$VoiceBanksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bankId,
      referencedTable: $db.voiceBanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceBanksTableFilterComposer(
            $db: $db,
            $table: $db.voiceBanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VoiceAssetsTableFilterComposer get voiceAssetId {
    final $$VoiceAssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.voiceAssetId,
      referencedTable: $db.voiceAssets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceAssetsTableFilterComposer(
            $db: $db,
            $table: $db.voiceAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VoiceBankMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $VoiceBankMembersTable> {
  $$VoiceBankMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  $$VoiceBanksTableOrderingComposer get bankId {
    final $$VoiceBanksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bankId,
      referencedTable: $db.voiceBanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceBanksTableOrderingComposer(
            $db: $db,
            $table: $db.voiceBanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VoiceAssetsTableOrderingComposer get voiceAssetId {
    final $$VoiceAssetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.voiceAssetId,
      referencedTable: $db.voiceAssets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceAssetsTableOrderingComposer(
            $db: $db,
            $table: $db.voiceAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VoiceBankMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $VoiceBankMembersTable> {
  $$VoiceBankMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  $$VoiceBanksTableAnnotationComposer get bankId {
    final $$VoiceBanksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bankId,
      referencedTable: $db.voiceBanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceBanksTableAnnotationComposer(
            $db: $db,
            $table: $db.voiceBanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VoiceAssetsTableAnnotationComposer get voiceAssetId {
    final $$VoiceAssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.voiceAssetId,
      referencedTable: $db.voiceAssets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceAssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.voiceAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VoiceBankMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VoiceBankMembersTable,
          VoiceBankMember,
          $$VoiceBankMembersTableFilterComposer,
          $$VoiceBankMembersTableOrderingComposer,
          $$VoiceBankMembersTableAnnotationComposer,
          $$VoiceBankMembersTableCreateCompanionBuilder,
          $$VoiceBankMembersTableUpdateCompanionBuilder,
          (VoiceBankMember, $$VoiceBankMembersTableReferences),
          VoiceBankMember,
          PrefetchHooks Function({bool bankId, bool voiceAssetId})
        > {
  $$VoiceBankMembersTableTableManager(
    _$AppDatabase db,
    $VoiceBankMembersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VoiceBankMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VoiceBankMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VoiceBankMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bankId = const Value.absent(),
                Value<String> voiceAssetId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VoiceBankMembersCompanion(
                id: id,
                bankId: bankId,
                voiceAssetId: voiceAssetId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bankId,
                required String voiceAssetId,
                Value<int> rowid = const Value.absent(),
              }) => VoiceBankMembersCompanion.insert(
                id: id,
                bankId: bankId,
                voiceAssetId: voiceAssetId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VoiceBankMembersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bankId = false, voiceAssetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bankId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bankId,
                                referencedTable:
                                    $$VoiceBankMembersTableReferences
                                        ._bankIdTable(db),
                                referencedColumn:
                                    $$VoiceBankMembersTableReferences
                                        ._bankIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (voiceAssetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.voiceAssetId,
                                referencedTable:
                                    $$VoiceBankMembersTableReferences
                                        ._voiceAssetIdTable(db),
                                referencedColumn:
                                    $$VoiceBankMembersTableReferences
                                        ._voiceAssetIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$VoiceBankMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VoiceBankMembersTable,
      VoiceBankMember,
      $$VoiceBankMembersTableFilterComposer,
      $$VoiceBankMembersTableOrderingComposer,
      $$VoiceBankMembersTableAnnotationComposer,
      $$VoiceBankMembersTableCreateCompanionBuilder,
      $$VoiceBankMembersTableUpdateCompanionBuilder,
      (VoiceBankMember, $$VoiceBankMembersTableReferences),
      VoiceBankMember,
      PrefetchHooks Function({bool bankId, bool voiceAssetId})
    >;
typedef $$TtsJobsTableCreateCompanionBuilder =
    TtsJobsCompanion Function({
      required String id,
      required String voiceAssetId,
      required String inputText,
      required String status,
      Value<String?> outputPath,
      Value<String?> errorMessage,
      required DateTime createdAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$TtsJobsTableUpdateCompanionBuilder =
    TtsJobsCompanion Function({
      Value<String> id,
      Value<String> voiceAssetId,
      Value<String> inputText,
      Value<String> status,
      Value<String?> outputPath,
      Value<String?> errorMessage,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

final class $$TtsJobsTableReferences
    extends BaseReferences<_$AppDatabase, $TtsJobsTable, TtsJob> {
  $$TtsJobsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $VoiceAssetsTable _voiceAssetIdTable(_$AppDatabase db) =>
      db.voiceAssets.createAlias(
        $_aliasNameGenerator(db.ttsJobs.voiceAssetId, db.voiceAssets.id),
      );

  $$VoiceAssetsTableProcessedTableManager get voiceAssetId {
    final $_column = $_itemColumn<String>('voice_asset_id')!;

    final manager = $$VoiceAssetsTableTableManager(
      $_db,
      $_db.voiceAssets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_voiceAssetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TtsJobsTableFilterComposer
    extends Composer<_$AppDatabase, $TtsJobsTable> {
  $$TtsJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputText => $composableBuilder(
    column: $table.inputText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$VoiceAssetsTableFilterComposer get voiceAssetId {
    final $$VoiceAssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.voiceAssetId,
      referencedTable: $db.voiceAssets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceAssetsTableFilterComposer(
            $db: $db,
            $table: $db.voiceAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TtsJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $TtsJobsTable> {
  $$TtsJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputText => $composableBuilder(
    column: $table.inputText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$VoiceAssetsTableOrderingComposer get voiceAssetId {
    final $$VoiceAssetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.voiceAssetId,
      referencedTable: $db.voiceAssets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceAssetsTableOrderingComposer(
            $db: $db,
            $table: $db.voiceAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TtsJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TtsJobsTable> {
  $$TtsJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get inputText =>
      $composableBuilder(column: $table.inputText, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  $$VoiceAssetsTableAnnotationComposer get voiceAssetId {
    final $$VoiceAssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.voiceAssetId,
      referencedTable: $db.voiceAssets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceAssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.voiceAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TtsJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TtsJobsTable,
          TtsJob,
          $$TtsJobsTableFilterComposer,
          $$TtsJobsTableOrderingComposer,
          $$TtsJobsTableAnnotationComposer,
          $$TtsJobsTableCreateCompanionBuilder,
          $$TtsJobsTableUpdateCompanionBuilder,
          (TtsJob, $$TtsJobsTableReferences),
          TtsJob,
          PrefetchHooks Function({bool voiceAssetId})
        > {
  $$TtsJobsTableTableManager(_$AppDatabase db, $TtsJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TtsJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TtsJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TtsJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> voiceAssetId = const Value.absent(),
                Value<String> inputText = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> outputPath = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TtsJobsCompanion(
                id: id,
                voiceAssetId: voiceAssetId,
                inputText: inputText,
                status: status,
                outputPath: outputPath,
                errorMessage: errorMessage,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String voiceAssetId,
                required String inputText,
                required String status,
                Value<String?> outputPath = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TtsJobsCompanion.insert(
                id: id,
                voiceAssetId: voiceAssetId,
                inputText: inputText,
                status: status,
                outputPath: outputPath,
                errorMessage: errorMessage,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TtsJobsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({voiceAssetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (voiceAssetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.voiceAssetId,
                                referencedTable: $$TtsJobsTableReferences
                                    ._voiceAssetIdTable(db),
                                referencedColumn: $$TtsJobsTableReferences
                                    ._voiceAssetIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TtsJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TtsJobsTable,
      TtsJob,
      $$TtsJobsTableFilterComposer,
      $$TtsJobsTableOrderingComposer,
      $$TtsJobsTableAnnotationComposer,
      $$TtsJobsTableCreateCompanionBuilder,
      $$TtsJobsTableUpdateCompanionBuilder,
      (TtsJob, $$TtsJobsTableReferences),
      TtsJob,
      PrefetchHooks Function({bool voiceAssetId})
    >;
typedef $$QuickTtsHistoriesTableCreateCompanionBuilder =
    QuickTtsHistoriesCompanion Function({
      required String id,
      required String voiceAssetId,
      required String voiceName,
      required String inputText,
      Value<String?> audioPath,
      Value<double?> audioDuration,
      Value<String?> error,
      required DateTime createdAt,
      Value<bool> missing,
      Value<int> rowid,
    });
typedef $$QuickTtsHistoriesTableUpdateCompanionBuilder =
    QuickTtsHistoriesCompanion Function({
      Value<String> id,
      Value<String> voiceAssetId,
      Value<String> voiceName,
      Value<String> inputText,
      Value<String?> audioPath,
      Value<double?> audioDuration,
      Value<String?> error,
      Value<DateTime> createdAt,
      Value<bool> missing,
      Value<int> rowid,
    });

final class $$QuickTtsHistoriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $QuickTtsHistoriesTable,
          QuickTtsHistory
        > {
  $$QuickTtsHistoriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $VoiceAssetsTable _voiceAssetIdTable(_$AppDatabase db) =>
      db.voiceAssets.createAlias(
        $_aliasNameGenerator(
          db.quickTtsHistories.voiceAssetId,
          db.voiceAssets.id,
        ),
      );

  $$VoiceAssetsTableProcessedTableManager get voiceAssetId {
    final $_column = $_itemColumn<String>('voice_asset_id')!;

    final manager = $$VoiceAssetsTableTableManager(
      $_db,
      $_db.voiceAssets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_voiceAssetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$QuickTtsHistoriesTableFilterComposer
    extends Composer<_$AppDatabase, $QuickTtsHistoriesTable> {
  $$QuickTtsHistoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voiceName => $composableBuilder(
    column: $table.voiceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputText => $composableBuilder(
    column: $table.inputText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get audioDuration => $composableBuilder(
    column: $table.audioDuration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get missing => $composableBuilder(
    column: $table.missing,
    builder: (column) => ColumnFilters(column),
  );

  $$VoiceAssetsTableFilterComposer get voiceAssetId {
    final $$VoiceAssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.voiceAssetId,
      referencedTable: $db.voiceAssets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceAssetsTableFilterComposer(
            $db: $db,
            $table: $db.voiceAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuickTtsHistoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $QuickTtsHistoriesTable> {
  $$QuickTtsHistoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voiceName => $composableBuilder(
    column: $table.voiceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputText => $composableBuilder(
    column: $table.inputText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get audioDuration => $composableBuilder(
    column: $table.audioDuration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get missing => $composableBuilder(
    column: $table.missing,
    builder: (column) => ColumnOrderings(column),
  );

  $$VoiceAssetsTableOrderingComposer get voiceAssetId {
    final $$VoiceAssetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.voiceAssetId,
      referencedTable: $db.voiceAssets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceAssetsTableOrderingComposer(
            $db: $db,
            $table: $db.voiceAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuickTtsHistoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuickTtsHistoriesTable> {
  $$QuickTtsHistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get voiceName =>
      $composableBuilder(column: $table.voiceName, builder: (column) => column);

  GeneratedColumn<String> get inputText =>
      $composableBuilder(column: $table.inputText, builder: (column) => column);

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<double> get audioDuration => $composableBuilder(
    column: $table.audioDuration,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get missing =>
      $composableBuilder(column: $table.missing, builder: (column) => column);

  $$VoiceAssetsTableAnnotationComposer get voiceAssetId {
    final $$VoiceAssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.voiceAssetId,
      referencedTable: $db.voiceAssets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceAssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.voiceAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuickTtsHistoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuickTtsHistoriesTable,
          QuickTtsHistory,
          $$QuickTtsHistoriesTableFilterComposer,
          $$QuickTtsHistoriesTableOrderingComposer,
          $$QuickTtsHistoriesTableAnnotationComposer,
          $$QuickTtsHistoriesTableCreateCompanionBuilder,
          $$QuickTtsHistoriesTableUpdateCompanionBuilder,
          (QuickTtsHistory, $$QuickTtsHistoriesTableReferences),
          QuickTtsHistory,
          PrefetchHooks Function({bool voiceAssetId})
        > {
  $$QuickTtsHistoriesTableTableManager(
    _$AppDatabase db,
    $QuickTtsHistoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuickTtsHistoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuickTtsHistoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuickTtsHistoriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> voiceAssetId = const Value.absent(),
                Value<String> voiceName = const Value.absent(),
                Value<String> inputText = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<double?> audioDuration = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> missing = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuickTtsHistoriesCompanion(
                id: id,
                voiceAssetId: voiceAssetId,
                voiceName: voiceName,
                inputText: inputText,
                audioPath: audioPath,
                audioDuration: audioDuration,
                error: error,
                createdAt: createdAt,
                missing: missing,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String voiceAssetId,
                required String voiceName,
                required String inputText,
                Value<String?> audioPath = const Value.absent(),
                Value<double?> audioDuration = const Value.absent(),
                Value<String?> error = const Value.absent(),
                required DateTime createdAt,
                Value<bool> missing = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuickTtsHistoriesCompanion.insert(
                id: id,
                voiceAssetId: voiceAssetId,
                voiceName: voiceName,
                inputText: inputText,
                audioPath: audioPath,
                audioDuration: audioDuration,
                error: error,
                createdAt: createdAt,
                missing: missing,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$QuickTtsHistoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({voiceAssetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (voiceAssetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.voiceAssetId,
                                referencedTable:
                                    $$QuickTtsHistoriesTableReferences
                                        ._voiceAssetIdTable(db),
                                referencedColumn:
                                    $$QuickTtsHistoriesTableReferences
                                        ._voiceAssetIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$QuickTtsHistoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuickTtsHistoriesTable,
      QuickTtsHistory,
      $$QuickTtsHistoriesTableFilterComposer,
      $$QuickTtsHistoriesTableOrderingComposer,
      $$QuickTtsHistoriesTableAnnotationComposer,
      $$QuickTtsHistoriesTableCreateCompanionBuilder,
      $$QuickTtsHistoriesTableUpdateCompanionBuilder,
      (QuickTtsHistory, $$QuickTtsHistoriesTableReferences),
      QuickTtsHistory,
      PrefetchHooks Function({bool voiceAssetId})
    >;
typedef $$PhaseTtsProjectsTableCreateCompanionBuilder =
    PhaseTtsProjectsCompanion Function({
      required String id,
      required String name,
      required String bankId,
      Value<String> scriptText,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<String?> folderSlug,
      Value<int> rowid,
    });
typedef $$PhaseTtsProjectsTableUpdateCompanionBuilder =
    PhaseTtsProjectsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> bankId,
      Value<String> scriptText,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> folderSlug,
      Value<int> rowid,
    });

final class $$PhaseTtsProjectsTableReferences
    extends
        BaseReferences<_$AppDatabase, $PhaseTtsProjectsTable, PhaseTtsProject> {
  $$PhaseTtsProjectsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $VoiceBanksTable _bankIdTable(_$AppDatabase db) =>
      db.voiceBanks.createAlias(
        $_aliasNameGenerator(db.phaseTtsProjects.bankId, db.voiceBanks.id),
      );

  $$VoiceBanksTableProcessedTableManager get bankId {
    final $_column = $_itemColumn<String>('bank_id')!;

    final manager = $$VoiceBanksTableTableManager(
      $_db,
      $_db.voiceBanks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bankIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PhaseTtsSegmentsTable, List<PhaseTtsSegment>>
  _phaseTtsSegmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.phaseTtsSegments,
    aliasName: $_aliasNameGenerator(
      db.phaseTtsProjects.id,
      db.phaseTtsSegments.projectId,
    ),
  );

  $$PhaseTtsSegmentsTableProcessedTableManager get phaseTtsSegmentsRefs {
    final manager = $$PhaseTtsSegmentsTableTableManager(
      $_db,
      $_db.phaseTtsSegments,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _phaseTtsSegmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PhaseTtsProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $PhaseTtsProjectsTable> {
  $$PhaseTtsProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scriptText => $composableBuilder(
    column: $table.scriptText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderSlug => $composableBuilder(
    column: $table.folderSlug,
    builder: (column) => ColumnFilters(column),
  );

  $$VoiceBanksTableFilterComposer get bankId {
    final $$VoiceBanksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bankId,
      referencedTable: $db.voiceBanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceBanksTableFilterComposer(
            $db: $db,
            $table: $db.voiceBanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> phaseTtsSegmentsRefs(
    Expression<bool> Function($$PhaseTtsSegmentsTableFilterComposer f) f,
  ) {
    final $$PhaseTtsSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.phaseTtsSegments,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhaseTtsSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.phaseTtsSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PhaseTtsProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $PhaseTtsProjectsTable> {
  $$PhaseTtsProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scriptText => $composableBuilder(
    column: $table.scriptText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderSlug => $composableBuilder(
    column: $table.folderSlug,
    builder: (column) => ColumnOrderings(column),
  );

  $$VoiceBanksTableOrderingComposer get bankId {
    final $$VoiceBanksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bankId,
      referencedTable: $db.voiceBanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceBanksTableOrderingComposer(
            $db: $db,
            $table: $db.voiceBanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhaseTtsProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhaseTtsProjectsTable> {
  $$PhaseTtsProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get scriptText => $composableBuilder(
    column: $table.scriptText,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get folderSlug => $composableBuilder(
    column: $table.folderSlug,
    builder: (column) => column,
  );

  $$VoiceBanksTableAnnotationComposer get bankId {
    final $$VoiceBanksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bankId,
      referencedTable: $db.voiceBanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceBanksTableAnnotationComposer(
            $db: $db,
            $table: $db.voiceBanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> phaseTtsSegmentsRefs<T extends Object>(
    Expression<T> Function($$PhaseTtsSegmentsTableAnnotationComposer a) f,
  ) {
    final $$PhaseTtsSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.phaseTtsSegments,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhaseTtsSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.phaseTtsSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PhaseTtsProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhaseTtsProjectsTable,
          PhaseTtsProject,
          $$PhaseTtsProjectsTableFilterComposer,
          $$PhaseTtsProjectsTableOrderingComposer,
          $$PhaseTtsProjectsTableAnnotationComposer,
          $$PhaseTtsProjectsTableCreateCompanionBuilder,
          $$PhaseTtsProjectsTableUpdateCompanionBuilder,
          (PhaseTtsProject, $$PhaseTtsProjectsTableReferences),
          PhaseTtsProject,
          PrefetchHooks Function({bool bankId, bool phaseTtsSegmentsRefs})
        > {
  $$PhaseTtsProjectsTableTableManager(
    _$AppDatabase db,
    $PhaseTtsProjectsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhaseTtsProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhaseTtsProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhaseTtsProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> bankId = const Value.absent(),
                Value<String> scriptText = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> folderSlug = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhaseTtsProjectsCompanion(
                id: id,
                name: name,
                bankId: bankId,
                scriptText: scriptText,
                createdAt: createdAt,
                updatedAt: updatedAt,
                folderSlug: folderSlug,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String bankId,
                Value<String> scriptText = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String?> folderSlug = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhaseTtsProjectsCompanion.insert(
                id: id,
                name: name,
                bankId: bankId,
                scriptText: scriptText,
                createdAt: createdAt,
                updatedAt: updatedAt,
                folderSlug: folderSlug,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PhaseTtsProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({bankId = false, phaseTtsSegmentsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (phaseTtsSegmentsRefs) db.phaseTtsSegments,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (bankId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.bankId,
                                    referencedTable:
                                        $$PhaseTtsProjectsTableReferences
                                            ._bankIdTable(db),
                                    referencedColumn:
                                        $$PhaseTtsProjectsTableReferences
                                            ._bankIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (phaseTtsSegmentsRefs)
                        await $_getPrefetchedData<
                          PhaseTtsProject,
                          $PhaseTtsProjectsTable,
                          PhaseTtsSegment
                        >(
                          currentTable: table,
                          referencedTable: $$PhaseTtsProjectsTableReferences
                              ._phaseTtsSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PhaseTtsProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).phaseTtsSegmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PhaseTtsProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhaseTtsProjectsTable,
      PhaseTtsProject,
      $$PhaseTtsProjectsTableFilterComposer,
      $$PhaseTtsProjectsTableOrderingComposer,
      $$PhaseTtsProjectsTableAnnotationComposer,
      $$PhaseTtsProjectsTableCreateCompanionBuilder,
      $$PhaseTtsProjectsTableUpdateCompanionBuilder,
      (PhaseTtsProject, $$PhaseTtsProjectsTableReferences),
      PhaseTtsProject,
      PrefetchHooks Function({bool bankId, bool phaseTtsSegmentsRefs})
    >;
typedef $$PhaseTtsSegmentsTableCreateCompanionBuilder =
    PhaseTtsSegmentsCompanion Function({
      required String id,
      required String projectId,
      required int orderIndex,
      required String segmentText,
      Value<String?> voiceAssetId,
      Value<String?> audioPath,
      Value<double?> audioDuration,
      Value<String?> error,
      Value<bool> missing,
      Value<int> rowid,
    });
typedef $$PhaseTtsSegmentsTableUpdateCompanionBuilder =
    PhaseTtsSegmentsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<int> orderIndex,
      Value<String> segmentText,
      Value<String?> voiceAssetId,
      Value<String?> audioPath,
      Value<double?> audioDuration,
      Value<String?> error,
      Value<bool> missing,
      Value<int> rowid,
    });

final class $$PhaseTtsSegmentsTableReferences
    extends
        BaseReferences<_$AppDatabase, $PhaseTtsSegmentsTable, PhaseTtsSegment> {
  $$PhaseTtsSegmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PhaseTtsProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.phaseTtsProjects.createAlias(
        $_aliasNameGenerator(
          db.phaseTtsSegments.projectId,
          db.phaseTtsProjects.id,
        ),
      );

  $$PhaseTtsProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$PhaseTtsProjectsTableTableManager(
      $_db,
      $_db.phaseTtsProjects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PhaseTtsSegmentsTableFilterComposer
    extends Composer<_$AppDatabase, $PhaseTtsSegmentsTable> {
  $$PhaseTtsSegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get segmentText => $composableBuilder(
    column: $table.segmentText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voiceAssetId => $composableBuilder(
    column: $table.voiceAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get audioDuration => $composableBuilder(
    column: $table.audioDuration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get missing => $composableBuilder(
    column: $table.missing,
    builder: (column) => ColumnFilters(column),
  );

  $$PhaseTtsProjectsTableFilterComposer get projectId {
    final $$PhaseTtsProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.phaseTtsProjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhaseTtsProjectsTableFilterComposer(
            $db: $db,
            $table: $db.phaseTtsProjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhaseTtsSegmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $PhaseTtsSegmentsTable> {
  $$PhaseTtsSegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get segmentText => $composableBuilder(
    column: $table.segmentText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voiceAssetId => $composableBuilder(
    column: $table.voiceAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get audioDuration => $composableBuilder(
    column: $table.audioDuration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get missing => $composableBuilder(
    column: $table.missing,
    builder: (column) => ColumnOrderings(column),
  );

  $$PhaseTtsProjectsTableOrderingComposer get projectId {
    final $$PhaseTtsProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.phaseTtsProjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhaseTtsProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.phaseTtsProjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhaseTtsSegmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhaseTtsSegmentsTable> {
  $$PhaseTtsSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get segmentText => $composableBuilder(
    column: $table.segmentText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voiceAssetId => $composableBuilder(
    column: $table.voiceAssetId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<double> get audioDuration => $composableBuilder(
    column: $table.audioDuration,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<bool> get missing =>
      $composableBuilder(column: $table.missing, builder: (column) => column);

  $$PhaseTtsProjectsTableAnnotationComposer get projectId {
    final $$PhaseTtsProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.phaseTtsProjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhaseTtsProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.phaseTtsProjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhaseTtsSegmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhaseTtsSegmentsTable,
          PhaseTtsSegment,
          $$PhaseTtsSegmentsTableFilterComposer,
          $$PhaseTtsSegmentsTableOrderingComposer,
          $$PhaseTtsSegmentsTableAnnotationComposer,
          $$PhaseTtsSegmentsTableCreateCompanionBuilder,
          $$PhaseTtsSegmentsTableUpdateCompanionBuilder,
          (PhaseTtsSegment, $$PhaseTtsSegmentsTableReferences),
          PhaseTtsSegment,
          PrefetchHooks Function({bool projectId})
        > {
  $$PhaseTtsSegmentsTableTableManager(
    _$AppDatabase db,
    $PhaseTtsSegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhaseTtsSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhaseTtsSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhaseTtsSegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String> segmentText = const Value.absent(),
                Value<String?> voiceAssetId = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<double?> audioDuration = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<bool> missing = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhaseTtsSegmentsCompanion(
                id: id,
                projectId: projectId,
                orderIndex: orderIndex,
                segmentText: segmentText,
                voiceAssetId: voiceAssetId,
                audioPath: audioPath,
                audioDuration: audioDuration,
                error: error,
                missing: missing,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required int orderIndex,
                required String segmentText,
                Value<String?> voiceAssetId = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<double?> audioDuration = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<bool> missing = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhaseTtsSegmentsCompanion.insert(
                id: id,
                projectId: projectId,
                orderIndex: orderIndex,
                segmentText: segmentText,
                voiceAssetId: voiceAssetId,
                audioPath: audioPath,
                audioDuration: audioDuration,
                error: error,
                missing: missing,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PhaseTtsSegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable:
                                    $$PhaseTtsSegmentsTableReferences
                                        ._projectIdTable(db),
                                referencedColumn:
                                    $$PhaseTtsSegmentsTableReferences
                                        ._projectIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PhaseTtsSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhaseTtsSegmentsTable,
      PhaseTtsSegment,
      $$PhaseTtsSegmentsTableFilterComposer,
      $$PhaseTtsSegmentsTableOrderingComposer,
      $$PhaseTtsSegmentsTableAnnotationComposer,
      $$PhaseTtsSegmentsTableCreateCompanionBuilder,
      $$PhaseTtsSegmentsTableUpdateCompanionBuilder,
      (PhaseTtsSegment, $$PhaseTtsSegmentsTableReferences),
      PhaseTtsSegment,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$DialogTtsProjectsTableCreateCompanionBuilder =
    DialogTtsProjectsCompanion Function({
      required String id,
      required String name,
      required String bankId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<String?> folderSlug,
      Value<int> rowid,
    });
typedef $$DialogTtsProjectsTableUpdateCompanionBuilder =
    DialogTtsProjectsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> bankId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> folderSlug,
      Value<int> rowid,
    });

final class $$DialogTtsProjectsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DialogTtsProjectsTable,
          DialogTtsProject
        > {
  $$DialogTtsProjectsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $VoiceBanksTable _bankIdTable(_$AppDatabase db) =>
      db.voiceBanks.createAlias(
        $_aliasNameGenerator(db.dialogTtsProjects.bankId, db.voiceBanks.id),
      );

  $$VoiceBanksTableProcessedTableManager get bankId {
    final $_column = $_itemColumn<String>('bank_id')!;

    final manager = $$VoiceBanksTableTableManager(
      $_db,
      $_db.voiceBanks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bankIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$DialogTtsLinesTable, List<DialogTtsLine>>
  _dialogTtsLinesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dialogTtsLines,
    aliasName: $_aliasNameGenerator(
      db.dialogTtsProjects.id,
      db.dialogTtsLines.projectId,
    ),
  );

  $$DialogTtsLinesTableProcessedTableManager get dialogTtsLinesRefs {
    final manager = $$DialogTtsLinesTableTableManager(
      $_db,
      $_db.dialogTtsLines,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_dialogTtsLinesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DialogTtsProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $DialogTtsProjectsTable> {
  $$DialogTtsProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderSlug => $composableBuilder(
    column: $table.folderSlug,
    builder: (column) => ColumnFilters(column),
  );

  $$VoiceBanksTableFilterComposer get bankId {
    final $$VoiceBanksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bankId,
      referencedTable: $db.voiceBanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceBanksTableFilterComposer(
            $db: $db,
            $table: $db.voiceBanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> dialogTtsLinesRefs(
    Expression<bool> Function($$DialogTtsLinesTableFilterComposer f) f,
  ) {
    final $$DialogTtsLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dialogTtsLines,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DialogTtsLinesTableFilterComposer(
            $db: $db,
            $table: $db.dialogTtsLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DialogTtsProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $DialogTtsProjectsTable> {
  $$DialogTtsProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderSlug => $composableBuilder(
    column: $table.folderSlug,
    builder: (column) => ColumnOrderings(column),
  );

  $$VoiceBanksTableOrderingComposer get bankId {
    final $$VoiceBanksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bankId,
      referencedTable: $db.voiceBanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceBanksTableOrderingComposer(
            $db: $db,
            $table: $db.voiceBanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DialogTtsProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DialogTtsProjectsTable> {
  $$DialogTtsProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get folderSlug => $composableBuilder(
    column: $table.folderSlug,
    builder: (column) => column,
  );

  $$VoiceBanksTableAnnotationComposer get bankId {
    final $$VoiceBanksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bankId,
      referencedTable: $db.voiceBanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceBanksTableAnnotationComposer(
            $db: $db,
            $table: $db.voiceBanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> dialogTtsLinesRefs<T extends Object>(
    Expression<T> Function($$DialogTtsLinesTableAnnotationComposer a) f,
  ) {
    final $$DialogTtsLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dialogTtsLines,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DialogTtsLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.dialogTtsLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DialogTtsProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DialogTtsProjectsTable,
          DialogTtsProject,
          $$DialogTtsProjectsTableFilterComposer,
          $$DialogTtsProjectsTableOrderingComposer,
          $$DialogTtsProjectsTableAnnotationComposer,
          $$DialogTtsProjectsTableCreateCompanionBuilder,
          $$DialogTtsProjectsTableUpdateCompanionBuilder,
          (DialogTtsProject, $$DialogTtsProjectsTableReferences),
          DialogTtsProject,
          PrefetchHooks Function({bool bankId, bool dialogTtsLinesRefs})
        > {
  $$DialogTtsProjectsTableTableManager(
    _$AppDatabase db,
    $DialogTtsProjectsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DialogTtsProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DialogTtsProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DialogTtsProjectsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> bankId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> folderSlug = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DialogTtsProjectsCompanion(
                id: id,
                name: name,
                bankId: bankId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                folderSlug: folderSlug,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String bankId,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String?> folderSlug = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DialogTtsProjectsCompanion.insert(
                id: id,
                name: name,
                bankId: bankId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                folderSlug: folderSlug,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DialogTtsProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({bankId = false, dialogTtsLinesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (dialogTtsLinesRefs) db.dialogTtsLines,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (bankId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.bankId,
                                    referencedTable:
                                        $$DialogTtsProjectsTableReferences
                                            ._bankIdTable(db),
                                    referencedColumn:
                                        $$DialogTtsProjectsTableReferences
                                            ._bankIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (dialogTtsLinesRefs)
                        await $_getPrefetchedData<
                          DialogTtsProject,
                          $DialogTtsProjectsTable,
                          DialogTtsLine
                        >(
                          currentTable: table,
                          referencedTable: $$DialogTtsProjectsTableReferences
                              ._dialogTtsLinesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DialogTtsProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).dialogTtsLinesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DialogTtsProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DialogTtsProjectsTable,
      DialogTtsProject,
      $$DialogTtsProjectsTableFilterComposer,
      $$DialogTtsProjectsTableOrderingComposer,
      $$DialogTtsProjectsTableAnnotationComposer,
      $$DialogTtsProjectsTableCreateCompanionBuilder,
      $$DialogTtsProjectsTableUpdateCompanionBuilder,
      (DialogTtsProject, $$DialogTtsProjectsTableReferences),
      DialogTtsProject,
      PrefetchHooks Function({bool bankId, bool dialogTtsLinesRefs})
    >;
typedef $$DialogTtsLinesTableCreateCompanionBuilder =
    DialogTtsLinesCompanion Function({
      required String id,
      required String projectId,
      required int orderIndex,
      required String lineText,
      Value<String?> voiceAssetId,
      Value<String?> audioPath,
      Value<double?> audioDuration,
      Value<String?> error,
      Value<bool> missing,
      Value<int> rowid,
    });
typedef $$DialogTtsLinesTableUpdateCompanionBuilder =
    DialogTtsLinesCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<int> orderIndex,
      Value<String> lineText,
      Value<String?> voiceAssetId,
      Value<String?> audioPath,
      Value<double?> audioDuration,
      Value<String?> error,
      Value<bool> missing,
      Value<int> rowid,
    });

final class $$DialogTtsLinesTableReferences
    extends BaseReferences<_$AppDatabase, $DialogTtsLinesTable, DialogTtsLine> {
  $$DialogTtsLinesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DialogTtsProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.dialogTtsProjects.createAlias(
        $_aliasNameGenerator(
          db.dialogTtsLines.projectId,
          db.dialogTtsProjects.id,
        ),
      );

  $$DialogTtsProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$DialogTtsProjectsTableTableManager(
      $_db,
      $_db.dialogTtsProjects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DialogTtsLinesTableFilterComposer
    extends Composer<_$AppDatabase, $DialogTtsLinesTable> {
  $$DialogTtsLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lineText => $composableBuilder(
    column: $table.lineText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voiceAssetId => $composableBuilder(
    column: $table.voiceAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get audioDuration => $composableBuilder(
    column: $table.audioDuration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get missing => $composableBuilder(
    column: $table.missing,
    builder: (column) => ColumnFilters(column),
  );

  $$DialogTtsProjectsTableFilterComposer get projectId {
    final $$DialogTtsProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.dialogTtsProjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DialogTtsProjectsTableFilterComposer(
            $db: $db,
            $table: $db.dialogTtsProjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DialogTtsLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $DialogTtsLinesTable> {
  $$DialogTtsLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lineText => $composableBuilder(
    column: $table.lineText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voiceAssetId => $composableBuilder(
    column: $table.voiceAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get audioDuration => $composableBuilder(
    column: $table.audioDuration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get missing => $composableBuilder(
    column: $table.missing,
    builder: (column) => ColumnOrderings(column),
  );

  $$DialogTtsProjectsTableOrderingComposer get projectId {
    final $$DialogTtsProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.dialogTtsProjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DialogTtsProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.dialogTtsProjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DialogTtsLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DialogTtsLinesTable> {
  $$DialogTtsLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lineText =>
      $composableBuilder(column: $table.lineText, builder: (column) => column);

  GeneratedColumn<String> get voiceAssetId => $composableBuilder(
    column: $table.voiceAssetId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<double> get audioDuration => $composableBuilder(
    column: $table.audioDuration,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<bool> get missing =>
      $composableBuilder(column: $table.missing, builder: (column) => column);

  $$DialogTtsProjectsTableAnnotationComposer get projectId {
    final $$DialogTtsProjectsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.projectId,
          referencedTable: $db.dialogTtsProjects,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DialogTtsProjectsTableAnnotationComposer(
                $db: $db,
                $table: $db.dialogTtsProjects,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$DialogTtsLinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DialogTtsLinesTable,
          DialogTtsLine,
          $$DialogTtsLinesTableFilterComposer,
          $$DialogTtsLinesTableOrderingComposer,
          $$DialogTtsLinesTableAnnotationComposer,
          $$DialogTtsLinesTableCreateCompanionBuilder,
          $$DialogTtsLinesTableUpdateCompanionBuilder,
          (DialogTtsLine, $$DialogTtsLinesTableReferences),
          DialogTtsLine,
          PrefetchHooks Function({bool projectId})
        > {
  $$DialogTtsLinesTableTableManager(
    _$AppDatabase db,
    $DialogTtsLinesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DialogTtsLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DialogTtsLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DialogTtsLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String> lineText = const Value.absent(),
                Value<String?> voiceAssetId = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<double?> audioDuration = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<bool> missing = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DialogTtsLinesCompanion(
                id: id,
                projectId: projectId,
                orderIndex: orderIndex,
                lineText: lineText,
                voiceAssetId: voiceAssetId,
                audioPath: audioPath,
                audioDuration: audioDuration,
                error: error,
                missing: missing,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required int orderIndex,
                required String lineText,
                Value<String?> voiceAssetId = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<double?> audioDuration = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<bool> missing = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DialogTtsLinesCompanion.insert(
                id: id,
                projectId: projectId,
                orderIndex: orderIndex,
                lineText: lineText,
                voiceAssetId: voiceAssetId,
                audioPath: audioPath,
                audioDuration: audioDuration,
                error: error,
                missing: missing,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DialogTtsLinesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable: $$DialogTtsLinesTableReferences
                                    ._projectIdTable(db),
                                referencedColumn:
                                    $$DialogTtsLinesTableReferences
                                        ._projectIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DialogTtsLinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DialogTtsLinesTable,
      DialogTtsLine,
      $$DialogTtsLinesTableFilterComposer,
      $$DialogTtsLinesTableOrderingComposer,
      $$DialogTtsLinesTableAnnotationComposer,
      $$DialogTtsLinesTableCreateCompanionBuilder,
      $$DialogTtsLinesTableUpdateCompanionBuilder,
      (DialogTtsLine, $$DialogTtsLinesTableReferences),
      DialogTtsLine,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$VideoDubProjectsTableCreateCompanionBuilder =
    VideoDubProjectsCompanion Function({
      required String id,
      required String name,
      required String bankId,
      Value<String?> videoPath,
      Value<double?> videoDurationSec,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<String?> folderSlug,
      Value<int> rowid,
    });
typedef $$VideoDubProjectsTableUpdateCompanionBuilder =
    VideoDubProjectsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> bankId,
      Value<String?> videoPath,
      Value<double?> videoDurationSec,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> folderSlug,
      Value<int> rowid,
    });

final class $$VideoDubProjectsTableReferences
    extends
        BaseReferences<_$AppDatabase, $VideoDubProjectsTable, VideoDubProject> {
  $$VideoDubProjectsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $VoiceBanksTable _bankIdTable(_$AppDatabase db) =>
      db.voiceBanks.createAlias(
        $_aliasNameGenerator(db.videoDubProjects.bankId, db.voiceBanks.id),
      );

  $$VoiceBanksTableProcessedTableManager get bankId {
    final $_column = $_itemColumn<String>('bank_id')!;

    final manager = $$VoiceBanksTableTableManager(
      $_db,
      $_db.voiceBanks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bankIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SubtitleCuesTable, List<SubtitleCue>>
  _subtitleCuesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.subtitleCues,
    aliasName: $_aliasNameGenerator(
      db.videoDubProjects.id,
      db.subtitleCues.projectId,
    ),
  );

  $$SubtitleCuesTableProcessedTableManager get subtitleCuesRefs {
    final manager = $$SubtitleCuesTableTableManager(
      $_db,
      $_db.subtitleCues,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_subtitleCuesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VideoDubProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $VideoDubProjectsTable> {
  $$VideoDubProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoPath => $composableBuilder(
    column: $table.videoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get videoDurationSec => $composableBuilder(
    column: $table.videoDurationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderSlug => $composableBuilder(
    column: $table.folderSlug,
    builder: (column) => ColumnFilters(column),
  );

  $$VoiceBanksTableFilterComposer get bankId {
    final $$VoiceBanksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bankId,
      referencedTable: $db.voiceBanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceBanksTableFilterComposer(
            $db: $db,
            $table: $db.voiceBanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> subtitleCuesRefs(
    Expression<bool> Function($$SubtitleCuesTableFilterComposer f) f,
  ) {
    final $$SubtitleCuesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subtitleCues,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubtitleCuesTableFilterComposer(
            $db: $db,
            $table: $db.subtitleCues,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VideoDubProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $VideoDubProjectsTable> {
  $$VideoDubProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoPath => $composableBuilder(
    column: $table.videoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get videoDurationSec => $composableBuilder(
    column: $table.videoDurationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderSlug => $composableBuilder(
    column: $table.folderSlug,
    builder: (column) => ColumnOrderings(column),
  );

  $$VoiceBanksTableOrderingComposer get bankId {
    final $$VoiceBanksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bankId,
      referencedTable: $db.voiceBanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceBanksTableOrderingComposer(
            $db: $db,
            $table: $db.voiceBanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VideoDubProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VideoDubProjectsTable> {
  $$VideoDubProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get videoPath =>
      $composableBuilder(column: $table.videoPath, builder: (column) => column);

  GeneratedColumn<double> get videoDurationSec => $composableBuilder(
    column: $table.videoDurationSec,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get folderSlug => $composableBuilder(
    column: $table.folderSlug,
    builder: (column) => column,
  );

  $$VoiceBanksTableAnnotationComposer get bankId {
    final $$VoiceBanksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bankId,
      referencedTable: $db.voiceBanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceBanksTableAnnotationComposer(
            $db: $db,
            $table: $db.voiceBanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> subtitleCuesRefs<T extends Object>(
    Expression<T> Function($$SubtitleCuesTableAnnotationComposer a) f,
  ) {
    final $$SubtitleCuesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subtitleCues,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubtitleCuesTableAnnotationComposer(
            $db: $db,
            $table: $db.subtitleCues,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VideoDubProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VideoDubProjectsTable,
          VideoDubProject,
          $$VideoDubProjectsTableFilterComposer,
          $$VideoDubProjectsTableOrderingComposer,
          $$VideoDubProjectsTableAnnotationComposer,
          $$VideoDubProjectsTableCreateCompanionBuilder,
          $$VideoDubProjectsTableUpdateCompanionBuilder,
          (VideoDubProject, $$VideoDubProjectsTableReferences),
          VideoDubProject,
          PrefetchHooks Function({bool bankId, bool subtitleCuesRefs})
        > {
  $$VideoDubProjectsTableTableManager(
    _$AppDatabase db,
    $VideoDubProjectsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VideoDubProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VideoDubProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VideoDubProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> bankId = const Value.absent(),
                Value<String?> videoPath = const Value.absent(),
                Value<double?> videoDurationSec = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> folderSlug = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VideoDubProjectsCompanion(
                id: id,
                name: name,
                bankId: bankId,
                videoPath: videoPath,
                videoDurationSec: videoDurationSec,
                createdAt: createdAt,
                updatedAt: updatedAt,
                folderSlug: folderSlug,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String bankId,
                Value<String?> videoPath = const Value.absent(),
                Value<double?> videoDurationSec = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String?> folderSlug = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VideoDubProjectsCompanion.insert(
                id: id,
                name: name,
                bankId: bankId,
                videoPath: videoPath,
                videoDurationSec: videoDurationSec,
                createdAt: createdAt,
                updatedAt: updatedAt,
                folderSlug: folderSlug,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VideoDubProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bankId = false, subtitleCuesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (subtitleCuesRefs) db.subtitleCues],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bankId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bankId,
                                referencedTable:
                                    $$VideoDubProjectsTableReferences
                                        ._bankIdTable(db),
                                referencedColumn:
                                    $$VideoDubProjectsTableReferences
                                        ._bankIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (subtitleCuesRefs)
                    await $_getPrefetchedData<
                      VideoDubProject,
                      $VideoDubProjectsTable,
                      SubtitleCue
                    >(
                      currentTable: table,
                      referencedTable: $$VideoDubProjectsTableReferences
                          ._subtitleCuesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$VideoDubProjectsTableReferences(
                            db,
                            table,
                            p0,
                          ).subtitleCuesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.projectId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$VideoDubProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VideoDubProjectsTable,
      VideoDubProject,
      $$VideoDubProjectsTableFilterComposer,
      $$VideoDubProjectsTableOrderingComposer,
      $$VideoDubProjectsTableAnnotationComposer,
      $$VideoDubProjectsTableCreateCompanionBuilder,
      $$VideoDubProjectsTableUpdateCompanionBuilder,
      (VideoDubProject, $$VideoDubProjectsTableReferences),
      VideoDubProject,
      PrefetchHooks Function({bool bankId, bool subtitleCuesRefs})
    >;
typedef $$SubtitleCuesTableCreateCompanionBuilder =
    SubtitleCuesCompanion Function({
      required String id,
      required String projectId,
      required int orderIndex,
      required int startMs,
      required int endMs,
      required String cueText,
      Value<String?> voiceAssetId,
      Value<String?> audioPath,
      Value<double?> audioDuration,
      Value<String?> error,
      Value<bool> missing,
      Value<int> rowid,
    });
typedef $$SubtitleCuesTableUpdateCompanionBuilder =
    SubtitleCuesCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<int> orderIndex,
      Value<int> startMs,
      Value<int> endMs,
      Value<String> cueText,
      Value<String?> voiceAssetId,
      Value<String?> audioPath,
      Value<double?> audioDuration,
      Value<String?> error,
      Value<bool> missing,
      Value<int> rowid,
    });

final class $$SubtitleCuesTableReferences
    extends BaseReferences<_$AppDatabase, $SubtitleCuesTable, SubtitleCue> {
  $$SubtitleCuesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $VideoDubProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.videoDubProjects.createAlias(
        $_aliasNameGenerator(db.subtitleCues.projectId, db.videoDubProjects.id),
      );

  $$VideoDubProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$VideoDubProjectsTableTableManager(
      $_db,
      $_db.videoDubProjects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SubtitleCuesTableFilterComposer
    extends Composer<_$AppDatabase, $SubtitleCuesTable> {
  $$SubtitleCuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cueText => $composableBuilder(
    column: $table.cueText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voiceAssetId => $composableBuilder(
    column: $table.voiceAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get audioDuration => $composableBuilder(
    column: $table.audioDuration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get missing => $composableBuilder(
    column: $table.missing,
    builder: (column) => ColumnFilters(column),
  );

  $$VideoDubProjectsTableFilterComposer get projectId {
    final $$VideoDubProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.videoDubProjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VideoDubProjectsTableFilterComposer(
            $db: $db,
            $table: $db.videoDubProjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubtitleCuesTableOrderingComposer
    extends Composer<_$AppDatabase, $SubtitleCuesTable> {
  $$SubtitleCuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cueText => $composableBuilder(
    column: $table.cueText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voiceAssetId => $composableBuilder(
    column: $table.voiceAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get audioDuration => $composableBuilder(
    column: $table.audioDuration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get missing => $composableBuilder(
    column: $table.missing,
    builder: (column) => ColumnOrderings(column),
  );

  $$VideoDubProjectsTableOrderingComposer get projectId {
    final $$VideoDubProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.videoDubProjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VideoDubProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.videoDubProjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubtitleCuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubtitleCuesTable> {
  $$SubtitleCuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumn<String> get cueText =>
      $composableBuilder(column: $table.cueText, builder: (column) => column);

  GeneratedColumn<String> get voiceAssetId => $composableBuilder(
    column: $table.voiceAssetId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<double> get audioDuration => $composableBuilder(
    column: $table.audioDuration,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<bool> get missing =>
      $composableBuilder(column: $table.missing, builder: (column) => column);

  $$VideoDubProjectsTableAnnotationComposer get projectId {
    final $$VideoDubProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.videoDubProjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VideoDubProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.videoDubProjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubtitleCuesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubtitleCuesTable,
          SubtitleCue,
          $$SubtitleCuesTableFilterComposer,
          $$SubtitleCuesTableOrderingComposer,
          $$SubtitleCuesTableAnnotationComposer,
          $$SubtitleCuesTableCreateCompanionBuilder,
          $$SubtitleCuesTableUpdateCompanionBuilder,
          (SubtitleCue, $$SubtitleCuesTableReferences),
          SubtitleCue,
          PrefetchHooks Function({bool projectId})
        > {
  $$SubtitleCuesTableTableManager(_$AppDatabase db, $SubtitleCuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubtitleCuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubtitleCuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubtitleCuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<int> startMs = const Value.absent(),
                Value<int> endMs = const Value.absent(),
                Value<String> cueText = const Value.absent(),
                Value<String?> voiceAssetId = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<double?> audioDuration = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<bool> missing = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubtitleCuesCompanion(
                id: id,
                projectId: projectId,
                orderIndex: orderIndex,
                startMs: startMs,
                endMs: endMs,
                cueText: cueText,
                voiceAssetId: voiceAssetId,
                audioPath: audioPath,
                audioDuration: audioDuration,
                error: error,
                missing: missing,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required int orderIndex,
                required int startMs,
                required int endMs,
                required String cueText,
                Value<String?> voiceAssetId = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<double?> audioDuration = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<bool> missing = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubtitleCuesCompanion.insert(
                id: id,
                projectId: projectId,
                orderIndex: orderIndex,
                startMs: startMs,
                endMs: endMs,
                cueText: cueText,
                voiceAssetId: voiceAssetId,
                audioPath: audioPath,
                audioDuration: audioDuration,
                error: error,
                missing: missing,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SubtitleCuesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable: $$SubtitleCuesTableReferences
                                    ._projectIdTable(db),
                                referencedColumn: $$SubtitleCuesTableReferences
                                    ._projectIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SubtitleCuesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubtitleCuesTable,
      SubtitleCue,
      $$SubtitleCuesTableFilterComposer,
      $$SubtitleCuesTableOrderingComposer,
      $$SubtitleCuesTableAnnotationComposer,
      $$SubtitleCuesTableCreateCompanionBuilder,
      $$SubtitleCuesTableUpdateCompanionBuilder,
      (SubtitleCue, $$SubtitleCuesTableReferences),
      SubtitleCue,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$AudioTracksTableCreateCompanionBuilder =
    AudioTracksCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      required String audioPath,
      Value<String?> avatarPath,
      Value<String?> refText,
      Value<String?> refLang,
      Value<double?> durationSec,
      Value<String> sourceType,
      required DateTime createdAt,
      Value<bool> missing,
      Value<int> rowid,
    });
typedef $$AudioTracksTableUpdateCompanionBuilder =
    AudioTracksCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<String> audioPath,
      Value<String?> avatarPath,
      Value<String?> refText,
      Value<String?> refLang,
      Value<double?> durationSec,
      Value<String> sourceType,
      Value<DateTime> createdAt,
      Value<bool> missing,
      Value<int> rowid,
    });

class $$AudioTracksTableFilterComposer
    extends Composer<_$AppDatabase, $AudioTracksTable> {
  $$AudioTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refText => $composableBuilder(
    column: $table.refText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refLang => $composableBuilder(
    column: $table.refLang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get missing => $composableBuilder(
    column: $table.missing,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AudioTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $AudioTracksTable> {
  $$AudioTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refText => $composableBuilder(
    column: $table.refText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refLang => $composableBuilder(
    column: $table.refLang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get missing => $composableBuilder(
    column: $table.missing,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AudioTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $AudioTracksTable> {
  $$AudioTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get refText =>
      $composableBuilder(column: $table.refText, builder: (column) => column);

  GeneratedColumn<String> get refLang =>
      $composableBuilder(column: $table.refLang, builder: (column) => column);

  GeneratedColumn<double> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get missing =>
      $composableBuilder(column: $table.missing, builder: (column) => column);
}

class $$AudioTracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AudioTracksTable,
          AudioTrack,
          $$AudioTracksTableFilterComposer,
          $$AudioTracksTableOrderingComposer,
          $$AudioTracksTableAnnotationComposer,
          $$AudioTracksTableCreateCompanionBuilder,
          $$AudioTracksTableUpdateCompanionBuilder,
          (
            AudioTrack,
            BaseReferences<_$AppDatabase, $AudioTracksTable, AudioTrack>,
          ),
          AudioTrack,
          PrefetchHooks Function()
        > {
  $$AudioTracksTableTableManager(_$AppDatabase db, $AudioTracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudioTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudioTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AudioTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> audioPath = const Value.absent(),
                Value<String?> avatarPath = const Value.absent(),
                Value<String?> refText = const Value.absent(),
                Value<String?> refLang = const Value.absent(),
                Value<double?> durationSec = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> missing = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioTracksCompanion(
                id: id,
                name: name,
                description: description,
                audioPath: audioPath,
                avatarPath: avatarPath,
                refText: refText,
                refLang: refLang,
                durationSec: durationSec,
                sourceType: sourceType,
                createdAt: createdAt,
                missing: missing,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                required String audioPath,
                Value<String?> avatarPath = const Value.absent(),
                Value<String?> refText = const Value.absent(),
                Value<String?> refLang = const Value.absent(),
                Value<double?> durationSec = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                required DateTime createdAt,
                Value<bool> missing = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioTracksCompanion.insert(
                id: id,
                name: name,
                description: description,
                audioPath: audioPath,
                avatarPath: avatarPath,
                refText: refText,
                refLang: refLang,
                durationSec: durationSec,
                sourceType: sourceType,
                createdAt: createdAt,
                missing: missing,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AudioTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AudioTracksTable,
      AudioTrack,
      $$AudioTracksTableFilterComposer,
      $$AudioTracksTableOrderingComposer,
      $$AudioTracksTableAnnotationComposer,
      $$AudioTracksTableCreateCompanionBuilder,
      $$AudioTracksTableUpdateCompanionBuilder,
      (
        AudioTrack,
        BaseReferences<_$AppDatabase, $AudioTracksTable, AudioTrack>,
      ),
      AudioTrack,
      PrefetchHooks Function()
    >;
typedef $$TimelineClipsTableCreateCompanionBuilder =
    TimelineClipsCompanion Function({
      required String id,
      required String projectId,
      required String projectType,
      Value<int> laneIndex,
      Value<int> startTimeMs,
      Value<double?> durationSec,
      required String audioPath,
      Value<String> sourceType,
      Value<String?> sourceLineId,
      Value<String> label,
      Value<bool> missing,
      Value<String?> linkGroupId,
      Value<int> rowid,
    });
typedef $$TimelineClipsTableUpdateCompanionBuilder =
    TimelineClipsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> projectType,
      Value<int> laneIndex,
      Value<int> startTimeMs,
      Value<double?> durationSec,
      Value<String> audioPath,
      Value<String> sourceType,
      Value<String?> sourceLineId,
      Value<String> label,
      Value<bool> missing,
      Value<String?> linkGroupId,
      Value<int> rowid,
    });

class $$TimelineClipsTableFilterComposer
    extends Composer<_$AppDatabase, $TimelineClipsTable> {
  $$TimelineClipsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectType => $composableBuilder(
    column: $table.projectType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get laneIndex => $composableBuilder(
    column: $table.laneIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startTimeMs => $composableBuilder(
    column: $table.startTimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceLineId => $composableBuilder(
    column: $table.sourceLineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get missing => $composableBuilder(
    column: $table.missing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkGroupId => $composableBuilder(
    column: $table.linkGroupId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TimelineClipsTableOrderingComposer
    extends Composer<_$AppDatabase, $TimelineClipsTable> {
  $$TimelineClipsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectType => $composableBuilder(
    column: $table.projectType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get laneIndex => $composableBuilder(
    column: $table.laneIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startTimeMs => $composableBuilder(
    column: $table.startTimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceLineId => $composableBuilder(
    column: $table.sourceLineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get missing => $composableBuilder(
    column: $table.missing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkGroupId => $composableBuilder(
    column: $table.linkGroupId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TimelineClipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TimelineClipsTable> {
  $$TimelineClipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get projectType => $composableBuilder(
    column: $table.projectType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get laneIndex =>
      $composableBuilder(column: $table.laneIndex, builder: (column) => column);

  GeneratedColumn<int> get startTimeMs => $composableBuilder(
    column: $table.startTimeMs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceLineId => $composableBuilder(
    column: $table.sourceLineId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<bool> get missing =>
      $composableBuilder(column: $table.missing, builder: (column) => column);

  GeneratedColumn<String> get linkGroupId => $composableBuilder(
    column: $table.linkGroupId,
    builder: (column) => column,
  );
}

class $$TimelineClipsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TimelineClipsTable,
          TimelineClip,
          $$TimelineClipsTableFilterComposer,
          $$TimelineClipsTableOrderingComposer,
          $$TimelineClipsTableAnnotationComposer,
          $$TimelineClipsTableCreateCompanionBuilder,
          $$TimelineClipsTableUpdateCompanionBuilder,
          (
            TimelineClip,
            BaseReferences<_$AppDatabase, $TimelineClipsTable, TimelineClip>,
          ),
          TimelineClip,
          PrefetchHooks Function()
        > {
  $$TimelineClipsTableTableManager(_$AppDatabase db, $TimelineClipsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TimelineClipsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TimelineClipsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TimelineClipsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> projectType = const Value.absent(),
                Value<int> laneIndex = const Value.absent(),
                Value<int> startTimeMs = const Value.absent(),
                Value<double?> durationSec = const Value.absent(),
                Value<String> audioPath = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String?> sourceLineId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<bool> missing = const Value.absent(),
                Value<String?> linkGroupId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimelineClipsCompanion(
                id: id,
                projectId: projectId,
                projectType: projectType,
                laneIndex: laneIndex,
                startTimeMs: startTimeMs,
                durationSec: durationSec,
                audioPath: audioPath,
                sourceType: sourceType,
                sourceLineId: sourceLineId,
                label: label,
                missing: missing,
                linkGroupId: linkGroupId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String projectType,
                Value<int> laneIndex = const Value.absent(),
                Value<int> startTimeMs = const Value.absent(),
                Value<double?> durationSec = const Value.absent(),
                required String audioPath,
                Value<String> sourceType = const Value.absent(),
                Value<String?> sourceLineId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<bool> missing = const Value.absent(),
                Value<String?> linkGroupId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimelineClipsCompanion.insert(
                id: id,
                projectId: projectId,
                projectType: projectType,
                laneIndex: laneIndex,
                startTimeMs: startTimeMs,
                durationSec: durationSec,
                audioPath: audioPath,
                sourceType: sourceType,
                sourceLineId: sourceLineId,
                label: label,
                missing: missing,
                linkGroupId: linkGroupId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TimelineClipsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TimelineClipsTable,
      TimelineClip,
      $$TimelineClipsTableFilterComposer,
      $$TimelineClipsTableOrderingComposer,
      $$TimelineClipsTableAnnotationComposer,
      $$TimelineClipsTableCreateCompanionBuilder,
      $$TimelineClipsTableUpdateCompanionBuilder,
      (
        TimelineClip,
        BaseReferences<_$AppDatabase, $TimelineClipsTable, TimelineClip>,
      ),
      TimelineClip,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$TtsProvidersTableTableManager get ttsProviders =>
      $$TtsProvidersTableTableManager(_db, _db.ttsProviders);
  $$ModelBindingsTableTableManager get modelBindings =>
      $$ModelBindingsTableTableManager(_db, _db.modelBindings);
  $$VoiceAssetsTableTableManager get voiceAssets =>
      $$VoiceAssetsTableTableManager(_db, _db.voiceAssets);
  $$VoiceBanksTableTableManager get voiceBanks =>
      $$VoiceBanksTableTableManager(_db, _db.voiceBanks);
  $$VoiceBankMembersTableTableManager get voiceBankMembers =>
      $$VoiceBankMembersTableTableManager(_db, _db.voiceBankMembers);
  $$TtsJobsTableTableManager get ttsJobs =>
      $$TtsJobsTableTableManager(_db, _db.ttsJobs);
  $$QuickTtsHistoriesTableTableManager get quickTtsHistories =>
      $$QuickTtsHistoriesTableTableManager(_db, _db.quickTtsHistories);
  $$PhaseTtsProjectsTableTableManager get phaseTtsProjects =>
      $$PhaseTtsProjectsTableTableManager(_db, _db.phaseTtsProjects);
  $$PhaseTtsSegmentsTableTableManager get phaseTtsSegments =>
      $$PhaseTtsSegmentsTableTableManager(_db, _db.phaseTtsSegments);
  $$DialogTtsProjectsTableTableManager get dialogTtsProjects =>
      $$DialogTtsProjectsTableTableManager(_db, _db.dialogTtsProjects);
  $$DialogTtsLinesTableTableManager get dialogTtsLines =>
      $$DialogTtsLinesTableTableManager(_db, _db.dialogTtsLines);
  $$VideoDubProjectsTableTableManager get videoDubProjects =>
      $$VideoDubProjectsTableTableManager(_db, _db.videoDubProjects);
  $$SubtitleCuesTableTableManager get subtitleCues =>
      $$SubtitleCuesTableTableManager(_db, _db.subtitleCues);
  $$AudioTracksTableTableManager get audioTracks =>
      $$AudioTracksTableTableManager(_db, _db.audioTracks);
  $$TimelineClipsTableTableManager get timelineClips =>
      $$TimelineClipsTableTableManager(_db, _db.timelineClips);
}
