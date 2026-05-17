// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Neiroha';

  @override
  String get navNovelReader => 'Novel Reader';

  @override
  String get navDialogTts => 'Dialog TTS';

  @override
  String get navPhaseTts => 'Phase TTS';

  @override
  String get navVideoDub => 'Video Dub';

  @override
  String get navVoiceAssets => 'Voice Assets';

  @override
  String get navVoiceBank => 'Voice Bank';

  @override
  String get navProviders => 'Providers';

  @override
  String get navSettings => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsGeneralDescription => 'Startup and workspace behavior';

  @override
  String get settingsTasks => 'Tasks';

  @override
  String get settingsTasksDescription =>
      'Current TTS work, queue depth and recent results';

  @override
  String get settingsApi => 'API Server';

  @override
  String get settingsApiDescription =>
      'Local middleware endpoint and access controls';

  @override
  String get settingsStorage => 'Storage';

  @override
  String get settingsStorageDescription =>
      'Data roots, disk sync and archive cleanup';

  @override
  String get settingsMedia => 'Media Tools';

  @override
  String get settingsMediaDescription => 'FFmpeg detection and export defaults';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAboutDescription => 'Version and app information';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSubtitle => 'Choose the app display language.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String languageSaved(String language) {
    return 'Language set to $language.';
  }

  @override
  String get startupScreenTitle => 'Startup Screen';

  @override
  String get startupScreenSubtitle =>
      'Choose the workspace Neiroha opens on launch, or restore the page used before closing.';

  @override
  String startupScreenSaved(String tab) {
    return 'Startup screen set to $tab.';
  }

  @override
  String get keepTtsRunningTitle => 'Keep TTS Running Across Screens';

  @override
  String get keepTtsRunningSubtitle =>
      'Useful for reading with Novel Reader while checking task progress or settings.';

  @override
  String get keepTtsRunningEnabled =>
      'TTS will continue when switching screens.';

  @override
  String get keepTtsRunningDisabled =>
      'Novel playback will stop when leaving the reader.';

  @override
  String get aboutSubtitle =>
      'v0.1.0 - AI Audio Middleware & Dubbing Workstation';

  @override
  String get uiUnassigned => '-- Unassigned --';

  @override
  String get uiOrUploadANewFile => '— or upload a new file —';

  @override
  String uiWillBeRemoved(Object name) {
    return '\"$name\" will be removed.';
  }

  @override
  String get uiCopyReusesTheSourceStreamFastLosslessH264H265Av1ForceA =>
      '\"copy\" reuses the source stream (fast, lossless). h264 / h265 / av1 force a transcode (slower, ffmpeg build must support the chosen encoder).';

  @override
  String uiArchivedFileSAreMissingOnDiskRowsFlaggedNotDeleted(Object count) {
    return '$count archived file(s) are missing on disk — rows flagged, not deleted.';
  }

  @override
  String uiRequestS(Object count) {
    return '$count request(s)';
  }

  @override
  String uiRunningWaiting(Object running, Object queued) {
    return '$running running, $queued waiting';
  }

  @override
  String get uiABankWithThisNameAlreadyExists =>
      'A bank with this name already exists';

  @override
  String get uiALabelForThisClonedVoiceTheActualVoiceIsDerivedFrom =>
      'A label for this cloned voice. The actual voice is derived from the reference audio.';

  @override
  String get uiAProfileRegisteredOnTheCosyVoiceServerLeaveAsNoneToSynthesise =>
      'A profile registered on the CosyVoice server. Leave as \"None\" to synthesise purely from your uploaded reference audio — typing a name that the server doesn\'t know causes 400 \"未找到角色\".';

  @override
  String get uiAVoiceBankGroupsCharactersForAProject =>
      'A Voice Bank groups characters for a project.\n';

  @override
  String get uiAVoiceBankGroupsCharactersForAProjectOnlyOneBankCan =>
      'A Voice Bank groups characters for a project.\nOnly one bank can be active at a time.';

  @override
  String get uiAVoiceProfileRegisteredOnTheServerLeaveAsNoneToSynthesise =>
      'A voice profile registered on the server. Leave as \"None\" to synthesise purely from your uploaded reference audio — sending an unregistered id is rejected.';

  @override
  String get uiAYoungWomanGentleAndSweetVoice =>
      'A young woman, gentle and sweet voice';

  @override
  String get uiActive => 'Active';

  @override
  String get uiAdapterUnavailableOnThisPlatform =>
      'This adapter is not available on the current platform. It cannot be enabled or used for health checks here.';

  @override
  String get uiAdapterType => 'Adapter Type';

  @override
  String get uiAdd => 'Add';

  @override
  String get uiAddChapter => 'Add chapter';

  @override
  String get uiAddCue => 'Add cue';

  @override
  String get uiAddDialogLinesBelow => 'Add dialog lines below';

  @override
  String get uiAddModel => 'Add Model';

  @override
  String get uiAddProvider => 'Add Provider';

  @override
  String get uiAddRule => 'Add rule';

  @override
  String get uiAddSubtitlesImportSRTLRC => 'Add subtitles (import SRT/LRC)';

  @override
  String get uiAddToTimelineDragToPlace => 'Add to timeline (drag to place)';

  @override
  String get uiAddVoice => 'Add Voice';

  @override
  String get uiAfterGeneratingSnapEachCueEndToItsTTSLength =>
      'After generating, snap each cue end to its TTS length.';

  @override
  String get uiAfterGeneratingSnapTheEndTimeToTheActualTTSLength =>
      'After generating, snap the End time to the actual TTS length.';

  @override
  String get uiAhead => 'Ahead';

  @override
  String uiAllArchivedFileSArePresent(Object count) {
    return 'All $count archived file(s) are present.';
  }

  @override
  String get uiAllCharactersFromThisBankAreAlreadyMembers =>
      'All characters from this bank are already members';

  @override
  String get uiAlpha => 'Alpha';

  @override
  String get uiAPIConfigSaved => 'API config saved.';

  @override
  String get uiAPIKey => 'API Key';

  @override
  String get uiAPIKeyOptional => 'API key (optional)';

  @override
  String get uiAPILogOutput => 'API Log Output';

  @override
  String get uiAPILogOutputDisabled => 'API log output disabled.';

  @override
  String get uiAPILogOutputEnabled => 'API log output enabled.';

  @override
  String get uiAPIOff => 'API Off';

  @override
  String get uiAppSupportFallbackInstallDirIsReadOnly =>
      'App-support fallback (install dir is read-only)';

  @override
  String get uiAppend => 'Append';

  @override
  String get uiApply => 'Apply';

  @override
  String get uiApplyAll => 'Apply All';

  @override
  String get uiApproxTokensDay => 'Approx tokens / day';

  @override
  String get uiApproxTokensMin => 'Approx tokens / min';

  @override
  String get uiArchivedAudioCleared => 'Archived audio cleared.';

  @override
  String get uiAssignAVoiceToThisCueFirst => 'Assign a voice to this cue first';

  @override
  String get uiAudioCodecForTheMuxedMP4AACIsTheBroadestCompatibleDefault =>
      'Audio codec for the muxed MP4. AAC is the broadest-compatible default.';

  @override
  String get uiAudioDurationUnknownCannotTrim =>
      'Audio duration unknown — cannot trim.';

  @override
  String get uiAudioFileIsMissingCannotSave =>
      'Audio file is missing — cannot save';

  @override
  String get uiAudioFileMissingOnDisk => 'Audio file missing on disk';

  @override
  String get uiAudioFormat => 'Audio format';

  @override
  String get uiAudioLibraryIsEmpty => 'Audio library is empty';

  @override
  String get uiAudioTagPrefix => 'Audio tag prefix';

  @override
  String get uiAutoSliceLongSegments => 'Auto slice long segments';

  @override
  String get uiAutoSplit => 'Auto Split';

  @override
  String get uiAutoSwitchChaptersWhilePlaying =>
      'Auto switch chapters while playing';

  @override
  String get uiAutoTurnPageWhilePlaying => 'Auto turn page while playing';

  @override
  String get uiAutoDetectFromPATH => 'Auto-detect from PATH';

  @override
  String uiAutoGenerateFailed(Object error) {
    return 'Auto-generate failed: $error';
  }

  @override
  String get uiAutoGenerateOnSend => 'Auto-generate on send';

  @override
  String get uiAutoGenerateTTS => 'Auto-generate TTS';

  @override
  String get uiAutoGenerateTTSAfterImport => 'Auto-generate TTS after import';

  @override
  String get uiAutoPlayAfterGenerate => 'Auto-play after generate';

  @override
  String get uiAutoSyncCueLengthsToAudio => 'Auto-sync cue lengths to audio';

  @override
  String get uiAutoSyncLengthToAudio => 'Auto-sync length to audio';

  @override
  String get uiBack => 'Back';

  @override
  String get uiBackToNovels => 'Back to novels';

  @override
  String get uiBackToProjects => 'Back to projects';

  @override
  String get uiBankHasNoCharacters => 'Bank has no characters';

  @override
  String get uiBankName => 'Bank name';

  @override
  String get uiBANKS => 'BANKS';

  @override
  String get uiBanksCharactersAndInspector => 'Banks, characters and inspector';

  @override
  String get uiBaseURL => 'Base URL';

  @override
  String get uiBearerTokenXAPIKey => 'Bearer token / X-API-Key';

  @override
  String get uiBindHost => 'Bind host';

  @override
  String get uiBoundTo0000WithNoAPIKeyAnyoneOn =>
      'Bound to 0.0.0.0 with no API key — anyone on the LAN can call your providers. Set an API key or rebind to 127.0.0.1.';

  @override
  String get uiBrowse => 'Browse…';

  @override
  String get uiBuiltIn => 'built-in';

  @override
  String get uiCACHE => 'CACHE';

  @override
  String get uiCacheHighlightColor => 'Cache Highlight Color';

  @override
  String get uiCancel => 'Cancel';

  @override
  String get uiChange => 'Change';

  @override
  String get uiChanged => 'Changed';

  @override
  String get uiChapterText => 'Chapter text';

  @override
  String get uiChapterTitle => 'Chapter title';

  @override
  String get uiChapters => 'Chapters';

  @override
  String get uiCharacterName => 'Character Name *';

  @override
  String get uiCharacterNotFound => 'Character not found';

  @override
  String get uiCHARACTERS => 'CHARACTERS';

  @override
  String get uiCharacters => 'Characters';

  @override
  String get uiCharactersAreSharedImportingJustAddsThemAsMembersOfThisBank =>
      'Characters are shared — importing just adds them as members of this bank.';

  @override
  String get uiChooseExportFolder => 'Choose export folder';

  @override
  String get uiChooseExportFolderForSubtitlesTTSFiles =>
      'Choose export folder for subtitles + TTS files';

  @override
  String get uiClear => 'Clear';

  @override
  String get uiClearAllArchivedAudio => 'Clear All Archived Audio';

  @override
  String get uiClearAllArchivedAudio2 => 'Clear all archived audio?';

  @override
  String get uiClearAllCues => 'Clear all cues';

  @override
  String get uiClearAllCues2 => 'Clear all cues?';

  @override
  String get uiClearAudio => 'Clear Audio';

  @override
  String uiClearFailed(Object error) {
    return 'Clear failed: $error';
  }

  @override
  String get uiClearHistoryForThisCharacter =>
      'Clear history for this character';

  @override
  String get uiClear2 => 'Clear…';

  @override
  String get uiClickToSelectAudioFile => 'Click to select audio file';

  @override
  String get uiClose => 'Close';

  @override
  String get uiClosePlayer => 'Close player';

  @override
  String get uiComfort => 'Comfort';

  @override
  String get uiConcurrency => 'Concurrency';

  @override
  String get uiConcurrency1IsSafestForLocalGPUTTSLeaveRateFieldsBlank =>
      'Concurrency 1 is safest for local GPU TTS. Leave rate fields blank for unlimited.';

  @override
  String get uiConfirm => 'Confirm';

  @override
  String get uiContainerCodecForExportAudioWAVFLACKeepFullQualityMP3Is =>
      'Container + codec for \"Export Audio\". WAV/FLAC keep full quality; MP3 is smaller.';

  @override
  String get uiCopyPath => 'Copy path';

  @override
  String get uiCORSOriginAllowlistCSVEmptyDenyAll =>
      'CORS origin allowlist (CSV, empty = deny all)';

  @override
  String uiCouldNotUseThatFolder(Object error) {
    return 'Could not use that folder: $error';
  }

  @override
  String get uiCreate => 'Create';

  @override
  String get uiCreateAVoiceBankFirst => 'Create a Voice Bank first';

  @override
  String get uiCreateCharacter => 'Create Character';

  @override
  String get uiCuesWillBeAddedToThisProject =>
      'Cues will be added to this project.';

  @override
  String get uiCuesWillBeRemovedGeneratedAudioFilesOnDiskAreKeptBut =>
      'Cues will be removed. Generated audio files on disk are kept but the references will be gone.';

  @override
  String get uiCuesWillBeRemovedGeneratedAudioFilesOnDiskAreKeptFor =>
      'Cues will be removed. Generated audio files on disk are kept for now.';

  @override
  String get uiCurrent => 'Current';

  @override
  String get uiCurrentTTSTasks => 'Current TTS Tasks';

  @override
  String get uiCustomLocation => 'Custom location';

  @override
  String get uiCustomVoices => 'Custom Voices';

  @override
  String get uiDark => 'Dark';

  @override
  String get uiDataDirectory => 'Data Directory';

  @override
  String get uiDefault => 'Default';

  @override
  String get uiDefaultLocation => 'Default location';

  @override
  String get uiDefaultMicrophone => 'Default microphone';

  @override
  String get uiDefaultModelName => 'Default Model Name';

  @override
  String get uiDelete => 'Delete';

  @override
  String get uiDeleteAudioTrack => 'Delete audio track?';

  @override
  String get uiDeleteChapter => 'Delete chapter';

  @override
  String get uiDeleteChapter2 => 'Delete chapter?';

  @override
  String get uiDeleteClip => 'Delete clip';

  @override
  String get uiDeleteProvider => 'Delete provider?';

  @override
  String get uiDeleteSegment => 'Delete segment';

  @override
  String get uiText =>
      'Deletes every generated take + imported reference audio. Projects, characters, banks are preserved.';

  @override
  String get uiDescribeTheVoiceYouWantToCreateThisWillBeUsedTo =>
      'Describe the voice you want to create. This will be used to generate a new voice.';

  @override
  String get uiDescription => 'Description';

  @override
  String get uiDescriptionOptional => 'Description (optional)';

  @override
  String get uiDesignModeRequiresAVoiceDescription =>
      'Design mode requires a Voice Description';

  @override
  String get uiDetectedUsedForWaveformExtractionAndImportedMediaAnalysis =>
      'Detected. Used for waveform extraction and imported-media analysis.';

  @override
  String get uiDialogue => 'Dialogue';

  @override
  String get uiDialogueRules => 'Dialogue Rules';

  @override
  String get uiDone => 'Done';

  @override
  String get uiDropAVoiceHereOrClickAddToTimelineOnASegment =>
      'Drop a voice here or click \"Add to timeline\" on a segment';

  @override
  String get uiDubTimeline => 'Dub Timeline';

  @override
  String get uiDubVideoWithTTSFromSubtitleCues =>
      'Dub video with TTS from subtitle cues';

  @override
  String get uiDuplicate => 'Duplicate';

  @override
  String get uiDuplicateAsTemplate => 'Duplicate as Template';

  @override
  String get uiDuplicateProvider => 'Duplicate Provider';

  @override
  String get uiEGHeavyRussianAccentGruffMiddleAgedMale =>
      'e.g. \"Heavy Russian accent, gruff middle-aged male\"';

  @override
  String get uiEGSpeakSoftlyAndSlowlyPrependedToTheText =>
      'e.g. \"Speak softly and slowly\" — prepended to the text';

  @override
  String get uiEGOrSpeakWithExcitement =>
      'e.g. \"用轻柔的声音说话\" or \"speak with excitement\"';

  @override
  String get uiEGAlloyOrGenshinPaimon => 'e.g. alloy or genshin-paimon';

  @override
  String get uiEGClone => 'e.g. clone';

  @override
  String get uiEGGenshinPaimon => 'e.g. genshin-paimon';

  @override
  String get uiEGMyClonedVoice => 'e.g. My Cloned Voice';

  @override
  String get uiEGZhEnJa => 'e.g. zh, en, ja';

  @override
  String get uiEdit => 'Edit';

  @override
  String get uiEDIT => 'EDIT';

  @override
  String get uiEditChapter => 'Edit chapter';

  @override
  String get uiEditCue => 'Edit cue';

  @override
  String get uiEditNovelText => 'Edit novel text';

  @override
  String get uiEditSplitRule => 'Edit Split Rule';

  @override
  String get uiEnableAtLeastOneProviderFirstProvidersTab =>
      'Enable at least one Provider first (Providers tab)';

  @override
  String get uiEnabled => 'Enabled';

  @override
  String get uiEncoding => 'Encoding…';

  @override
  String get uiEnd => 'End';

  @override
  String get uiEndMmSsMs => 'End (mm:ss.ms)';

  @override
  String get uiEndMustBeGreaterThanStart => 'End must be greater than start';

  @override
  String get uiError => 'Error';

  @override
  String uiError2(Object error) {
    return 'Error: $error';
  }

  @override
  String get uiExecutablePath => 'Executable Path';

  @override
  String get uiExportAudio => 'Export Audio';

  @override
  String get uiExportBook => 'Export Book';

  @override
  String get uiExportCancelled => 'Export cancelled';

  @override
  String get uiExportDefaults => 'Export Defaults';

  @override
  String get uiExportDubbedAudio => 'Export dubbed audio';

  @override
  String get uiExportDubbedVideo => 'Export dubbed video';

  @override
  String uiExportFailed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String get uiExportMerged => 'Export Merged';

  @override
  String get uiExportMergedAudio => 'Export merged audio';

  @override
  String get uiExportSubtitlesSingleTTSAudio =>
      'Export subtitles + Single TTS audio';

  @override
  String get uiExportSuccessful => 'Export successful';

  @override
  String get uiExportingAudio => 'Exporting audio…';

  @override
  String get uiExportingVideo => 'Exporting video…';

  @override
  String get uiFailed => 'Failed';

  @override
  String uiFailedToDeleteCharacter(Object error) {
    return 'Failed to delete character: $error';
  }

  @override
  String uiFailedToFetch(Object error) {
    return 'Failed to fetch: $error';
  }

  @override
  String uiFailedToSave(Object error) {
    return 'Failed to save: $error';
  }

  @override
  String get uiFFmpegIsRequiredForExportConfigureItInSettings =>
      'FFmpeg is required for export - configure it in Settings';

  @override
  String get uiFFmpegIsRequiredForExportConfigureItInSettings2 =>
      'FFmpeg is required for export — configure it in Settings';

  @override
  String get uiFFmpegNotDetectedWaveformsAndMediaProbingAreSkipped =>
      'FFmpeg not detected — waveforms and media probing are skipped.';

  @override
  String uiFFmpegUnavailableOnPlatform(String platform) {
    return 'FFmpeg CLI features are not available on $platform. Local muxing, trimming, waveform extraction, and video export are disabled.';
  }

  @override
  String get uiFFmpegUnavailableWaveformsAndLocalExportsAreDisabled =>
      'FFmpeg CLI is not available on this platform — waveforms and local audio/video exports are disabled.';

  @override
  String get uiFFmpegRequiredForTrimming => 'FFmpeg required for trimming.';

  @override
  String get uiFFmpegTrimFailed => 'FFmpeg trim failed.';

  @override
  String get uiFilledAutomaticallyWhenYouPickAboveOrTypeManually =>
      'Filled automatically when you pick above, or type manually';

  @override
  String get uiFont => 'Font';

  @override
  String get uiGenerate => 'Generate';

  @override
  String get uiGenerateAll => 'Generate All';

  @override
  String uiGenerateAll2(Object count) {
    return 'Generate All ($count)';
  }

  @override
  String get uiGenerateAllCues => 'Generate all cues';

  @override
  String get uiGenerateBook => 'Generate Book';

  @override
  String get uiGenerated => 'Generated';

  @override
  String get uiGenerating => 'Generating…';

  @override
  String get uiGENERATION => 'GENERATION';

  @override
  String get uiGPTSoVITSCloneModeNeedsPromptText =>
      'GPT-SoVITS clone mode needs Prompt Text';

  @override
  String get uiHealthCheck => 'Health Check';

  @override
  String get uiHealthCheckResults => 'Health Check Results';

  @override
  String get uiHexColor => 'Hex color';

  @override
  String get uiHttpsExampleComHttpLocalhost3000 =>
      'https://example.com, http://localhost:3000';

  @override
  String get uiIUnderstandThisCannotBeUndone =>
      'I understand this cannot be undone.';

  @override
  String get uiImport => 'Import';

  @override
  String uiImportCues(Object count) {
    return 'Import $count cues?';
  }

  @override
  String get uiImportAVideoOntoTheV1TrackFromTheTimeline =>
      'Import a video onto the V1 track from the timeline.';

  @override
  String get uiImportAll => 'Import All';

  @override
  String get uiImportAudio => 'Import Audio';

  @override
  String get uiImportFolder => 'Import folder';

  @override
  String get uiImportFromAnotherBank => 'Import from another bank';

  @override
  String get uiImportFromAudioLibrary => 'Import from Audio Library';

  @override
  String get uiImportOrAddAChapterToEditNovelText =>
      'Import or add a chapter to edit novel text.';

  @override
  String get uiImportSFXFromFile => 'Import SFX from file';

  @override
  String get uiImportThisCharacter => 'Import this character';

  @override
  String get uiImportTXTFiles => 'Import TXT files';

  @override
  String get uiImportTXTFilesImportAFolderOrAddAChapter =>
      'Import TXT files, import a folder, or add a chapter.';

  @override
  String get uiImportVideo => 'Import Video';

  @override
  String uiImported(Object name) {
    return 'Imported \"$name\"';
  }

  @override
  String uiImportedCharacterS(Object count) {
    return 'Imported $count character(s)';
  }

  @override
  String uiImportedCues(Object count) {
    return 'Imported $count cues';
  }

  @override
  String get uiInputDevice => 'Input device';

  @override
  String get uiInstructText => 'Instruct Text *';

  @override
  String uiInvalidRegex(Object error) {
    return 'Invalid regex: $error';
  }

  @override
  String get uiLanguageCode => 'Language Code';

  @override
  String get uiLeaveBlankToAutoDetectEGCFfmpegBinFfmpegExe =>
      'Leave blank to auto-detect (e.g. C:\\ffmpeg\\bin\\ffmpeg.exe)';

  @override
  String get uiLine => 'Line';

  @override
  String get uiLines => 'Lines';

  @override
  String get uiLoadingModels => 'Loading models...';

  @override
  String get uiLoadingRegisteredVoices => 'Loading registered voices...';

  @override
  String get uiLoadingServerProfiles => 'Loading server profiles...';

  @override
  String get uiLoadingVoices => 'Loading voices...';

  @override
  String get uiManageRules => 'Manage rules';

  @override
  String get uiMergingAudio => 'Merging audio...';

  @override
  String get uiMode => 'Mode';

  @override
  String get uiModelName => 'Model Name';

  @override
  String get uiMultiCharacterConversations => 'Multi-character conversations';

  @override
  String get uiName => 'Name';

  @override
  String get uiNameIsRequired => 'Name is required';

  @override
  String get uiNarrator => 'Narrator';

  @override
  String get uiNaturalLanguageVoiceDescriptionAtSynthesisTimeThisIsSentToThe =>
      'Natural-language voice description. At synthesis time this is sent to the provider.';

  @override
  String
  get uiNaturalLanguageVoiceDescriptionAtSynthesisTimePrependItToTheText =>
      'Natural-language voice description. At synthesis time, prepend it to the text in parentheses — e.g.\n(A young woman, gentle and sweet voice)';

  @override
  String get uiNewBank => 'New Bank';

  @override
  String get uiNewCharacter => 'New Character';

  @override
  String get uiNewCharacterAddedToThisBank =>
      'New Character (added to this bank)';

  @override
  String get uiNewDialogTTSProject => 'New Dialog TTS Project';

  @override
  String get uiNewName => 'New name';

  @override
  String get uiNewNovel => 'New Novel';

  @override
  String get uiNewPhaseTTSProject => 'New Phase TTS Project';

  @override
  String get uiNewProject => 'New Project';

  @override
  String get uiNewSplitRule => 'New Split Rule';

  @override
  String get uiNewVideoDubProject => 'New Video Dub Project';

  @override
  String get uiNewVoiceBank => 'New Voice Bank';

  @override
  String get uiNewVoiceCharacter => 'New Voice Character';

  @override
  String get uiNextChapter => 'Next chapter';

  @override
  String get uiNextPage => 'Next page';

  @override
  String get uiNextVoice => 'Next voice';

  @override
  String get uiNoAPIRequestsLoggedYet => 'No API requests logged yet.';

  @override
  String get uiNoAudioTracksYet => 'No audio tracks yet';

  @override
  String get uiNoBanksYet => 'No banks yet';

  @override
  String get uiNoCharactersInThisBankYet => 'No characters in this bank yet';

  @override
  String get uiNoCuesFoundInFile => 'No cues found in file';

  @override
  String get uiNoCuesYetImportAnSRTLRCFileOrAddOneManually =>
      'No cues yet.\nImport an SRT/LRC file or add one manually.';

  @override
  String get uiNoDialogProjectsYet => 'No dialog projects yet';

  @override
  String get uiNoGeneratedSegmentsToMerge => 'No generated segments to merge.';

  @override
  String get uiNoMatches => 'No matches';

  @override
  String get uiNoModelsOrVoicesYetUseFetchAllOrAddManually =>
      'No models or voices yet. Use \"Fetch All\" or add manually.';

  @override
  String get uiNoPerSentenceStyleControls => 'No per-sentence style controls';

  @override
  String get uiNoProjectsYet => 'No projects yet';

  @override
  String get uiNoProvidersAvailable => 'No providers available';

  @override
  String get uiNoProvidersYet => 'No providers yet';

  @override
  String get uiNoRule => 'No rule';

  @override
  String get uiNoRules => 'No rules';

  @override
  String get uiNoTTSModelsFoundGoToProvidersFetchAllToCacheAvailable =>
      'No TTS models found. Go to Providers → Fetch All to cache available models.';

  @override
  String get uiNoUnfinishedTTSTasksRightNow =>
      'No unfinished TTS tasks right now.';

  @override
  String get uiNoVideoDubProjectsYet => 'No video dub projects yet';

  @override
  String get uiNoVideoLoaded => 'No video loaded';

  @override
  String get uiNoVoicesInThisBankAddVoicesInVoiceBank =>
      'No voices in this bank. Add voices in Voice Bank.';

  @override
  String get uiNoVoicesYetUseFetchToGetAvailableVoices =>
      'No voices yet. Use \"Fetch\" to get available voices.';

  @override
  String get uiNoneUploadManually => 'None (upload manually)';

  @override
  String get uiNoneUseUploadedAudioOnly => 'None (use uploaded audio only)';

  @override
  String get uiNotFoundInstallFfmpegOrSetAPathBelowTheAppWorks =>
      'Not found. Install ffmpeg (or set a path below) — the app works without it, but waveforms and media probing will be skipped.';

  @override
  String get uiNothingToExportNoGeneratedTTSA3AudioOrUnmutedV1 =>
      'Nothing to export — no generated TTS, A3 audio, or unmuted V1';

  @override
  String get uiNovelLongFormNarration => 'Novel & long-form narration';

  @override
  String get uiOK => 'OK';

  @override
  String get uiOnlyPending => 'Only pending';

  @override
  String get uiOpenFolder => 'Open folder';

  @override
  String get uiOutputSpeakerNameOptional => 'Output Speaker Name (optional)';

  @override
  String get uiOverwriteWhileReading => 'Overwrite while reading';

  @override
  String get uiPaper => 'Paper';

  @override
  String uiParseFailed(Object error) {
    return 'Parse failed: $error';
  }

  @override
  String get uiPasteYourNovelTextHereEachParagraphBecomesATTSSegment =>
      'Paste your novel text here...\n\nEach paragraph becomes a TTS segment.';

  @override
  String get uiPasteYourNovelTextHereUseAutoSplitToBreakItInto =>
      'Paste your novel text here...\n\nUse Auto Split to break it into TTS segments.';

  @override
  String get uiPatternIsRequired => 'Pattern is required';

  @override
  String get uiPending => 'Pending';

  @override
  String get uiPickAClipCollectedInTheApp => 'Pick a clip collected in the app';

  @override
  String get uiPickAnAudioFileFromDisk => 'Pick an audio file from disk';

  @override
  String get uiPickAudio => 'Pick audio';

  @override
  String get uiPlayAllGeneratedAudio => 'Play all generated audio';

  @override
  String get uiPlayFromHere => 'Play from here';

  @override
  String get uiPLAYBACK => 'PLAYBACK';

  @override
  String get uiPlaysTheNewLineOnceItFinishes =>
      'Plays the new line once it finishes';

  @override
  String get uiPort => 'Port';

  @override
  String get uiPortableNextToExecutable => 'Portable (next to executable)';

  @override
  String get uiPreview => 'Preview';

  @override
  String get uiPreviousChapter => 'Previous chapter';

  @override
  String get uiPreviousPage => 'Previous page';

  @override
  String get uiPreviousVoice => 'Previous voice';

  @override
  String get uiProbing => 'Probing…';

  @override
  String get uiProjectName => 'Project name';

  @override
  String get uiPromptLanguage => 'Prompt Language';

  @override
  String get uiPromptTextSpokenInRefAudio =>
      'Prompt Text (spoken in ref audio)';

  @override
  String get uiPromptTextSpokenInRefAudio2 =>
      'Prompt Text (spoken in ref audio) *';

  @override
  String get uiProvider => 'Provider';

  @override
  String get uiProviderNotFoundForThisCharacter =>
      'Provider not found for this character';

  @override
  String get uiQueueRateLimits => 'Queue & Rate Limits';

  @override
  String get uiQueued => 'Queued';

  @override
  String get uiQUICKTEST => 'QUICK TEST';

  @override
  String get uiRateLimitReqMinIP0Off => 'Rate limit (req/min/IP, 0 = off)';

  @override
  String get uiReCheck => 'Re-check';

  @override
  String get uiReRecord => 'Re-record';

  @override
  String get uiReaderAppearance => 'Reader appearance';

  @override
  String get uiReaderAppearance2 => 'Reader Appearance';

  @override
  String get uiRecent => 'Recent';

  @override
  String get uiRecord => 'Record';

  @override
  String get uiRecordAudio => 'Record Audio';

  @override
  String
  get uiRecordExternalAPIRequestMetadataInThisPanelRequestBodiesAndAuth =>
      'Record external API request metadata in this panel. Request bodies and auth headers are not stored.';

  @override
  String uiRecordingFailed(Object error) {
    return 'Recording failed: $error';
  }

  @override
  String get uiREFERENCEAUDIO => 'REFERENCE AUDIO';

  @override
  String get uiReferenceLanguage => 'Reference Language';

  @override
  String get uiReferenceText => 'Reference Text';

  @override
  String get uiReferenceTranscript => 'Reference Transcript';

  @override
  String get uiRegenerate => 'Regenerate';

  @override
  String get uiRegenerateAll => 'Regenerate all';

  @override
  String get uiRegexPattern => 'Regex pattern';

  @override
  String get uiRegisteredVoice => 'Registered Voice';

  @override
  String get uiRemoveFromBank => 'Remove from bank';

  @override
  String get uiRename => 'Rename';

  @override
  String get uiRenameVoiceBank => 'Rename Voice Bank';

  @override
  String get uiReplace => 'Replace';

  @override
  String get uiReplaceOriginal => 'Replace original';

  @override
  String get uiRequestsDay => 'Requests / day';

  @override
  String get uiRequestsMin => 'Requests / min';

  @override
  String get uiReset => 'Reset';

  @override
  String get uiRunAutoSplitToCreateSegments =>
      'Run Auto Split to create segments';

  @override
  String get uiRunGenerateAllImmediatelyCuesWithoutAVoiceAreSkipped =>
      'Run Generate All immediately. Cues without a voice are skipped.';

  @override
  String get uiRunTTSForThisCueImmediatelyAfterSavingNeedsAVoiceIn =>
      'Run TTS for this cue immediately after saving. Needs a voice in the bank.';

  @override
  String get uiRunning => 'Running';

  @override
  String uiRunningOn(Object address) {
    return 'Running on $address';
  }

  @override
  String get uiSave => 'Save';

  @override
  String get uiSaveExit => 'Save & Exit';

  @override
  String get uiSaveLeave => 'Save & Leave';

  @override
  String get uiSaveRestart => 'Save & restart';

  @override
  String get uiSaveAsNew => 'Save as new';

  @override
  String get uiSaveAsVoiceAsset => 'Save as Voice Asset';

  @override
  String get uiSaveChanges => 'Save Changes';

  @override
  String get uiSaveSegment => 'Save segment';

  @override
  String get uiSaved => 'Saved';

  @override
  String uiSavedToVoiceAssets(Object name) {
    return 'Saved \"$name\" to Voice Assets';
  }

  @override
  String uiScanFailed(Object error) {
    return 'Scan failed: $error';
  }

  @override
  String get uiScanNow => 'Scan Now';

  @override
  String get uiScanning => 'Scanning…';

  @override
  String get uiSCRIPT => 'SCRIPT';

  @override
  String get uiSearchCharacters => 'Search characters...';

  @override
  String get uiSearchProjects => 'Search projects';

  @override
  String get uiSearchVoices => 'Search voices';

  @override
  String get uiSearch => 'Search…';

  @override
  String get uiSEGMENTS => 'SEGMENTS';

  @override
  String get uiSelectABankAndCharacterToEdit =>
      'Select a bank and character to edit';

  @override
  String get uiSelectACharacterToEdit => 'Select a character to edit';

  @override
  String get uiSelectACharacterToQuickTest =>
      'Select a character to quick-test';

  @override
  String get uiSelectATrack => 'Select a track';

  @override
  String get uiSelectAVoxCPM2Mode => 'Select a VoxCPM2 mode';

  @override
  String get uiSelectFromVoiceAssets => 'Select from Voice Assets';

  @override
  String get uiSelectModel => 'Select Model';

  @override
  String get uiSelectOrAddAProvider => 'Select or add a provider';

  @override
  String get uiSelectOrCreateAVoiceBank => 'Select or create a Voice Bank';

  @override
  String get uiSelectOrEnterAGPTSoVITSSpeaker =>
      'Select or enter a GPT-SoVITS speaker';

  @override
  String get uiSelectSpeaker => 'Select Speaker';

  @override
  String get uiSelectVoice => 'Select Voice';

  @override
  String uiSendFailed(Object error) {
    return 'Send failed: $error';
  }

  @override
  String get uiSentenceVoice => 'Sentence Voice';

  @override
  String get uiServerProfile => 'Server Profile';

  @override
  String get uiSETTINGS => 'SETTINGS';

  @override
  String get uiSingleAudioTracksForVoiceCloning =>
      'Single audio tracks for voice cloning';

  @override
  String get uiSkipPunctuationOnlyText => 'Skip punctuation-only text';

  @override
  String get uiSlice => 'Slice';

  @override
  String get uiSliceAfterPunctuation => 'Slice after punctuation';

  @override
  String get uiSourceBank => 'Source Bank';

  @override
  String get uiSourceVideoMissingOnDisk => 'Source video missing on disk';

  @override
  String get uiSpaceEnterPToPlayOrStop => 'Space / Enter / P to play or stop';

  @override
  String get uiSpeakerVoiceID => 'Speaker / Voice ID *';

  @override
  String get uiSpeed10Normal => 'Speed (1.0 = normal)';

  @override
  String get uiSplitAtBlankLines => 'Split at blank lines';

  @override
  String get uiSplitAtRegexMatch => 'Split at regex match';

  @override
  String get uiSplitRules => 'Split Rules';

  @override
  String get uiStart => 'Start';

  @override
  String get uiStartMmSsMs => 'Start (mm:ss.ms)';

  @override
  String get uiSTATS => 'STATS';

  @override
  String get uiStopped => 'Stopped';

  @override
  String get uiStyleDirection => 'Style / direction';

  @override
  String get uiStyleInstruction => 'Style Instruction';

  @override
  String get uiStyleInstructionOptional => 'Style Instruction (optional)';

  @override
  String get uiSubtitleText => 'Subtitle text';

  @override
  String get uiSubtitles => 'Subtitles';

  @override
  String get uiSyncCueLengthsToTTS => 'Sync cue lengths to TTS';

  @override
  String get uiSyncWithDisk => 'Sync with Disk';

  @override
  String get uiSynthesizeTTSRightAfterSending =>
      'Synthesize TTS right after sending';

  @override
  String get uiTapToChange => 'Tap to change';

  @override
  String get uiTextIsRequired => 'Text is required';

  @override
  String get uiTextLanguageOptional => 'Text Language (optional)';

  @override
  String get uiTextLanguageSynthesisOutput =>
      'Text Language (synthesis output)';

  @override
  String uiThisProjectAlreadyHasCuesReplaceThemOrAppendTheNewCues(
    Object count,
  ) {
    return 'This project already has $count cues. Replace them, or append the new cues after?';
  }

  @override
  String get uiTimeline => 'Timeline';

  @override
  String get uiTotalLength => 'Total length';

  @override
  String get uiTranscriptOfTheAudioUsedByVoiceCloningModelsThatNeedIt =>
      'Transcript of the audio (used by voice cloning models that need it)';

  @override
  String get uiTranscriptOfTheReferenceAudio =>
      'Transcript of the reference audio';

  @override
  String get uiTrim => 'Trim';

  @override
  String get uiTrimApplied => 'Trim applied';

  @override
  String get uiTTSQueueIsIdle => 'TTS queue is idle';

  @override
  String get uiTypeBelowToTestThisVoice => 'Type below to test this voice';

  @override
  String get uiTypeDialogLineEnterToSendCtrlEnterForNewline =>
      'Type dialog line… (Enter to send, Ctrl+Enter for newline)';

  @override
  String get uiTypeSomethingToTest => 'Type something to test...';

  @override
  String get uiUltraCloneModeRequiresAPromptText =>
      'Ultra Clone mode requires a Prompt Text';

  @override
  String get uiUnknown => 'Unknown';

  @override
  String get uiUnsavedChanges => 'Unsaved changes';

  @override
  String get uiUnavailableOnThisPlatform => 'Unavailable on this platform';

  @override
  String get uiUploadAVoiceSampleTheModelWillCloneItsToneAndSpeak =>
      'Upload a voice sample — the model will clone its tone and speak the synthesis text in any language.';

  @override
  String get uiUploadAVoiceSampleToUseAsTheBaseVoiceInsteadOf =>
      'Upload a voice sample to use as the base voice instead of a preset profile.';

  @override
  String get uiUploadAnAudioFileOrRecordANewSampleToGetStarted =>
      'Upload an audio file or record a new sample to get started.';

  @override
  String get uiUploadAudio => 'Upload Audio';

  @override
  String get uiUseChaptersBelowToImportTXTImportAFolderOrAddA =>
      'Use Chapters below to import TXT, import a folder, or add a chapter.';

  @override
  String get uiUseFormatMmSsMsOrHHMmSsMs =>
      'Use format mm:ss.ms or HH:mm:ss.ms';

  @override
  String get uiUsedByTheVideoDubEditorSExportAudioExportVideoButtons =>
      'Used by the Video Dub editor\'s Export Audio / Export Video buttons.';

  @override
  String get uiUsingOverride => 'Using override';

  @override
  String get uiVideoAudioCodec => 'Video audio codec';

  @override
  String get uiVideoCodec => 'Video codec';

  @override
  String get uiVoice => 'Voice';

  @override
  String get uiVoiceSpeakerID => 'Voice / Speaker ID';

  @override
  String get uiVoiceSpeakerName => 'Voice / Speaker Name';

  @override
  String get uiVoiceAssetDirectory => 'Voice Asset Directory';

  @override
  String get uiVoiceAssetDirectoryResetToDefault =>
      'Voice asset directory reset to default';

  @override
  String uiVoiceAssetDirectorySetTo(Object path) {
    return 'Voice asset directory set to $path';
  }

  @override
  String get uiVoiceBank => 'Voice bank';

  @override
  String get uiVoiceDescription => 'Voice Description *';

  @override
  String get uiVoiceDesignRequiresAVoiceDescription =>
      'Voice Design requires a Voice Description';

  @override
  String get uiVoiceForAll => 'Voice for all';

  @override
  String get uiVoiceInstruction => 'Voice Instruction';

  @override
  String get uiVoiceName => 'Voice Name';

  @override
  String get uiVoiceSettings => 'Voice settings';

  @override
  String get uiVOICES => 'VOICES';

  @override
  String get uiVOICESINBANK => 'VOICES IN BANK';

  @override
  String get uiWaiting => 'Waiting';

  @override
  String get uiYouCanConfigureTheURLAPIKeyAndModelAfterCreation =>
      'You can configure the URL, API key, and model after creation.';

  @override
  String get uiYouHaveUnsavedChangesInThisProjectSaveBeforeLeaving =>
      'You have unsaved changes in this project. Save before leaving?';

  @override
  String get uiZhEnJaKo => 'zh / en / ja / ko ...';

  @override
  String uiAudioExportFailed(Object error) {
    return 'Audio export failed: $error';
  }

  @override
  String uiExportedCuesAudioFilesTo(
    Object cueCount,
    Object audioCount,
    Object path,
  ) {
    return 'Exported $cueCount cues + $audioCount audio files to $path';
  }

  @override
  String uiExportedCuesAudioFilesToMissing(
    Object cueCount,
    Object audioCount,
    Object path,
    Object missingCount,
  ) {
    return 'Exported $cueCount cues + $audioCount audio files to $path ($missingCount missing)';
  }

  @override
  String get uiNoNovelProjectsYet => 'No novel projects yet';

  @override
  String uiSidecarSRTFailed(Object error) {
    return 'Sidecar SRT failed: $error';
  }

  @override
  String uiSRTSidecarWrittenTo(Object name) {
    return 'SRT sidecar written to $name.';
  }

  @override
  String get startupLastPage => 'Last page before close';

  @override
  String get fontSettingsTitle => 'Interface Font';

  @override
  String get fontSettingsSubtitle =>
      'Use the app default font or your operating system UI font.';

  @override
  String get fontModeAppDefault => 'App default';

  @override
  String get fontModeSystem => 'System font';

  @override
  String fontModeSaved(String font) {
    return 'Font set to $font.';
  }

  @override
  String get uiVideoDubUnavailableOnAndroidPhone =>
      'Video Dub is disabled on Android phones';

  @override
  String get uiVideoDubUnavailableOnAndroidPhoneDescription =>
      'Video editing needs more horizontal space than tall phone screens can provide. Use a tablet, foldable wide layout, or desktop to edit video dubbing projects.';

  @override
  String get uiDetails => 'Details';
}
