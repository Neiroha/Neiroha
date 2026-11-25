// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get webFeatureUnavailable =>
      'This feature uses desktop files or media tools. Open Neiroha on desktop to use it.';

  @override
  String get webStorageUnavailable =>
      'Neiroha could not open browser storage. Allow site storage or try a current browser.';

  @override
  String get webStorageDescription =>
      'Providers, voice settings, voice banks and preferences are stored in this browser. Generated audio is kept in memory until the page reloads or the tab closes.';

  @override
  String get webSessionAudio =>
      'Audio history is cleared when you reload. Download clips you want to keep.';

  @override
  String get webLocalAudioUnavailable =>
      'Reference audio and avatar files require the desktop app.';

  @override
  String get webSpeechAdapterUnavailable =>
      'This provider adapter is unavailable for web previews. Choose a browser-compatible provider in the character settings.';

  @override
  String get webSpeechProviderDisabled =>
      'The provider for this character is disabled. Enable it or choose another provider in the character settings.';

  @override
  String get webSpeechEndpointInvalid =>
      'The provider URL is invalid. Enter a full HTTP(S) address in the provider settings.';

  @override
  String get webRealtimeUnavailable =>
      'OpenAI Realtime is unavailable on the web. Choose a Speech model in the character settings or use the desktop app.';

  @override
  String get webGeminiLiveUnavailable =>
      'This model requires Gemini Live. Choose a Gemini TTS model such as gemini-3.8-flash-tts.';

  @override
  String get webOpenAiRealtimeWrongAdapter =>
      'For Web playback with the official OpenAI endpoint, choose a Speech model. On desktop, choose the official OpenAI adapter for Realtime.';

  @override
  String get webMiMoModelRetired =>
      'MiMo V2 TTS has retired. Choose mimo-v2.5-tts.';

  @override
  String get webSpeechLocalReference =>
      'This character requires local reference audio. Use the desktop app or choose a character with a preset voice.';

  @override
  String get webSpeechPresetRequired =>
      'Select an OpenAI preset voice in the character settings.';

  @override
  String get webSpeechIncompatibleVoice =>
      'This voice is incompatible with the selected model. Choose another voice in the character settings.';

  @override
  String get quickTtsPlaybackMode => 'Preview playback';

  @override
  String get quickTtsStreamPlayback => 'Prefer streaming';

  @override
  String get quickTtsFullPlayback => 'Generate full clip';

  @override
  String get webProviderNetworkError =>
      'The browser could not reach the provider. Check the URL and allow the Neiroha site origin on the provider (CORS).';

  @override
  String get webDownloadAudio => 'Download audio';

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
  String get navProviders => 'AI Services';

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
      'v0.5.1 - AI Audio Middleware & Dubbing Workstation';

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
  String get uiAppSupportMacOs =>
      'Application Support (standard macOS location)';

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
  String get uiExportVideo => 'Export Video';

  @override
  String get uiExportBook => 'Export Book';

  @override
  String get uiExportNovelAudio => 'Export novel audio';

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
  String get uiExporting => 'Exporting…';

  @override
  String get uiExportingAudio => 'Exporting audio…';

  @override
  String get uiExportingNovelAudio => 'Exporting novel audio…';

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
  String get uiGenerateFullBookCacheBeforeExporting =>
      'Generate the full book cache before exporting.';

  @override
  String uiGenerateAllStopped(Object error) {
    return 'Generate all stopped: $error';
  }

  @override
  String get uiGenerated => 'Generated';

  @override
  String uiGeneratedCues(Object done) {
    return 'Generated $done cue(s)';
  }

  @override
  String uiGeneratedCuesWithFailures(Object done, Object failed) {
    return 'Generated $done cue(s), $failed failed';
  }

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
  String get uiLeaveBlankToAutoDetectMacOsFfmpeg =>
      'Leave blank to auto-detect (e.g. /opt/homebrew/bin/ffmpeg)';

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
  String get uiNoCuesToGenerateAssignVoiceFirst =>
      'No cues to generate — assign a voice first';

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
  String get uiNoReadableSegmentsToExport => 'No readable segments to export.';

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
  String get uiNovelCacheCompleted => 'Novel cache completed.';

  @override
  String uiNovelCacheCompletedWithFailures(Object failed) {
    return 'Novel cache completed with $failed failed segment(s).';
  }

  @override
  String get uiNovelCacheOverwritten => 'Novel cache overwritten.';

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
  String get uiProjectSettings => 'Project Settings';

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
  String get uiDontSave => 'Don\'t save';

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
  String get splitRuleNewlineName => 'By paragraph (blank line)';

  @override
  String get splitRuleSentenceName =>
      'By sentence punctuation (Chinese / English)';

  @override
  String get splitRuleQuotesName => 'By closing quote (Chinese / English)';

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
  String uiVoiceCount(Object count) {
    return '$count voices';
  }

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
  String get healthCheckTimeoutTitle => 'Health Check Timeout';

  @override
  String get healthCheckTimeoutSubtitle =>
      'Stop provider and voice-bank checks that hang too long.';

  @override
  String healthCheckTimeoutSaved(int seconds) {
    return 'Health check timeout saved: ${seconds}s';
  }

  @override
  String get healthCheckFailedTooltip => 'Health check failed';

  @override
  String get uiDisabled => 'Disabled';

  @override
  String get uiProviderMissing => 'Provider missing';

  @override
  String get uiReachable => 'Reachable';

  @override
  String get uiUnreachable => 'Unreachable';

  @override
  String get uiNoHealthCheckResults => 'No health check results.';

  @override
  String unhealthyVoiceWarning(String voice) {
    return 'Health check failed for $voice. Generation may fail.';
  }

  @override
  String get novelPureReadingMode => 'Pure reading mode';

  @override
  String get novelPlaybackGap => 'Gap';

  @override
  String get novelTextFilters => 'Text Filters';

  @override
  String get novelTextFilterRules => 'Text Filter Rules';

  @override
  String get novelNewTextFilterRule => 'New Text Filter Rule';

  @override
  String get novelEditTextFilterRule => 'Edit Text Filter Rule';

  @override
  String get novelReplacement => 'Replacement';

  @override
  String get novelReplacementHint => 'Leave empty to remove matched text.';

  @override
  String get novelPatternRequired => 'Pattern is required';

  @override
  String get novelSaveApply => 'Save & Apply';

  @override
  String get pressBackAgainToExit => 'Press Back again to exit.';

  @override
  String uiVideoDubMissingVoiceSkippedText(Object missingVoice) {
    return '$missingVoice without a voice will be skipped. ';
  }

  @override
  String uiVideoDubRegenerateExistingCuesPrompt(
    Object alreadyDone,
    Object pending,
    Object missingVoiceText,
  ) {
    return '$alreadyDone cue(s) already have audio. $pending pending. ${missingVoiceText}Regenerate the existing ones too, or only fill in the gaps?';
  }

  @override
  String get uiAutoTtsSkippedNoVoices =>
      'Auto-TTS skipped — bank has no voices';

  @override
  String get uiVideoDubUnavailableOnAndroidPhone =>
      'Video Dub is disabled on Android phones';

  @override
  String get uiVideoDubUnavailableOnAndroidPhoneDescription =>
      'Video editing needs more horizontal space than tall phone screens can provide. Use a tablet, foldable wide layout, or desktop to edit video dubbing projects.';

  @override
  String get uiDetails => 'Details';

  @override
  String get uiVoiceForImportedCues => 'Voice for imported cues';

  @override
  String get uiVoiceForImportedCuesHint =>
      'Pick a character from the voice bank of this project, or leave cues unassigned and cast them one by one.';

  @override
  String get uiLeaveUnassigned => 'Leave unassigned';

  @override
  String get uiCloudVoiceCloneHint =>
      'Pick a voice above, or add a reference audio to clone a new voice on the provider account when saving.';

  @override
  String uiCloudVoiceCloneFailed(Object error) {
    return 'Voice clone failed: $error';
  }

  @override
  String get uiIndexTtsEmotionHint =>
      'Optional emotion description (needs the experimental emotion mode of the WebUI)';

  @override
  String get uiApiAutoStart => 'Start API server on launch';

  @override
  String get uiApiAutoStartDescription =>
      'Start the local API and MCP server automatically when Neiroha opens, so agents can connect without a manual toggle.';

  @override
  String get uiMcpEndpoint => 'MCP server for AI agents';

  @override
  String uiMcpEndpointDescription(Object url) {
    return 'Lets agents manage providers, voices and dubbing jobs at $url (streamable HTTP). Uses the API key above when set.';
  }

  @override
  String get loudnessAction => 'Unify loudness';

  @override
  String get loudnessActionTooltip =>
      'Bring every generated clip to the same loudness';

  @override
  String get loudnessTitle => 'Unify Loudness';

  @override
  String loudnessIntro(Object count) {
    return 'Measures the perceived loudness (LUFS) of $count generated clips and brings each one to the same target. Only the gain changes; a limiter keeps peaks from clipping. Files are rewritten in place, so timelines and exports pick up the result automatically.';
  }

  @override
  String get loudnessTarget => 'TARGET LOUDNESS';

  @override
  String get loudnessPresetLoud => 'Loud';

  @override
  String get loudnessPresetLoudHint =>
      '-14 LUFS · short-video and music platforms';

  @override
  String get loudnessPresetStandard => 'Standard';

  @override
  String get loudnessPresetStandardHint =>
      '-16 LUFS · podcasts, audiobooks, narration';

  @override
  String get loudnessPresetSoft => 'Soft';

  @override
  String get loudnessPresetSoftHint =>
      '-20 LUFS · ASMR, sleep and whisper content';

  @override
  String get loudnessPresetBroadcast => 'Broadcast';

  @override
  String get loudnessPresetBroadcastHint =>
      '-23 LUFS · EBU R128 broadcast standard';

  @override
  String get loudnessPresetCustom => 'Custom';

  @override
  String get loudnessPresetCustomHint =>
      'Pick any target between -30 and -10 LUFS';

  @override
  String get loudnessKeepBackup => 'Keep original backups';

  @override
  String get loudnessKeepBackupHint =>
      'Originals go to an _original_audio folder next to the clips. Later runs always start from them, so you can change the target without stacking quality loss.';

  @override
  String get loudnessAnalyze => 'Analyze';

  @override
  String loudnessAnalyzing(Object done, Object total) {
    return 'Analyzing $done / $total';
  }

  @override
  String loudnessApplying(Object done, Object total) {
    return 'Processing $done / $total';
  }

  @override
  String loudnessApply(Object count) {
    return 'Unify $count clips';
  }

  @override
  String get loudnessRange => 'Current range';

  @override
  String get loudnessSpread => 'Spread';

  @override
  String get loudnessNeedsChange => 'To adjust';

  @override
  String loudnessSummary(
    Object adjusted,
    Object onTarget,
    Object silent,
    Object failed,
  ) {
    return 'Adjusted $adjusted · already on target $onTarget · silent, skipped $silent · failed $failed';
  }

  @override
  String loudnessLastError(Object error) {
    return 'Last error: $error';
  }

  @override
  String get loudnessNoAudio => 'No generated audio to unify yet.';

  @override
  String get loudnessFfmpegRequired =>
      'Unifying loudness needs FFmpeg — configure it in Settings.';

  @override
  String get loudnessStop => 'Stop';

  @override
  String phaseStatsGenerated(Object done, Object total) {
    return '$done/$total generated';
  }

  @override
  String phaseStatsFailed(Object count) {
    return '$count failed';
  }

  @override
  String phaseStatsUnassigned(Object count) {
    return '$count without voice';
  }

  @override
  String get phaseFilterAll => 'All';

  @override
  String get phaseFilterPending => 'Pending';

  @override
  String get phaseFilterDone => 'Generated';

  @override
  String get phaseFilterFailed => 'Failed';

  @override
  String get phaseNoFilterMatches => 'No segments match this filter.';

  @override
  String get phaseApplyVoiceToAll => 'Apply to all';

  @override
  String get phaseEditText => 'Edit text';

  @override
  String get phaseEditTextHint =>
      'Saving changed text clears the generated audio of this segment.';

  @override
  String get phaseResplitTitle => 'Re-split the script?';

  @override
  String phaseResplitBody(Object count) {
    return 'This replaces the current $count segments together with their voice assignments, style settings and generated audio links.';
  }

  @override
  String get phaseResplitConfirm => 'Re-split';

  @override
  String phaseCharCount(Object count) {
    return '$count chars';
  }

  @override
  String get phasePlay => 'Play';

  @override
  String get phasePlayAll => 'Play all';

  @override
  String get phaseStopPlayback => 'Stop';

  @override
  String get phaseMoreActions => 'More actions';

  @override
  String get loudnessAutoTitle => 'Normalize after generation';

  @override
  String loudnessAutoHint(Object target) {
    return 'New clips go to the voice bank target ($target LUFS) plus the loudness offset of each character.';
  }

  @override
  String get loudnessCharacterOffset => 'Loudness offset';

  @override
  String get loudnessCharacterOffsetHint =>
      'Relative to the voice bank target. For example -3 dB keeps a narrator under the cast, +1 to +2 dB lifts a lead.';

  @override
  String get loudnessBankTarget => 'Loudness target';

  @override
  String get loudnessBankTargetHint =>
      'Projects that normalize audio bring this cast here, then add the offset of each character. About -16 LUFS suits narration, -20 LUFS suits ASMR.';

  @override
  String get bankDeactivate => 'Deactivate';

  @override
  String get bankSetActive => 'Set Active';

  @override
  String get bankSettingsMenu => 'Settings…';

  @override
  String get bankSettingsTitle => 'Voice bank settings';

  @override
  String get loudnessUseOffsets => 'Apply character offsets';

  @override
  String get loudnessUseOffsetsHint =>
      'Each speaker lands on the target plus their own offset, for example a narrator a few dB lower.';

  @override
  String loudnessRestore(Object count) {
    return 'Restore originals ($count)';
  }

  @override
  String loudnessRestored(Object count) {
    return 'Restored $count clips to their original loudness.';
  }

  @override
  String get phaseStopGenerating => 'Stop generating';

  @override
  String phaseRetryFailed(Object count) {
    return 'Retry failed ($count)';
  }

  @override
  String get phaseSelectMode => 'Select multiple';

  @override
  String get phaseAddSegment => 'Add segment';

  @override
  String phaseSelectedCount(Object count) {
    return '$count selected';
  }

  @override
  String get phaseSelectAll => 'Select all';

  @override
  String get phaseAssignVoice => 'Assign voice';

  @override
  String get phaseRegenerateSelected => 'Regenerate selected';

  @override
  String get phaseDeleteSelected => 'Delete selected';

  @override
  String get phaseExitSelect => 'Exit multi-select';

  @override
  String get phaseInsertBelow => 'Insert below';

  @override
  String get phaseMergeNext => 'Merge with next';

  @override
  String get phaseSplit => 'Split…';

  @override
  String get phaseSplitTitle => 'Split segment';

  @override
  String get phaseSplitHint => 'Click where the second segment should start.';

  @override
  String get phaseSplitAction => 'Split here';

  @override
  String get phaseInsertTitle => 'New segment';

  @override
  String get phaseInsertAction => 'Insert';

  @override
  String phaseDeletedCount(Object count) {
    return 'Deleted $count segments';
  }

  @override
  String get phaseUndo => 'Undo';

  @override
  String get phaseDragToReorder => 'Drag to reorder';

  @override
  String get phaseShortcuts =>
      'Keyboard: Up/Down move · Space play/stop · Enter generate · F2 edit · Delete remove · Esc clear · Ctrl+A select all (multi-select) · Ctrl+S save';

  @override
  String get phaseMergeSettings => 'Playback and export';

  @override
  String get phaseMergeGap => 'Pause between segments';

  @override
  String get phaseMergeGapHint => 'Used by Play All and Export Merged.';

  @override
  String get phaseFadeIn => 'Fade in';

  @override
  String get phaseFadeOut => 'Fade out';

  @override
  String get phaseFadeHint =>
      'Applied to every segment in the merged export. 10–50 ms removes clicks at the cuts; longer values soften each line.';

  @override
  String get sectionReferenceAudio => 'REFERENCE AUDIO';

  @override
  String get sectionCharacterInfo => 'CHARACTER INFO';

  @override
  String get sectionProvider => 'PROVIDER';

  @override
  String get sectionModel => 'MODEL';

  @override
  String get sectionVoice => 'VOICE';

  @override
  String get sectionVoiceNameOptional => 'VOICE NAME (optional)';

  @override
  String get sectionVoiceDescription => 'VOICE DESCRIPTION';

  @override
  String get sectionCosyvoiceMode => 'COSYVOICE MODE';

  @override
  String get sectionServerProfileOptional => 'SERVER PROFILE (optional)';

  @override
  String get sectionInstruct => 'INSTRUCT';

  @override
  String get sectionVoxcpm2Mode => 'VOXCPM2 MODE';

  @override
  String get sectionGptSovitsMode => 'GPT-SOVITS MODE';

  @override
  String get sectionTrainedSpeaker => 'TRAINED SPEAKER';

  @override
  String get sectionVoiceClone => 'VOICE CLONE';

  @override
  String get sectionVoiceDesign => 'VOICE DESIGN';

  @override
  String get sectionOutput => 'OUTPUT';

  @override
  String get autoFillProviderSpeaker => 'Auto-fill: Provider + Speaker';

  @override
  String get statusIdle => 'Idle';

  @override
  String get statusPreview => 'Preview';

  @override
  String novelGeneratingSegments(Object count) {
    return 'Generating $count segments';
  }

  @override
  String novelGeneratingShort(Object count) {
    return 'Generating $count';
  }

  @override
  String get novelEpubReserved =>
      'EPUB import is not supported yet; the TXT files were imported.';

  @override
  String novelImportFailed(Object error) {
    return 'Import failed: $error';
  }

  @override
  String get novelSegmentSaved => 'Segment saved.';

  @override
  String get novelSegmentDeleted => 'Segment deleted.';

  @override
  String novelDeleteChapterMessage(Object title) {
    return 'This removes \"$title\" and its cached audio.';
  }

  @override
  String get novelChapterDeleted => 'Chapter deleted.';

  @override
  String novelDialogueRulesSaved(Object count) {
    return 'Dialogue rules saved; rebuilt $count segments.';
  }

  @override
  String get novelTextFiltersSaved =>
      'Text filters saved. Stale novel audio will regenerate on demand.';

  @override
  String novelPlaybackStopped(Object error) {
    return 'Playback stopped: $error';
  }

  @override
  String get novelNarrator => 'Narrator';

  @override
  String get novelDialogue => 'Dialogue';

  @override
  String novelSegmentLabel(Object index) {
    return 'Segment $index';
  }

  @override
  String get phaseNoAudioToPlay => 'No generated audio to play.';

  @override
  String get dialogLineFallback => 'Line';

  @override
  String get videoDubDeleteV1First =>
      'Delete the V1 clip first; only one source video is allowed.';

  @override
  String get statusWritingWav => 'Recording WAV';

  @override
  String novelImported(Object chapters, Object segments) {
    return 'Imported $chapters chapters, $segments segments.';
  }

  @override
  String get novelImportFolderTitle => 'Import novel folder';

  @override
  String get uiStopSynthesis => 'Stop synthesis';

  @override
  String get uiAudioBuffering => 'Buffering…';

  @override
  String get roleReadMode => 'Read';

  @override
  String get roleReviewMode => 'Role review';

  @override
  String get roleCharacters => 'Characters';

  @override
  String get roleAddCharacter => 'Add character';

  @override
  String get roleName => 'Name';

  @override
  String get roleAliases => 'Aliases (comma separated)';

  @override
  String get roleDescription => 'Description';

  @override
  String get roleNoCharacter => 'Unassigned';

  @override
  String get roleVoice => 'Voice';

  @override
  String get roleDefaultVoice => 'Use project default';

  @override
  String get roleChapterOverride => 'Override voice in this chapter';

  @override
  String get roleSelected => 'Review selected sentence';

  @override
  String get rolePickSentence => 'Select a sentence to review';

  @override
  String get roleCategory => 'Category';

  @override
  String get roleNarrator => 'Narration';

  @override
  String get roleDialogue => 'Dialogue';

  @override
  String get roleThought => 'Thought';

  @override
  String get roleSystem => 'System';

  @override
  String get roleScope => 'Apply to';

  @override
  String get roleOnlySentence => 'This sentence';

  @override
  String get roleChapterUnlocked => 'Same character in this chapter, unlocked';

  @override
  String get roleLock => 'Lock manual result';

  @override
  String get roleApply => 'Apply changes';

  @override
  String get roleUndo => 'Undo last annotation edit';

  @override
  String get rolePending => 'Pending';

  @override
  String get roleInferred => 'Inferred from context';

  @override
  String get roleConflict => 'Conflicting evidence';

  @override
  String get roleConfirmed => 'Manually confirmed';

  @override
  String get roleInstruction => 'Sentence style override (optional)';

  @override
  String get roleSentenceVoice => 'Sentence voice override';

  @override
  String get roleMerge => 'Merge character';

  @override
  String get roleMergeInto => 'Merge into';

  @override
  String get roleManualReason => 'Manual review';

  @override
  String get roleCached => 'Audio cache ready';

  @override
  String get roleStaleCache => 'Audio needs regeneration';

  @override
  String get roleNoCache => 'Audio not generated';

  @override
  String get roleRename => 'Edit character';

  @override
  String get rolePreview => 'Preview selected sentence';

  @override
  String get rolePendingList => 'Sentences to review';

  @override
  String get roleNoPending => 'No pending sentences in this chapter';

  @override
  String get roleAnalysisModel => 'Role analysis model (text model ID)';

  @override
  String get roleAnalysisProvider => 'Analysis connection';

  @override
  String get roleAnalysisStart => 'Analyze current chapter';

  @override
  String get roleAnalysisResume => 'Confirm roster and continue / resume';

  @override
  String get roleAnalysisPause => 'Pause analysis';

  @override
  String get roleAnalysisFeedback => 'Character or review feedback';

  @override
  String get roleAnalysisReplan => 'Replan cast with new intent';

  @override
  String get roleAnalysisBudget =>
      'Current chapter only. Up to 12 analysis requests per run, plus one tool check for an unverified model. Charges may apply. Locked and manually confirmed sentences are preserved.';

  @override
  String get roleAnalysisOffline =>
      'Configure a connection in Providers before choosing an analysis model.';

  @override
  String get modelDiscover => 'Discover models / capabilities';

  @override
  String get modelRefresh => 'Refresh from connection';

  @override
  String get modelManual => 'Use this model manually';

  @override
  String get modelUnknown => 'Unknown';

  @override
  String get modelSupported => 'Supported';

  @override
  String get modelUnsupported => 'Unsupported';

  @override
  String get roleToolModelHint =>
      'Choose a text model with function calling. Unknown models get a short tool check before processing your text.';

  @override
  String get modelCapabilityHint =>
      'Catalog facts describe capability. Account availability is verified by actual successful use. No paid probes are automatic.';

  @override
  String get modelOverride => 'Override task capability for this route';

  @override
  String get modelNoModels => 'No cached models. Refresh or enter a model ID.';

  @override
  String get roleStagePlan => 'Planning characters';

  @override
  String get roleStageRoster => 'Waiting for roster review';

  @override
  String get roleStageLabel => 'Labeling sentences';

  @override
  String get roleStageValidate => 'Validating labels';

  @override
  String get roleStageReview => 'Reviewing uncertain labels';

  @override
  String get roleStageReplan => 'Replanning from feedback';

  @override
  String get roleStagePaused => 'Paused';

  @override
  String get roleStageCompleted => 'Completed';

  @override
  String get roleStageFailed => 'Analysis failed';

  @override
  String get roleAnalysisSentences => 'sentences';

  @override
  String get roleAnalysisCalls => 'calls';

  @override
  String get roleSplitText => 'Split text';

  @override
  String get roleSplitTextHelp =>
      'Select a range to isolate it, or place the cursor at a split point. All text and labels are preserved.';

  @override
  String get roleMergeText => 'Merge text';

  @override
  String get roleMergeTextHelp =>
      'Merge from the current segment through the chosen end. Mixed labels become unassigned and pending. Old audio is retained but no longer used.';

  @override
  String get roleMergeUntil => 'Merge through';

  @override
  String get roleMergeNewline => 'Insert newlines between segments';

  @override
  String get roleUndoStructure => 'Undo last text split/merge';

  @override
  String get roleStyleMatrix => 'Character styles by category';

  @override
  String get roleStyleHelp =>
      'Leave fields empty to inherit defaults. Clear both fields to remove this override.';

  @override
  String get roleSplitCharacter => 'Split character';

  @override
  String get roleSplitCharacterHelp =>
      'Move selected lines in this chapter to a new character and copy voice bindings. Annotation undo restores attribution and retains the new identity.';

  @override
  String get roleIdentityKind => 'Identity type';

  @override
  String get roleIdentityNamed => 'Named character';

  @override
  String get roleIdentityAnonymous => 'Anonymous speaker';

  @override
  String get roleIdentityGroup => 'Group';

  @override
  String get roleDirectionHelp =>
      'Each director action runs one bounded model task. Review before applying. Casting preserves bindings; tone handles up to 30 unconfirmed, unlocked segments without delivery instructions.';

  @override
  String get roleSuggestCast => 'Suggest voice casting';

  @override
  String get roleSuggestTone => 'Suggest delivery';

  @override
  String get roleDirectionReview => 'Review suggestions';

  @override
  String get roleDirectionEmpty =>
      'The model returned no applicable suggestions.';

  @override
  String get taskProfiles => 'Task model profiles';

  @override
  String get taskProfilesHelp =>
      'Configure separate connections, models and protocols for analysis, casting, delivery and narration. Narration overrides the novel model/protocol while retaining character voices and references. Unconfigured tasks use existing selections.';

  @override
  String get taskSynthesis => 'Novel narration';

  @override
  String get taskProtocol => 'Service protocol';

  @override
  String get taskEndpoint =>
      'Relative endpoint path (blank for protocol default)';

  @override
  String get taskKeyHeader => 'API key header name';

  @override
  String get taskUseDefaults => 'Restore task defaults';

  @override
  String get modelReadDeclaration => 'Read backend capability declaration';

  @override
  String get uiLiveSentencePreview => 'Live preview and save complete audio';

  @override
  String get roleSceneTitle => 'Scene understanding';

  @override
  String get roleSceneFirstPerson => 'First-person narrator';

  @override
  String get roleScenePresent => 'Characters in the scene';

  @override
  String get roleSceneNested => 'Quoted storytellers';

  @override
  String get roleSceneHelp =>
      'Check these identities with the cast. Use feedback and re-plan to correct the scene before continuing.';

  @override
  String get roleToolReview => 'Local tool review';

  @override
  String get roleToolBudget =>
      'Per session: up to 3 calls, 20,000 budgeted tokens, 6 local reads, 8 proposals, and 1,600 output tokens per call. Unknown usage stays reserved; resuming keeps the budget.';

  @override
  String get roleToolCurrent => 'Current segment only';

  @override
  String get roleToolDoubts => 'Chapter doubts (up to 8 segments)';

  @override
  String get roleToolStart => 'Start a new local review';

  @override
  String get roleToolReviewProposals => 'Review character and label proposals';

  @override
  String get roleToolApplyHint =>
      'Select proposals to apply. Accepted labels remain AI inferred. Text, locked and confirmed labels are protected. Merging moves the listed labels and compatible voice bindings, then removes the source identity.';

  @override
  String get roleToolDependency =>
      'Select the new character proposal required by the label change.';

  @override
  String get roleToolAdd => 'Add character';

  @override
  String get roleToolPatch => 'Change label';

  @override
  String get roleToolMerge => 'Merge identities';

  @override
  String get roleToolReady => 'Ready for review';

  @override
  String get roleToolBudgetExhausted => 'Budget exhausted';

  @override
  String get roleToolApplied => 'Selected proposals applied';

  @override
  String get roleToolEmpty => 'No changes proposed';

  @override
  String get roleToolEvidence => 'Text evidence';

  @override
  String get roleToolAffected => 'Affected segments';

  @override
  String get roleToolReserved =>
      'Budget usage (including unknown reservations)';

  @override
  String get settingsRoleAi => 'Role assignment AI';

  @override
  String get settingsRoleAiDescription =>
      'Shared models, profiles and stage prompts for novels and long text';

  @override
  String get roleSkillSettingsHint =>
      'Choose a profile and edit each stage prompt. Novel review and long-text role assignment share it; project task settings and explicit model choices take priority. Defaults ship with the app. Restoring the current profile saves immediately. Prompt changes require unfinished analyses to restart.';

  @override
  String get roleSkillProfile => 'Role profile';

  @override
  String get roleSkillDefault => 'Built-in default profile';

  @override
  String get roleSkillClone => 'Duplicate as new profile';

  @override
  String get roleSkillRestoreProfile => 'Restore current profile';

  @override
  String get roleSkillProfileName => 'Profile name';

  @override
  String get roleSkillUseEntryConnection =>
      'Use the connection selected in the workspace';

  @override
  String get roleSkillNode => 'Analysis stage';

  @override
  String get roleSkillPrompt => 'Stage prompt';

  @override
  String get roleSkillRestoreNode => 'Restore this stage prompt';

  @override
  String get roleSkillSave => 'Save and activate profiles';

  @override
  String get phaseAutoRoles => 'AI role assignment';

  @override
  String get phaseRoleIntent => 'Dubbing intent (optional)';

  @override
  String get phaseRoleIntentHint =>
      'For example: keep the exact text, give characters distinct voices, and keep story quotations with the storyteller.';

  @override
  String get phaseRoleReviewHint =>
      'Analysis leaves the project untouched. Review characters, exact text and voices before applying. Unassigned voices remain pending. Applying replaces the current segments; existing audio remains on disk.';

  @override
  String get phaseRoleAnalyze => 'Analyze and preview';

  @override
  String get phaseRoleApply => 'Apply roles and voices';

  @override
  String get phaseRoleUnknown => 'Unresolved speaker';

  @override
  String get phaseRoleNarrator => 'Default narration voice';

  @override
  String get phaseRoleNoVoice => 'Choose a voice later';

  @override
  String get phaseRoleStatus =>
      'See the task monitor for analysis progress. Up to 40 calls, cancellable during analysis. Audio synthesis starts separately.';

  @override
  String get phaseRoleStale =>
      'Text, segments, voice bank or role configuration changed. Analyze again.';

  @override
  String get dubbingMode => 'Dubbing mode';

  @override
  String get dubbingModeAutomatic => 'Automatic';

  @override
  String get dubbingModeStoryteller => 'Storyteller';

  @override
  String get dubbingModeDramatized => 'Dramatized';

  @override
  String get dubbingModeScript => 'Script & chat';

  @override
  String get dubbingModeAutomaticHelp =>
      'Infer roles from viewpoint, speech cues, and context.';

  @override
  String get dubbingModeStorytellerHelp =>
      'Keep the storyteller’s voice for quotations within their story.';

  @override
  String get dubbingModeDramatizedHelp =>
      'Give clearly attributed quotes their own voices and return to the storyteller afterward.';

  @override
  String get dubbingModeScriptHelp =>
      'Use speaker headers or message senders for dialogue and narration for stage directions.';

  @override
  String get phaseRoleEditSegment => 'Edit assignment';

  @override
  String get phaseRoleModelEvidence => 'Original AI reasoning';

  @override
  String get phaseRoleContext => 'Show context';

  @override
  String get phaseRolePrevious => 'Previous segment';

  @override
  String get phaseRoleFollowing => 'Next segment';

  @override
  String get phaseRoleCategory => 'Segment category';

  @override
  String get phaseRoleSpeaker => 'Character';

  @override
  String get phaseRoleNoCharacter => 'No character assigned';

  @override
  String get phaseRoleAddCharacter => 'Add character';

  @override
  String get phaseRoleCharacterName => 'Character name';

  @override
  String get phaseRoleNameRequired => 'Enter a name that is not already in use';

  @override
  String get phaseRoleSegments => 'Segments';

  @override
  String get phaseRoleVoices => 'Character voices';

  @override
  String get phaseRoleNeedsReview => 'Needs review';

  @override
  String get phaseRoleSearch => 'Search text or characters';

  @override
  String get phaseRoleVoiceHelp =>
      'Choose a voice for all segments of a character. You can also assign voices later in the generation list.';

  @override
  String get phaseRoleNoMatches => 'No matching segments.';

  @override
  String get phaseRoleEdited => 'Edited manually';

  @override
  String get phaseRolePreviewTitle => 'Review role assignments';

  @override
  String get phaseRoleStop => 'Stop analysis';

  @override
  String get phaseRoleStopping => 'Stopping…';

  @override
  String get phaseRoleStopped =>
      'Analysis stopped. You can adjust your settings and try again.';

  @override
  String get phaseRolePreparing => 'Preparing text…';

  @override
  String get phaseRoleAdjustIntent => 'Adjust dubbing intent';

  @override
  String get phaseRoleBackToPreview => 'Back to preview';

  @override
  String get phaseRoleLengthLimit =>
      'This text exceeds 360 segments or 64,000 UTF-16 units. Analyze it in shorter sections.';

  @override
  String get phaseRoleConnectionSettings => 'Connection and model';

  @override
  String get phaseRoleRestoreSuggestion => 'Restore AI suggestion';

  @override
  String get roleAnalysisPanelTitle => 'AI role assignment';

  @override
  String get roleAnalysisApproveRoster => 'Confirm cast and assign lines';

  @override
  String get roleAnalysisResumeShort => 'Resume analysis';

  @override
  String get roleAnalysisRestart => 'Analyze again';

  @override
  String get roleAnalysisRosterHint =>
      'Check the cast and scene below before assigning lines.';

  @override
  String get rolePollOnlyUncertain => 'Only uncertain segments';

  @override
  String get roleNoUncertain => 'No uncertain segments in this chapter.';

  @override
  String phaseRoleReviewSummary(int total, int uncertain, int missing) {
    return '$total segments · $uncertain to review · $missing voice groups unassigned';
  }

  @override
  String phaseRoleReplaceExisting(int count) {
    return 'Applying replaces $count existing segments. The script and generated audio files are retained.';
  }

  @override
  String phaseRoleKeepUncertain(int count) {
    return '$count segments still need review. Go back to edit, or apply their current assignments.';
  }

  @override
  String phaseRoleInputSummary(int count) {
    return 'Detected $count semantic segments. Analysis uses up to 40 model calls, plus one tool check for an unverified model.';
  }

  @override
  String phaseRoleProgress(int processed, int total, int calls) {
    return '$processed/$total segments processed · $calls calls started';
  }

  @override
  String get roleShowMorePending => 'Show more segments to review';

  @override
  String get playbackLoop => 'Loop playback';

  @override
  String get playbackLoopOn => 'Loop on';

  @override
  String get playbackDownload => 'Download audio';

  @override
  String get playbackMoreActions => 'More playback actions';

  @override
  String get navSubtitles => 'Transcribe & Translate';

  @override
  String get transcribeFromAudio =>
      'Transcribe the audio into the reference text';

  @override
  String get transcribeNeedsStt =>
      'Enable a provider with speech-to-text (e.g. OpenAI, ElevenLabs) to transcribe';

  @override
  String get transcribeFilled =>
      'Reference text filled from the audio. Review it, then save.';

  @override
  String transcribeFailed(String error) {
    return 'Transcription failed: $error';
  }

  @override
  String get liveModeRealtime => 'Live call';

  @override
  String get liveModeCompanion => 'AI companion';

  @override
  String get liveModeRealtimeHint =>
      'Talk in real time with a Realtime model, like a phone call';

  @override
  String get liveModeCompanionHint =>
      'An LLM answers with tools; the character\'s own voice speaks';

  @override
  String get liveNeedsRealtime =>
      'Needs a provider with a Realtime model (e.g. OpenAI)';

  @override
  String get liveNeedsCompanion => 'Needs a language model (LLM) service';

  @override
  String get liveStateIdle => 'Idle';

  @override
  String get liveStateConnecting => 'Connecting';

  @override
  String get liveStateListening => 'Listening';

  @override
  String get liveStateThinking => 'Thinking';

  @override
  String get liveStateSpeaking => 'Speaking';

  @override
  String get liveSettings => 'Character live settings';

  @override
  String get livePersona => 'Persona';

  @override
  String get livePersonaHint =>
      'How the character thinks and talks. Empty uses the voice name, description and instruction.';

  @override
  String get liveRealtimeVoice => 'Realtime voice';

  @override
  String get liveDefault => 'Default';

  @override
  String get liveAllowInterrupt => 'Allow interrupting (headphones)';

  @override
  String get liveAllowInterruptHint =>
      'Keeps the microphone open while the character speaks. Without headphones it would hear itself.';

  @override
  String get subtitlePickMedia => 'Choose a video or audio file';

  @override
  String get subtitleSourceLanguage => 'Spoken language';

  @override
  String get subtitleSourceLanguageHint => 'Optional, e.g. ja. Empty = detect';

  @override
  String get subtitleTargetLanguage => 'Translate to';

  @override
  String get subtitleNoTranslation => 'No translation (transcript only)';

  @override
  String get subtitleContext => 'Context for the translator';

  @override
  String get subtitleContextHint => 'Title, names, genre or glossary';

  @override
  String get subtitleFormat => 'Output format';

  @override
  String get subtitleModeOriginal => 'Original';

  @override
  String get subtitleModeTranslation => 'Translation';

  @override
  String get subtitleModeBilingual => 'Bilingual';

  @override
  String get subtitleRun => 'Transcribe';

  @override
  String get subtitleExport => 'Export subtitles';

  @override
  String subtitleSaved(String path) {
    return 'Saved $path';
  }

  @override
  String get subtitlePreview => 'Preview';

  @override
  String get subtitleEmpty => 'Pick a file and run to see the subtitles here.';

  @override
  String get subtitleMissingCapability => 'not available';

  @override
  String get subtitleStageDecoding => 'Decoding';

  @override
  String get subtitleStageDetecting => 'Detecting speech';

  @override
  String get subtitleStageTranscribing => 'Transcribing';

  @override
  String get subtitleStageTranslating => 'Translating';

  @override
  String get subtitleStageDone => 'Done';

  @override
  String get modalityText => 'Text';

  @override
  String get modalityImage => 'Image';

  @override
  String get modalityAudio => 'Audio';

  @override
  String get modalityVideo => 'Video';

  @override
  String get modalityPdf => 'PDF';

  @override
  String get llmThinkUnknown => 'Thinking ?';

  @override
  String get llmThinkNone => 'No thinking';

  @override
  String get llmThinkLevelsUnknown => 'Thinking (levels unknown)';

  @override
  String llmThinkLevels(int count, String from, String to) {
    return 'Thinking $count levels $from→$to';
  }

  @override
  String get llmThinkCanDisable => ', can turn off';

  @override
  String llmThinkDefault(String level) {
    return 'Default: $level';
  }

  @override
  String llmThinkModes(String modes) {
    return 'Modes: $modes';
  }

  @override
  String get llmTools => 'Tool calling';

  @override
  String get llmToolsNo => 'No tool calling';

  @override
  String get llmToolsUnknown => 'Tool calling ?';

  @override
  String get llmToolsParallel => 'Can call several tools in one turn';

  @override
  String get llmInputsUnknown => 'Input ?';

  @override
  String get llmSchema => 'JSON schema';

  @override
  String llmContext(String tokens) {
    return '$tokens context';
  }

  @override
  String get llmSourceCatalog => 'Built-in catalog';

  @override
  String get llmSourceAccount => 'Found in this account';

  @override
  String get llmSourceUnlisted =>
      'Built-in catalog · not listed by this account';

  @override
  String llmPickerTitle(String provider) {
    return 'Language models · $provider';
  }

  @override
  String get llmPickerSearch => 'Search, or type a model ID';

  @override
  String get llmPickerToolsOnly => 'Tool calling only';

  @override
  String get llmPickerLoading => 'Reading the model list…';

  @override
  String llmPickerFound(int count) {
    return 'The account lists $count models; traits come from the public catalog.';
  }

  @override
  String llmPickerDenied(String error) {
    return 'Credentials rejected: $error';
  }

  @override
  String get llmPickerOffline =>
      'No model list from this provider; showing the built-in catalog.';

  @override
  String llmPickerUse(String id) {
    return 'Use $id';
  }

  @override
  String get llmNeedsToolsNo =>
      'This model cannot call tools; role analysis needs tool calling.';

  @override
  String get llmNeedsToolsUnknown =>
      'Tool calling unknown; one small test request runs before the first analysis.';

  @override
  String get llmProviderDisabled => '(disabled)';

  @override
  String get llmProviderHint =>
      'Only providers that offer a language model are listed';

  @override
  String get voiceFilterHint => 'Filter voices';

  @override
  String voiceMoreHidden(int count) {
    return '$count more — type to filter';
  }

  @override
  String voiceEngineVoices(String engine) {
    return '$engine voices';
  }

  @override
  String get navMusic => 'Song Studio';

  @override
  String get musicModel => 'Model';

  @override
  String get musicTitle => 'Title';

  @override
  String get musicTitleHint => 'Untitled song';

  @override
  String get musicPrompt => 'Style & arrangement';

  @override
  String get musicPromptHint =>
      'Genre, mood, instruments, vocalist, tempo, length…';

  @override
  String get musicLyrics => 'Lyrics';

  @override
  String get musicLyricsHint =>
      'Leave empty to let the model write them. Section tags such as [Verse] and [Chorus] shape the song.';

  @override
  String get musicInstrumental => 'Instrumental (no vocals)';

  @override
  String get musicLossless => 'Lossless WAV when the model offers it';

  @override
  String get musicImages => 'Reference images';

  @override
  String get musicAddImage => 'Add image';

  @override
  String get musicGenerate => 'Compose';

  @override
  String musicGenerating(int seconds) {
    return 'Composing… ${seconds}s';
  }

  @override
  String get musicNoModel =>
      'No enabled provider offers song generation. Add a Google Gemini provider.';

  @override
  String get musicEmpty => 'Generated songs appear here.';

  @override
  String get musicShowInFolder => 'Show in folder';

  @override
  String get musicSaveAs => 'Save as…';

  @override
  String get musicDelete => 'Delete';

  @override
  String get musicReuse => 'Reuse settings';

  @override
  String get musicNoLyrics => 'Instrumental, no lyrics.';

  @override
  String get musicWatermark =>
      'Lyria audio carries an inaudible SynthID watermark.';

  @override
  String musicSaved(String path) {
    return 'Saved to $path';
  }

  @override
  String get liveRealtimeModel => 'Realtime model';

  @override
  String get chainTitle => 'Processing chain';

  @override
  String get chainHint =>
      'Steps wrap the TTS of this character like chained functions: text steps rewrite the line first, voice conversion re-voices the audio after. Applies wherever the character speaks.';

  @override
  String get chainInput => 'Line';

  @override
  String get chainOutput => 'Audio';

  @override
  String get chainAdd => 'Add step';

  @override
  String get chainTranslate => 'Translate (LLM)';

  @override
  String get chainRewrite => 'Rewrite (LLM)';

  @override
  String get chainConvert => 'Voice conversion';

  @override
  String chainTranslateTo(String language) {
    return 'Translate → $language';
  }

  @override
  String chainConvertTo(String voice) {
    return 'Re-voice → $voice';
  }

  @override
  String get chainTargetLanguage => 'Target language';

  @override
  String get chainTargetLanguageHint => 'e.g. Japanese, English, Cantonese';

  @override
  String get chainInstruction => 'Instruction';

  @override
  String get chainInstructionHint =>
      'e.g. Say it in a calm, old-fashioned tone and keep it short.';

  @override
  String get chainTargetVoice => 'Target voice';

  @override
  String get chainModel => 'Model';

  @override
  String get chainNoModels => 'No enabled provider offers this capability yet.';

  @override
  String get chainNeedsSetup => 'Needs setup';

  @override
  String get chainNoStreaming =>
      'Voice conversion runs sentence by sentence: playback starts once the first sentence is converted. On the web, converters that only return files convert the whole line first.';

  @override
  String retireBadge(Object date) {
    return 'Retires $date';
  }

  @override
  String retireHint(Object model, Object date, Object replacement) {
    return '$model stops working on $date. Switch to $replacement.';
  }

  @override
  String retireHintNoReplacement(Object model, Object date) {
    return '$model stops working on $date. Pick a model from another provider.';
  }

  @override
  String retireBanner(Object count, Object date, Object days) {
    return '$count characters use models that stop working on $date ($days days left).';
  }

  @override
  String get retireMigrate => 'Migrate';

  @override
  String get retireMigrateTitle => 'Move characters to replacement models?';

  @override
  String get retireMigrateManual =>
      'No replacement runs here; change these in the character inspector:';

  @override
  String retireMigrated(Object count) {
    return 'Moved $count characters.';
  }

  @override
  String retireSwitchTo(Object model) {
    return 'Switch to $model';
  }

  @override
  String get retireLater => 'Later';

  @override
  String get chainTrim => 'Trim silence';

  @override
  String get chainVerify => 'ASR check';

  @override
  String get chainTrimHint =>
      'Cuts silence at both ends of each sentence and shortens pauses longer than 0.35 s.';

  @override
  String get chainVerifyHint =>
      'Transcribes what was spoken, compares it with the line and lists skipped words. Playback is not delayed.';

  @override
  String get chainVerifyLanguage => 'Recognition language (optional)';

  @override
  String chainCheckMissing(Object score, Object missing) {
    return 'Heard $score% · missing: $missing';
  }

  @override
  String chainCheckClean(Object score) {
    return 'Heard $score% · nothing missing';
  }

  @override
  String chainCheckFailed(Object error) {
    return 'ASR check failed: $error';
  }

  @override
  String get chainCheckNone =>
      'No ASR check yet; preview the character to run one.';

  @override
  String get settingsAiCapabilities => 'AI capabilities';

  @override
  String get settingsAiCapabilitiesDescription =>
      'Default models, per-capability limits and added models';

  @override
  String get capLlm => 'Language model';

  @override
  String get capTts => 'Speech synthesis';

  @override
  String get capStt => 'Speech recognition';

  @override
  String get capRealtime => 'Realtime voice';

  @override
  String get capTranslate => 'Speech translation';

  @override
  String get capVc => 'Voice conversion';

  @override
  String get capVad => 'Voice activity';

  @override
  String get capMusic => 'Music';

  @override
  String get capDefaultModel => 'Default model';

  @override
  String get capAutomatic => 'Automatic (first available)';

  @override
  String get capConnections => 'Connections';

  @override
  String get capNoConnections =>
      'No enabled connection offers this capability.';

  @override
  String get capLimits => 'Limits';

  @override
  String capLimitsTitle(Object capability, Object connection) {
    return '$capability limits · $connection';
  }

  @override
  String get capLimitsHint =>
      'Leave a field empty to inherit the connection limit. Each capability queues on its own, so language-model calls do not take speech slots.';

  @override
  String get capInherited => 'Inherited';

  @override
  String get capConcurrency => 'Concurrent requests';

  @override
  String get capRpm => 'Requests / minute';

  @override
  String get capRpd => 'Requests / day';

  @override
  String get capTpm => 'Tokens / minute';

  @override
  String get capTpd => 'Tokens / day';

  @override
  String get capAddModel => 'Add model';

  @override
  String get capModelId => 'Model id';

  @override
  String get capDisplayName => 'Display name (optional)';

  @override
  String capModelRejected(Object model) {
    return 'This connection cannot open model $model.';
  }

  @override
  String get capOff => 'Off';

  @override
  String get capAll => 'All';

  @override
  String get inspectorTabBasic => 'Basics';

  @override
  String get inspectorTabVoice => 'Voice';

  @override
  String get provTabOverview => 'Overview';

  @override
  String get provCapabilities => 'Capabilities';

  @override
  String provCapUse(Object capability) {
    return 'Use $capability on this connection';
  }

  @override
  String provCapOffHint(Object capability) {
    return '$capability is off here; features will not route to this connection.';
  }

  @override
  String get provConnectionOff =>
      'This connection is turned off. Switch it on in the list before features use its models.';

  @override
  String get provSetDefault => 'Set as default';

  @override
  String get provIsDefault => 'Default';

  @override
  String get provSourceAdded => 'Added by you';

  @override
  String get provSourceFetched => 'Fetched from the account';

  @override
  String get provDiscoverLlm => 'Discover from account';

  @override
  String get provOtherModels => 'Other fetched models';

  @override
  String get provCheckAll => 'Check capabilities';

  @override
  String get provHealthOk => 'Available';

  @override
  String get provHealthFailed => 'Failed';

  @override
  String get provHealthUnavailable => 'Unavailable';

  @override
  String get provHealthUnknown => 'Unknown';

  @override
  String get provHealthNotChecked => 'Not checked yet';

  @override
  String provHealthSome(Object list) {
    return 'Some capabilities failed: $list';
  }

  @override
  String get provLimitsConnection => 'Connection limits';

  @override
  String get provLimitsPerCapability => 'Per capability';

  @override
  String get provAddPick => 'Choose a provider';

  @override
  String get provAddHint =>
      'Fill in the address and key on the Overview tab after creating it, then check its capabilities.';

  @override
  String get featPresetVoices => 'Preset voices';

  @override
  String get featInstructions => 'Style instructions';

  @override
  String get featStreamingOutput => 'Streaming';

  @override
  String get featCloudClone => 'Cloud cloning';

  @override
  String get featZeroShotClone => 'Zero-shot cloning';

  @override
  String get featFileTranscription => 'File transcription';

  @override
  String get featStreamingTranscription => 'Streaming transcription';

  @override
  String get featWordTimestamps => 'Word timestamps';

  @override
  String get featDiarization => 'Speaker labels';

  @override
  String get featLanguageDetection => 'Language detection';

  @override
  String get featKeywords => 'Keywords';

  @override
  String get featAudioOutput => 'Audio output';

  @override
  String get featTextOutput => 'Text output';

  @override
  String get featToolCalls => 'Tool calls';

  @override
  String get featServerVad => 'Server VAD';

  @override
  String get featInputTranscription => 'Input transcript';

  @override
  String get featSourceTranscript => 'Source transcript';

  @override
  String get featStructuredOutput => 'Structured output';

  @override
  String get featReasoning => 'Reasoning';

  @override
  String get featVocals => 'Vocals';

  @override
  String get featTimedLyrics => 'Timed lyrics';

  @override
  String get featImagePrompt => 'Image prompt';

  @override
  String get featLosslessOutput => 'Lossless output';

  @override
  String get featZeroShot => 'Zero-shot';

  @override
  String get featLocal => 'Local';

  @override
  String get sidebarExpand => 'Expand sidebar';

  @override
  String get sidebarCollapse => 'Collapse sidebar';

  @override
  String get musicSearch => 'Search songs';

  @override
  String musicCount(Object count) {
    return '$count songs';
  }

  @override
  String get musicNoMatch => 'No song matches.';

  @override
  String get musicStyle => 'Style';

  @override
  String get musicGenre => 'Genre';

  @override
  String get musicMood => 'Mood';

  @override
  String get musicInstruments => 'Instruments';

  @override
  String get musicVoice => 'Vocals';

  @override
  String get musicTempo => 'Tempo';

  @override
  String get musicStyleHint =>
      'Tap a tag to add it to the style; tap again to remove it.';

  @override
  String musicLyricsStats(Object lines, Object chars) {
    return '$lines lines · $chars characters';
  }

  @override
  String get musicOptions => 'Options';

  @override
  String get musicNowPlaying => 'Now playing';

  @override
  String get musicPlay => 'Play';

  @override
  String get musicPause => 'Pause';

  @override
  String get musicLyricsTitle => 'Lyrics';

  @override
  String get musicSeekHint => 'Tap a timed line to jump there.';

  @override
  String get musicGenPop => 'Pop';

  @override
  String get musicGenRock => 'Rock';

  @override
  String get musicGenElectronic => 'Electronic';

  @override
  String get musicGenFolk => 'Folk';

  @override
  String get musicGenChinese => 'Chinese traditional';

  @override
  String get musicGenJazz => 'Jazz';

  @override
  String get musicGenHipHop => 'Hip-hop';

  @override
  String get musicGenLofi => 'Lo-fi';

  @override
  String get musicGenOrchestral => 'Orchestral';

  @override
  String get musicGenAnime => 'Anime';

  @override
  String get musicMoodHappy => 'Upbeat';

  @override
  String get musicMoodSad => 'Melancholy';

  @override
  String get musicMoodEpic => 'Epic';

  @override
  String get musicMoodCalm => 'Calm';

  @override
  String get musicMoodDreamy => 'Dreamy';

  @override
  String get musicMoodDark => 'Dark';

  @override
  String get musicInsPiano => 'Piano';

  @override
  String get musicInsGuitar => 'Acoustic guitar';

  @override
  String get musicInsSynth => 'Synthesizer';

  @override
  String get musicInsStrings => 'Strings';

  @override
  String get musicInsGuzheng => 'Guzheng';

  @override
  String get musicInsDrums => 'Drums';

  @override
  String get musicVoxFemale => 'Female vocals';

  @override
  String get musicVoxMale => 'Male vocals';

  @override
  String get musicVoxChoir => 'Choir';

  @override
  String get musicTempoSlow => 'Slow';

  @override
  String get musicTempoMid => 'Mid-tempo';

  @override
  String get musicTempoFast => 'Fast';

  @override
  String chainCheckExtra(Object extra) {
    return 'Extra: $extra';
  }

  @override
  String capModelUnavailable(Object model) {
    return '$model (unavailable)';
  }

  @override
  String capFollowDefault(Object model) {
    return 'Follow default ($model)';
  }

  @override
  String get capFollowDefaultNone => 'Follow default';

  @override
  String get subtitleModels => 'Models';

  @override
  String get subtitleTranslateModel => 'Translation model';

  @override
  String get provHubDefaults => 'Default models';

  @override
  String get provHubDefaultsHint =>
      'The model each capability uses by default; click a provider to open it';

  @override
  String get provHubDefaultsShort => 'What each capability runs on';

  @override
  String get provHubRoleAiShort => 'Profiles, model and stage prompts';

  @override
  String get provHubConnections => 'Providers';

  @override
  String get provHubFeatureModels => 'Models chosen by features';

  @override
  String get provHubFeatureModelsHint =>
      'These features do not follow the defaults below';

  @override
  String get provHubResetFeatureModel => 'Follow the default again';

  @override
  String provModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models',
      one: '1 model',
    );
    return '$_temp0';
  }

  @override
  String get provConnection => 'Connection';

  @override
  String get settingsAiServicesHint => 'Providers, default models and role AI';

  @override
  String capAutomaticInOrder(Object model) {
    return 'Automatic: in the order below ($model)';
  }

  @override
  String get capAutoOrderHint =>
      'With no default set, the first available connection below and its preferred model are used. Drag the handles to reorder; switched-off connections are skipped.';

  @override
  String get capPreferred => 'Preferred';

  @override
  String capPreferredModel(Object model) {
    return 'Preferred: $model';
  }

  @override
  String get capModelAdded => 'Added';

  @override
  String get capModelOrder => 'Model order';

  @override
  String capUseCustomModel(Object model, Object connection) {
    return 'Use “$model” on $connection';
  }

  @override
  String provHubConnectionsShort(int count, int enabled) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count connections',
      one: '1 connection',
    );
    return '$_temp0 · $enabled on';
  }

  @override
  String get provProvidersHint =>
      'Tap to open its settings; drag the handle to reorder';

  @override
  String get roleAnalysisModelPick => 'Analysis model';

  @override
  String roleModelFollowDefault(Object model) {
    return 'Follow the default LLM ($model)';
  }

  @override
  String get roleModelHint =>
      'Role assignment checks and corrects itself through function calling. Type to search; a picked model is tested at once.';

  @override
  String get roleToolChecking => 'Testing function calling…';

  @override
  String get roleToolSupported => 'Supports function calling';

  @override
  String get roleToolUnsupported =>
      'No function calling: role assignment cannot correct itself, pick another model';

  @override
  String get roleToolUnknown => 'Function calling not tested yet';

  @override
  String roleToolFailed(Object error) {
    return 'Function calling test failed: $error';
  }

  @override
  String get roleToolTest => 'Test';

  @override
  String provAvailableModels(int count) {
    return 'Models you can add · $count';
  }

  @override
  String get provAvailableModelsHint =>
      'Listed by the model catalog or your account. Added models appear in the defaults, the model order and every model picker; starring one as the default adds it too.';

  @override
  String get quickTtsSendHint =>
      'Enter to generate, Shift+Enter for a new line';

  @override
  String get voiceRequired => 'Choose a voice';

  @override
  String voiceNotForModel(String voice, String model) {
    return '$model does not offer the voice $voice; choose another';
  }

  @override
  String get bankSwitch => 'Switch voice bank';

  @override
  String get bankActions => 'Voice bank actions';

  @override
  String get paneCharacterSettings => 'Character settings';

  @override
  String get navOrderReset => 'Restore default';

  @override
  String get navOrderTitle => 'Sidebar';

  @override
  String get navOrderSubtitle =>
      'Drag to reorder, and use the eye to hide pages you don\'t use; AI services and Settings stay at the bottom.';

  @override
  String get navOrderHidden => 'Hidden';

  @override
  String navOrderHiddenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages hidden',
      one: '1 page hidden',
    );
    return '$_temp0; Restore default shows them all.';
  }

  @override
  String navOrderHide(String page) {
    return 'Hide $page from the sidebar';
  }

  @override
  String navOrderShow(String page) {
    return 'Show $page in the sidebar';
  }

  @override
  String get navCharacterChat => 'Character Chat';

  @override
  String get chatNew => 'New chat';

  @override
  String get chatListEmpty => 'No chats yet. Start one with a character.';

  @override
  String get chatPick => 'Pick a chat, or start a new one';

  @override
  String get chatCharacter => 'Character';

  @override
  String get chatEngine => 'Mode';

  @override
  String get chatTitleOptional => 'Title (optional)';

  @override
  String get chatNoCharacters => 'Add a character in the Voice Bank first.';

  @override
  String chatDeleteConfirm(String title) {
    return 'Delete \"$title\" and all of its messages?';
  }

  @override
  String chatComposerHint(String name) {
    return 'Message $name';
  }

  @override
  String get chatMicStart => 'Talk (microphone)';

  @override
  String get chatMicStop => 'Stop listening';

  @override
  String get chatMicUnavailable =>
      'Speaking needs speech recognition and VAD services';

  @override
  String get chatCallStart => 'Start call';

  @override
  String get chatCallEnd => 'Hang up';

  @override
  String chatEmptyCompanion(String name) {
    return 'Type a message, or turn on the microphone and talk. $name answers in their own voice.';
  }

  @override
  String chatEmptyRealtime(String name) {
    return 'Start the call and just talk; $name answers in real time. You can type too.';
  }

  @override
  String get chatToolTime => 'Checked the time';

  @override
  String chatToolRemember(String fact) {
    return 'Remembered: $fact';
  }

  @override
  String chatToolForget(String fact) {
    return 'Forgot: $fact';
  }

  @override
  String chatToolOther(String name) {
    return 'Used $name';
  }

  @override
  String get chatMemory => 'Memory';

  @override
  String get chatMemoryEmpty =>
      'Nothing remembered yet. Tell the character something about yourself.';

  @override
  String get chatLlmModel => 'Chat model';

  @override
  String get chatUseTools => 'Let the character use tools';

  @override
  String get chatUseToolsHint =>
      'Check the time and remember what you tell them. The model must support function calling.';

  @override
  String chatEmotion(String emotion) {
    String _temp0 = intl.Intl.selectLogic(emotion, {
      'happy': 'happy',
      'sad': 'sad',
      'angry': 'angry',
      'surprised': 'surprised',
      'shy': 'shy',
      'serious': 'serious',
      'playful': 'playful',
      'other': 'calm',
    });
    return '$_temp0';
  }

  @override
  String get chatReplay => 'Play again';

  @override
  String get chatStopReplay => 'Stop';

  @override
  String get chatPanelPersona => 'Persona';

  @override
  String get chatPersonaHint =>
      'Who the character is: personality, way of speaking, relationship with you. Empty uses the default below.';

  @override
  String get chatPersonaDefault => 'Default persona';

  @override
  String get chatPanelModel => 'Model';

  @override
  String get chatPanelVoice => 'Voice';

  @override
  String get chatModelFeatures => 'Capabilities';

  @override
  String get chatFeatureTools => 'Tools';

  @override
  String get chatFeatureStructured => 'Structured reply';

  @override
  String get chatFeatureTranscribe => 'Transcribes you';

  @override
  String get chatFeatureVad => 'Turn detection';

  @override
  String get chatFeatureUnknown =>
      'Capabilities unknown; tools are tried and dropped if refused';

  @override
  String get chatToolsUnsupported =>
      'This model has no tools; the character just talks.';

  @override
  String chatVoiceChain(String steps) {
    return 'Chain: $steps';
  }

  @override
  String get chatVoiceNoChain => 'No processing chain';

  @override
  String get chatVoiceChainHint =>
      'Translation, rewriting and voice conversion are set in the character\'s processing chain in the Voice Bank.';

  @override
  String get chatVoiceRealtimeHint =>
      'A call speaks with the Realtime voice; the chain\'s voice conversion is applied to it.';

  @override
  String get chatAppliesNextCall =>
      'Changes apply the next time you start a call.';

  @override
  String get chatChainConverts => 'Voice conversion from the processing chain';
}
