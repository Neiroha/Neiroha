import 'package:drift/drift.dart';
import 'tables.dart';

/// Work-level identities; changing a name never changes synthesis parameters.
class NovelCharacters extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(NovelProjects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get aliasesJson => text().withDefault(const Constant('[]'))();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get color => integer().withDefault(const Constant(0xFF7E9CD8))();
  @override
  Set<Column> get primaryKey => {id};
}

class NovelAnnotations extends Table {
  TextColumn get segmentId =>
      text().references(NovelSegments, #id, onDelete: KeyAction.cascade)();
  TextColumn get projectId =>
      text().references(NovelProjects, #id, onDelete: KeyAction.cascade)();
  TextColumn get textRevision => text()();
  TextColumn get characterId => text().nullable().references(
    NovelCharacters,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get kind => text().withDefault(const Constant('narrator'))();
  TextColumn get voiceAssetId => text().nullable()();
  TextColumn get instruction => text().nullable()();
  BoolColumn get locked => boolean().withDefault(const Constant(false))();
  TextColumn get reviewState => text().withDefault(const Constant('pending'))();
  TextColumn get reason => text().withDefault(const Constant(''))();
  TextColumn get changeId => text()();
  @override
  Set<Column> get primaryKey => {segmentId};
}

/// Empty chapterId means the work-level binding; a chapter can override it.
class NovelVoiceBindings extends Table {
  TextColumn get characterId =>
      text().references(NovelCharacters, #id, onDelete: KeyAction.cascade)();
  TextColumn get chapterId => text().withDefault(const Constant(''))();
  TextColumn get voiceAssetId =>
      text().references(VoiceAssets, #id, onDelete: KeyAction.cascade)();
  TextColumn get instruction => text().nullable()();
  @override
  Set<Column> get primaryKey => {characterId, chapterId};
}

class NovelRoleEdits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get projectId =>
      text().references(NovelProjects, #id, onDelete: KeyAction.cascade)();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
}
