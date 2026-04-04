import 'package:drift/drift.dart';

class TtsProviders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get adapterType => text()(); // AdapterType enum name
  TextColumn get baseUrl => text()();
  TextColumn get apiKey => text().withDefault(const Constant(''))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class ModelBindings extends Table {
  TextColumn get id => text()();
  TextColumn get providerId => text().references(TtsProviders, #id)();
  TextColumn get modelKey => text()();
  // Stored as comma-separated TaskMode enum names
  TextColumn get supportedTaskModes => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

class VoiceAssets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get providerId => text().references(TtsProviders, #id)();
  TextColumn get modelBindingId => text().references(ModelBindings, #id)();
  TextColumn get taskMode => text()(); // TaskMode enum name
  TextColumn get refAudioPath => text().nullable()();
  TextColumn get promptText => text().nullable()();
  TextColumn get promptLang => text().nullable()();
  TextColumn get voiceInstruction => text().nullable()();
  TextColumn get presetVoiceName => text().nullable()();
  RealColumn get speed => real().withDefault(const Constant(1.0))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class TtsJobs extends Table {
  TextColumn get id => text()();
  TextColumn get voiceAssetId => text().references(VoiceAssets, #id)();
  TextColumn get inputText => text()();
  TextColumn get status => text()(); // JobStatus enum name
  TextColumn get outputPath => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
