import 'package:drift/drift.dart';

import 'tables.dart';

/// Per-character settings that used to live in `AppSettings` JSON: the
/// processing chain (`voice.chain.*`) and live dialog (`dialog.live.*`).
class VoiceAssetSettings extends Table {
  TextColumn get voiceAssetId =>
      text().references(VoiceAssets, #id, onDelete: KeyAction.cascade)();
  TextColumn get chainJson => text().nullable()();
  TextColumn get liveJson => text().nullable()();
  @override
  Set<Column> get primaryKey => {voiceAssetId};
}

/// A connection's settings for one capability. No row: the capability is on
/// and takes the connection's own limits. Limits are per capability, so the
/// LLM calls of a connection do not use up its TTS slots.
class ConnectionCapabilities extends Table {
  TextColumn get connectionId =>
      text().references(TtsProviders, #id, onDelete: KeyAction.cascade)();
  TextColumn get capability => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get maxConcurrency => integer().nullable()();
  IntColumn get requestsPerMinute => integer().nullable()();
  IntColumn get requestsPerDay => integer().nullable()();
  IntColumn get tokensPerMinute => integer().nullable()();
  IntColumn get tokensPerDay => integer().nullable()();

  /// Base URL for this capability when it differs from the connection's.
  TextColumn get serviceOverride => text().nullable()();
  @override
  Set<Column> get primaryKey => {connectionId, capability};
}

/// Models added to a connection beyond its plugin's catalog (one row per
/// model × capability).
class ProviderModels extends Table {
  TextColumn get id => text()();
  TextColumn get connectionId =>
      text().references(TtsProviders, #id, onDelete: KeyAction.cascade)();
  TextColumn get modelId => text()();
  TextColumn get capability => text()();
  TextColumn get route => text().nullable()();
  TextColumn get displayName => text().nullable()();
  TextColumn get featuresJson => text().withDefault(const Constant('[]'))();
  TextColumn get lifecycle => text().nullable()();
  DateTimeColumn get shutdownAt => dateTime().nullable()();

  /// `manual` (added by the user) or `discovered` (listed by the server).
  TextColumn get source => text().withDefault(const Constant('manual'))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {connectionId, modelId, capability},
  ];
}

/// The model a capability uses when a feature does not pick one. Empty
/// [purpose] is the capability-wide default; a purpose (`subtitle`,
/// `role_analysis`…) can override it.
class CapabilityDefaults extends Table {
  TextColumn get capability => text()();
  TextColumn get purpose => text().withDefault(const Constant(''))();
  TextColumn get connectionId =>
      text().references(TtsProviders, #id, onDelete: KeyAction.cascade)();
  TextColumn get modelId => text()();
  @override
  Set<Column> get primaryKey => {capability, purpose};
}
