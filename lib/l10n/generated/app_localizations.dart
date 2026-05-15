import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Application title.
  ///
  /// In en, this message translates to:
  /// **'Neiroha'**
  String get appTitle;

  /// No description provided for @navNovelReader.
  ///
  /// In en, this message translates to:
  /// **'Novel Reader'**
  String get navNovelReader;

  /// No description provided for @navDialogTts.
  ///
  /// In en, this message translates to:
  /// **'Dialog TTS'**
  String get navDialogTts;

  /// No description provided for @navPhaseTts.
  ///
  /// In en, this message translates to:
  /// **'Phase TTS'**
  String get navPhaseTts;

  /// No description provided for @navVideoDub.
  ///
  /// In en, this message translates to:
  /// **'Video Dub'**
  String get navVideoDub;

  /// No description provided for @navVoiceAssets.
  ///
  /// In en, this message translates to:
  /// **'Voice Assets'**
  String get navVoiceAssets;

  /// No description provided for @navVoiceBank.
  ///
  /// In en, this message translates to:
  /// **'Voice Bank'**
  String get navVoiceBank;

  /// No description provided for @navProviders.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get navProviders;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsGeneralDescription.
  ///
  /// In en, this message translates to:
  /// **'Startup and workspace behavior'**
  String get settingsGeneralDescription;

  /// No description provided for @settingsTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get settingsTasks;

  /// No description provided for @settingsTasksDescription.
  ///
  /// In en, this message translates to:
  /// **'Current TTS work, queue depth and recent results'**
  String get settingsTasksDescription;

  /// No description provided for @settingsApi.
  ///
  /// In en, this message translates to:
  /// **'API Server'**
  String get settingsApi;

  /// No description provided for @settingsApiDescription.
  ///
  /// In en, this message translates to:
  /// **'Local middleware endpoint and access controls'**
  String get settingsApiDescription;

  /// No description provided for @settingsStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorage;

  /// No description provided for @settingsStorageDescription.
  ///
  /// In en, this message translates to:
  /// **'Data roots, disk sync and archive cleanup'**
  String get settingsStorageDescription;

  /// No description provided for @settingsMedia.
  ///
  /// In en, this message translates to:
  /// **'Media Tools'**
  String get settingsMedia;

  /// No description provided for @settingsMediaDescription.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg detection and export defaults'**
  String get settingsMediaDescription;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Version and app information'**
  String get settingsAboutDescription;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the app display language.'**
  String get languageSubtitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageSaved.
  ///
  /// In en, this message translates to:
  /// **'Language set to {language}.'**
  String languageSaved(String language);

  /// No description provided for @startupScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Startup Screen'**
  String get startupScreenTitle;

  /// No description provided for @startupScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the workspace Neiroha opens on launch, or restore the page used before closing.'**
  String get startupScreenSubtitle;

  /// No description provided for @startupScreenSaved.
  ///
  /// In en, this message translates to:
  /// **'Startup screen set to {tab}.'**
  String startupScreenSaved(String tab);

  /// No description provided for @keepTtsRunningTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep TTS Running Across Screens'**
  String get keepTtsRunningTitle;

  /// No description provided for @keepTtsRunningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Useful for reading with Novel Reader while checking task progress or settings.'**
  String get keepTtsRunningSubtitle;

  /// No description provided for @keepTtsRunningEnabled.
  ///
  /// In en, this message translates to:
  /// **'TTS will continue when switching screens.'**
  String get keepTtsRunningEnabled;

  /// No description provided for @keepTtsRunningDisabled.
  ///
  /// In en, this message translates to:
  /// **'Novel playback will stop when leaving the reader.'**
  String get keepTtsRunningDisabled;

  /// No description provided for @aboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'v0.1.0 - AI Audio Middleware & Dubbing Workstation'**
  String get aboutSubtitle;

  /// No description provided for @uiUnassigned.
  ///
  /// In en, this message translates to:
  /// **'-- Unassigned --'**
  String get uiUnassigned;

  /// No description provided for @uiOrUploadANewFile.
  ///
  /// In en, this message translates to:
  /// **'— or upload a new file —'**
  String get uiOrUploadANewFile;

  /// No description provided for @uiWillBeRemoved.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be removed.'**
  String uiWillBeRemoved(Object name);

  /// No description provided for @uiCopyReusesTheSourceStreamFastLosslessH264H265Av1ForceA.
  ///
  /// In en, this message translates to:
  /// **'\"copy\" reuses the source stream (fast, lossless). h264 / h265 / av1 force a transcode (slower, ffmpeg build must support the chosen encoder).'**
  String get uiCopyReusesTheSourceStreamFastLosslessH264H265Av1ForceA;

  /// No description provided for @uiArchivedFileSAreMissingOnDiskRowsFlaggedNotDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count} archived file(s) are missing on disk — rows flagged, not deleted.'**
  String uiArchivedFileSAreMissingOnDiskRowsFlaggedNotDeleted(Object count);

  /// No description provided for @uiRequestS.
  ///
  /// In en, this message translates to:
  /// **'{count} request(s)'**
  String uiRequestS(Object count);

  /// No description provided for @uiRunningWaiting.
  ///
  /// In en, this message translates to:
  /// **'{running} running, {queued} waiting'**
  String uiRunningWaiting(Object running, Object queued);

  /// No description provided for @uiABankWithThisNameAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'A bank with this name already exists'**
  String get uiABankWithThisNameAlreadyExists;

  /// No description provided for @uiALabelForThisClonedVoiceTheActualVoiceIsDerivedFrom.
  ///
  /// In en, this message translates to:
  /// **'A label for this cloned voice. The actual voice is derived from the reference audio.'**
  String get uiALabelForThisClonedVoiceTheActualVoiceIsDerivedFrom;

  /// No description provided for @uiAProfileRegisteredOnTheCosyVoiceServerLeaveAsNoneToSynthesise.
  ///
  /// In en, this message translates to:
  /// **'A profile registered on the CosyVoice server. Leave as \"None\" to synthesise purely from your uploaded reference audio — typing a name that the server doesn\'\'t know causes 400 \"未找到角色\".'**
  String get uiAProfileRegisteredOnTheCosyVoiceServerLeaveAsNoneToSynthesise;

  /// No description provided for @uiAVoiceBankGroupsCharactersForAProject.
  ///
  /// In en, this message translates to:
  /// **'A Voice Bank groups characters for a project.\n'**
  String get uiAVoiceBankGroupsCharactersForAProject;

  /// No description provided for @uiAVoiceBankGroupsCharactersForAProjectOnlyOneBankCan.
  ///
  /// In en, this message translates to:
  /// **'A Voice Bank groups characters for a project.\nOnly one bank can be active at a time.'**
  String get uiAVoiceBankGroupsCharactersForAProjectOnlyOneBankCan;

  /// No description provided for @uiAVoiceProfileRegisteredOnTheServerLeaveAsNoneToSynthesise.
  ///
  /// In en, this message translates to:
  /// **'A voice profile registered on the server. Leave as \"None\" to synthesise purely from your uploaded reference audio — sending an unregistered id is rejected.'**
  String get uiAVoiceProfileRegisteredOnTheServerLeaveAsNoneToSynthesise;

  /// No description provided for @uiAYoungWomanGentleAndSweetVoice.
  ///
  /// In en, this message translates to:
  /// **'A young woman, gentle and sweet voice'**
  String get uiAYoungWomanGentleAndSweetVoice;

  /// No description provided for @uiActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get uiActive;

  /// No description provided for @uiAdapterType.
  ///
  /// In en, this message translates to:
  /// **'Adapter Type'**
  String get uiAdapterType;

  /// No description provided for @uiAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get uiAdd;

  /// No description provided for @uiAddChapter.
  ///
  /// In en, this message translates to:
  /// **'Add chapter'**
  String get uiAddChapter;

  /// No description provided for @uiAddCue.
  ///
  /// In en, this message translates to:
  /// **'Add cue'**
  String get uiAddCue;

  /// No description provided for @uiAddDialogLinesBelow.
  ///
  /// In en, this message translates to:
  /// **'Add dialog lines below'**
  String get uiAddDialogLinesBelow;

  /// No description provided for @uiAddModel.
  ///
  /// In en, this message translates to:
  /// **'Add Model'**
  String get uiAddModel;

  /// No description provided for @uiAddProvider.
  ///
  /// In en, this message translates to:
  /// **'Add Provider'**
  String get uiAddProvider;

  /// No description provided for @uiAddRule.
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get uiAddRule;

  /// No description provided for @uiAddSubtitlesImportSRTLRC.
  ///
  /// In en, this message translates to:
  /// **'Add subtitles (import SRT/LRC)'**
  String get uiAddSubtitlesImportSRTLRC;

  /// No description provided for @uiAddToTimelineDragToPlace.
  ///
  /// In en, this message translates to:
  /// **'Add to timeline (drag to place)'**
  String get uiAddToTimelineDragToPlace;

  /// No description provided for @uiAddVoice.
  ///
  /// In en, this message translates to:
  /// **'Add Voice'**
  String get uiAddVoice;

  /// No description provided for @uiAfterGeneratingSnapEachCueEndToItsTTSLength.
  ///
  /// In en, this message translates to:
  /// **'After generating, snap each cue end to its TTS length.'**
  String get uiAfterGeneratingSnapEachCueEndToItsTTSLength;

  /// No description provided for @uiAfterGeneratingSnapTheEndTimeToTheActualTTSLength.
  ///
  /// In en, this message translates to:
  /// **'After generating, snap the End time to the actual TTS length.'**
  String get uiAfterGeneratingSnapTheEndTimeToTheActualTTSLength;

  /// No description provided for @uiAhead.
  ///
  /// In en, this message translates to:
  /// **'Ahead'**
  String get uiAhead;

  /// No description provided for @uiAllArchivedFileSArePresent.
  ///
  /// In en, this message translates to:
  /// **'All {count} archived file(s) are present.'**
  String uiAllArchivedFileSArePresent(Object count);

  /// No description provided for @uiAllCharactersFromThisBankAreAlreadyMembers.
  ///
  /// In en, this message translates to:
  /// **'All characters from this bank are already members'**
  String get uiAllCharactersFromThisBankAreAlreadyMembers;

  /// No description provided for @uiAlpha.
  ///
  /// In en, this message translates to:
  /// **'Alpha'**
  String get uiAlpha;

  /// No description provided for @uiAPIConfigSaved.
  ///
  /// In en, this message translates to:
  /// **'API config saved.'**
  String get uiAPIConfigSaved;

  /// No description provided for @uiAPIKey.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get uiAPIKey;

  /// No description provided for @uiAPIKeyOptional.
  ///
  /// In en, this message translates to:
  /// **'API key (optional)'**
  String get uiAPIKeyOptional;

  /// No description provided for @uiAPILogOutput.
  ///
  /// In en, this message translates to:
  /// **'API Log Output'**
  String get uiAPILogOutput;

  /// No description provided for @uiAPILogOutputDisabled.
  ///
  /// In en, this message translates to:
  /// **'API log output disabled.'**
  String get uiAPILogOutputDisabled;

  /// No description provided for @uiAPILogOutputEnabled.
  ///
  /// In en, this message translates to:
  /// **'API log output enabled.'**
  String get uiAPILogOutputEnabled;

  /// No description provided for @uiAPIOff.
  ///
  /// In en, this message translates to:
  /// **'API Off'**
  String get uiAPIOff;

  /// No description provided for @uiAppSupportFallbackInstallDirIsReadOnly.
  ///
  /// In en, this message translates to:
  /// **'App-support fallback (install dir is read-only)'**
  String get uiAppSupportFallbackInstallDirIsReadOnly;

  /// No description provided for @uiAppend.
  ///
  /// In en, this message translates to:
  /// **'Append'**
  String get uiAppend;

  /// No description provided for @uiApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get uiApply;

  /// No description provided for @uiApplyAll.
  ///
  /// In en, this message translates to:
  /// **'Apply All'**
  String get uiApplyAll;

  /// No description provided for @uiApproxTokensDay.
  ///
  /// In en, this message translates to:
  /// **'Approx tokens / day'**
  String get uiApproxTokensDay;

  /// No description provided for @uiApproxTokensMin.
  ///
  /// In en, this message translates to:
  /// **'Approx tokens / min'**
  String get uiApproxTokensMin;

  /// No description provided for @uiArchivedAudioCleared.
  ///
  /// In en, this message translates to:
  /// **'Archived audio cleared.'**
  String get uiArchivedAudioCleared;

  /// No description provided for @uiAssignAVoiceToThisCueFirst.
  ///
  /// In en, this message translates to:
  /// **'Assign a voice to this cue first'**
  String get uiAssignAVoiceToThisCueFirst;

  /// No description provided for @uiAudioCodecForTheMuxedMP4AACIsTheBroadestCompatibleDefault.
  ///
  /// In en, this message translates to:
  /// **'Audio codec for the muxed MP4. AAC is the broadest-compatible default.'**
  String get uiAudioCodecForTheMuxedMP4AACIsTheBroadestCompatibleDefault;

  /// No description provided for @uiAudioDurationUnknownCannotTrim.
  ///
  /// In en, this message translates to:
  /// **'Audio duration unknown — cannot trim.'**
  String get uiAudioDurationUnknownCannotTrim;

  /// No description provided for @uiAudioFileIsMissingCannotSave.
  ///
  /// In en, this message translates to:
  /// **'Audio file is missing — cannot save'**
  String get uiAudioFileIsMissingCannotSave;

  /// No description provided for @uiAudioFileMissingOnDisk.
  ///
  /// In en, this message translates to:
  /// **'Audio file missing on disk'**
  String get uiAudioFileMissingOnDisk;

  /// No description provided for @uiAudioFormat.
  ///
  /// In en, this message translates to:
  /// **'Audio format'**
  String get uiAudioFormat;

  /// No description provided for @uiAudioLibraryIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Audio library is empty'**
  String get uiAudioLibraryIsEmpty;

  /// No description provided for @uiAudioTagPrefix.
  ///
  /// In en, this message translates to:
  /// **'Audio tag prefix'**
  String get uiAudioTagPrefix;

  /// No description provided for @uiAutoSliceLongSegments.
  ///
  /// In en, this message translates to:
  /// **'Auto slice long segments'**
  String get uiAutoSliceLongSegments;

  /// No description provided for @uiAutoSplit.
  ///
  /// In en, this message translates to:
  /// **'Auto Split'**
  String get uiAutoSplit;

  /// No description provided for @uiAutoSwitchChaptersWhilePlaying.
  ///
  /// In en, this message translates to:
  /// **'Auto switch chapters while playing'**
  String get uiAutoSwitchChaptersWhilePlaying;

  /// No description provided for @uiAutoTurnPageWhilePlaying.
  ///
  /// In en, this message translates to:
  /// **'Auto turn page while playing'**
  String get uiAutoTurnPageWhilePlaying;

  /// No description provided for @uiAutoDetectFromPATH.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect from PATH'**
  String get uiAutoDetectFromPATH;

  /// No description provided for @uiAutoGenerateFailed.
  ///
  /// In en, this message translates to:
  /// **'Auto-generate failed: {error}'**
  String uiAutoGenerateFailed(Object error);

  /// No description provided for @uiAutoGenerateOnSend.
  ///
  /// In en, this message translates to:
  /// **'Auto-generate on send'**
  String get uiAutoGenerateOnSend;

  /// No description provided for @uiAutoGenerateTTS.
  ///
  /// In en, this message translates to:
  /// **'Auto-generate TTS'**
  String get uiAutoGenerateTTS;

  /// No description provided for @uiAutoGenerateTTSAfterImport.
  ///
  /// In en, this message translates to:
  /// **'Auto-generate TTS after import'**
  String get uiAutoGenerateTTSAfterImport;

  /// No description provided for @uiAutoPlayAfterGenerate.
  ///
  /// In en, this message translates to:
  /// **'Auto-play after generate'**
  String get uiAutoPlayAfterGenerate;

  /// No description provided for @uiAutoSyncCueLengthsToAudio.
  ///
  /// In en, this message translates to:
  /// **'Auto-sync cue lengths to audio'**
  String get uiAutoSyncCueLengthsToAudio;

  /// No description provided for @uiAutoSyncLengthToAudio.
  ///
  /// In en, this message translates to:
  /// **'Auto-sync length to audio'**
  String get uiAutoSyncLengthToAudio;

  /// No description provided for @uiBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get uiBack;

  /// No description provided for @uiBackToNovels.
  ///
  /// In en, this message translates to:
  /// **'Back to novels'**
  String get uiBackToNovels;

  /// No description provided for @uiBackToProjects.
  ///
  /// In en, this message translates to:
  /// **'Back to projects'**
  String get uiBackToProjects;

  /// No description provided for @uiBankHasNoCharacters.
  ///
  /// In en, this message translates to:
  /// **'Bank has no characters'**
  String get uiBankHasNoCharacters;

  /// No description provided for @uiBankName.
  ///
  /// In en, this message translates to:
  /// **'Bank name'**
  String get uiBankName;

  /// No description provided for @uiBANKS.
  ///
  /// In en, this message translates to:
  /// **'BANKS'**
  String get uiBANKS;

  /// No description provided for @uiBanksCharactersAndInspector.
  ///
  /// In en, this message translates to:
  /// **'Banks, characters and inspector'**
  String get uiBanksCharactersAndInspector;

  /// No description provided for @uiBaseURL.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get uiBaseURL;

  /// No description provided for @uiBearerTokenXAPIKey.
  ///
  /// In en, this message translates to:
  /// **'Bearer token / X-API-Key'**
  String get uiBearerTokenXAPIKey;

  /// No description provided for @uiBindHost.
  ///
  /// In en, this message translates to:
  /// **'Bind host'**
  String get uiBindHost;

  /// No description provided for @uiBoundTo0000WithNoAPIKeyAnyoneOn.
  ///
  /// In en, this message translates to:
  /// **'Bound to 0.0.0.0 with no API key — anyone on the LAN can call your providers. Set an API key or rebind to 127.0.0.1.'**
  String get uiBoundTo0000WithNoAPIKeyAnyoneOn;

  /// No description provided for @uiBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse…'**
  String get uiBrowse;

  /// No description provided for @uiBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'built-in'**
  String get uiBuiltIn;

  /// No description provided for @uiCACHE.
  ///
  /// In en, this message translates to:
  /// **'CACHE'**
  String get uiCACHE;

  /// No description provided for @uiCacheHighlightColor.
  ///
  /// In en, this message translates to:
  /// **'Cache Highlight Color'**
  String get uiCacheHighlightColor;

  /// No description provided for @uiCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get uiCancel;

  /// No description provided for @uiChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get uiChange;

  /// No description provided for @uiChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed'**
  String get uiChanged;

  /// No description provided for @uiChapterText.
  ///
  /// In en, this message translates to:
  /// **'Chapter text'**
  String get uiChapterText;

  /// No description provided for @uiChapterTitle.
  ///
  /// In en, this message translates to:
  /// **'Chapter title'**
  String get uiChapterTitle;

  /// No description provided for @uiChapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get uiChapters;

  /// No description provided for @uiCharacterName.
  ///
  /// In en, this message translates to:
  /// **'Character Name *'**
  String get uiCharacterName;

  /// No description provided for @uiCharacterNotFound.
  ///
  /// In en, this message translates to:
  /// **'Character not found'**
  String get uiCharacterNotFound;

  /// No description provided for @uiCHARACTERS.
  ///
  /// In en, this message translates to:
  /// **'CHARACTERS'**
  String get uiCHARACTERS;

  /// No description provided for @uiCharactersAreSharedImportingJustAddsThemAsMembersOfThisBank.
  ///
  /// In en, this message translates to:
  /// **'Characters are shared — importing just adds them as members of this bank.'**
  String get uiCharactersAreSharedImportingJustAddsThemAsMembersOfThisBank;

  /// No description provided for @uiChooseExportFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose export folder'**
  String get uiChooseExportFolder;

  /// No description provided for @uiChooseExportFolderForSubtitlesTTSFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose export folder for subtitles + TTS files'**
  String get uiChooseExportFolderForSubtitlesTTSFiles;

  /// No description provided for @uiClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get uiClear;

  /// No description provided for @uiClearAllArchivedAudio.
  ///
  /// In en, this message translates to:
  /// **'Clear All Archived Audio'**
  String get uiClearAllArchivedAudio;

  /// No description provided for @uiClearAllArchivedAudio2.
  ///
  /// In en, this message translates to:
  /// **'Clear all archived audio?'**
  String get uiClearAllArchivedAudio2;

  /// No description provided for @uiClearAllCues.
  ///
  /// In en, this message translates to:
  /// **'Clear all cues'**
  String get uiClearAllCues;

  /// No description provided for @uiClearAllCues2.
  ///
  /// In en, this message translates to:
  /// **'Clear all cues?'**
  String get uiClearAllCues2;

  /// No description provided for @uiClearAudio.
  ///
  /// In en, this message translates to:
  /// **'Clear Audio'**
  String get uiClearAudio;

  /// No description provided for @uiClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Clear failed: {error}'**
  String uiClearFailed(Object error);

  /// No description provided for @uiClearHistoryForThisCharacter.
  ///
  /// In en, this message translates to:
  /// **'Clear history for this character'**
  String get uiClearHistoryForThisCharacter;

  /// No description provided for @uiClear2.
  ///
  /// In en, this message translates to:
  /// **'Clear…'**
  String get uiClear2;

  /// No description provided for @uiClickToSelectAudioFile.
  ///
  /// In en, this message translates to:
  /// **'Click to select audio file'**
  String get uiClickToSelectAudioFile;

  /// No description provided for @uiClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get uiClose;

  /// No description provided for @uiClosePlayer.
  ///
  /// In en, this message translates to:
  /// **'Close player'**
  String get uiClosePlayer;

  /// No description provided for @uiComfort.
  ///
  /// In en, this message translates to:
  /// **'Comfort'**
  String get uiComfort;

  /// No description provided for @uiConcurrency.
  ///
  /// In en, this message translates to:
  /// **'Concurrency'**
  String get uiConcurrency;

  /// No description provided for @uiConcurrency1IsSafestForLocalGPUTTSLeaveRateFieldsBlank.
  ///
  /// In en, this message translates to:
  /// **'Concurrency 1 is safest for local GPU TTS. Leave rate fields blank for unlimited.'**
  String get uiConcurrency1IsSafestForLocalGPUTTSLeaveRateFieldsBlank;

  /// No description provided for @uiConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get uiConfirm;

  /// No description provided for @uiContainerCodecForExportAudioWAVFLACKeepFullQualityMP3Is.
  ///
  /// In en, this message translates to:
  /// **'Container + codec for \"Export Audio\". WAV/FLAC keep full quality; MP3 is smaller.'**
  String get uiContainerCodecForExportAudioWAVFLACKeepFullQualityMP3Is;

  /// No description provided for @uiCopyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get uiCopyPath;

  /// No description provided for @uiCORSOriginAllowlistCSVEmptyDenyAll.
  ///
  /// In en, this message translates to:
  /// **'CORS origin allowlist (CSV, empty = deny all)'**
  String get uiCORSOriginAllowlistCSVEmptyDenyAll;

  /// No description provided for @uiCouldNotUseThatFolder.
  ///
  /// In en, this message translates to:
  /// **'Could not use that folder: {error}'**
  String uiCouldNotUseThatFolder(Object error);

  /// No description provided for @uiCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get uiCreate;

  /// No description provided for @uiCreateAVoiceBankFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a Voice Bank first'**
  String get uiCreateAVoiceBankFirst;

  /// No description provided for @uiCreateCharacter.
  ///
  /// In en, this message translates to:
  /// **'Create Character'**
  String get uiCreateCharacter;

  /// No description provided for @uiCuesWillBeAddedToThisProject.
  ///
  /// In en, this message translates to:
  /// **'Cues will be added to this project.'**
  String get uiCuesWillBeAddedToThisProject;

  /// No description provided for @uiCuesWillBeRemovedGeneratedAudioFilesOnDiskAreKeptBut.
  ///
  /// In en, this message translates to:
  /// **'Cues will be removed. Generated audio files on disk are kept but the references will be gone.'**
  String get uiCuesWillBeRemovedGeneratedAudioFilesOnDiskAreKeptBut;

  /// No description provided for @uiCuesWillBeRemovedGeneratedAudioFilesOnDiskAreKeptFor.
  ///
  /// In en, this message translates to:
  /// **'Cues will be removed. Generated audio files on disk are kept for now.'**
  String get uiCuesWillBeRemovedGeneratedAudioFilesOnDiskAreKeptFor;

  /// No description provided for @uiCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get uiCurrent;

  /// No description provided for @uiCurrentTTSTasks.
  ///
  /// In en, this message translates to:
  /// **'Current TTS Tasks'**
  String get uiCurrentTTSTasks;

  /// No description provided for @uiCustomLocation.
  ///
  /// In en, this message translates to:
  /// **'Custom location'**
  String get uiCustomLocation;

  /// No description provided for @uiCustomVoices.
  ///
  /// In en, this message translates to:
  /// **'Custom Voices'**
  String get uiCustomVoices;

  /// No description provided for @uiDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get uiDark;

  /// No description provided for @uiDataDirectory.
  ///
  /// In en, this message translates to:
  /// **'Data Directory'**
  String get uiDataDirectory;

  /// No description provided for @uiDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get uiDefault;

  /// No description provided for @uiDefaultLocation.
  ///
  /// In en, this message translates to:
  /// **'Default location'**
  String get uiDefaultLocation;

  /// No description provided for @uiDefaultMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Default microphone'**
  String get uiDefaultMicrophone;

  /// No description provided for @uiDefaultModelName.
  ///
  /// In en, this message translates to:
  /// **'Default Model Name'**
  String get uiDefaultModelName;

  /// No description provided for @uiDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get uiDelete;

  /// No description provided for @uiDeleteAudioTrack.
  ///
  /// In en, this message translates to:
  /// **'Delete audio track?'**
  String get uiDeleteAudioTrack;

  /// No description provided for @uiDeleteChapter.
  ///
  /// In en, this message translates to:
  /// **'Delete chapter'**
  String get uiDeleteChapter;

  /// No description provided for @uiDeleteChapter2.
  ///
  /// In en, this message translates to:
  /// **'Delete chapter?'**
  String get uiDeleteChapter2;

  /// No description provided for @uiDeleteClip.
  ///
  /// In en, this message translates to:
  /// **'Delete clip'**
  String get uiDeleteClip;

  /// No description provided for @uiDeleteProvider.
  ///
  /// In en, this message translates to:
  /// **'Delete provider?'**
  String get uiDeleteProvider;

  /// No description provided for @uiDeleteSegment.
  ///
  /// In en, this message translates to:
  /// **'Delete segment'**
  String get uiDeleteSegment;

  /// No description provided for @uiText.
  ///
  /// In en, this message translates to:
  /// **'Deletes every generated take + imported reference audio. Projects, characters, banks are preserved.'**
  String get uiText;

  /// No description provided for @uiDescribeTheVoiceYouWantToCreateThisWillBeUsedTo.
  ///
  /// In en, this message translates to:
  /// **'Describe the voice you want to create. This will be used to generate a new voice.'**
  String get uiDescribeTheVoiceYouWantToCreateThisWillBeUsedTo;

  /// No description provided for @uiDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get uiDescription;

  /// No description provided for @uiDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get uiDescriptionOptional;

  /// No description provided for @uiDesignModeRequiresAVoiceDescription.
  ///
  /// In en, this message translates to:
  /// **'Design mode requires a Voice Description'**
  String get uiDesignModeRequiresAVoiceDescription;

  /// No description provided for @uiDetectedUsedForWaveformExtractionAndImportedMediaAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Detected. Used for waveform extraction and imported-media analysis.'**
  String get uiDetectedUsedForWaveformExtractionAndImportedMediaAnalysis;

  /// No description provided for @uiDialogue.
  ///
  /// In en, this message translates to:
  /// **'Dialogue'**
  String get uiDialogue;

  /// No description provided for @uiDialogueRules.
  ///
  /// In en, this message translates to:
  /// **'Dialogue Rules'**
  String get uiDialogueRules;

  /// No description provided for @uiDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get uiDone;

  /// No description provided for @uiDropAVoiceHereOrClickAddToTimelineOnASegment.
  ///
  /// In en, this message translates to:
  /// **'Drop a voice here or click \"Add to timeline\" on a segment'**
  String get uiDropAVoiceHereOrClickAddToTimelineOnASegment;

  /// No description provided for @uiDubTimeline.
  ///
  /// In en, this message translates to:
  /// **'Dub Timeline'**
  String get uiDubTimeline;

  /// No description provided for @uiDubVideoWithTTSFromSubtitleCues.
  ///
  /// In en, this message translates to:
  /// **'Dub video with TTS from subtitle cues'**
  String get uiDubVideoWithTTSFromSubtitleCues;

  /// No description provided for @uiDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get uiDuplicate;

  /// No description provided for @uiDuplicateAsTemplate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate as Template'**
  String get uiDuplicateAsTemplate;

  /// No description provided for @uiDuplicateProvider.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Provider'**
  String get uiDuplicateProvider;

  /// No description provided for @uiEGHeavyRussianAccentGruffMiddleAgedMale.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"Heavy Russian accent, gruff middle-aged male\"'**
  String get uiEGHeavyRussianAccentGruffMiddleAgedMale;

  /// No description provided for @uiEGSpeakSoftlyAndSlowlyPrependedToTheText.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"Speak softly and slowly\" — prepended to the text'**
  String get uiEGSpeakSoftlyAndSlowlyPrependedToTheText;

  /// No description provided for @uiEGOrSpeakWithExcitement.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"用轻柔的声音说话\" or \"speak with excitement\"'**
  String get uiEGOrSpeakWithExcitement;

  /// No description provided for @uiEGAlloyOrGenshinPaimon.
  ///
  /// In en, this message translates to:
  /// **'e.g. alloy or genshin-paimon'**
  String get uiEGAlloyOrGenshinPaimon;

  /// No description provided for @uiEGClone.
  ///
  /// In en, this message translates to:
  /// **'e.g. clone'**
  String get uiEGClone;

  /// No description provided for @uiEGGenshinPaimon.
  ///
  /// In en, this message translates to:
  /// **'e.g. genshin-paimon'**
  String get uiEGGenshinPaimon;

  /// No description provided for @uiEGMyClonedVoice.
  ///
  /// In en, this message translates to:
  /// **'e.g. My Cloned Voice'**
  String get uiEGMyClonedVoice;

  /// No description provided for @uiEGZhEnJa.
  ///
  /// In en, this message translates to:
  /// **'e.g. zh, en, ja'**
  String get uiEGZhEnJa;

  /// No description provided for @uiEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get uiEdit;

  /// No description provided for @uiEDIT.
  ///
  /// In en, this message translates to:
  /// **'EDIT'**
  String get uiEDIT;

  /// No description provided for @uiEditChapter.
  ///
  /// In en, this message translates to:
  /// **'Edit chapter'**
  String get uiEditChapter;

  /// No description provided for @uiEditCue.
  ///
  /// In en, this message translates to:
  /// **'Edit cue'**
  String get uiEditCue;

  /// No description provided for @uiEditNovelText.
  ///
  /// In en, this message translates to:
  /// **'Edit novel text'**
  String get uiEditNovelText;

  /// No description provided for @uiEditSplitRule.
  ///
  /// In en, this message translates to:
  /// **'Edit Split Rule'**
  String get uiEditSplitRule;

  /// No description provided for @uiEnableAtLeastOneProviderFirstProvidersTab.
  ///
  /// In en, this message translates to:
  /// **'Enable at least one Provider first (Providers tab)'**
  String get uiEnableAtLeastOneProviderFirstProvidersTab;

  /// No description provided for @uiEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get uiEnabled;

  /// No description provided for @uiEncoding.
  ///
  /// In en, this message translates to:
  /// **'Encoding…'**
  String get uiEncoding;

  /// No description provided for @uiEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get uiEnd;

  /// No description provided for @uiEndMmSsMs.
  ///
  /// In en, this message translates to:
  /// **'End (mm:ss.ms)'**
  String get uiEndMmSsMs;

  /// No description provided for @uiEndMustBeGreaterThanStart.
  ///
  /// In en, this message translates to:
  /// **'End must be greater than start'**
  String get uiEndMustBeGreaterThanStart;

  /// No description provided for @uiError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get uiError;

  /// No description provided for @uiError2.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String uiError2(Object error);

  /// No description provided for @uiExecutablePath.
  ///
  /// In en, this message translates to:
  /// **'Executable Path'**
  String get uiExecutablePath;

  /// No description provided for @uiExportAudio.
  ///
  /// In en, this message translates to:
  /// **'Export Audio'**
  String get uiExportAudio;

  /// No description provided for @uiExportBook.
  ///
  /// In en, this message translates to:
  /// **'Export Book'**
  String get uiExportBook;

  /// No description provided for @uiExportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export cancelled'**
  String get uiExportCancelled;

  /// No description provided for @uiExportDefaults.
  ///
  /// In en, this message translates to:
  /// **'Export Defaults'**
  String get uiExportDefaults;

  /// No description provided for @uiExportDubbedAudio.
  ///
  /// In en, this message translates to:
  /// **'Export dubbed audio'**
  String get uiExportDubbedAudio;

  /// No description provided for @uiExportDubbedVideo.
  ///
  /// In en, this message translates to:
  /// **'Export dubbed video'**
  String get uiExportDubbedVideo;

  /// No description provided for @uiExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String uiExportFailed(Object error);

  /// No description provided for @uiExportMerged.
  ///
  /// In en, this message translates to:
  /// **'Export Merged'**
  String get uiExportMerged;

  /// No description provided for @uiExportMergedAudio.
  ///
  /// In en, this message translates to:
  /// **'Export merged audio'**
  String get uiExportMergedAudio;

  /// No description provided for @uiExportSubtitlesSingleTTSAudio.
  ///
  /// In en, this message translates to:
  /// **'Export subtitles + Single TTS audio'**
  String get uiExportSubtitlesSingleTTSAudio;

  /// No description provided for @uiExportSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Export successful'**
  String get uiExportSuccessful;

  /// No description provided for @uiExportingAudio.
  ///
  /// In en, this message translates to:
  /// **'Exporting audio…'**
  String get uiExportingAudio;

  /// No description provided for @uiExportingVideo.
  ///
  /// In en, this message translates to:
  /// **'Exporting video…'**
  String get uiExportingVideo;

  /// No description provided for @uiFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get uiFailed;

  /// No description provided for @uiFailedToDeleteCharacter.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete character: {error}'**
  String uiFailedToDeleteCharacter(Object error);

  /// No description provided for @uiFailedToFetch.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch: {error}'**
  String uiFailedToFetch(Object error);

  /// No description provided for @uiFailedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String uiFailedToSave(Object error);

  /// No description provided for @uiFFmpegIsRequiredForExportConfigureItInSettings.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg is required for export - configure it in Settings'**
  String get uiFFmpegIsRequiredForExportConfigureItInSettings;

  /// No description provided for @uiFFmpegIsRequiredForExportConfigureItInSettings2.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg is required for export — configure it in Settings'**
  String get uiFFmpegIsRequiredForExportConfigureItInSettings2;

  /// No description provided for @uiFFmpegNotDetectedWaveformsAndMediaProbingAreSkipped.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg not detected — waveforms and media probing are skipped.'**
  String get uiFFmpegNotDetectedWaveformsAndMediaProbingAreSkipped;

  /// No description provided for @uiFFmpegRequiredForTrimming.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg required for trimming.'**
  String get uiFFmpegRequiredForTrimming;

  /// No description provided for @uiFFmpegTrimFailed.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg trim failed.'**
  String get uiFFmpegTrimFailed;

  /// No description provided for @uiFilledAutomaticallyWhenYouPickAboveOrTypeManually.
  ///
  /// In en, this message translates to:
  /// **'Filled automatically when you pick above, or type manually'**
  String get uiFilledAutomaticallyWhenYouPickAboveOrTypeManually;

  /// No description provided for @uiFont.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get uiFont;

  /// No description provided for @uiGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get uiGenerate;

  /// No description provided for @uiGenerateAll.
  ///
  /// In en, this message translates to:
  /// **'Generate All'**
  String get uiGenerateAll;

  /// No description provided for @uiGenerateAll2.
  ///
  /// In en, this message translates to:
  /// **'Generate All ({count})'**
  String uiGenerateAll2(Object count);

  /// No description provided for @uiGenerateAllCues.
  ///
  /// In en, this message translates to:
  /// **'Generate all cues'**
  String get uiGenerateAllCues;

  /// No description provided for @uiGenerateBook.
  ///
  /// In en, this message translates to:
  /// **'Generate Book'**
  String get uiGenerateBook;

  /// No description provided for @uiGenerated.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get uiGenerated;

  /// No description provided for @uiGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get uiGenerating;

  /// No description provided for @uiGENERATION.
  ///
  /// In en, this message translates to:
  /// **'GENERATION'**
  String get uiGENERATION;

  /// No description provided for @uiGPTSoVITSCloneModeNeedsPromptText.
  ///
  /// In en, this message translates to:
  /// **'GPT-SoVITS clone mode needs Prompt Text'**
  String get uiGPTSoVITSCloneModeNeedsPromptText;

  /// No description provided for @uiHealthCheck.
  ///
  /// In en, this message translates to:
  /// **'Health Check'**
  String get uiHealthCheck;

  /// No description provided for @uiHealthCheckResults.
  ///
  /// In en, this message translates to:
  /// **'Health Check Results'**
  String get uiHealthCheckResults;

  /// No description provided for @uiHexColor.
  ///
  /// In en, this message translates to:
  /// **'Hex color'**
  String get uiHexColor;

  /// No description provided for @uiHttpsExampleComHttpLocalhost3000.
  ///
  /// In en, this message translates to:
  /// **'https://example.com, http://localhost:3000'**
  String get uiHttpsExampleComHttpLocalhost3000;

  /// No description provided for @uiIUnderstandThisCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'I understand this cannot be undone.'**
  String get uiIUnderstandThisCannotBeUndone;

  /// No description provided for @uiImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get uiImport;

  /// No description provided for @uiImportCues.
  ///
  /// In en, this message translates to:
  /// **'Import {count} cues?'**
  String uiImportCues(Object count);

  /// No description provided for @uiImportAVideoOntoTheV1TrackFromTheTimeline.
  ///
  /// In en, this message translates to:
  /// **'Import a video onto the V1 track from the timeline.'**
  String get uiImportAVideoOntoTheV1TrackFromTheTimeline;

  /// No description provided for @uiImportAll.
  ///
  /// In en, this message translates to:
  /// **'Import All'**
  String get uiImportAll;

  /// No description provided for @uiImportAudio.
  ///
  /// In en, this message translates to:
  /// **'Import Audio'**
  String get uiImportAudio;

  /// No description provided for @uiImportFolder.
  ///
  /// In en, this message translates to:
  /// **'Import folder'**
  String get uiImportFolder;

  /// No description provided for @uiImportFromAnotherBank.
  ///
  /// In en, this message translates to:
  /// **'Import from another bank'**
  String get uiImportFromAnotherBank;

  /// No description provided for @uiImportFromAudioLibrary.
  ///
  /// In en, this message translates to:
  /// **'Import from Audio Library'**
  String get uiImportFromAudioLibrary;

  /// No description provided for @uiImportOrAddAChapterToEditNovelText.
  ///
  /// In en, this message translates to:
  /// **'Import or add a chapter to edit novel text.'**
  String get uiImportOrAddAChapterToEditNovelText;

  /// No description provided for @uiImportSFXFromFile.
  ///
  /// In en, this message translates to:
  /// **'Import SFX from file'**
  String get uiImportSFXFromFile;

  /// No description provided for @uiImportThisCharacter.
  ///
  /// In en, this message translates to:
  /// **'Import this character'**
  String get uiImportThisCharacter;

  /// No description provided for @uiImportTXTFiles.
  ///
  /// In en, this message translates to:
  /// **'Import TXT files'**
  String get uiImportTXTFiles;

  /// No description provided for @uiImportTXTFilesImportAFolderOrAddAChapter.
  ///
  /// In en, this message translates to:
  /// **'Import TXT files, import a folder, or add a chapter.'**
  String get uiImportTXTFilesImportAFolderOrAddAChapter;

  /// No description provided for @uiImportVideo.
  ///
  /// In en, this message translates to:
  /// **'Import Video'**
  String get uiImportVideo;

  /// No description provided for @uiImported.
  ///
  /// In en, this message translates to:
  /// **'Imported \"{name}\"'**
  String uiImported(Object name);

  /// No description provided for @uiImportedCharacterS.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} character(s)'**
  String uiImportedCharacterS(Object count);

  /// No description provided for @uiImportedCues.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} cues'**
  String uiImportedCues(Object count);

  /// No description provided for @uiInputDevice.
  ///
  /// In en, this message translates to:
  /// **'Input device'**
  String get uiInputDevice;

  /// No description provided for @uiInstructText.
  ///
  /// In en, this message translates to:
  /// **'Instruct Text *'**
  String get uiInstructText;

  /// No description provided for @uiInvalidRegex.
  ///
  /// In en, this message translates to:
  /// **'Invalid regex: {error}'**
  String uiInvalidRegex(Object error);

  /// No description provided for @uiLanguageCode.
  ///
  /// In en, this message translates to:
  /// **'Language Code'**
  String get uiLanguageCode;

  /// No description provided for @uiLeaveBlankToAutoDetectEGCFfmpegBinFfmpegExe.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to auto-detect (e.g. C:\\ffmpeg\\bin\\ffmpeg.exe)'**
  String get uiLeaveBlankToAutoDetectEGCFfmpegBinFfmpegExe;

  /// No description provided for @uiLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get uiLine;

  /// No description provided for @uiLines.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get uiLines;

  /// No description provided for @uiLoadingModels.
  ///
  /// In en, this message translates to:
  /// **'Loading models...'**
  String get uiLoadingModels;

  /// No description provided for @uiLoadingRegisteredVoices.
  ///
  /// In en, this message translates to:
  /// **'Loading registered voices...'**
  String get uiLoadingRegisteredVoices;

  /// No description provided for @uiLoadingServerProfiles.
  ///
  /// In en, this message translates to:
  /// **'Loading server profiles...'**
  String get uiLoadingServerProfiles;

  /// No description provided for @uiLoadingVoices.
  ///
  /// In en, this message translates to:
  /// **'Loading voices...'**
  String get uiLoadingVoices;

  /// No description provided for @uiManageRules.
  ///
  /// In en, this message translates to:
  /// **'Manage rules'**
  String get uiManageRules;

  /// No description provided for @uiMergingAudio.
  ///
  /// In en, this message translates to:
  /// **'Merging audio...'**
  String get uiMergingAudio;

  /// No description provided for @uiMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get uiMode;

  /// No description provided for @uiModelName.
  ///
  /// In en, this message translates to:
  /// **'Model Name'**
  String get uiModelName;

  /// No description provided for @uiMultiCharacterConversations.
  ///
  /// In en, this message translates to:
  /// **'Multi-character conversations'**
  String get uiMultiCharacterConversations;

  /// No description provided for @uiName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get uiName;

  /// No description provided for @uiNameIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get uiNameIsRequired;

  /// No description provided for @uiNarrator.
  ///
  /// In en, this message translates to:
  /// **'Narrator'**
  String get uiNarrator;

  /// No description provided for @uiNaturalLanguageVoiceDescriptionAtSynthesisTimeThisIsSentToThe.
  ///
  /// In en, this message translates to:
  /// **'Natural-language voice description. At synthesis time this is sent to the provider.'**
  String get uiNaturalLanguageVoiceDescriptionAtSynthesisTimeThisIsSentToThe;

  /// No description provided for @uiNaturalLanguageVoiceDescriptionAtSynthesisTimePrependItToTheText.
  ///
  /// In en, this message translates to:
  /// **'Natural-language voice description. At synthesis time, prepend it to the text in parentheses — e.g.\n(A young woman, gentle and sweet voice)'**
  String get uiNaturalLanguageVoiceDescriptionAtSynthesisTimePrependItToTheText;

  /// No description provided for @uiNewBank.
  ///
  /// In en, this message translates to:
  /// **'New Bank'**
  String get uiNewBank;

  /// No description provided for @uiNewCharacter.
  ///
  /// In en, this message translates to:
  /// **'New Character'**
  String get uiNewCharacter;

  /// No description provided for @uiNewCharacterAddedToThisBank.
  ///
  /// In en, this message translates to:
  /// **'New Character (added to this bank)'**
  String get uiNewCharacterAddedToThisBank;

  /// No description provided for @uiNewDialogTTSProject.
  ///
  /// In en, this message translates to:
  /// **'New Dialog TTS Project'**
  String get uiNewDialogTTSProject;

  /// No description provided for @uiNewName.
  ///
  /// In en, this message translates to:
  /// **'New name'**
  String get uiNewName;

  /// No description provided for @uiNewNovel.
  ///
  /// In en, this message translates to:
  /// **'New Novel'**
  String get uiNewNovel;

  /// No description provided for @uiNewPhaseTTSProject.
  ///
  /// In en, this message translates to:
  /// **'New Phase TTS Project'**
  String get uiNewPhaseTTSProject;

  /// No description provided for @uiNewProject.
  ///
  /// In en, this message translates to:
  /// **'New Project'**
  String get uiNewProject;

  /// No description provided for @uiNewSplitRule.
  ///
  /// In en, this message translates to:
  /// **'New Split Rule'**
  String get uiNewSplitRule;

  /// No description provided for @uiNewVideoDubProject.
  ///
  /// In en, this message translates to:
  /// **'New Video Dub Project'**
  String get uiNewVideoDubProject;

  /// No description provided for @uiNewVoiceBank.
  ///
  /// In en, this message translates to:
  /// **'New Voice Bank'**
  String get uiNewVoiceBank;

  /// No description provided for @uiNewVoiceCharacter.
  ///
  /// In en, this message translates to:
  /// **'New Voice Character'**
  String get uiNewVoiceCharacter;

  /// No description provided for @uiNextChapter.
  ///
  /// In en, this message translates to:
  /// **'Next chapter'**
  String get uiNextChapter;

  /// No description provided for @uiNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get uiNextPage;

  /// No description provided for @uiNextVoice.
  ///
  /// In en, this message translates to:
  /// **'Next voice'**
  String get uiNextVoice;

  /// No description provided for @uiNoAPIRequestsLoggedYet.
  ///
  /// In en, this message translates to:
  /// **'No API requests logged yet.'**
  String get uiNoAPIRequestsLoggedYet;

  /// No description provided for @uiNoAudioTracksYet.
  ///
  /// In en, this message translates to:
  /// **'No audio tracks yet'**
  String get uiNoAudioTracksYet;

  /// No description provided for @uiNoBanksYet.
  ///
  /// In en, this message translates to:
  /// **'No banks yet'**
  String get uiNoBanksYet;

  /// No description provided for @uiNoCharactersInThisBankYet.
  ///
  /// In en, this message translates to:
  /// **'No characters in this bank yet'**
  String get uiNoCharactersInThisBankYet;

  /// No description provided for @uiNoCuesFoundInFile.
  ///
  /// In en, this message translates to:
  /// **'No cues found in file'**
  String get uiNoCuesFoundInFile;

  /// No description provided for @uiNoCuesYetImportAnSRTLRCFileOrAddOneManually.
  ///
  /// In en, this message translates to:
  /// **'No cues yet.\nImport an SRT/LRC file or add one manually.'**
  String get uiNoCuesYetImportAnSRTLRCFileOrAddOneManually;

  /// No description provided for @uiNoDialogProjectsYet.
  ///
  /// In en, this message translates to:
  /// **'No dialog projects yet'**
  String get uiNoDialogProjectsYet;

  /// No description provided for @uiNoGeneratedSegmentsToMerge.
  ///
  /// In en, this message translates to:
  /// **'No generated segments to merge.'**
  String get uiNoGeneratedSegmentsToMerge;

  /// No description provided for @uiNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get uiNoMatches;

  /// No description provided for @uiNoModelsOrVoicesYetUseFetchAllOrAddManually.
  ///
  /// In en, this message translates to:
  /// **'No models or voices yet. Use \"Fetch All\" or add manually.'**
  String get uiNoModelsOrVoicesYetUseFetchAllOrAddManually;

  /// No description provided for @uiNoPerSentenceStyleControls.
  ///
  /// In en, this message translates to:
  /// **'No per-sentence style controls'**
  String get uiNoPerSentenceStyleControls;

  /// No description provided for @uiNoProjectsYet.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get uiNoProjectsYet;

  /// No description provided for @uiNoProvidersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No providers available'**
  String get uiNoProvidersAvailable;

  /// No description provided for @uiNoProvidersYet.
  ///
  /// In en, this message translates to:
  /// **'No providers yet'**
  String get uiNoProvidersYet;

  /// No description provided for @uiNoRule.
  ///
  /// In en, this message translates to:
  /// **'No rule'**
  String get uiNoRule;

  /// No description provided for @uiNoRules.
  ///
  /// In en, this message translates to:
  /// **'No rules'**
  String get uiNoRules;

  /// No description provided for @uiNoTTSModelsFoundGoToProvidersFetchAllToCacheAvailable.
  ///
  /// In en, this message translates to:
  /// **'No TTS models found. Go to Providers → Fetch All to cache available models.'**
  String get uiNoTTSModelsFoundGoToProvidersFetchAllToCacheAvailable;

  /// No description provided for @uiNoUnfinishedTTSTasksRightNow.
  ///
  /// In en, this message translates to:
  /// **'No unfinished TTS tasks right now.'**
  String get uiNoUnfinishedTTSTasksRightNow;

  /// No description provided for @uiNoVideoDubProjectsYet.
  ///
  /// In en, this message translates to:
  /// **'No video dub projects yet'**
  String get uiNoVideoDubProjectsYet;

  /// No description provided for @uiNoVideoLoaded.
  ///
  /// In en, this message translates to:
  /// **'No video loaded'**
  String get uiNoVideoLoaded;

  /// No description provided for @uiNoVoicesInThisBankAddVoicesInVoiceBank.
  ///
  /// In en, this message translates to:
  /// **'No voices in this bank. Add voices in Voice Bank.'**
  String get uiNoVoicesInThisBankAddVoicesInVoiceBank;

  /// No description provided for @uiNoVoicesYetUseFetchToGetAvailableVoices.
  ///
  /// In en, this message translates to:
  /// **'No voices yet. Use \"Fetch\" to get available voices.'**
  String get uiNoVoicesYetUseFetchToGetAvailableVoices;

  /// No description provided for @uiNoneUploadManually.
  ///
  /// In en, this message translates to:
  /// **'None (upload manually)'**
  String get uiNoneUploadManually;

  /// No description provided for @uiNoneUseUploadedAudioOnly.
  ///
  /// In en, this message translates to:
  /// **'None (use uploaded audio only)'**
  String get uiNoneUseUploadedAudioOnly;

  /// No description provided for @uiNotFoundInstallFfmpegOrSetAPathBelowTheAppWorks.
  ///
  /// In en, this message translates to:
  /// **'Not found. Install ffmpeg (or set a path below) — the app works without it, but waveforms and media probing will be skipped.'**
  String get uiNotFoundInstallFfmpegOrSetAPathBelowTheAppWorks;

  /// No description provided for @uiNothingToExportNoGeneratedTTSA3AudioOrUnmutedV1.
  ///
  /// In en, this message translates to:
  /// **'Nothing to export — no generated TTS, A3 audio, or unmuted V1'**
  String get uiNothingToExportNoGeneratedTTSA3AudioOrUnmutedV1;

  /// No description provided for @uiNovelLongFormNarration.
  ///
  /// In en, this message translates to:
  /// **'Novel & long-form narration'**
  String get uiNovelLongFormNarration;

  /// No description provided for @uiOK.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get uiOK;

  /// No description provided for @uiOnlyPending.
  ///
  /// In en, this message translates to:
  /// **'Only pending'**
  String get uiOnlyPending;

  /// No description provided for @uiOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get uiOpenFolder;

  /// No description provided for @uiOutputSpeakerNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Output Speaker Name (optional)'**
  String get uiOutputSpeakerNameOptional;

  /// No description provided for @uiOverwriteWhileReading.
  ///
  /// In en, this message translates to:
  /// **'Overwrite while reading'**
  String get uiOverwriteWhileReading;

  /// No description provided for @uiPaper.
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get uiPaper;

  /// No description provided for @uiParseFailed.
  ///
  /// In en, this message translates to:
  /// **'Parse failed: {error}'**
  String uiParseFailed(Object error);

  /// No description provided for @uiPasteYourNovelTextHereEachParagraphBecomesATTSSegment.
  ///
  /// In en, this message translates to:
  /// **'Paste your novel text here...\n\nEach paragraph becomes a TTS segment.'**
  String get uiPasteYourNovelTextHereEachParagraphBecomesATTSSegment;

  /// No description provided for @uiPasteYourNovelTextHereUseAutoSplitToBreakItInto.
  ///
  /// In en, this message translates to:
  /// **'Paste your novel text here...\n\nUse Auto Split to break it into TTS segments.'**
  String get uiPasteYourNovelTextHereUseAutoSplitToBreakItInto;

  /// No description provided for @uiPatternIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Pattern is required'**
  String get uiPatternIsRequired;

  /// No description provided for @uiPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get uiPending;

  /// No description provided for @uiPickAClipCollectedInTheApp.
  ///
  /// In en, this message translates to:
  /// **'Pick a clip collected in the app'**
  String get uiPickAClipCollectedInTheApp;

  /// No description provided for @uiPickAnAudioFileFromDisk.
  ///
  /// In en, this message translates to:
  /// **'Pick an audio file from disk'**
  String get uiPickAnAudioFileFromDisk;

  /// No description provided for @uiPickAudio.
  ///
  /// In en, this message translates to:
  /// **'Pick audio'**
  String get uiPickAudio;

  /// No description provided for @uiPlayAllGeneratedAudio.
  ///
  /// In en, this message translates to:
  /// **'Play all generated audio'**
  String get uiPlayAllGeneratedAudio;

  /// No description provided for @uiPlayFromHere.
  ///
  /// In en, this message translates to:
  /// **'Play from here'**
  String get uiPlayFromHere;

  /// No description provided for @uiPLAYBACK.
  ///
  /// In en, this message translates to:
  /// **'PLAYBACK'**
  String get uiPLAYBACK;

  /// No description provided for @uiPlaysTheNewLineOnceItFinishes.
  ///
  /// In en, this message translates to:
  /// **'Plays the new line once it finishes'**
  String get uiPlaysTheNewLineOnceItFinishes;

  /// No description provided for @uiPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get uiPort;

  /// No description provided for @uiPortableNextToExecutable.
  ///
  /// In en, this message translates to:
  /// **'Portable (next to executable)'**
  String get uiPortableNextToExecutable;

  /// No description provided for @uiPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get uiPreview;

  /// No description provided for @uiPreviousChapter.
  ///
  /// In en, this message translates to:
  /// **'Previous chapter'**
  String get uiPreviousChapter;

  /// No description provided for @uiPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get uiPreviousPage;

  /// No description provided for @uiPreviousVoice.
  ///
  /// In en, this message translates to:
  /// **'Previous voice'**
  String get uiPreviousVoice;

  /// No description provided for @uiProbing.
  ///
  /// In en, this message translates to:
  /// **'Probing…'**
  String get uiProbing;

  /// No description provided for @uiProjectName.
  ///
  /// In en, this message translates to:
  /// **'Project name'**
  String get uiProjectName;

  /// No description provided for @uiPromptLanguage.
  ///
  /// In en, this message translates to:
  /// **'Prompt Language'**
  String get uiPromptLanguage;

  /// No description provided for @uiPromptTextSpokenInRefAudio.
  ///
  /// In en, this message translates to:
  /// **'Prompt Text (spoken in ref audio)'**
  String get uiPromptTextSpokenInRefAudio;

  /// No description provided for @uiPromptTextSpokenInRefAudio2.
  ///
  /// In en, this message translates to:
  /// **'Prompt Text (spoken in ref audio) *'**
  String get uiPromptTextSpokenInRefAudio2;

  /// No description provided for @uiProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get uiProvider;

  /// No description provided for @uiProviderNotFoundForThisCharacter.
  ///
  /// In en, this message translates to:
  /// **'Provider not found for this character'**
  String get uiProviderNotFoundForThisCharacter;

  /// No description provided for @uiQueueRateLimits.
  ///
  /// In en, this message translates to:
  /// **'Queue & Rate Limits'**
  String get uiQueueRateLimits;

  /// No description provided for @uiQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get uiQueued;

  /// No description provided for @uiQUICKTEST.
  ///
  /// In en, this message translates to:
  /// **'QUICK TEST'**
  String get uiQUICKTEST;

  /// No description provided for @uiRateLimitReqMinIP0Off.
  ///
  /// In en, this message translates to:
  /// **'Rate limit (req/min/IP, 0 = off)'**
  String get uiRateLimitReqMinIP0Off;

  /// No description provided for @uiReCheck.
  ///
  /// In en, this message translates to:
  /// **'Re-check'**
  String get uiReCheck;

  /// No description provided for @uiReRecord.
  ///
  /// In en, this message translates to:
  /// **'Re-record'**
  String get uiReRecord;

  /// No description provided for @uiReaderAppearance.
  ///
  /// In en, this message translates to:
  /// **'Reader appearance'**
  String get uiReaderAppearance;

  /// No description provided for @uiReaderAppearance2.
  ///
  /// In en, this message translates to:
  /// **'Reader Appearance'**
  String get uiReaderAppearance2;

  /// No description provided for @uiRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get uiRecent;

  /// No description provided for @uiRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get uiRecord;

  /// No description provided for @uiRecordAudio.
  ///
  /// In en, this message translates to:
  /// **'Record Audio'**
  String get uiRecordAudio;

  /// No description provided for @uiRecordExternalAPIRequestMetadataInThisPanelRequestBodiesAndAuth.
  ///
  /// In en, this message translates to:
  /// **'Record external API request metadata in this panel. Request bodies and auth headers are not stored.'**
  String get uiRecordExternalAPIRequestMetadataInThisPanelRequestBodiesAndAuth;

  /// No description provided for @uiRecordingFailed.
  ///
  /// In en, this message translates to:
  /// **'Recording failed: {error}'**
  String uiRecordingFailed(Object error);

  /// No description provided for @uiREFERENCEAUDIO.
  ///
  /// In en, this message translates to:
  /// **'REFERENCE AUDIO'**
  String get uiREFERENCEAUDIO;

  /// No description provided for @uiReferenceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Reference Language'**
  String get uiReferenceLanguage;

  /// No description provided for @uiReferenceText.
  ///
  /// In en, this message translates to:
  /// **'Reference Text'**
  String get uiReferenceText;

  /// No description provided for @uiReferenceTranscript.
  ///
  /// In en, this message translates to:
  /// **'Reference Transcript'**
  String get uiReferenceTranscript;

  /// No description provided for @uiRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get uiRegenerate;

  /// No description provided for @uiRegenerateAll.
  ///
  /// In en, this message translates to:
  /// **'Regenerate all'**
  String get uiRegenerateAll;

  /// No description provided for @uiRegexPattern.
  ///
  /// In en, this message translates to:
  /// **'Regex pattern'**
  String get uiRegexPattern;

  /// No description provided for @uiRegisteredVoice.
  ///
  /// In en, this message translates to:
  /// **'Registered Voice'**
  String get uiRegisteredVoice;

  /// No description provided for @uiRemoveFromBank.
  ///
  /// In en, this message translates to:
  /// **'Remove from bank'**
  String get uiRemoveFromBank;

  /// No description provided for @uiRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get uiRename;

  /// No description provided for @uiRenameVoiceBank.
  ///
  /// In en, this message translates to:
  /// **'Rename Voice Bank'**
  String get uiRenameVoiceBank;

  /// No description provided for @uiReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get uiReplace;

  /// No description provided for @uiReplaceOriginal.
  ///
  /// In en, this message translates to:
  /// **'Replace original'**
  String get uiReplaceOriginal;

  /// No description provided for @uiRequestsDay.
  ///
  /// In en, this message translates to:
  /// **'Requests / day'**
  String get uiRequestsDay;

  /// No description provided for @uiRequestsMin.
  ///
  /// In en, this message translates to:
  /// **'Requests / min'**
  String get uiRequestsMin;

  /// No description provided for @uiReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get uiReset;

  /// No description provided for @uiRunAutoSplitToCreateSegments.
  ///
  /// In en, this message translates to:
  /// **'Run Auto Split to create segments'**
  String get uiRunAutoSplitToCreateSegments;

  /// No description provided for @uiRunGenerateAllImmediatelyCuesWithoutAVoiceAreSkipped.
  ///
  /// In en, this message translates to:
  /// **'Run Generate All immediately. Cues without a voice are skipped.'**
  String get uiRunGenerateAllImmediatelyCuesWithoutAVoiceAreSkipped;

  /// No description provided for @uiRunTTSForThisCueImmediatelyAfterSavingNeedsAVoiceIn.
  ///
  /// In en, this message translates to:
  /// **'Run TTS for this cue immediately after saving. Needs a voice in the bank.'**
  String get uiRunTTSForThisCueImmediatelyAfterSavingNeedsAVoiceIn;

  /// No description provided for @uiRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get uiRunning;

  /// No description provided for @uiRunningOn.
  ///
  /// In en, this message translates to:
  /// **'Running on {address}'**
  String uiRunningOn(Object address);

  /// No description provided for @uiSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get uiSave;

  /// No description provided for @uiSaveExit.
  ///
  /// In en, this message translates to:
  /// **'Save & Exit'**
  String get uiSaveExit;

  /// No description provided for @uiSaveLeave.
  ///
  /// In en, this message translates to:
  /// **'Save & Leave'**
  String get uiSaveLeave;

  /// No description provided for @uiSaveRestart.
  ///
  /// In en, this message translates to:
  /// **'Save & restart'**
  String get uiSaveRestart;

  /// No description provided for @uiSaveAsNew.
  ///
  /// In en, this message translates to:
  /// **'Save as new'**
  String get uiSaveAsNew;

  /// No description provided for @uiSaveAsVoiceAsset.
  ///
  /// In en, this message translates to:
  /// **'Save as Voice Asset'**
  String get uiSaveAsVoiceAsset;

  /// No description provided for @uiSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get uiSaveChanges;

  /// No description provided for @uiSaveSegment.
  ///
  /// In en, this message translates to:
  /// **'Save segment'**
  String get uiSaveSegment;

  /// No description provided for @uiSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get uiSaved;

  /// No description provided for @uiSavedToVoiceAssets.
  ///
  /// In en, this message translates to:
  /// **'Saved \"{name}\" to Voice Assets'**
  String uiSavedToVoiceAssets(Object name);

  /// No description provided for @uiScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String uiScanFailed(Object error);

  /// No description provided for @uiScanNow.
  ///
  /// In en, this message translates to:
  /// **'Scan Now'**
  String get uiScanNow;

  /// No description provided for @uiScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get uiScanning;

  /// No description provided for @uiSCRIPT.
  ///
  /// In en, this message translates to:
  /// **'SCRIPT'**
  String get uiSCRIPT;

  /// No description provided for @uiSearchCharacters.
  ///
  /// In en, this message translates to:
  /// **'Search characters...'**
  String get uiSearchCharacters;

  /// No description provided for @uiSearchProjects.
  ///
  /// In en, this message translates to:
  /// **'Search projects'**
  String get uiSearchProjects;

  /// No description provided for @uiSearchVoices.
  ///
  /// In en, this message translates to:
  /// **'Search voices'**
  String get uiSearchVoices;

  /// No description provided for @uiSearch.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get uiSearch;

  /// No description provided for @uiSEGMENTS.
  ///
  /// In en, this message translates to:
  /// **'SEGMENTS'**
  String get uiSEGMENTS;

  /// No description provided for @uiSelectABankAndCharacterToEdit.
  ///
  /// In en, this message translates to:
  /// **'Select a bank and character to edit'**
  String get uiSelectABankAndCharacterToEdit;

  /// No description provided for @uiSelectACharacterToEdit.
  ///
  /// In en, this message translates to:
  /// **'Select a character to edit'**
  String get uiSelectACharacterToEdit;

  /// No description provided for @uiSelectACharacterToQuickTest.
  ///
  /// In en, this message translates to:
  /// **'Select a character to quick-test'**
  String get uiSelectACharacterToQuickTest;

  /// No description provided for @uiSelectATrack.
  ///
  /// In en, this message translates to:
  /// **'Select a track'**
  String get uiSelectATrack;

  /// No description provided for @uiSelectAVoxCPM2Mode.
  ///
  /// In en, this message translates to:
  /// **'Select a VoxCPM2 mode'**
  String get uiSelectAVoxCPM2Mode;

  /// No description provided for @uiSelectFromVoiceAssets.
  ///
  /// In en, this message translates to:
  /// **'Select from Voice Assets'**
  String get uiSelectFromVoiceAssets;

  /// No description provided for @uiSelectModel.
  ///
  /// In en, this message translates to:
  /// **'Select Model'**
  String get uiSelectModel;

  /// No description provided for @uiSelectOrAddAProvider.
  ///
  /// In en, this message translates to:
  /// **'Select or add a provider'**
  String get uiSelectOrAddAProvider;

  /// No description provided for @uiSelectOrCreateAVoiceBank.
  ///
  /// In en, this message translates to:
  /// **'Select or create a Voice Bank'**
  String get uiSelectOrCreateAVoiceBank;

  /// No description provided for @uiSelectOrEnterAGPTSoVITSSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Select or enter a GPT-SoVITS speaker'**
  String get uiSelectOrEnterAGPTSoVITSSpeaker;

  /// No description provided for @uiSelectSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Select Speaker'**
  String get uiSelectSpeaker;

  /// No description provided for @uiSelectVoice.
  ///
  /// In en, this message translates to:
  /// **'Select Voice'**
  String get uiSelectVoice;

  /// No description provided for @uiSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Send failed: {error}'**
  String uiSendFailed(Object error);

  /// No description provided for @uiSentenceVoice.
  ///
  /// In en, this message translates to:
  /// **'Sentence Voice'**
  String get uiSentenceVoice;

  /// No description provided for @uiServerProfile.
  ///
  /// In en, this message translates to:
  /// **'Server Profile'**
  String get uiServerProfile;

  /// No description provided for @uiSETTINGS.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get uiSETTINGS;

  /// No description provided for @uiSingleAudioTracksForVoiceCloning.
  ///
  /// In en, this message translates to:
  /// **'Single audio tracks for voice cloning'**
  String get uiSingleAudioTracksForVoiceCloning;

  /// No description provided for @uiSkipPunctuationOnlyText.
  ///
  /// In en, this message translates to:
  /// **'Skip punctuation-only text'**
  String get uiSkipPunctuationOnlyText;

  /// No description provided for @uiSlice.
  ///
  /// In en, this message translates to:
  /// **'Slice'**
  String get uiSlice;

  /// No description provided for @uiSliceAfterPunctuation.
  ///
  /// In en, this message translates to:
  /// **'Slice after punctuation'**
  String get uiSliceAfterPunctuation;

  /// No description provided for @uiSourceBank.
  ///
  /// In en, this message translates to:
  /// **'Source Bank'**
  String get uiSourceBank;

  /// No description provided for @uiSourceVideoMissingOnDisk.
  ///
  /// In en, this message translates to:
  /// **'Source video missing on disk'**
  String get uiSourceVideoMissingOnDisk;

  /// No description provided for @uiSpaceEnterPToPlayOrStop.
  ///
  /// In en, this message translates to:
  /// **'Space / Enter / P to play or stop'**
  String get uiSpaceEnterPToPlayOrStop;

  /// No description provided for @uiSpeakerVoiceID.
  ///
  /// In en, this message translates to:
  /// **'Speaker / Voice ID *'**
  String get uiSpeakerVoiceID;

  /// No description provided for @uiSpeed10Normal.
  ///
  /// In en, this message translates to:
  /// **'Speed (1.0 = normal)'**
  String get uiSpeed10Normal;

  /// No description provided for @uiSplitAtBlankLines.
  ///
  /// In en, this message translates to:
  /// **'Split at blank lines'**
  String get uiSplitAtBlankLines;

  /// No description provided for @uiSplitAtRegexMatch.
  ///
  /// In en, this message translates to:
  /// **'Split at regex match'**
  String get uiSplitAtRegexMatch;

  /// No description provided for @uiSplitRules.
  ///
  /// In en, this message translates to:
  /// **'Split Rules'**
  String get uiSplitRules;

  /// No description provided for @uiStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get uiStart;

  /// No description provided for @uiStartMmSsMs.
  ///
  /// In en, this message translates to:
  /// **'Start (mm:ss.ms)'**
  String get uiStartMmSsMs;

  /// No description provided for @uiSTATS.
  ///
  /// In en, this message translates to:
  /// **'STATS'**
  String get uiSTATS;

  /// No description provided for @uiStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get uiStopped;

  /// No description provided for @uiStyleDirection.
  ///
  /// In en, this message translates to:
  /// **'Style / direction'**
  String get uiStyleDirection;

  /// No description provided for @uiStyleInstruction.
  ///
  /// In en, this message translates to:
  /// **'Style Instruction'**
  String get uiStyleInstruction;

  /// No description provided for @uiStyleInstructionOptional.
  ///
  /// In en, this message translates to:
  /// **'Style Instruction (optional)'**
  String get uiStyleInstructionOptional;

  /// No description provided for @uiSubtitleText.
  ///
  /// In en, this message translates to:
  /// **'Subtitle text'**
  String get uiSubtitleText;

  /// No description provided for @uiSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get uiSubtitles;

  /// No description provided for @uiSyncCueLengthsToTTS.
  ///
  /// In en, this message translates to:
  /// **'Sync cue lengths to TTS'**
  String get uiSyncCueLengthsToTTS;

  /// No description provided for @uiSyncWithDisk.
  ///
  /// In en, this message translates to:
  /// **'Sync with Disk'**
  String get uiSyncWithDisk;

  /// No description provided for @uiSynthesizeTTSRightAfterSending.
  ///
  /// In en, this message translates to:
  /// **'Synthesize TTS right after sending'**
  String get uiSynthesizeTTSRightAfterSending;

  /// No description provided for @uiTapToChange.
  ///
  /// In en, this message translates to:
  /// **'Tap to change'**
  String get uiTapToChange;

  /// No description provided for @uiTextIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Text is required'**
  String get uiTextIsRequired;

  /// No description provided for @uiTextLanguageOptional.
  ///
  /// In en, this message translates to:
  /// **'Text Language (optional)'**
  String get uiTextLanguageOptional;

  /// No description provided for @uiTextLanguageSynthesisOutput.
  ///
  /// In en, this message translates to:
  /// **'Text Language (synthesis output)'**
  String get uiTextLanguageSynthesisOutput;

  /// No description provided for @uiThisProjectAlreadyHasCuesReplaceThemOrAppendTheNewCues.
  ///
  /// In en, this message translates to:
  /// **'This project already has {count} cues. Replace them, or append the new cues after?'**
  String uiThisProjectAlreadyHasCuesReplaceThemOrAppendTheNewCues(Object count);

  /// No description provided for @uiTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get uiTimeline;

  /// No description provided for @uiTotalLength.
  ///
  /// In en, this message translates to:
  /// **'Total length'**
  String get uiTotalLength;

  /// No description provided for @uiTranscriptOfTheAudioUsedByVoiceCloningModelsThatNeedIt.
  ///
  /// In en, this message translates to:
  /// **'Transcript of the audio (used by voice cloning models that need it)'**
  String get uiTranscriptOfTheAudioUsedByVoiceCloningModelsThatNeedIt;

  /// No description provided for @uiTranscriptOfTheReferenceAudio.
  ///
  /// In en, this message translates to:
  /// **'Transcript of the reference audio'**
  String get uiTranscriptOfTheReferenceAudio;

  /// No description provided for @uiTrim.
  ///
  /// In en, this message translates to:
  /// **'Trim'**
  String get uiTrim;

  /// No description provided for @uiTrimApplied.
  ///
  /// In en, this message translates to:
  /// **'Trim applied'**
  String get uiTrimApplied;

  /// No description provided for @uiTTSQueueIsIdle.
  ///
  /// In en, this message translates to:
  /// **'TTS queue is idle'**
  String get uiTTSQueueIsIdle;

  /// No description provided for @uiTypeBelowToTestThisVoice.
  ///
  /// In en, this message translates to:
  /// **'Type below to test this voice'**
  String get uiTypeBelowToTestThisVoice;

  /// No description provided for @uiTypeDialogLineEnterToSendCtrlEnterForNewline.
  ///
  /// In en, this message translates to:
  /// **'Type dialog line… (Enter to send, Ctrl+Enter for newline)'**
  String get uiTypeDialogLineEnterToSendCtrlEnterForNewline;

  /// No description provided for @uiTypeSomethingToTest.
  ///
  /// In en, this message translates to:
  /// **'Type something to test...'**
  String get uiTypeSomethingToTest;

  /// No description provided for @uiUltraCloneModeRequiresAPromptText.
  ///
  /// In en, this message translates to:
  /// **'Ultra Clone mode requires a Prompt Text'**
  String get uiUltraCloneModeRequiresAPromptText;

  /// No description provided for @uiUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get uiUnknown;

  /// No description provided for @uiUnsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get uiUnsavedChanges;

  /// No description provided for @uiUploadAVoiceSampleTheModelWillCloneItsToneAndSpeak.
  ///
  /// In en, this message translates to:
  /// **'Upload a voice sample — the model will clone its tone and speak the synthesis text in any language.'**
  String get uiUploadAVoiceSampleTheModelWillCloneItsToneAndSpeak;

  /// No description provided for @uiUploadAVoiceSampleToUseAsTheBaseVoiceInsteadOf.
  ///
  /// In en, this message translates to:
  /// **'Upload a voice sample to use as the base voice instead of a preset profile.'**
  String get uiUploadAVoiceSampleToUseAsTheBaseVoiceInsteadOf;

  /// No description provided for @uiUploadAnAudioFileOrRecordANewSampleToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Upload an audio file or record a new sample to get started.'**
  String get uiUploadAnAudioFileOrRecordANewSampleToGetStarted;

  /// No description provided for @uiUploadAudio.
  ///
  /// In en, this message translates to:
  /// **'Upload Audio'**
  String get uiUploadAudio;

  /// No description provided for @uiUseChaptersBelowToImportTXTImportAFolderOrAddA.
  ///
  /// In en, this message translates to:
  /// **'Use Chapters below to import TXT, import a folder, or add a chapter.'**
  String get uiUseChaptersBelowToImportTXTImportAFolderOrAddA;

  /// No description provided for @uiUseFormatMmSsMsOrHHMmSsMs.
  ///
  /// In en, this message translates to:
  /// **'Use format mm:ss.ms or HH:mm:ss.ms'**
  String get uiUseFormatMmSsMsOrHHMmSsMs;

  /// No description provided for @uiUsedByTheVideoDubEditorSExportAudioExportVideoButtons.
  ///
  /// In en, this message translates to:
  /// **'Used by the Video Dub editor\'\'s Export Audio / Export Video buttons.'**
  String get uiUsedByTheVideoDubEditorSExportAudioExportVideoButtons;

  /// No description provided for @uiUsingOverride.
  ///
  /// In en, this message translates to:
  /// **'Using override'**
  String get uiUsingOverride;

  /// No description provided for @uiVideoAudioCodec.
  ///
  /// In en, this message translates to:
  /// **'Video audio codec'**
  String get uiVideoAudioCodec;

  /// No description provided for @uiVideoCodec.
  ///
  /// In en, this message translates to:
  /// **'Video codec'**
  String get uiVideoCodec;

  /// No description provided for @uiVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get uiVoice;

  /// No description provided for @uiVoiceSpeakerID.
  ///
  /// In en, this message translates to:
  /// **'Voice / Speaker ID'**
  String get uiVoiceSpeakerID;

  /// No description provided for @uiVoiceSpeakerName.
  ///
  /// In en, this message translates to:
  /// **'Voice / Speaker Name'**
  String get uiVoiceSpeakerName;

  /// No description provided for @uiVoiceAssetDirectory.
  ///
  /// In en, this message translates to:
  /// **'Voice Asset Directory'**
  String get uiVoiceAssetDirectory;

  /// No description provided for @uiVoiceAssetDirectoryResetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Voice asset directory reset to default'**
  String get uiVoiceAssetDirectoryResetToDefault;

  /// No description provided for @uiVoiceAssetDirectorySetTo.
  ///
  /// In en, this message translates to:
  /// **'Voice asset directory set to {path}'**
  String uiVoiceAssetDirectorySetTo(Object path);

  /// No description provided for @uiVoiceBank.
  ///
  /// In en, this message translates to:
  /// **'Voice bank'**
  String get uiVoiceBank;

  /// No description provided for @uiVoiceDescription.
  ///
  /// In en, this message translates to:
  /// **'Voice Description *'**
  String get uiVoiceDescription;

  /// No description provided for @uiVoiceDesignRequiresAVoiceDescription.
  ///
  /// In en, this message translates to:
  /// **'Voice Design requires a Voice Description'**
  String get uiVoiceDesignRequiresAVoiceDescription;

  /// No description provided for @uiVoiceForAll.
  ///
  /// In en, this message translates to:
  /// **'Voice for all'**
  String get uiVoiceForAll;

  /// No description provided for @uiVoiceInstruction.
  ///
  /// In en, this message translates to:
  /// **'Voice Instruction'**
  String get uiVoiceInstruction;

  /// No description provided for @uiVoiceName.
  ///
  /// In en, this message translates to:
  /// **'Voice Name'**
  String get uiVoiceName;

  /// No description provided for @uiVoiceSettings.
  ///
  /// In en, this message translates to:
  /// **'Voice settings'**
  String get uiVoiceSettings;

  /// No description provided for @uiVOICES.
  ///
  /// In en, this message translates to:
  /// **'VOICES'**
  String get uiVOICES;

  /// No description provided for @uiVOICESINBANK.
  ///
  /// In en, this message translates to:
  /// **'VOICES IN BANK'**
  String get uiVOICESINBANK;

  /// No description provided for @uiWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get uiWaiting;

  /// No description provided for @uiYouCanConfigureTheURLAPIKeyAndModelAfterCreation.
  ///
  /// In en, this message translates to:
  /// **'You can configure the URL, API key, and model after creation.'**
  String get uiYouCanConfigureTheURLAPIKeyAndModelAfterCreation;

  /// No description provided for @uiYouHaveUnsavedChangesInThisProjectSaveBeforeLeaving.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes in this project. Save before leaving?'**
  String get uiYouHaveUnsavedChangesInThisProjectSaveBeforeLeaving;

  /// No description provided for @uiZhEnJaKo.
  ///
  /// In en, this message translates to:
  /// **'zh / en / ja / ko ...'**
  String get uiZhEnJaKo;

  /// No description provided for @uiAudioExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Audio export failed: {error}'**
  String uiAudioExportFailed(Object error);

  /// No description provided for @uiExportedCuesAudioFilesTo.
  ///
  /// In en, this message translates to:
  /// **'Exported {cueCount} cues + {audioCount} audio files to {path}'**
  String uiExportedCuesAudioFilesTo(
    Object cueCount,
    Object audioCount,
    Object path,
  );

  /// No description provided for @uiExportedCuesAudioFilesToMissing.
  ///
  /// In en, this message translates to:
  /// **'Exported {cueCount} cues + {audioCount} audio files to {path} ({missingCount} missing)'**
  String uiExportedCuesAudioFilesToMissing(
    Object cueCount,
    Object audioCount,
    Object path,
    Object missingCount,
  );

  /// No description provided for @uiNoNovelProjectsYet.
  ///
  /// In en, this message translates to:
  /// **'No novel projects yet'**
  String get uiNoNovelProjectsYet;

  /// No description provided for @uiSidecarSRTFailed.
  ///
  /// In en, this message translates to:
  /// **'Sidecar SRT failed: {error}'**
  String uiSidecarSRTFailed(Object error);

  /// No description provided for @uiSRTSidecarWrittenTo.
  ///
  /// In en, this message translates to:
  /// **'SRT sidecar written to {name}.'**
  String uiSRTSidecarWrittenTo(Object name);

  /// No description provided for @startupLastPage.
  ///
  /// In en, this message translates to:
  /// **'Last page before close'**
  String get startupLastPage;

  /// No description provided for @fontSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Interface Font'**
  String get fontSettingsTitle;

  /// No description provided for @fontSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use the app default font or your operating system UI font.'**
  String get fontSettingsSubtitle;

  /// No description provided for @fontModeAppDefault.
  ///
  /// In en, this message translates to:
  /// **'App default'**
  String get fontModeAppDefault;

  /// No description provided for @fontModeSystem.
  ///
  /// In en, this message translates to:
  /// **'System font'**
  String get fontModeSystem;

  /// No description provided for @fontModeSaved.
  ///
  /// In en, this message translates to:
  /// **'Font set to {font}.'**
  String fontModeSaved(String font);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
