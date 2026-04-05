// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
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
    defaultValue: const Constant(true),
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
  const TtsProvider({
    required this.id,
    required this.name,
    required this.adapterType,
    required this.baseUrl,
    required this.apiKey,
    required this.defaultModelName,
    required this.enabled,
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
  }) => TtsProvider(
    id: id ?? this.id,
    name: name ?? this.name,
    adapterType: adapterType ?? this.adapterType,
    baseUrl: baseUrl ?? this.baseUrl,
    apiKey: apiKey ?? this.apiKey,
    defaultModelName: defaultModelName ?? this.defaultModelName,
    enabled: enabled ?? this.enabled,
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
          ..write('enabled: $enabled')
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
          other.enabled == this.enabled);
}

class TtsProvidersCompanion extends UpdateCompanion<TtsProvider> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> adapterType;
  final Value<String> baseUrl;
  final Value<String> apiKey;
  final Value<String> defaultModelName;
  final Value<bool> enabled;
  final Value<int> rowid;
  const TtsProvidersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.adapterType = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.apiKey = const Value.absent(),
    this.defaultModelName = const Value.absent(),
    this.enabled = const Value.absent(),
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
    speed,
    enabled,
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
      speed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
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
  final double speed;
  final bool enabled;
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
    required this.speed,
    required this.enabled,
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
    map['speed'] = Variable<double>(speed);
    map['enabled'] = Variable<bool>(enabled);
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
      speed: Value(speed),
      enabled: Value(enabled),
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
      speed: serializer.fromJson<double>(json['speed']),
      enabled: serializer.fromJson<bool>(json['enabled']),
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
      'speed': serializer.toJson<double>(speed),
      'enabled': serializer.toJson<bool>(enabled),
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
    double? speed,
    bool? enabled,
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
    speed: speed ?? this.speed,
    enabled: enabled ?? this.enabled,
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
      speed: data.speed.present ? data.speed.value : this.speed,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
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
          ..write('speed: $speed, ')
          ..write('enabled: $enabled')
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
    speed,
    enabled,
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
          other.speed == this.speed &&
          other.enabled == this.enabled);
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
  final Value<double> speed;
  final Value<bool> enabled;
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
    this.speed = const Value.absent(),
    this.enabled = const Value.absent(),
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
    this.speed = const Value.absent(),
    this.enabled = const Value.absent(),
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
    Expression<double>? speed,
    Expression<bool>? enabled,
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
      if (speed != null) 'speed': speed,
      if (enabled != null) 'enabled': enabled,
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
    Value<double>? speed,
    Value<bool>? enabled,
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
      speed: speed ?? this.speed,
      enabled: enabled ?? this.enabled,
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
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
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
          ..write('speed: $speed, ')
          ..write('enabled: $enabled, ')
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TtsProvidersTable ttsProviders = $TtsProvidersTable(this);
  late final $ModelBindingsTable modelBindings = $ModelBindingsTable(this);
  late final $VoiceAssetsTable voiceAssets = $VoiceAssetsTable(this);
  late final $TtsJobsTable ttsJobs = $TtsJobsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    ttsProviders,
    modelBindings,
    voiceAssets,
    ttsJobs,
  ];
}

typedef $$TtsProvidersTableCreateCompanionBuilder =
    TtsProvidersCompanion Function({
      required String id,
      required String name,
      required String adapterType,
      required String baseUrl,
      Value<String> apiKey,
      Value<String> defaultModelName,
      Value<bool> enabled,
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
                Value<int> rowid = const Value.absent(),
              }) => TtsProvidersCompanion(
                id: id,
                name: name,
                adapterType: adapterType,
                baseUrl: baseUrl,
                apiKey: apiKey,
                defaultModelName: defaultModelName,
                enabled: enabled,
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
                Value<int> rowid = const Value.absent(),
              }) => TtsProvidersCompanion.insert(
                id: id,
                name: name,
                adapterType: adapterType,
                baseUrl: baseUrl,
                apiKey: apiKey,
                defaultModelName: defaultModelName,
                enabled: enabled,
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
      Value<double> speed,
      Value<bool> enabled,
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
      Value<double> speed,
      Value<bool> enabled,
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

  ColumnFilters<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
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

  ColumnOrderings<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
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

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

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
          PrefetchHooks Function({bool providerId, bool ttsJobsRefs})
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
                Value<double> speed = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
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
                speed: speed,
                enabled: enabled,
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
                Value<double> speed = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
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
                speed: speed,
                enabled: enabled,
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
          prefetchHooksCallback: ({providerId = false, ttsJobsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (ttsJobsRefs) db.ttsJobs],
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
                                referencedTable: $$VoiceAssetsTableReferences
                                    ._providerIdTable(db),
                                referencedColumn: $$VoiceAssetsTableReferences
                                    ._providerIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
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
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
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
      PrefetchHooks Function({bool providerId, bool ttsJobsRefs})
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TtsProvidersTableTableManager get ttsProviders =>
      $$TtsProvidersTableTableManager(_db, _db.ttsProviders);
  $$ModelBindingsTableTableManager get modelBindings =>
      $$ModelBindingsTableTableManager(_db, _db.modelBindings);
  $$VoiceAssetsTableTableManager get voiceAssets =>
      $$VoiceAssetsTableTableManager(_db, _db.voiceAssets);
  $$TtsJobsTableTableManager get ttsJobs =>
      $$TtsJobsTableTableManager(_db, _db.ttsJobs);
}
