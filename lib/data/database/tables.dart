import 'package:drift/drift.dart';

class TtsProviders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get adapterType => text()(); // AdapterType enum name
  TextColumn get baseUrl => text()();
  TextColumn get apiKey => text().withDefault(const Constant(''))();
  TextColumn get defaultModelName =>
      text().withDefault(const Constant('tts-1'))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class ModelBindings extends Table {
  TextColumn get id => text()();
  TextColumn get providerId => text().references(TtsProviders, #id)();
  TextColumn get modelKey => text()();
  TextColumn get supportedTaskModes =>
      text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

class VoiceAssets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get description => text().nullable()();
  TextColumn get providerId => text().references(TtsProviders, #id)();
  // Nullable: characters can be created without a formal model binding
  TextColumn get modelBindingId => text().nullable()();
  TextColumn get modelName => text().nullable()(); // Direct model name override
  TextColumn get taskMode => text()(); // TaskMode enum name
  TextColumn get refAudioPath => text().nullable()();
  RealColumn get refAudioTrimStart => real().nullable()();
  RealColumn get refAudioTrimEnd => real().nullable()();
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
