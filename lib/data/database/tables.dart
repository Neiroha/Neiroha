import 'package:drift/drift.dart';

// ─────────────── App Settings (key/value store) ───────────────
//
// Holds app-wide preferences that are not tied to a particular domain entity.
// Known keys:
//   'voiceAssetRoot' → absolute path chosen by the user for the audio library.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class TtsProviders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get adapterType => text()(); // AdapterType enum name
  TextColumn get baseUrl => text()();
  TextColumn get apiKey => text().withDefault(const Constant(''))();
  TextColumn get defaultModelName =>
      text().withDefault(const Constant('tts-1'))();
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  IntColumn get maxConcurrency => integer().withDefault(const Constant(1))();
  IntColumn get requestsPerMinute => integer().nullable()();
  IntColumn get requestsPerDay => integer().nullable()();
  IntColumn get tokensPerMinute => integer().nullable()();
  IntColumn get tokensPerDay => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────── Audio Tracks (single audio samples) ───────────────
//
// A library of individual audio clips that the user collects from any source
// (TTS output, microphone recording, file upload). These can be referenced by
// voice cloning models that need a reference audio sample.
class AudioTracks extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get description => text().nullable()();
  TextColumn get audioPath => text()();
  TextColumn get avatarPath => text().nullable()();
  TextColumn get refText => text().nullable()();
  TextColumn get refLang => text().nullable()();
  RealColumn get durationSec => real().nullable()();
  TextColumn get sourceType => text().withDefault(const Constant('upload'))();
  // upload | record | quickTts | phaseTts | dialogTts
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get missing => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class ModelBindings extends Table {
  TextColumn get id => text()();
  TextColumn get providerId => text().references(TtsProviders, #id)();
  TextColumn get modelKey => text()();
  TextColumn get supportedTaskModes => text().withDefault(const Constant(''))();

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
  TextColumn get avatarPath => text().nullable()();
  RealColumn get speed => real().withDefault(const Constant(1.0))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  // Pinned folder name used under voice_asset/quick_tts/. Set once at first
  // generation so renaming the display name doesn't rehome the folder.
  TextColumn get folderSlug => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class VoiceBanks extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class VoiceBankMembers extends Table {
  TextColumn get id => text()();
  TextColumn get bankId => text().references(VoiceBanks, #id)();
  TextColumn get voiceAssetId => text().references(VoiceAssets, #id)();

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

// ─────────────── Quick TTS History ───────────────

class QuickTtsHistories extends Table {
  TextColumn get id => text()();
  TextColumn get voiceAssetId => text().references(VoiceAssets, #id)();
  TextColumn get voiceName => text()();
  TextColumn get inputText => text()();
  TextColumn get audioPath => text().nullable()();
  RealColumn get audioDuration => real().nullable()();
  TextColumn get error => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get missing => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────── Phase TTS Projects & Segments ───────────────

class PhaseTtsProjects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get bankId => text().references(VoiceBanks, #id)();
  TextColumn get scriptText => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get folderSlug => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PhaseTtsSegments extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(PhaseTtsProjects, #id)();
  IntColumn get orderIndex => integer()();
  TextColumn get segmentText => text()();
  // Reserved for future multi-role workflows. The current Phase TTS editor
  // uses [voiceAssetId] directly for simple per-sentence voice assignment.
  TextColumn get speakerLabel => text().nullable()();
  TextColumn get voiceAssetId => text().nullable()();
  TextColumn get audioPath => text().nullable()();
  RealColumn get audioDuration => real().nullable()();
  TextColumn get error => text().nullable()();
  BoolColumn get missing => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────── Novel Reader Projects, Chapters & Segments ───────────────

class NovelProjects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get bankId => text().references(VoiceBanks, #id)();
  TextColumn get narratorVoiceAssetId => text().nullable()();
  TextColumn get dialogueVoiceAssetId => text().nullable()();
  TextColumn get readerTheme => text().withDefault(const Constant('dark'))();
  RealColumn get fontSize => real().withDefault(const Constant(20.0))();
  RealColumn get lineHeight => real().withDefault(const Constant(1.75))();
  BoolColumn get autoTurnPage => boolean().withDefault(const Constant(true))();
  BoolColumn get autoAdvanceChapters =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get autoSliceLongSegments =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get sliceOnlyAtPunctuation =>
      boolean().withDefault(const Constant(true))();
  IntColumn get maxSliceChars => integer().withDefault(const Constant(50))();
  IntColumn get prefetchSegments => integer().withDefault(const Constant(5))();
  BoolColumn get overwriteCacheWhilePlaying =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get skipPunctuationOnlySegments =>
      boolean().withDefault(const Constant(true))();
  TextColumn get cacheCurrentColor =>
      text().withDefault(const Constant('#2F6B54'))();
  TextColumn get cacheStaleColor =>
      text().withDefault(const Constant('#7A5A2A'))();
  RealColumn get cacheHighlightOpacity =>
      real().withDefault(const Constant(0.12))();
  IntColumn get currentGlobalIndex =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get folderSlug => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class NovelChapters extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(NovelProjects, #id)();
  IntColumn get orderIndex => integer()();
  TextColumn get title => text().withLength(min: 1)();
  TextColumn get sourcePath => text().nullable()();
  TextColumn get rawText => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

class NovelSegments extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(NovelProjects, #id)();
  TextColumn get chapterId => text().references(NovelChapters, #id)();
  IntColumn get globalIndex => integer()();
  IntColumn get orderIndex => integer()();
  TextColumn get segmentText => text()();
  // narrator | dialogue. Future role assignment can add speaker labels without
  // changing the lightweight reader workflow.
  TextColumn get segmentType =>
      text().withDefault(const Constant('narrator'))();
  TextColumn get audioPath => text().nullable()();
  RealColumn get audioDuration => real().nullable()();
  TextColumn get audioCacheKey => text().nullable()();
  TextColumn get error => text().nullable()();
  BoolColumn get missing => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────── Dialog TTS Projects & Lines ───────────────

class DialogTtsProjects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get bankId => text().references(VoiceBanks, #id)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get folderSlug => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DialogTtsLines extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(DialogTtsProjects, #id)();
  IntColumn get orderIndex => integer()();
  TextColumn get lineText => text()();
  TextColumn get voiceAssetId => text().nullable()();
  TextColumn get audioPath => text().nullable()();
  RealColumn get audioDuration => real().nullable()();
  TextColumn get error => text().nullable()();
  BoolColumn get missing => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────── Video Dub Projects & Subtitle Cues ───────────────

class VideoDubProjects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get bankId => text().references(VoiceBanks, #id)();
  TextColumn get videoPath => text().nullable()();
  RealColumn get videoDurationSec => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get folderSlug => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SubtitleCues extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(VideoDubProjects, #id)();
  IntColumn get orderIndex => integer()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();
  TextColumn get cueText => text()();
  TextColumn get voiceAssetId => text().nullable()();
  TextColumn get audioPath => text().nullable()();
  RealColumn get audioDuration => real().nullable()();
  TextColumn get error => text().nullable()();
  BoolColumn get missing => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────── Timeline Clips ───────────────
//
// Editable timeline model for Dialog/Phase TTS projects. Each clip is a freely
// positioned audio segment (generated from a line, imported from voice assets,
// or uploaded as SFX). Clips support multi-lane layout and arbitrary start
// times, so they exist independently of the source line's order.
class TimelineClips extends Table {
  TextColumn get id => text()();
  // Parent project id (dialog or phase).
  TextColumn get projectId => text()();
  // 'dialog' | 'phase' — scopes queries by project type.
  TextColumn get projectType => text()();
  // Horizontal lane; 0 is the default lane. Negative lanes render above.
  IntColumn get laneIndex => integer().withDefault(const Constant(0))();
  // Clip start time on the timeline, in milliseconds.
  IntColumn get startTimeMs => integer().withDefault(const Constant(0))();
  // Audio duration in seconds (captured after first probe/playback).
  RealColumn get durationSec => real().nullable()();
  // On-disk audio path.
  TextColumn get audioPath => text()();
  // 'generated' | 'imported' | 'sfx' | 'video' | 'image' | 'video-audio' —
  // drives visual + delete semantics. Video-dub clips may carry any of
  // the latter three.
  TextColumn get sourceType =>
      text().withDefault(const Constant('generated'))();
  // Optional id of the originating DialogTtsLine or PhaseTtsSegment.
  TextColumn get sourceLineId => text().nullable()();
  // Display label (voice name, filename, etc.).
  TextColumn get label => text().withDefault(const Constant(''))();
  BoolColumn get missing => boolean().withDefault(const Constant(false))();
  // Premiere-style link group: V1 video + A1 video-audio clips share the
  // same id so a drag/trim on V1 can move its A1 sibling in lock-step.
  // Null = not linked.
  TextColumn get linkGroupId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
