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

  /// No description provided for @webFeatureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This feature uses desktop files or media tools. Open Neiroha on desktop to use it.'**
  String get webFeatureUnavailable;

  /// No description provided for @webStorageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Neiroha could not open browser storage. Allow site storage or try a current browser.'**
  String get webStorageUnavailable;

  /// No description provided for @webStorageDescription.
  ///
  /// In en, this message translates to:
  /// **'Providers, voice settings, voice banks and preferences are stored in this browser. Generated audio is kept in memory until the page reloads or the tab closes.'**
  String get webStorageDescription;

  /// No description provided for @webSessionAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio history is cleared when you reload. Download clips you want to keep.'**
  String get webSessionAudio;

  /// No description provided for @webLocalAudioUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Reference audio and avatar files require the desktop app.'**
  String get webLocalAudioUnavailable;

  /// No description provided for @webSpeechAdapterUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This provider adapter is unavailable for web previews. Choose a browser-compatible provider in the character settings.'**
  String get webSpeechAdapterUnavailable;

  /// No description provided for @webSpeechProviderDisabled.
  ///
  /// In en, this message translates to:
  /// **'The provider for this character is disabled. Enable it or choose another provider in the character settings.'**
  String get webSpeechProviderDisabled;

  /// No description provided for @webSpeechEndpointInvalid.
  ///
  /// In en, this message translates to:
  /// **'The provider URL is invalid. Enter a full HTTP(S) address in the provider settings.'**
  String get webSpeechEndpointInvalid;

  /// No description provided for @webRealtimeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'OpenAI Realtime is unavailable on the web. Choose a Speech model in the character settings or use the desktop app.'**
  String get webRealtimeUnavailable;

  /// No description provided for @webGeminiLiveUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This model requires Gemini Live. Choose a Gemini TTS model such as gemini-3.8-flash-tts.'**
  String get webGeminiLiveUnavailable;

  /// No description provided for @webOpenAiRealtimeWrongAdapter.
  ///
  /// In en, this message translates to:
  /// **'For Web playback with the official OpenAI endpoint, choose a Speech model. On desktop, choose the official OpenAI adapter for Realtime.'**
  String get webOpenAiRealtimeWrongAdapter;

  /// No description provided for @webMiMoModelRetired.
  ///
  /// In en, this message translates to:
  /// **'MiMo V2 TTS has retired. Choose mimo-v2.5-tts.'**
  String get webMiMoModelRetired;

  /// No description provided for @webSpeechLocalReference.
  ///
  /// In en, this message translates to:
  /// **'This character requires local reference audio. Use the desktop app or choose a character with a preset voice.'**
  String get webSpeechLocalReference;

  /// No description provided for @webSpeechPresetRequired.
  ///
  /// In en, this message translates to:
  /// **'Select an OpenAI preset voice in the character settings.'**
  String get webSpeechPresetRequired;

  /// No description provided for @webSpeechIncompatibleVoice.
  ///
  /// In en, this message translates to:
  /// **'This voice is incompatible with the selected model. Choose another voice in the character settings.'**
  String get webSpeechIncompatibleVoice;

  /// No description provided for @quickTtsPlaybackMode.
  ///
  /// In en, this message translates to:
  /// **'Preview playback'**
  String get quickTtsPlaybackMode;

  /// No description provided for @quickTtsStreamPlayback.
  ///
  /// In en, this message translates to:
  /// **'Prefer streaming'**
  String get quickTtsStreamPlayback;

  /// No description provided for @quickTtsFullPlayback.
  ///
  /// In en, this message translates to:
  /// **'Generate full clip'**
  String get quickTtsFullPlayback;

  /// No description provided for @webProviderNetworkError.
  ///
  /// In en, this message translates to:
  /// **'The browser could not reach the provider. Check the URL and allow the Neiroha site origin on the provider (CORS).'**
  String get webProviderNetworkError;

  /// No description provided for @webDownloadAudio.
  ///
  /// In en, this message translates to:
  /// **'Download audio'**
  String get webDownloadAudio;

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
  /// **'v0.5.1 - AI Audio Middleware & Dubbing Workstation'**
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

  /// No description provided for @uiAdapterUnavailableOnThisPlatform.
  ///
  /// In en, this message translates to:
  /// **'This adapter is not available on the current platform. It cannot be enabled or used for health checks here.'**
  String get uiAdapterUnavailableOnThisPlatform;

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

  /// No description provided for @uiAppSupportMacOs.
  ///
  /// In en, this message translates to:
  /// **'Application Support (standard macOS location)'**
  String get uiAppSupportMacOs;

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

  /// No description provided for @uiCharacters.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get uiCharacters;

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

  /// No description provided for @uiExportVideo.
  ///
  /// In en, this message translates to:
  /// **'Export Video'**
  String get uiExportVideo;

  /// No description provided for @uiExportBook.
  ///
  /// In en, this message translates to:
  /// **'Export Book'**
  String get uiExportBook;

  /// No description provided for @uiExportNovelAudio.
  ///
  /// In en, this message translates to:
  /// **'Export novel audio'**
  String get uiExportNovelAudio;

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

  /// No description provided for @uiExporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get uiExporting;

  /// No description provided for @uiExportingAudio.
  ///
  /// In en, this message translates to:
  /// **'Exporting audio…'**
  String get uiExportingAudio;

  /// No description provided for @uiExportingNovelAudio.
  ///
  /// In en, this message translates to:
  /// **'Exporting novel audio…'**
  String get uiExportingNovelAudio;

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

  /// No description provided for @uiFFmpegUnavailableOnPlatform.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg CLI features are not available on {platform}. Local muxing, trimming, waveform extraction, and video export are disabled.'**
  String uiFFmpegUnavailableOnPlatform(String platform);

  /// No description provided for @uiFFmpegUnavailableWaveformsAndLocalExportsAreDisabled.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg CLI is not available on this platform — waveforms and local audio/video exports are disabled.'**
  String get uiFFmpegUnavailableWaveformsAndLocalExportsAreDisabled;

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

  /// No description provided for @uiGenerateFullBookCacheBeforeExporting.
  ///
  /// In en, this message translates to:
  /// **'Generate the full book cache before exporting.'**
  String get uiGenerateFullBookCacheBeforeExporting;

  /// No description provided for @uiGenerateAllStopped.
  ///
  /// In en, this message translates to:
  /// **'Generate all stopped: {error}'**
  String uiGenerateAllStopped(Object error);

  /// No description provided for @uiGenerated.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get uiGenerated;

  /// No description provided for @uiGeneratedCues.
  ///
  /// In en, this message translates to:
  /// **'Generated {done} cue(s)'**
  String uiGeneratedCues(Object done);

  /// No description provided for @uiGeneratedCuesWithFailures.
  ///
  /// In en, this message translates to:
  /// **'Generated {done} cue(s), {failed} failed'**
  String uiGeneratedCuesWithFailures(Object done, Object failed);

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

  /// No description provided for @uiLeaveBlankToAutoDetectMacOsFfmpeg.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to auto-detect (e.g. /opt/homebrew/bin/ffmpeg)'**
  String get uiLeaveBlankToAutoDetectMacOsFfmpeg;

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

  /// No description provided for @uiNoCuesToGenerateAssignVoiceFirst.
  ///
  /// In en, this message translates to:
  /// **'No cues to generate — assign a voice first'**
  String get uiNoCuesToGenerateAssignVoiceFirst;

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

  /// No description provided for @uiNoReadableSegmentsToExport.
  ///
  /// In en, this message translates to:
  /// **'No readable segments to export.'**
  String get uiNoReadableSegmentsToExport;

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

  /// No description provided for @uiNovelCacheCompleted.
  ///
  /// In en, this message translates to:
  /// **'Novel cache completed.'**
  String get uiNovelCacheCompleted;

  /// No description provided for @uiNovelCacheCompletedWithFailures.
  ///
  /// In en, this message translates to:
  /// **'Novel cache completed with {failed} failed segment(s).'**
  String uiNovelCacheCompletedWithFailures(Object failed);

  /// No description provided for @uiNovelCacheOverwritten.
  ///
  /// In en, this message translates to:
  /// **'Novel cache overwritten.'**
  String get uiNovelCacheOverwritten;

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

  /// No description provided for @uiProjectSettings.
  ///
  /// In en, this message translates to:
  /// **'Project Settings'**
  String get uiProjectSettings;

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

  /// No description provided for @uiDontSave.
  ///
  /// In en, this message translates to:
  /// **'Don\'\'t save'**
  String get uiDontSave;

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

  /// No description provided for @splitRuleNewlineName.
  ///
  /// In en, this message translates to:
  /// **'By paragraph (blank line)'**
  String get splitRuleNewlineName;

  /// No description provided for @splitRuleSentenceName.
  ///
  /// In en, this message translates to:
  /// **'By sentence punctuation (Chinese / English)'**
  String get splitRuleSentenceName;

  /// No description provided for @splitRuleQuotesName.
  ///
  /// In en, this message translates to:
  /// **'By closing quote (Chinese / English)'**
  String get splitRuleQuotesName;

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

  /// No description provided for @uiUnavailableOnThisPlatform.
  ///
  /// In en, this message translates to:
  /// **'Unavailable on this platform'**
  String get uiUnavailableOnThisPlatform;

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

  /// No description provided for @uiVoiceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} voices'**
  String uiVoiceCount(Object count);

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

  /// No description provided for @healthCheckTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Check Timeout'**
  String get healthCheckTimeoutTitle;

  /// No description provided for @healthCheckTimeoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stop provider and voice-bank checks that hang too long.'**
  String get healthCheckTimeoutSubtitle;

  /// No description provided for @healthCheckTimeoutSaved.
  ///
  /// In en, this message translates to:
  /// **'Health check timeout saved: {seconds}s'**
  String healthCheckTimeoutSaved(int seconds);

  /// No description provided for @healthCheckFailedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Health check failed'**
  String get healthCheckFailedTooltip;

  /// No description provided for @uiDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get uiDisabled;

  /// No description provided for @uiProviderMissing.
  ///
  /// In en, this message translates to:
  /// **'Provider missing'**
  String get uiProviderMissing;

  /// No description provided for @uiReachable.
  ///
  /// In en, this message translates to:
  /// **'Reachable'**
  String get uiReachable;

  /// No description provided for @uiUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Unreachable'**
  String get uiUnreachable;

  /// No description provided for @uiNoHealthCheckResults.
  ///
  /// In en, this message translates to:
  /// **'No health check results.'**
  String get uiNoHealthCheckResults;

  /// No description provided for @unhealthyVoiceWarning.
  ///
  /// In en, this message translates to:
  /// **'Health check failed for {voice}. Generation may fail.'**
  String unhealthyVoiceWarning(String voice);

  /// No description provided for @novelPureReadingMode.
  ///
  /// In en, this message translates to:
  /// **'Pure reading mode'**
  String get novelPureReadingMode;

  /// No description provided for @novelPlaybackGap.
  ///
  /// In en, this message translates to:
  /// **'Gap'**
  String get novelPlaybackGap;

  /// No description provided for @novelTextFilters.
  ///
  /// In en, this message translates to:
  /// **'Text Filters'**
  String get novelTextFilters;

  /// No description provided for @novelTextFilterRules.
  ///
  /// In en, this message translates to:
  /// **'Text Filter Rules'**
  String get novelTextFilterRules;

  /// No description provided for @novelNewTextFilterRule.
  ///
  /// In en, this message translates to:
  /// **'New Text Filter Rule'**
  String get novelNewTextFilterRule;

  /// No description provided for @novelEditTextFilterRule.
  ///
  /// In en, this message translates to:
  /// **'Edit Text Filter Rule'**
  String get novelEditTextFilterRule;

  /// No description provided for @novelReplacement.
  ///
  /// In en, this message translates to:
  /// **'Replacement'**
  String get novelReplacement;

  /// No description provided for @novelReplacementHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to remove matched text.'**
  String get novelReplacementHint;

  /// No description provided for @novelPatternRequired.
  ///
  /// In en, this message translates to:
  /// **'Pattern is required'**
  String get novelPatternRequired;

  /// No description provided for @novelSaveApply.
  ///
  /// In en, this message translates to:
  /// **'Save & Apply'**
  String get novelSaveApply;

  /// No description provided for @pressBackAgainToExit.
  ///
  /// In en, this message translates to:
  /// **'Press Back again to exit.'**
  String get pressBackAgainToExit;

  /// No description provided for @uiVideoDubMissingVoiceSkippedText.
  ///
  /// In en, this message translates to:
  /// **'{missingVoice} without a voice will be skipped. '**
  String uiVideoDubMissingVoiceSkippedText(Object missingVoice);

  /// No description provided for @uiVideoDubRegenerateExistingCuesPrompt.
  ///
  /// In en, this message translates to:
  /// **'{alreadyDone} cue(s) already have audio. {pending} pending. {missingVoiceText}Regenerate the existing ones too, or only fill in the gaps?'**
  String uiVideoDubRegenerateExistingCuesPrompt(
    Object alreadyDone,
    Object pending,
    Object missingVoiceText,
  );

  /// No description provided for @uiAutoTtsSkippedNoVoices.
  ///
  /// In en, this message translates to:
  /// **'Auto-TTS skipped — bank has no voices'**
  String get uiAutoTtsSkippedNoVoices;

  /// No description provided for @uiVideoDubUnavailableOnAndroidPhone.
  ///
  /// In en, this message translates to:
  /// **'Video Dub is disabled on Android phones'**
  String get uiVideoDubUnavailableOnAndroidPhone;

  /// No description provided for @uiVideoDubUnavailableOnAndroidPhoneDescription.
  ///
  /// In en, this message translates to:
  /// **'Video editing needs more horizontal space than tall phone screens can provide. Use a tablet, foldable wide layout, or desktop to edit video dubbing projects.'**
  String get uiVideoDubUnavailableOnAndroidPhoneDescription;

  /// No description provided for @uiDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get uiDetails;

  /// No description provided for @uiVoiceForImportedCues.
  ///
  /// In en, this message translates to:
  /// **'Voice for imported cues'**
  String get uiVoiceForImportedCues;

  /// No description provided for @uiVoiceForImportedCuesHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a character from the voice bank of this project, or leave cues unassigned and cast them one by one.'**
  String get uiVoiceForImportedCuesHint;

  /// No description provided for @uiLeaveUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Leave unassigned'**
  String get uiLeaveUnassigned;

  /// No description provided for @uiCloudVoiceCloneHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a voice above, or add a reference audio to clone a new voice on the provider account when saving.'**
  String get uiCloudVoiceCloneHint;

  /// No description provided for @uiCloudVoiceCloneFailed.
  ///
  /// In en, this message translates to:
  /// **'Voice clone failed: {error}'**
  String uiCloudVoiceCloneFailed(Object error);

  /// No description provided for @uiIndexTtsEmotionHint.
  ///
  /// In en, this message translates to:
  /// **'Optional emotion description (needs the experimental emotion mode of the WebUI)'**
  String get uiIndexTtsEmotionHint;

  /// No description provided for @uiApiAutoStart.
  ///
  /// In en, this message translates to:
  /// **'Start API server on launch'**
  String get uiApiAutoStart;

  /// No description provided for @uiApiAutoStartDescription.
  ///
  /// In en, this message translates to:
  /// **'Start the local API and MCP server automatically when Neiroha opens, so agents can connect without a manual toggle.'**
  String get uiApiAutoStartDescription;

  /// No description provided for @uiMcpEndpoint.
  ///
  /// In en, this message translates to:
  /// **'MCP server for AI agents'**
  String get uiMcpEndpoint;

  /// No description provided for @uiMcpEndpointDescription.
  ///
  /// In en, this message translates to:
  /// **'Lets agents manage providers, voices and dubbing jobs at {url} (streamable HTTP). Uses the API key above when set.'**
  String uiMcpEndpointDescription(Object url);

  /// No description provided for @loudnessAction.
  ///
  /// In en, this message translates to:
  /// **'Unify loudness'**
  String get loudnessAction;

  /// No description provided for @loudnessActionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Bring every generated clip to the same loudness'**
  String get loudnessActionTooltip;

  /// No description provided for @loudnessTitle.
  ///
  /// In en, this message translates to:
  /// **'Unify Loudness'**
  String get loudnessTitle;

  /// No description provided for @loudnessIntro.
  ///
  /// In en, this message translates to:
  /// **'Measures the perceived loudness (LUFS) of {count} generated clips and brings each one to the same target. Only the gain changes; a limiter keeps peaks from clipping. Files are rewritten in place, so timelines and exports pick up the result automatically.'**
  String loudnessIntro(Object count);

  /// No description provided for @loudnessTarget.
  ///
  /// In en, this message translates to:
  /// **'TARGET LOUDNESS'**
  String get loudnessTarget;

  /// No description provided for @loudnessPresetLoud.
  ///
  /// In en, this message translates to:
  /// **'Loud'**
  String get loudnessPresetLoud;

  /// No description provided for @loudnessPresetLoudHint.
  ///
  /// In en, this message translates to:
  /// **'-14 LUFS · short-video and music platforms'**
  String get loudnessPresetLoudHint;

  /// No description provided for @loudnessPresetStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get loudnessPresetStandard;

  /// No description provided for @loudnessPresetStandardHint.
  ///
  /// In en, this message translates to:
  /// **'-16 LUFS · podcasts, audiobooks, narration'**
  String get loudnessPresetStandardHint;

  /// No description provided for @loudnessPresetSoft.
  ///
  /// In en, this message translates to:
  /// **'Soft'**
  String get loudnessPresetSoft;

  /// No description provided for @loudnessPresetSoftHint.
  ///
  /// In en, this message translates to:
  /// **'-20 LUFS · ASMR, sleep and whisper content'**
  String get loudnessPresetSoftHint;

  /// No description provided for @loudnessPresetBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Broadcast'**
  String get loudnessPresetBroadcast;

  /// No description provided for @loudnessPresetBroadcastHint.
  ///
  /// In en, this message translates to:
  /// **'-23 LUFS · EBU R128 broadcast standard'**
  String get loudnessPresetBroadcastHint;

  /// No description provided for @loudnessPresetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get loudnessPresetCustom;

  /// No description provided for @loudnessPresetCustomHint.
  ///
  /// In en, this message translates to:
  /// **'Pick any target between -30 and -10 LUFS'**
  String get loudnessPresetCustomHint;

  /// No description provided for @loudnessKeepBackup.
  ///
  /// In en, this message translates to:
  /// **'Keep original backups'**
  String get loudnessKeepBackup;

  /// No description provided for @loudnessKeepBackupHint.
  ///
  /// In en, this message translates to:
  /// **'Originals go to an _original_audio folder next to the clips. Later runs always start from them, so you can change the target without stacking quality loss.'**
  String get loudnessKeepBackupHint;

  /// No description provided for @loudnessAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get loudnessAnalyze;

  /// No description provided for @loudnessAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing {done} / {total}'**
  String loudnessAnalyzing(Object done, Object total);

  /// No description provided for @loudnessApplying.
  ///
  /// In en, this message translates to:
  /// **'Processing {done} / {total}'**
  String loudnessApplying(Object done, Object total);

  /// No description provided for @loudnessApply.
  ///
  /// In en, this message translates to:
  /// **'Unify {count} clips'**
  String loudnessApply(Object count);

  /// No description provided for @loudnessRange.
  ///
  /// In en, this message translates to:
  /// **'Current range'**
  String get loudnessRange;

  /// No description provided for @loudnessSpread.
  ///
  /// In en, this message translates to:
  /// **'Spread'**
  String get loudnessSpread;

  /// No description provided for @loudnessNeedsChange.
  ///
  /// In en, this message translates to:
  /// **'To adjust'**
  String get loudnessNeedsChange;

  /// No description provided for @loudnessSummary.
  ///
  /// In en, this message translates to:
  /// **'Adjusted {adjusted} · already on target {onTarget} · silent, skipped {silent} · failed {failed}'**
  String loudnessSummary(
    Object adjusted,
    Object onTarget,
    Object silent,
    Object failed,
  );

  /// No description provided for @loudnessLastError.
  ///
  /// In en, this message translates to:
  /// **'Last error: {error}'**
  String loudnessLastError(Object error);

  /// No description provided for @loudnessNoAudio.
  ///
  /// In en, this message translates to:
  /// **'No generated audio to unify yet.'**
  String get loudnessNoAudio;

  /// No description provided for @loudnessFfmpegRequired.
  ///
  /// In en, this message translates to:
  /// **'Unifying loudness needs FFmpeg — configure it in Settings.'**
  String get loudnessFfmpegRequired;

  /// No description provided for @loudnessStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get loudnessStop;

  /// No description provided for @phaseStatsGenerated.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} generated'**
  String phaseStatsGenerated(Object done, Object total);

  /// No description provided for @phaseStatsFailed.
  ///
  /// In en, this message translates to:
  /// **'{count} failed'**
  String phaseStatsFailed(Object count);

  /// No description provided for @phaseStatsUnassigned.
  ///
  /// In en, this message translates to:
  /// **'{count} without voice'**
  String phaseStatsUnassigned(Object count);

  /// No description provided for @phaseFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get phaseFilterAll;

  /// No description provided for @phaseFilterPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get phaseFilterPending;

  /// No description provided for @phaseFilterDone.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get phaseFilterDone;

  /// No description provided for @phaseFilterFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get phaseFilterFailed;

  /// No description provided for @phaseNoFilterMatches.
  ///
  /// In en, this message translates to:
  /// **'No segments match this filter.'**
  String get phaseNoFilterMatches;

  /// No description provided for @phaseApplyVoiceToAll.
  ///
  /// In en, this message translates to:
  /// **'Apply to all'**
  String get phaseApplyVoiceToAll;

  /// No description provided for @phaseEditText.
  ///
  /// In en, this message translates to:
  /// **'Edit text'**
  String get phaseEditText;

  /// No description provided for @phaseEditTextHint.
  ///
  /// In en, this message translates to:
  /// **'Saving changed text clears the generated audio of this segment.'**
  String get phaseEditTextHint;

  /// No description provided for @phaseResplitTitle.
  ///
  /// In en, this message translates to:
  /// **'Re-split the script?'**
  String get phaseResplitTitle;

  /// No description provided for @phaseResplitBody.
  ///
  /// In en, this message translates to:
  /// **'This replaces the current {count} segments together with their voice assignments, style settings and generated audio links.'**
  String phaseResplitBody(Object count);

  /// No description provided for @phaseResplitConfirm.
  ///
  /// In en, this message translates to:
  /// **'Re-split'**
  String get phaseResplitConfirm;

  /// No description provided for @phaseCharCount.
  ///
  /// In en, this message translates to:
  /// **'{count} chars'**
  String phaseCharCount(Object count);

  /// No description provided for @phasePlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get phasePlay;

  /// No description provided for @phasePlayAll.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get phasePlayAll;

  /// No description provided for @phaseStopPlayback.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get phaseStopPlayback;

  /// No description provided for @phaseMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get phaseMoreActions;

  /// No description provided for @loudnessAutoTitle.
  ///
  /// In en, this message translates to:
  /// **'Normalize after generation'**
  String get loudnessAutoTitle;

  /// No description provided for @loudnessAutoHint.
  ///
  /// In en, this message translates to:
  /// **'New clips go to the voice bank target ({target} LUFS) plus the loudness offset of each character.'**
  String loudnessAutoHint(Object target);

  /// No description provided for @loudnessCharacterOffset.
  ///
  /// In en, this message translates to:
  /// **'Loudness offset'**
  String get loudnessCharacterOffset;

  /// No description provided for @loudnessCharacterOffsetHint.
  ///
  /// In en, this message translates to:
  /// **'Relative to the voice bank target. For example -3 dB keeps a narrator under the cast, +1 to +2 dB lifts a lead.'**
  String get loudnessCharacterOffsetHint;

  /// No description provided for @loudnessBankTarget.
  ///
  /// In en, this message translates to:
  /// **'Loudness target'**
  String get loudnessBankTarget;

  /// No description provided for @loudnessBankTargetHint.
  ///
  /// In en, this message translates to:
  /// **'Projects that normalize audio bring this cast here, then add the offset of each character. About -16 LUFS suits narration, -20 LUFS suits ASMR.'**
  String get loudnessBankTargetHint;

  /// No description provided for @bankDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get bankDeactivate;

  /// No description provided for @bankSetActive.
  ///
  /// In en, this message translates to:
  /// **'Set Active'**
  String get bankSetActive;

  /// No description provided for @bankSettingsMenu.
  ///
  /// In en, this message translates to:
  /// **'Settings…'**
  String get bankSettingsMenu;

  /// No description provided for @bankSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice bank settings'**
  String get bankSettingsTitle;

  /// No description provided for @loudnessUseOffsets.
  ///
  /// In en, this message translates to:
  /// **'Apply character offsets'**
  String get loudnessUseOffsets;

  /// No description provided for @loudnessUseOffsetsHint.
  ///
  /// In en, this message translates to:
  /// **'Each speaker lands on the target plus their own offset, for example a narrator a few dB lower.'**
  String get loudnessUseOffsetsHint;

  /// No description provided for @loudnessRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore originals ({count})'**
  String loudnessRestore(Object count);

  /// No description provided for @loudnessRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored {count} clips to their original loudness.'**
  String loudnessRestored(Object count);

  /// No description provided for @phaseStopGenerating.
  ///
  /// In en, this message translates to:
  /// **'Stop generating'**
  String get phaseStopGenerating;

  /// No description provided for @phaseRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry failed ({count})'**
  String phaseRetryFailed(Object count);

  /// No description provided for @phaseSelectMode.
  ///
  /// In en, this message translates to:
  /// **'Select multiple'**
  String get phaseSelectMode;

  /// No description provided for @phaseAddSegment.
  ///
  /// In en, this message translates to:
  /// **'Add segment'**
  String get phaseAddSegment;

  /// No description provided for @phaseSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String phaseSelectedCount(Object count);

  /// No description provided for @phaseSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get phaseSelectAll;

  /// No description provided for @phaseAssignVoice.
  ///
  /// In en, this message translates to:
  /// **'Assign voice'**
  String get phaseAssignVoice;

  /// No description provided for @phaseRegenerateSelected.
  ///
  /// In en, this message translates to:
  /// **'Regenerate selected'**
  String get phaseRegenerateSelected;

  /// No description provided for @phaseDeleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get phaseDeleteSelected;

  /// No description provided for @phaseExitSelect.
  ///
  /// In en, this message translates to:
  /// **'Exit multi-select'**
  String get phaseExitSelect;

  /// No description provided for @phaseInsertBelow.
  ///
  /// In en, this message translates to:
  /// **'Insert below'**
  String get phaseInsertBelow;

  /// No description provided for @phaseMergeNext.
  ///
  /// In en, this message translates to:
  /// **'Merge with next'**
  String get phaseMergeNext;

  /// No description provided for @phaseSplit.
  ///
  /// In en, this message translates to:
  /// **'Split…'**
  String get phaseSplit;

  /// No description provided for @phaseSplitTitle.
  ///
  /// In en, this message translates to:
  /// **'Split segment'**
  String get phaseSplitTitle;

  /// No description provided for @phaseSplitHint.
  ///
  /// In en, this message translates to:
  /// **'Click where the second segment should start.'**
  String get phaseSplitHint;

  /// No description provided for @phaseSplitAction.
  ///
  /// In en, this message translates to:
  /// **'Split here'**
  String get phaseSplitAction;

  /// No description provided for @phaseInsertTitle.
  ///
  /// In en, this message translates to:
  /// **'New segment'**
  String get phaseInsertTitle;

  /// No description provided for @phaseInsertAction.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get phaseInsertAction;

  /// No description provided for @phaseDeletedCount.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} segments'**
  String phaseDeletedCount(Object count);

  /// No description provided for @phaseUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get phaseUndo;

  /// No description provided for @phaseDragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get phaseDragToReorder;

  /// No description provided for @phaseShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard: Up/Down move · Space play/stop · Enter generate · F2 edit · Delete remove · Esc clear · Ctrl+A select all (multi-select) · Ctrl+S save'**
  String get phaseShortcuts;

  /// No description provided for @phaseMergeSettings.
  ///
  /// In en, this message translates to:
  /// **'Playback and export'**
  String get phaseMergeSettings;

  /// No description provided for @phaseMergeGap.
  ///
  /// In en, this message translates to:
  /// **'Pause between segments'**
  String get phaseMergeGap;

  /// No description provided for @phaseMergeGapHint.
  ///
  /// In en, this message translates to:
  /// **'Used by Play All and Export Merged.'**
  String get phaseMergeGapHint;

  /// No description provided for @phaseFadeIn.
  ///
  /// In en, this message translates to:
  /// **'Fade in'**
  String get phaseFadeIn;

  /// No description provided for @phaseFadeOut.
  ///
  /// In en, this message translates to:
  /// **'Fade out'**
  String get phaseFadeOut;

  /// No description provided for @phaseFadeHint.
  ///
  /// In en, this message translates to:
  /// **'Applied to every segment in the merged export. 10–50 ms removes clicks at the cuts; longer values soften each line.'**
  String get phaseFadeHint;

  /// No description provided for @sectionReferenceAudio.
  ///
  /// In en, this message translates to:
  /// **'REFERENCE AUDIO'**
  String get sectionReferenceAudio;

  /// No description provided for @sectionCharacterInfo.
  ///
  /// In en, this message translates to:
  /// **'CHARACTER INFO'**
  String get sectionCharacterInfo;

  /// No description provided for @sectionProvider.
  ///
  /// In en, this message translates to:
  /// **'PROVIDER'**
  String get sectionProvider;

  /// No description provided for @sectionModel.
  ///
  /// In en, this message translates to:
  /// **'MODEL'**
  String get sectionModel;

  /// No description provided for @sectionVoice.
  ///
  /// In en, this message translates to:
  /// **'VOICE'**
  String get sectionVoice;

  /// No description provided for @sectionVoiceNameOptional.
  ///
  /// In en, this message translates to:
  /// **'VOICE NAME (optional)'**
  String get sectionVoiceNameOptional;

  /// No description provided for @sectionVoiceDescription.
  ///
  /// In en, this message translates to:
  /// **'VOICE DESCRIPTION'**
  String get sectionVoiceDescription;

  /// No description provided for @sectionCosyvoiceMode.
  ///
  /// In en, this message translates to:
  /// **'COSYVOICE MODE'**
  String get sectionCosyvoiceMode;

  /// No description provided for @sectionServerProfileOptional.
  ///
  /// In en, this message translates to:
  /// **'SERVER PROFILE (optional)'**
  String get sectionServerProfileOptional;

  /// No description provided for @sectionInstruct.
  ///
  /// In en, this message translates to:
  /// **'INSTRUCT'**
  String get sectionInstruct;

  /// No description provided for @sectionVoxcpm2Mode.
  ///
  /// In en, this message translates to:
  /// **'VOXCPM2 MODE'**
  String get sectionVoxcpm2Mode;

  /// No description provided for @sectionGptSovitsMode.
  ///
  /// In en, this message translates to:
  /// **'GPT-SOVITS MODE'**
  String get sectionGptSovitsMode;

  /// No description provided for @sectionTrainedSpeaker.
  ///
  /// In en, this message translates to:
  /// **'TRAINED SPEAKER'**
  String get sectionTrainedSpeaker;

  /// No description provided for @sectionVoiceClone.
  ///
  /// In en, this message translates to:
  /// **'VOICE CLONE'**
  String get sectionVoiceClone;

  /// No description provided for @sectionVoiceDesign.
  ///
  /// In en, this message translates to:
  /// **'VOICE DESIGN'**
  String get sectionVoiceDesign;

  /// No description provided for @sectionOutput.
  ///
  /// In en, this message translates to:
  /// **'OUTPUT'**
  String get sectionOutput;

  /// No description provided for @autoFillProviderSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Auto-fill: Provider + Speaker'**
  String get autoFillProviderSpeaker;

  /// No description provided for @statusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get statusIdle;

  /// No description provided for @statusPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get statusPreview;

  /// No description provided for @novelGeneratingSegments.
  ///
  /// In en, this message translates to:
  /// **'Generating {count} segments'**
  String novelGeneratingSegments(Object count);

  /// No description provided for @novelGeneratingShort.
  ///
  /// In en, this message translates to:
  /// **'Generating {count}'**
  String novelGeneratingShort(Object count);

  /// No description provided for @novelEpubReserved.
  ///
  /// In en, this message translates to:
  /// **'EPUB import is not supported yet; the TXT files were imported.'**
  String get novelEpubReserved;

  /// No description provided for @novelImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String novelImportFailed(Object error);

  /// No description provided for @novelSegmentSaved.
  ///
  /// In en, this message translates to:
  /// **'Segment saved.'**
  String get novelSegmentSaved;

  /// No description provided for @novelSegmentDeleted.
  ///
  /// In en, this message translates to:
  /// **'Segment deleted.'**
  String get novelSegmentDeleted;

  /// No description provided for @novelDeleteChapterMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes \"{title}\" and its cached audio.'**
  String novelDeleteChapterMessage(Object title);

  /// No description provided for @novelChapterDeleted.
  ///
  /// In en, this message translates to:
  /// **'Chapter deleted.'**
  String get novelChapterDeleted;

  /// No description provided for @novelDialogueRulesSaved.
  ///
  /// In en, this message translates to:
  /// **'Dialogue rules saved; rebuilt {count} segments.'**
  String novelDialogueRulesSaved(Object count);

  /// No description provided for @novelTextFiltersSaved.
  ///
  /// In en, this message translates to:
  /// **'Text filters saved. Stale novel audio will regenerate on demand.'**
  String get novelTextFiltersSaved;

  /// No description provided for @novelPlaybackStopped.
  ///
  /// In en, this message translates to:
  /// **'Playback stopped: {error}'**
  String novelPlaybackStopped(Object error);

  /// No description provided for @novelNarrator.
  ///
  /// In en, this message translates to:
  /// **'Narrator'**
  String get novelNarrator;

  /// No description provided for @novelDialogue.
  ///
  /// In en, this message translates to:
  /// **'Dialogue'**
  String get novelDialogue;

  /// No description provided for @novelSegmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Segment {index}'**
  String novelSegmentLabel(Object index);

  /// No description provided for @phaseNoAudioToPlay.
  ///
  /// In en, this message translates to:
  /// **'No generated audio to play.'**
  String get phaseNoAudioToPlay;

  /// No description provided for @dialogLineFallback.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get dialogLineFallback;

  /// No description provided for @videoDubDeleteV1First.
  ///
  /// In en, this message translates to:
  /// **'Delete the V1 clip first; only one source video is allowed.'**
  String get videoDubDeleteV1First;

  /// No description provided for @statusWritingWav.
  ///
  /// In en, this message translates to:
  /// **'Recording WAV'**
  String get statusWritingWav;

  /// No description provided for @novelImported.
  ///
  /// In en, this message translates to:
  /// **'Imported {chapters} chapters, {segments} segments.'**
  String novelImported(Object chapters, Object segments);

  /// No description provided for @novelImportFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Import novel folder'**
  String get novelImportFolderTitle;

  /// No description provided for @uiStopSynthesis.
  ///
  /// In en, this message translates to:
  /// **'Stop synthesis'**
  String get uiStopSynthesis;

  /// No description provided for @uiAudioBuffering.
  ///
  /// In en, this message translates to:
  /// **'Buffering…'**
  String get uiAudioBuffering;

  /// No description provided for @roleReadMode.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get roleReadMode;

  /// No description provided for @roleReviewMode.
  ///
  /// In en, this message translates to:
  /// **'Role review'**
  String get roleReviewMode;

  /// No description provided for @roleCharacters.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get roleCharacters;

  /// No description provided for @roleAddCharacter.
  ///
  /// In en, this message translates to:
  /// **'Add character'**
  String get roleAddCharacter;

  /// No description provided for @roleName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get roleName;

  /// No description provided for @roleAliases.
  ///
  /// In en, this message translates to:
  /// **'Aliases (comma separated)'**
  String get roleAliases;

  /// No description provided for @roleDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get roleDescription;

  /// No description provided for @roleNoCharacter.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get roleNoCharacter;

  /// No description provided for @roleVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get roleVoice;

  /// No description provided for @roleDefaultVoice.
  ///
  /// In en, this message translates to:
  /// **'Use project default'**
  String get roleDefaultVoice;

  /// No description provided for @roleChapterOverride.
  ///
  /// In en, this message translates to:
  /// **'Override voice in this chapter'**
  String get roleChapterOverride;

  /// No description provided for @roleSelected.
  ///
  /// In en, this message translates to:
  /// **'Review selected sentence'**
  String get roleSelected;

  /// No description provided for @rolePickSentence.
  ///
  /// In en, this message translates to:
  /// **'Select a sentence to review'**
  String get rolePickSentence;

  /// No description provided for @roleCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get roleCategory;

  /// No description provided for @roleNarrator.
  ///
  /// In en, this message translates to:
  /// **'Narration'**
  String get roleNarrator;

  /// No description provided for @roleDialogue.
  ///
  /// In en, this message translates to:
  /// **'Dialogue'**
  String get roleDialogue;

  /// No description provided for @roleThought.
  ///
  /// In en, this message translates to:
  /// **'Thought'**
  String get roleThought;

  /// No description provided for @roleSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get roleSystem;

  /// No description provided for @roleScope.
  ///
  /// In en, this message translates to:
  /// **'Apply to'**
  String get roleScope;

  /// No description provided for @roleOnlySentence.
  ///
  /// In en, this message translates to:
  /// **'This sentence'**
  String get roleOnlySentence;

  /// No description provided for @roleChapterUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Same character in this chapter, unlocked'**
  String get roleChapterUnlocked;

  /// No description provided for @roleLock.
  ///
  /// In en, this message translates to:
  /// **'Lock manual result'**
  String get roleLock;

  /// No description provided for @roleApply.
  ///
  /// In en, this message translates to:
  /// **'Apply changes'**
  String get roleApply;

  /// No description provided for @roleUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo last annotation edit'**
  String get roleUndo;

  /// No description provided for @rolePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get rolePending;

  /// No description provided for @roleInferred.
  ///
  /// In en, this message translates to:
  /// **'Inferred from context'**
  String get roleInferred;

  /// No description provided for @roleConflict.
  ///
  /// In en, this message translates to:
  /// **'Conflicting evidence'**
  String get roleConflict;

  /// No description provided for @roleConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Manually confirmed'**
  String get roleConfirmed;

  /// No description provided for @roleInstruction.
  ///
  /// In en, this message translates to:
  /// **'Sentence style override (optional)'**
  String get roleInstruction;

  /// No description provided for @roleSentenceVoice.
  ///
  /// In en, this message translates to:
  /// **'Sentence voice override'**
  String get roleSentenceVoice;

  /// No description provided for @roleMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge character'**
  String get roleMerge;

  /// No description provided for @roleMergeInto.
  ///
  /// In en, this message translates to:
  /// **'Merge into'**
  String get roleMergeInto;

  /// No description provided for @roleManualReason.
  ///
  /// In en, this message translates to:
  /// **'Manual review'**
  String get roleManualReason;

  /// No description provided for @roleCached.
  ///
  /// In en, this message translates to:
  /// **'Audio cache ready'**
  String get roleCached;

  /// No description provided for @roleStaleCache.
  ///
  /// In en, this message translates to:
  /// **'Audio needs regeneration'**
  String get roleStaleCache;

  /// No description provided for @roleNoCache.
  ///
  /// In en, this message translates to:
  /// **'Audio not generated'**
  String get roleNoCache;

  /// No description provided for @roleRename.
  ///
  /// In en, this message translates to:
  /// **'Edit character'**
  String get roleRename;

  /// No description provided for @rolePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview selected sentence'**
  String get rolePreview;

  /// No description provided for @rolePendingList.
  ///
  /// In en, this message translates to:
  /// **'Sentences to review'**
  String get rolePendingList;

  /// No description provided for @roleNoPending.
  ///
  /// In en, this message translates to:
  /// **'No pending sentences in this chapter'**
  String get roleNoPending;

  /// No description provided for @roleAnalysisModel.
  ///
  /// In en, this message translates to:
  /// **'Role analysis model (text model ID)'**
  String get roleAnalysisModel;

  /// No description provided for @roleAnalysisProvider.
  ///
  /// In en, this message translates to:
  /// **'Analysis connection'**
  String get roleAnalysisProvider;

  /// No description provided for @roleAnalysisStart.
  ///
  /// In en, this message translates to:
  /// **'Analyze current chapter'**
  String get roleAnalysisStart;

  /// No description provided for @roleAnalysisResume.
  ///
  /// In en, this message translates to:
  /// **'Confirm roster and continue / resume'**
  String get roleAnalysisResume;

  /// No description provided for @roleAnalysisPause.
  ///
  /// In en, this message translates to:
  /// **'Pause analysis'**
  String get roleAnalysisPause;

  /// No description provided for @roleAnalysisFeedback.
  ///
  /// In en, this message translates to:
  /// **'Character or review feedback'**
  String get roleAnalysisFeedback;

  /// No description provided for @roleAnalysisReplan.
  ///
  /// In en, this message translates to:
  /// **'Replan cast with new intent'**
  String get roleAnalysisReplan;

  /// No description provided for @roleAnalysisBudget.
  ///
  /// In en, this message translates to:
  /// **'Current chapter only. Up to 12 analysis requests per run, plus one tool check for an unverified model. Charges may apply. Locked and manually confirmed sentences are preserved.'**
  String get roleAnalysisBudget;

  /// No description provided for @roleAnalysisOffline.
  ///
  /// In en, this message translates to:
  /// **'Configure a connection in Providers before choosing an analysis model.'**
  String get roleAnalysisOffline;

  /// No description provided for @modelDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover models / capabilities'**
  String get modelDiscover;

  /// No description provided for @modelRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh from connection'**
  String get modelRefresh;

  /// No description provided for @modelManual.
  ///
  /// In en, this message translates to:
  /// **'Use this model manually'**
  String get modelManual;

  /// No description provided for @modelUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get modelUnknown;

  /// No description provided for @modelSupported.
  ///
  /// In en, this message translates to:
  /// **'Supported'**
  String get modelSupported;

  /// No description provided for @modelUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported'**
  String get modelUnsupported;

  /// No description provided for @roleToolModelHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a text model with function calling. Unknown models get a short tool check before processing your text.'**
  String get roleToolModelHint;

  /// No description provided for @modelCapabilityHint.
  ///
  /// In en, this message translates to:
  /// **'Catalog facts describe capability. Account availability is verified by actual successful use. No paid probes are automatic.'**
  String get modelCapabilityHint;

  /// No description provided for @modelOverride.
  ///
  /// In en, this message translates to:
  /// **'Override task capability for this route'**
  String get modelOverride;

  /// No description provided for @modelNoModels.
  ///
  /// In en, this message translates to:
  /// **'No cached models. Refresh or enter a model ID.'**
  String get modelNoModels;

  /// No description provided for @roleStagePlan.
  ///
  /// In en, this message translates to:
  /// **'Planning characters'**
  String get roleStagePlan;

  /// No description provided for @roleStageRoster.
  ///
  /// In en, this message translates to:
  /// **'Waiting for roster review'**
  String get roleStageRoster;

  /// No description provided for @roleStageLabel.
  ///
  /// In en, this message translates to:
  /// **'Labeling sentences'**
  String get roleStageLabel;

  /// No description provided for @roleStageValidate.
  ///
  /// In en, this message translates to:
  /// **'Validating labels'**
  String get roleStageValidate;

  /// No description provided for @roleStageReview.
  ///
  /// In en, this message translates to:
  /// **'Reviewing uncertain labels'**
  String get roleStageReview;

  /// No description provided for @roleStageReplan.
  ///
  /// In en, this message translates to:
  /// **'Replanning from feedback'**
  String get roleStageReplan;

  /// No description provided for @roleStagePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get roleStagePaused;

  /// No description provided for @roleStageCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get roleStageCompleted;

  /// No description provided for @roleStageFailed.
  ///
  /// In en, this message translates to:
  /// **'Analysis failed'**
  String get roleStageFailed;

  /// No description provided for @roleAnalysisSentences.
  ///
  /// In en, this message translates to:
  /// **'sentences'**
  String get roleAnalysisSentences;

  /// No description provided for @roleAnalysisCalls.
  ///
  /// In en, this message translates to:
  /// **'calls'**
  String get roleAnalysisCalls;

  /// No description provided for @roleSplitText.
  ///
  /// In en, this message translates to:
  /// **'Split text'**
  String get roleSplitText;

  /// No description provided for @roleSplitTextHelp.
  ///
  /// In en, this message translates to:
  /// **'Select a range to isolate it, or place the cursor at a split point. All text and labels are preserved.'**
  String get roleSplitTextHelp;

  /// No description provided for @roleMergeText.
  ///
  /// In en, this message translates to:
  /// **'Merge text'**
  String get roleMergeText;

  /// No description provided for @roleMergeTextHelp.
  ///
  /// In en, this message translates to:
  /// **'Merge from the current segment through the chosen end. Mixed labels become unassigned and pending. Old audio is retained but no longer used.'**
  String get roleMergeTextHelp;

  /// No description provided for @roleMergeUntil.
  ///
  /// In en, this message translates to:
  /// **'Merge through'**
  String get roleMergeUntil;

  /// No description provided for @roleMergeNewline.
  ///
  /// In en, this message translates to:
  /// **'Insert newlines between segments'**
  String get roleMergeNewline;

  /// No description provided for @roleUndoStructure.
  ///
  /// In en, this message translates to:
  /// **'Undo last text split/merge'**
  String get roleUndoStructure;

  /// No description provided for @roleStyleMatrix.
  ///
  /// In en, this message translates to:
  /// **'Character styles by category'**
  String get roleStyleMatrix;

  /// No description provided for @roleStyleHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave fields empty to inherit defaults. Clear both fields to remove this override.'**
  String get roleStyleHelp;

  /// No description provided for @roleSplitCharacter.
  ///
  /// In en, this message translates to:
  /// **'Split character'**
  String get roleSplitCharacter;

  /// No description provided for @roleSplitCharacterHelp.
  ///
  /// In en, this message translates to:
  /// **'Move selected lines in this chapter to a new character and copy voice bindings. Annotation undo restores attribution and retains the new identity.'**
  String get roleSplitCharacterHelp;

  /// No description provided for @roleIdentityKind.
  ///
  /// In en, this message translates to:
  /// **'Identity type'**
  String get roleIdentityKind;

  /// No description provided for @roleIdentityNamed.
  ///
  /// In en, this message translates to:
  /// **'Named character'**
  String get roleIdentityNamed;

  /// No description provided for @roleIdentityAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous speaker'**
  String get roleIdentityAnonymous;

  /// No description provided for @roleIdentityGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get roleIdentityGroup;

  /// No description provided for @roleDirectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Each director action runs one bounded model task. Review before applying. Casting preserves bindings; tone handles up to 30 unconfirmed, unlocked segments without delivery instructions.'**
  String get roleDirectionHelp;

  /// No description provided for @roleSuggestCast.
  ///
  /// In en, this message translates to:
  /// **'Suggest voice casting'**
  String get roleSuggestCast;

  /// No description provided for @roleSuggestTone.
  ///
  /// In en, this message translates to:
  /// **'Suggest delivery'**
  String get roleSuggestTone;

  /// No description provided for @roleDirectionReview.
  ///
  /// In en, this message translates to:
  /// **'Review suggestions'**
  String get roleDirectionReview;

  /// No description provided for @roleDirectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'The model returned no applicable suggestions.'**
  String get roleDirectionEmpty;

  /// No description provided for @taskProfiles.
  ///
  /// In en, this message translates to:
  /// **'Task model profiles'**
  String get taskProfiles;

  /// No description provided for @taskProfilesHelp.
  ///
  /// In en, this message translates to:
  /// **'Configure separate connections, models and protocols for analysis, casting, delivery and narration. Narration overrides the novel model/protocol while retaining character voices and references. Unconfigured tasks use existing selections.'**
  String get taskProfilesHelp;

  /// No description provided for @taskSynthesis.
  ///
  /// In en, this message translates to:
  /// **'Novel narration'**
  String get taskSynthesis;

  /// No description provided for @taskProtocol.
  ///
  /// In en, this message translates to:
  /// **'Service protocol'**
  String get taskProtocol;

  /// No description provided for @taskEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Relative endpoint path (blank for protocol default)'**
  String get taskEndpoint;

  /// No description provided for @taskKeyHeader.
  ///
  /// In en, this message translates to:
  /// **'API key header name'**
  String get taskKeyHeader;

  /// No description provided for @taskUseDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore task defaults'**
  String get taskUseDefaults;

  /// No description provided for @modelReadDeclaration.
  ///
  /// In en, this message translates to:
  /// **'Read backend capability declaration'**
  String get modelReadDeclaration;

  /// No description provided for @uiLiveSentencePreview.
  ///
  /// In en, this message translates to:
  /// **'Live preview and save complete audio'**
  String get uiLiveSentencePreview;

  /// No description provided for @roleSceneTitle.
  ///
  /// In en, this message translates to:
  /// **'Scene understanding'**
  String get roleSceneTitle;

  /// No description provided for @roleSceneFirstPerson.
  ///
  /// In en, this message translates to:
  /// **'First-person narrator'**
  String get roleSceneFirstPerson;

  /// No description provided for @roleScenePresent.
  ///
  /// In en, this message translates to:
  /// **'Characters in the scene'**
  String get roleScenePresent;

  /// No description provided for @roleSceneNested.
  ///
  /// In en, this message translates to:
  /// **'Quoted storytellers'**
  String get roleSceneNested;

  /// No description provided for @roleSceneHelp.
  ///
  /// In en, this message translates to:
  /// **'Check these identities with the cast. Use feedback and re-plan to correct the scene before continuing.'**
  String get roleSceneHelp;

  /// No description provided for @roleToolReview.
  ///
  /// In en, this message translates to:
  /// **'Local tool review'**
  String get roleToolReview;

  /// No description provided for @roleToolBudget.
  ///
  /// In en, this message translates to:
  /// **'Per session: up to 3 calls, 20,000 budgeted tokens, 6 local reads, 8 proposals, and 1,600 output tokens per call. Unknown usage stays reserved; resuming keeps the budget.'**
  String get roleToolBudget;

  /// No description provided for @roleToolCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current segment only'**
  String get roleToolCurrent;

  /// No description provided for @roleToolDoubts.
  ///
  /// In en, this message translates to:
  /// **'Chapter doubts (up to 8 segments)'**
  String get roleToolDoubts;

  /// No description provided for @roleToolStart.
  ///
  /// In en, this message translates to:
  /// **'Start a new local review'**
  String get roleToolStart;

  /// No description provided for @roleToolReviewProposals.
  ///
  /// In en, this message translates to:
  /// **'Review character and label proposals'**
  String get roleToolReviewProposals;

  /// No description provided for @roleToolApplyHint.
  ///
  /// In en, this message translates to:
  /// **'Select proposals to apply. Accepted labels remain AI inferred. Text, locked and confirmed labels are protected. Merging moves the listed labels and compatible voice bindings, then removes the source identity.'**
  String get roleToolApplyHint;

  /// No description provided for @roleToolDependency.
  ///
  /// In en, this message translates to:
  /// **'Select the new character proposal required by the label change.'**
  String get roleToolDependency;

  /// No description provided for @roleToolAdd.
  ///
  /// In en, this message translates to:
  /// **'Add character'**
  String get roleToolAdd;

  /// No description provided for @roleToolPatch.
  ///
  /// In en, this message translates to:
  /// **'Change label'**
  String get roleToolPatch;

  /// No description provided for @roleToolMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge identities'**
  String get roleToolMerge;

  /// No description provided for @roleToolReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for review'**
  String get roleToolReady;

  /// No description provided for @roleToolBudgetExhausted.
  ///
  /// In en, this message translates to:
  /// **'Budget exhausted'**
  String get roleToolBudgetExhausted;

  /// No description provided for @roleToolApplied.
  ///
  /// In en, this message translates to:
  /// **'Selected proposals applied'**
  String get roleToolApplied;

  /// No description provided for @roleToolEmpty.
  ///
  /// In en, this message translates to:
  /// **'No changes proposed'**
  String get roleToolEmpty;

  /// No description provided for @roleToolEvidence.
  ///
  /// In en, this message translates to:
  /// **'Text evidence'**
  String get roleToolEvidence;

  /// No description provided for @roleToolAffected.
  ///
  /// In en, this message translates to:
  /// **'Affected segments'**
  String get roleToolAffected;

  /// No description provided for @roleToolReserved.
  ///
  /// In en, this message translates to:
  /// **'Budget usage (including unknown reservations)'**
  String get roleToolReserved;

  /// No description provided for @settingsRoleAi.
  ///
  /// In en, this message translates to:
  /// **'Role assignment AI'**
  String get settingsRoleAi;

  /// No description provided for @settingsRoleAiDescription.
  ///
  /// In en, this message translates to:
  /// **'Shared models, profiles and stage prompts for novels and long text'**
  String get settingsRoleAiDescription;

  /// No description provided for @roleSkillSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a profile and edit each stage prompt. Novel review and long-text role assignment share it; project task settings and explicit model choices take priority. Defaults ship with the app. Restoring the current profile saves immediately. Prompt changes require unfinished analyses to restart.'**
  String get roleSkillSettingsHint;

  /// No description provided for @roleSkillProfile.
  ///
  /// In en, this message translates to:
  /// **'Role profile'**
  String get roleSkillProfile;

  /// No description provided for @roleSkillDefault.
  ///
  /// In en, this message translates to:
  /// **'Built-in default profile'**
  String get roleSkillDefault;

  /// No description provided for @roleSkillClone.
  ///
  /// In en, this message translates to:
  /// **'Duplicate as new profile'**
  String get roleSkillClone;

  /// No description provided for @roleSkillRestoreProfile.
  ///
  /// In en, this message translates to:
  /// **'Restore current profile'**
  String get roleSkillRestoreProfile;

  /// No description provided for @roleSkillProfileName.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get roleSkillProfileName;

  /// No description provided for @roleSkillUseEntryConnection.
  ///
  /// In en, this message translates to:
  /// **'Use the connection selected in the workspace'**
  String get roleSkillUseEntryConnection;

  /// No description provided for @roleSkillNode.
  ///
  /// In en, this message translates to:
  /// **'Analysis stage'**
  String get roleSkillNode;

  /// No description provided for @roleSkillPrompt.
  ///
  /// In en, this message translates to:
  /// **'Stage prompt'**
  String get roleSkillPrompt;

  /// No description provided for @roleSkillRestoreNode.
  ///
  /// In en, this message translates to:
  /// **'Restore this stage prompt'**
  String get roleSkillRestoreNode;

  /// No description provided for @roleSkillSave.
  ///
  /// In en, this message translates to:
  /// **'Save and activate profiles'**
  String get roleSkillSave;

  /// No description provided for @phaseAutoRoles.
  ///
  /// In en, this message translates to:
  /// **'AI role assignment'**
  String get phaseAutoRoles;

  /// No description provided for @phaseRoleIntent.
  ///
  /// In en, this message translates to:
  /// **'Dubbing intent (optional)'**
  String get phaseRoleIntent;

  /// No description provided for @phaseRoleIntentHint.
  ///
  /// In en, this message translates to:
  /// **'For example: keep the exact text, give characters distinct voices, and keep story quotations with the storyteller.'**
  String get phaseRoleIntentHint;

  /// No description provided for @phaseRoleReviewHint.
  ///
  /// In en, this message translates to:
  /// **'Analysis leaves the project untouched. Review characters, exact text and voices before applying. Unassigned voices remain pending. Applying replaces the current segments; existing audio remains on disk.'**
  String get phaseRoleReviewHint;

  /// No description provided for @phaseRoleAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Analyze and preview'**
  String get phaseRoleAnalyze;

  /// No description provided for @phaseRoleApply.
  ///
  /// In en, this message translates to:
  /// **'Apply roles and voices'**
  String get phaseRoleApply;

  /// No description provided for @phaseRoleUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unresolved speaker'**
  String get phaseRoleUnknown;

  /// No description provided for @phaseRoleNarrator.
  ///
  /// In en, this message translates to:
  /// **'Default narration voice'**
  String get phaseRoleNarrator;

  /// No description provided for @phaseRoleNoVoice.
  ///
  /// In en, this message translates to:
  /// **'Choose a voice later'**
  String get phaseRoleNoVoice;

  /// No description provided for @phaseRoleStatus.
  ///
  /// In en, this message translates to:
  /// **'See the task monitor for analysis progress. Up to 40 calls, cancellable during analysis. Audio synthesis starts separately.'**
  String get phaseRoleStatus;

  /// No description provided for @phaseRoleStale.
  ///
  /// In en, this message translates to:
  /// **'Text, segments, voice bank or role configuration changed. Analyze again.'**
  String get phaseRoleStale;

  /// No description provided for @dubbingMode.
  ///
  /// In en, this message translates to:
  /// **'Dubbing mode'**
  String get dubbingMode;

  /// No description provided for @dubbingModeAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get dubbingModeAutomatic;

  /// No description provided for @dubbingModeStoryteller.
  ///
  /// In en, this message translates to:
  /// **'Storyteller'**
  String get dubbingModeStoryteller;

  /// No description provided for @dubbingModeDramatized.
  ///
  /// In en, this message translates to:
  /// **'Dramatized'**
  String get dubbingModeDramatized;

  /// No description provided for @dubbingModeScript.
  ///
  /// In en, this message translates to:
  /// **'Script & chat'**
  String get dubbingModeScript;

  /// No description provided for @dubbingModeAutomaticHelp.
  ///
  /// In en, this message translates to:
  /// **'Infer roles from viewpoint, speech cues, and context.'**
  String get dubbingModeAutomaticHelp;

  /// No description provided for @dubbingModeStorytellerHelp.
  ///
  /// In en, this message translates to:
  /// **'Keep the storyteller’s voice for quotations within their story.'**
  String get dubbingModeStorytellerHelp;

  /// No description provided for @dubbingModeDramatizedHelp.
  ///
  /// In en, this message translates to:
  /// **'Give clearly attributed quotes their own voices and return to the storyteller afterward.'**
  String get dubbingModeDramatizedHelp;

  /// No description provided for @dubbingModeScriptHelp.
  ///
  /// In en, this message translates to:
  /// **'Use speaker headers or message senders for dialogue and narration for stage directions.'**
  String get dubbingModeScriptHelp;

  /// No description provided for @phaseRoleEditSegment.
  ///
  /// In en, this message translates to:
  /// **'Edit assignment'**
  String get phaseRoleEditSegment;

  /// No description provided for @phaseRoleModelEvidence.
  ///
  /// In en, this message translates to:
  /// **'Original AI reasoning'**
  String get phaseRoleModelEvidence;

  /// No description provided for @phaseRoleContext.
  ///
  /// In en, this message translates to:
  /// **'Show context'**
  String get phaseRoleContext;

  /// No description provided for @phaseRolePrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous segment'**
  String get phaseRolePrevious;

  /// No description provided for @phaseRoleFollowing.
  ///
  /// In en, this message translates to:
  /// **'Next segment'**
  String get phaseRoleFollowing;

  /// No description provided for @phaseRoleCategory.
  ///
  /// In en, this message translates to:
  /// **'Segment category'**
  String get phaseRoleCategory;

  /// No description provided for @phaseRoleSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get phaseRoleSpeaker;

  /// No description provided for @phaseRoleNoCharacter.
  ///
  /// In en, this message translates to:
  /// **'No character assigned'**
  String get phaseRoleNoCharacter;

  /// No description provided for @phaseRoleAddCharacter.
  ///
  /// In en, this message translates to:
  /// **'Add character'**
  String get phaseRoleAddCharacter;

  /// No description provided for @phaseRoleCharacterName.
  ///
  /// In en, this message translates to:
  /// **'Character name'**
  String get phaseRoleCharacterName;

  /// No description provided for @phaseRoleNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name that is not already in use'**
  String get phaseRoleNameRequired;

  /// No description provided for @phaseRoleSegments.
  ///
  /// In en, this message translates to:
  /// **'Segments'**
  String get phaseRoleSegments;

  /// No description provided for @phaseRoleVoices.
  ///
  /// In en, this message translates to:
  /// **'Character voices'**
  String get phaseRoleVoices;

  /// No description provided for @phaseRoleNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get phaseRoleNeedsReview;

  /// No description provided for @phaseRoleSearch.
  ///
  /// In en, this message translates to:
  /// **'Search text or characters'**
  String get phaseRoleSearch;

  /// No description provided for @phaseRoleVoiceHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose a voice for all segments of a character. You can also assign voices later in the generation list.'**
  String get phaseRoleVoiceHelp;

  /// No description provided for @phaseRoleNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching segments.'**
  String get phaseRoleNoMatches;

  /// No description provided for @phaseRoleEdited.
  ///
  /// In en, this message translates to:
  /// **'Edited manually'**
  String get phaseRoleEdited;

  /// No description provided for @phaseRolePreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review role assignments'**
  String get phaseRolePreviewTitle;

  /// No description provided for @phaseRoleStop.
  ///
  /// In en, this message translates to:
  /// **'Stop analysis'**
  String get phaseRoleStop;

  /// No description provided for @phaseRoleStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping…'**
  String get phaseRoleStopping;

  /// No description provided for @phaseRoleStopped.
  ///
  /// In en, this message translates to:
  /// **'Analysis stopped. You can adjust your settings and try again.'**
  String get phaseRoleStopped;

  /// No description provided for @phaseRolePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing text…'**
  String get phaseRolePreparing;

  /// No description provided for @phaseRoleAdjustIntent.
  ///
  /// In en, this message translates to:
  /// **'Adjust dubbing intent'**
  String get phaseRoleAdjustIntent;

  /// No description provided for @phaseRoleBackToPreview.
  ///
  /// In en, this message translates to:
  /// **'Back to preview'**
  String get phaseRoleBackToPreview;

  /// No description provided for @phaseRoleLengthLimit.
  ///
  /// In en, this message translates to:
  /// **'This text exceeds 360 segments or 64,000 UTF-16 units. Analyze it in shorter sections.'**
  String get phaseRoleLengthLimit;

  /// No description provided for @phaseRoleConnectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Connection and model'**
  String get phaseRoleConnectionSettings;

  /// No description provided for @phaseRoleRestoreSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Restore AI suggestion'**
  String get phaseRoleRestoreSuggestion;

  /// No description provided for @roleAnalysisPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'AI role assignment'**
  String get roleAnalysisPanelTitle;

  /// No description provided for @roleAnalysisApproveRoster.
  ///
  /// In en, this message translates to:
  /// **'Confirm cast and assign lines'**
  String get roleAnalysisApproveRoster;

  /// No description provided for @roleAnalysisResumeShort.
  ///
  /// In en, this message translates to:
  /// **'Resume analysis'**
  String get roleAnalysisResumeShort;

  /// No description provided for @roleAnalysisRestart.
  ///
  /// In en, this message translates to:
  /// **'Analyze again'**
  String get roleAnalysisRestart;

  /// No description provided for @roleAnalysisRosterHint.
  ///
  /// In en, this message translates to:
  /// **'Check the cast and scene below before assigning lines.'**
  String get roleAnalysisRosterHint;

  /// No description provided for @rolePollOnlyUncertain.
  ///
  /// In en, this message translates to:
  /// **'Only uncertain segments'**
  String get rolePollOnlyUncertain;

  /// No description provided for @roleNoUncertain.
  ///
  /// In en, this message translates to:
  /// **'No uncertain segments in this chapter.'**
  String get roleNoUncertain;

  /// No description provided for @phaseRoleReviewSummary.
  ///
  /// In en, this message translates to:
  /// **'{total} segments · {uncertain} to review · {missing} voice groups unassigned'**
  String phaseRoleReviewSummary(int total, int uncertain, int missing);

  /// No description provided for @phaseRoleReplaceExisting.
  ///
  /// In en, this message translates to:
  /// **'Applying replaces {count} existing segments. The script and generated audio files are retained.'**
  String phaseRoleReplaceExisting(int count);

  /// No description provided for @phaseRoleKeepUncertain.
  ///
  /// In en, this message translates to:
  /// **'{count} segments still need review. Go back to edit, or apply their current assignments.'**
  String phaseRoleKeepUncertain(int count);

  /// No description provided for @phaseRoleInputSummary.
  ///
  /// In en, this message translates to:
  /// **'Detected {count} semantic segments. Analysis uses up to 40 model calls, plus one tool check for an unverified model.'**
  String phaseRoleInputSummary(int count);

  /// No description provided for @phaseRoleProgress.
  ///
  /// In en, this message translates to:
  /// **'{processed}/{total} segments processed · {calls} calls started'**
  String phaseRoleProgress(int processed, int total, int calls);

  /// No description provided for @roleShowMorePending.
  ///
  /// In en, this message translates to:
  /// **'Show more segments to review'**
  String get roleShowMorePending;

  /// No description provided for @playbackLoop.
  ///
  /// In en, this message translates to:
  /// **'Loop playback'**
  String get playbackLoop;

  /// No description provided for @playbackLoopOn.
  ///
  /// In en, this message translates to:
  /// **'Loop on'**
  String get playbackLoopOn;

  /// No description provided for @playbackDownload.
  ///
  /// In en, this message translates to:
  /// **'Download audio'**
  String get playbackDownload;

  /// No description provided for @playbackMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More playback actions'**
  String get playbackMoreActions;

  /// No description provided for @navSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Transcribe & Translate'**
  String get navSubtitles;

  /// No description provided for @transcribeFromAudio.
  ///
  /// In en, this message translates to:
  /// **'Transcribe the audio into the reference text'**
  String get transcribeFromAudio;

  /// No description provided for @transcribeNeedsStt.
  ///
  /// In en, this message translates to:
  /// **'Enable a provider with speech-to-text (e.g. OpenAI, ElevenLabs) to transcribe'**
  String get transcribeNeedsStt;

  /// No description provided for @transcribeFilled.
  ///
  /// In en, this message translates to:
  /// **'Reference text filled from the audio. Review it, then save.'**
  String get transcribeFilled;

  /// No description provided for @transcribeFailed.
  ///
  /// In en, this message translates to:
  /// **'Transcription failed: {error}'**
  String transcribeFailed(String error);

  /// No description provided for @liveModeScript.
  ///
  /// In en, this message translates to:
  /// **'Script'**
  String get liveModeScript;

  /// No description provided for @liveModeRealtime.
  ///
  /// In en, this message translates to:
  /// **'Realtime'**
  String get liveModeRealtime;

  /// No description provided for @liveModeCompanion.
  ///
  /// In en, this message translates to:
  /// **'Companion'**
  String get liveModeCompanion;

  /// No description provided for @liveModeScriptHint.
  ///
  /// In en, this message translates to:
  /// **'Write lines and generate each character voice'**
  String get liveModeScriptHint;

  /// No description provided for @liveModeRealtimeHint.
  ///
  /// In en, this message translates to:
  /// **'Full-duplex voice chat with a Realtime model'**
  String get liveModeRealtimeHint;

  /// No description provided for @liveModeCompanionHint.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition → LLM → the character own TTS voice'**
  String get liveModeCompanionHint;

  /// No description provided for @liveNeedsRealtime.
  ///
  /// In en, this message translates to:
  /// **'Needs a provider with a Realtime model (e.g. OpenAI)'**
  String get liveNeedsRealtime;

  /// No description provided for @liveNeedsCompanion.
  ///
  /// In en, this message translates to:
  /// **'Needs providers with speech-to-text and an LLM'**
  String get liveNeedsCompanion;

  /// No description provided for @liveStateIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get liveStateIdle;

  /// No description provided for @liveStateConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get liveStateConnecting;

  /// No description provided for @liveStateListening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get liveStateListening;

  /// No description provided for @liveStateThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get liveStateThinking;

  /// No description provided for @liveStateSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Speaking'**
  String get liveStateSpeaking;

  /// No description provided for @liveNoCharacter.
  ///
  /// In en, this message translates to:
  /// **'Pick a character'**
  String get liveNoCharacter;

  /// No description provided for @liveVcActive.
  ///
  /// In en, this message translates to:
  /// **'Replies are converted to the character timbre'**
  String get liveVcActive;

  /// No description provided for @liveSettings.
  ///
  /// In en, this message translates to:
  /// **'Character live settings'**
  String get liveSettings;

  /// No description provided for @liveStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get liveStart;

  /// No description provided for @liveStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get liveStop;

  /// No description provided for @liveEmptyRealtime.
  ///
  /// In en, this message translates to:
  /// **'Press Start and talk. The character answers in real time; use headphones if you want to interrupt it.'**
  String get liveEmptyRealtime;

  /// No description provided for @liveEmptyCompanion.
  ///
  /// In en, this message translates to:
  /// **'Press Start and talk. When you pause, the character replies with its own voice.'**
  String get liveEmptyCompanion;

  /// No description provided for @liveTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Or type a message'**
  String get liveTypeHint;

  /// No description provided for @liveSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Live dialog · {name}'**
  String liveSettingsTitle(String name);

  /// No description provided for @livePersona.
  ///
  /// In en, this message translates to:
  /// **'Persona'**
  String get livePersona;

  /// No description provided for @livePersonaHint.
  ///
  /// In en, this message translates to:
  /// **'How the character thinks and talks. Empty uses the voice name, description and instruction.'**
  String get livePersonaHint;

  /// No description provided for @liveRealtimeVoice.
  ///
  /// In en, this message translates to:
  /// **'Realtime voice'**
  String get liveRealtimeVoice;

  /// No description provided for @liveDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get liveDefault;

  /// No description provided for @liveAllowInterrupt.
  ///
  /// In en, this message translates to:
  /// **'Allow interrupting (headphones)'**
  String get liveAllowInterrupt;

  /// No description provided for @liveAllowInterruptHint.
  ///
  /// In en, this message translates to:
  /// **'Keeps the microphone open while the character speaks. Without headphones it would hear itself.'**
  String get liveAllowInterruptHint;

  /// No description provided for @liveVcTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice conversion'**
  String get liveVcTitle;

  /// No description provided for @liveVcHint.
  ///
  /// In en, this message translates to:
  /// **'Convert each reply to the character timbre with a voice-conversion model: emotion from the dialog model, timbre from the character, no training. Adds latency.'**
  String get liveVcHint;

  /// No description provided for @liveVcProvider.
  ///
  /// In en, this message translates to:
  /// **'Conversion provider'**
  String get liveVcProvider;

  /// No description provided for @liveVcOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get liveVcOff;

  /// No description provided for @liveVcVoice.
  ///
  /// In en, this message translates to:
  /// **'Target voice ID'**
  String get liveVcVoice;

  /// No description provided for @liveVcVoiceHint.
  ///
  /// In en, this message translates to:
  /// **'The provider voice to convert into, e.g. an ElevenLabs voice ID'**
  String get liveVcVoiceHint;

  /// No description provided for @subtitlePickMedia.
  ///
  /// In en, this message translates to:
  /// **'Choose a video or audio file'**
  String get subtitlePickMedia;

  /// No description provided for @subtitleSourceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Spoken language'**
  String get subtitleSourceLanguage;

  /// No description provided for @subtitleSourceLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Optional, e.g. ja. Empty = detect'**
  String get subtitleSourceLanguageHint;

  /// No description provided for @subtitleTargetLanguage.
  ///
  /// In en, this message translates to:
  /// **'Translate to'**
  String get subtitleTargetLanguage;

  /// No description provided for @subtitleNoTranslation.
  ///
  /// In en, this message translates to:
  /// **'No translation (transcript only)'**
  String get subtitleNoTranslation;

  /// No description provided for @subtitleContext.
  ///
  /// In en, this message translates to:
  /// **'Context for the translator'**
  String get subtitleContext;

  /// No description provided for @subtitleContextHint.
  ///
  /// In en, this message translates to:
  /// **'Title, names, genre or glossary'**
  String get subtitleContextHint;

  /// No description provided for @subtitleFormat.
  ///
  /// In en, this message translates to:
  /// **'Output format'**
  String get subtitleFormat;

  /// No description provided for @subtitleModeOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get subtitleModeOriginal;

  /// No description provided for @subtitleModeTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get subtitleModeTranslation;

  /// No description provided for @subtitleModeBilingual.
  ///
  /// In en, this message translates to:
  /// **'Bilingual'**
  String get subtitleModeBilingual;

  /// No description provided for @subtitleRun.
  ///
  /// In en, this message translates to:
  /// **'Transcribe'**
  String get subtitleRun;

  /// No description provided for @subtitleExport.
  ///
  /// In en, this message translates to:
  /// **'Export subtitles'**
  String get subtitleExport;

  /// No description provided for @subtitleSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved {path}'**
  String subtitleSaved(String path);

  /// No description provided for @subtitlePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get subtitlePreview;

  /// No description provided for @subtitleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Pick a file and run to see the subtitles here.'**
  String get subtitleEmpty;

  /// No description provided for @subtitleMissingCapability.
  ///
  /// In en, this message translates to:
  /// **'not available'**
  String get subtitleMissingCapability;

  /// No description provided for @subtitleStageDecoding.
  ///
  /// In en, this message translates to:
  /// **'Decoding'**
  String get subtitleStageDecoding;

  /// No description provided for @subtitleStageDetecting.
  ///
  /// In en, this message translates to:
  /// **'Detecting speech'**
  String get subtitleStageDetecting;

  /// No description provided for @subtitleStageTranscribing.
  ///
  /// In en, this message translates to:
  /// **'Transcribing'**
  String get subtitleStageTranscribing;

  /// No description provided for @subtitleStageTranslating.
  ///
  /// In en, this message translates to:
  /// **'Translating'**
  String get subtitleStageTranslating;

  /// No description provided for @subtitleStageDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get subtitleStageDone;

  /// No description provided for @modalityText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get modalityText;

  /// No description provided for @modalityImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get modalityImage;

  /// No description provided for @modalityAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get modalityAudio;

  /// No description provided for @modalityVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get modalityVideo;

  /// No description provided for @modalityPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get modalityPdf;

  /// No description provided for @llmThinkUnknown.
  ///
  /// In en, this message translates to:
  /// **'Thinking ?'**
  String get llmThinkUnknown;

  /// No description provided for @llmThinkNone.
  ///
  /// In en, this message translates to:
  /// **'No thinking'**
  String get llmThinkNone;

  /// No description provided for @llmThinkLevelsUnknown.
  ///
  /// In en, this message translates to:
  /// **'Thinking (levels unknown)'**
  String get llmThinkLevelsUnknown;

  /// No description provided for @llmThinkLevels.
  ///
  /// In en, this message translates to:
  /// **'Thinking {count} levels {from}→{to}'**
  String llmThinkLevels(int count, String from, String to);

  /// No description provided for @llmThinkCanDisable.
  ///
  /// In en, this message translates to:
  /// **', can turn off'**
  String get llmThinkCanDisable;

  /// No description provided for @llmThinkDefault.
  ///
  /// In en, this message translates to:
  /// **'Default: {level}'**
  String llmThinkDefault(String level);

  /// No description provided for @llmThinkModes.
  ///
  /// In en, this message translates to:
  /// **'Modes: {modes}'**
  String llmThinkModes(String modes);

  /// No description provided for @llmTools.
  ///
  /// In en, this message translates to:
  /// **'Tool calling'**
  String get llmTools;

  /// No description provided for @llmToolsNo.
  ///
  /// In en, this message translates to:
  /// **'No tool calling'**
  String get llmToolsNo;

  /// No description provided for @llmToolsUnknown.
  ///
  /// In en, this message translates to:
  /// **'Tool calling ?'**
  String get llmToolsUnknown;

  /// No description provided for @llmToolsParallel.
  ///
  /// In en, this message translates to:
  /// **'Can call several tools in one turn'**
  String get llmToolsParallel;

  /// No description provided for @llmInputsUnknown.
  ///
  /// In en, this message translates to:
  /// **'Input ?'**
  String get llmInputsUnknown;

  /// No description provided for @llmSchema.
  ///
  /// In en, this message translates to:
  /// **'JSON schema'**
  String get llmSchema;

  /// No description provided for @llmContext.
  ///
  /// In en, this message translates to:
  /// **'{tokens} context'**
  String llmContext(String tokens);

  /// No description provided for @llmSourceCatalog.
  ///
  /// In en, this message translates to:
  /// **'Built-in catalog'**
  String get llmSourceCatalog;

  /// No description provided for @llmSourceAccount.
  ///
  /// In en, this message translates to:
  /// **'Found in this account'**
  String get llmSourceAccount;

  /// No description provided for @llmSourceUnlisted.
  ///
  /// In en, this message translates to:
  /// **'Built-in catalog · not listed by this account'**
  String get llmSourceUnlisted;

  /// No description provided for @llmPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Language models · {provider}'**
  String llmPickerTitle(String provider);

  /// No description provided for @llmPickerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search, or type a model ID'**
  String get llmPickerSearch;

  /// No description provided for @llmPickerToolsOnly.
  ///
  /// In en, this message translates to:
  /// **'Tool calling only'**
  String get llmPickerToolsOnly;

  /// No description provided for @llmPickerLoading.
  ///
  /// In en, this message translates to:
  /// **'Reading the model list…'**
  String get llmPickerLoading;

  /// No description provided for @llmPickerFound.
  ///
  /// In en, this message translates to:
  /// **'The account lists {count} models; traits come from the public catalog.'**
  String llmPickerFound(int count);

  /// No description provided for @llmPickerDenied.
  ///
  /// In en, this message translates to:
  /// **'Credentials rejected: {error}'**
  String llmPickerDenied(String error);

  /// No description provided for @llmPickerOffline.
  ///
  /// In en, this message translates to:
  /// **'No model list from this provider; showing the built-in catalog.'**
  String get llmPickerOffline;

  /// No description provided for @llmPickerUse.
  ///
  /// In en, this message translates to:
  /// **'Use {id}'**
  String llmPickerUse(String id);

  /// No description provided for @llmNeedsToolsNo.
  ///
  /// In en, this message translates to:
  /// **'This model cannot call tools; role analysis needs tool calling.'**
  String get llmNeedsToolsNo;

  /// No description provided for @llmNeedsToolsUnknown.
  ///
  /// In en, this message translates to:
  /// **'Tool calling unknown; one small test request runs before the first analysis.'**
  String get llmNeedsToolsUnknown;

  /// No description provided for @llmProviderDisabled.
  ///
  /// In en, this message translates to:
  /// **'(disabled)'**
  String get llmProviderDisabled;

  /// No description provided for @llmProviderHint.
  ///
  /// In en, this message translates to:
  /// **'Only providers that offer a language model are listed'**
  String get llmProviderHint;

  /// No description provided for @voiceFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter voices'**
  String get voiceFilterHint;

  /// No description provided for @voiceMoreHidden.
  ///
  /// In en, this message translates to:
  /// **'{count} more — type to filter'**
  String voiceMoreHidden(int count);

  /// No description provided for @voiceEngineVoices.
  ///
  /// In en, this message translates to:
  /// **'{engine} voices'**
  String voiceEngineVoices(String engine);

  /// No description provided for @navMusic.
  ///
  /// In en, this message translates to:
  /// **'Song Studio'**
  String get navMusic;

  /// No description provided for @musicModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get musicModel;

  /// No description provided for @musicTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get musicTitle;

  /// No description provided for @musicTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Untitled song'**
  String get musicTitleHint;

  /// No description provided for @musicPrompt.
  ///
  /// In en, this message translates to:
  /// **'Style & arrangement'**
  String get musicPrompt;

  /// No description provided for @musicPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Genre, mood, instruments, vocalist, tempo, length…'**
  String get musicPromptHint;

  /// No description provided for @musicLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get musicLyrics;

  /// No description provided for @musicLyricsHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to let the model write them. Section tags such as [Verse] and [Chorus] shape the song.'**
  String get musicLyricsHint;

  /// No description provided for @musicInstrumental.
  ///
  /// In en, this message translates to:
  /// **'Instrumental (no vocals)'**
  String get musicInstrumental;

  /// No description provided for @musicLossless.
  ///
  /// In en, this message translates to:
  /// **'Lossless WAV when the model offers it'**
  String get musicLossless;

  /// No description provided for @musicImages.
  ///
  /// In en, this message translates to:
  /// **'Reference images'**
  String get musicImages;

  /// No description provided for @musicAddImage.
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get musicAddImage;

  /// No description provided for @musicGenerate.
  ///
  /// In en, this message translates to:
  /// **'Compose'**
  String get musicGenerate;

  /// No description provided for @musicGenerating.
  ///
  /// In en, this message translates to:
  /// **'Composing… {seconds}s'**
  String musicGenerating(int seconds);

  /// No description provided for @musicNoModel.
  ///
  /// In en, this message translates to:
  /// **'No enabled provider offers song generation. Add a Google Gemini provider.'**
  String get musicNoModel;

  /// No description provided for @musicEmpty.
  ///
  /// In en, this message translates to:
  /// **'Generated songs appear here.'**
  String get musicEmpty;

  /// No description provided for @musicShowInFolder.
  ///
  /// In en, this message translates to:
  /// **'Show in folder'**
  String get musicShowInFolder;

  /// No description provided for @musicSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as…'**
  String get musicSaveAs;

  /// No description provided for @musicDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get musicDelete;

  /// No description provided for @musicReuse.
  ///
  /// In en, this message translates to:
  /// **'Reuse settings'**
  String get musicReuse;

  /// No description provided for @musicNoLyrics.
  ///
  /// In en, this message translates to:
  /// **'Instrumental, no lyrics.'**
  String get musicNoLyrics;

  /// No description provided for @musicWatermark.
  ///
  /// In en, this message translates to:
  /// **'Lyria audio carries an inaudible SynthID watermark.'**
  String get musicWatermark;

  /// No description provided for @musicSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String musicSaved(String path);

  /// No description provided for @liveRealtimeModel.
  ///
  /// In en, this message translates to:
  /// **'Realtime model'**
  String get liveRealtimeModel;

  /// No description provided for @chainTitle.
  ///
  /// In en, this message translates to:
  /// **'Processing chain'**
  String get chainTitle;

  /// No description provided for @chainHint.
  ///
  /// In en, this message translates to:
  /// **'Steps wrap the TTS of this character like chained functions: text steps rewrite the line first, voice conversion re-voices the audio after. Applies wherever the character speaks.'**
  String get chainHint;

  /// No description provided for @chainInput.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get chainInput;

  /// No description provided for @chainOutput.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get chainOutput;

  /// No description provided for @chainAdd.
  ///
  /// In en, this message translates to:
  /// **'Add step'**
  String get chainAdd;

  /// No description provided for @chainTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate (LLM)'**
  String get chainTranslate;

  /// No description provided for @chainRewrite.
  ///
  /// In en, this message translates to:
  /// **'Rewrite (LLM)'**
  String get chainRewrite;

  /// No description provided for @chainConvert.
  ///
  /// In en, this message translates to:
  /// **'Voice conversion'**
  String get chainConvert;

  /// No description provided for @chainTranslateTo.
  ///
  /// In en, this message translates to:
  /// **'Translate → {language}'**
  String chainTranslateTo(String language);

  /// No description provided for @chainConvertTo.
  ///
  /// In en, this message translates to:
  /// **'Re-voice → {voice}'**
  String chainConvertTo(String voice);

  /// No description provided for @chainTargetLanguage.
  ///
  /// In en, this message translates to:
  /// **'Target language'**
  String get chainTargetLanguage;

  /// No description provided for @chainTargetLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Japanese, English, Cantonese'**
  String get chainTargetLanguageHint;

  /// No description provided for @chainInstruction.
  ///
  /// In en, this message translates to:
  /// **'Instruction'**
  String get chainInstruction;

  /// No description provided for @chainInstructionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Say it in a calm, old-fashioned tone and keep it short.'**
  String get chainInstructionHint;

  /// No description provided for @chainTargetVoice.
  ///
  /// In en, this message translates to:
  /// **'Target voice'**
  String get chainTargetVoice;

  /// No description provided for @chainModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get chainModel;

  /// No description provided for @chainNoModels.
  ///
  /// In en, this message translates to:
  /// **'No enabled provider offers this capability yet.'**
  String get chainNoModels;

  /// No description provided for @chainNeedsSetup.
  ///
  /// In en, this message translates to:
  /// **'Needs setup'**
  String get chainNeedsSetup;

  /// No description provided for @chainNoStreaming.
  ///
  /// In en, this message translates to:
  /// **'Voice conversion runs sentence by sentence: playback starts once the first sentence is converted. On the web, converters that only return files convert the whole line first.'**
  String get chainNoStreaming;

  /// No description provided for @retireBadge.
  ///
  /// In en, this message translates to:
  /// **'Retires {date}'**
  String retireBadge(Object date);

  /// No description provided for @retireHint.
  ///
  /// In en, this message translates to:
  /// **'{model} stops working on {date}. Switch to {replacement}.'**
  String retireHint(Object model, Object date, Object replacement);

  /// No description provided for @retireHintNoReplacement.
  ///
  /// In en, this message translates to:
  /// **'{model} stops working on {date}. Pick a model from another provider.'**
  String retireHintNoReplacement(Object model, Object date);

  /// No description provided for @retireBanner.
  ///
  /// In en, this message translates to:
  /// **'{count} characters use models that stop working on {date} ({days} days left).'**
  String retireBanner(Object count, Object date, Object days);

  /// No description provided for @retireMigrate.
  ///
  /// In en, this message translates to:
  /// **'Migrate'**
  String get retireMigrate;

  /// No description provided for @retireMigrateTitle.
  ///
  /// In en, this message translates to:
  /// **'Move characters to replacement models?'**
  String get retireMigrateTitle;

  /// No description provided for @retireMigrateManual.
  ///
  /// In en, this message translates to:
  /// **'No replacement runs here; change these in the character inspector:'**
  String get retireMigrateManual;

  /// No description provided for @retireMigrated.
  ///
  /// In en, this message translates to:
  /// **'Moved {count} characters.'**
  String retireMigrated(Object count);

  /// No description provided for @retireSwitchTo.
  ///
  /// In en, this message translates to:
  /// **'Switch to {model}'**
  String retireSwitchTo(Object model);

  /// No description provided for @retireLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get retireLater;

  /// No description provided for @chainTrim.
  ///
  /// In en, this message translates to:
  /// **'Trim silence'**
  String get chainTrim;

  /// No description provided for @chainVerify.
  ///
  /// In en, this message translates to:
  /// **'ASR check'**
  String get chainVerify;

  /// No description provided for @chainTrimHint.
  ///
  /// In en, this message translates to:
  /// **'Cuts silence at both ends of each sentence and shortens pauses longer than 0.35 s.'**
  String get chainTrimHint;

  /// No description provided for @chainVerifyHint.
  ///
  /// In en, this message translates to:
  /// **'Transcribes what was spoken, compares it with the line and lists skipped words. Playback is not delayed.'**
  String get chainVerifyHint;

  /// No description provided for @chainVerifyLanguage.
  ///
  /// In en, this message translates to:
  /// **'Recognition language (optional)'**
  String get chainVerifyLanguage;

  /// No description provided for @chainCheckMissing.
  ///
  /// In en, this message translates to:
  /// **'Heard {score}% · missing: {missing}'**
  String chainCheckMissing(Object score, Object missing);

  /// No description provided for @chainCheckClean.
  ///
  /// In en, this message translates to:
  /// **'Heard {score}% · nothing missing'**
  String chainCheckClean(Object score);

  /// No description provided for @chainCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'ASR check failed: {error}'**
  String chainCheckFailed(Object error);

  /// No description provided for @chainCheckNone.
  ///
  /// In en, this message translates to:
  /// **'No ASR check yet; preview the character to run one.'**
  String get chainCheckNone;

  /// No description provided for @settingsAiCapabilities.
  ///
  /// In en, this message translates to:
  /// **'AI capabilities'**
  String get settingsAiCapabilities;

  /// No description provided for @settingsAiCapabilitiesDescription.
  ///
  /// In en, this message translates to:
  /// **'Default models, per-capability limits and added models'**
  String get settingsAiCapabilitiesDescription;

  /// No description provided for @capLlm.
  ///
  /// In en, this message translates to:
  /// **'Language model'**
  String get capLlm;

  /// No description provided for @capTts.
  ///
  /// In en, this message translates to:
  /// **'Speech synthesis'**
  String get capTts;

  /// No description provided for @capStt.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition'**
  String get capStt;

  /// No description provided for @capRealtime.
  ///
  /// In en, this message translates to:
  /// **'Realtime voice'**
  String get capRealtime;

  /// No description provided for @capTranslate.
  ///
  /// In en, this message translates to:
  /// **'Speech translation'**
  String get capTranslate;

  /// No description provided for @capVc.
  ///
  /// In en, this message translates to:
  /// **'Voice conversion'**
  String get capVc;

  /// No description provided for @capVad.
  ///
  /// In en, this message translates to:
  /// **'Voice activity'**
  String get capVad;

  /// No description provided for @capMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get capMusic;

  /// No description provided for @capDefaultModel.
  ///
  /// In en, this message translates to:
  /// **'Default model'**
  String get capDefaultModel;

  /// No description provided for @capAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic (first available)'**
  String get capAutomatic;

  /// No description provided for @capConnections.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get capConnections;

  /// No description provided for @capNoConnections.
  ///
  /// In en, this message translates to:
  /// **'No enabled connection offers this capability.'**
  String get capNoConnections;

  /// No description provided for @capLimits.
  ///
  /// In en, this message translates to:
  /// **'Limits'**
  String get capLimits;

  /// No description provided for @capLimitsTitle.
  ///
  /// In en, this message translates to:
  /// **'{capability} limits · {connection}'**
  String capLimitsTitle(Object capability, Object connection);

  /// No description provided for @capLimitsHint.
  ///
  /// In en, this message translates to:
  /// **'Leave a field empty to inherit the connection limit. Each capability queues on its own, so language-model calls do not take speech slots.'**
  String get capLimitsHint;

  /// No description provided for @capInherited.
  ///
  /// In en, this message translates to:
  /// **'Inherited'**
  String get capInherited;

  /// No description provided for @capConcurrency.
  ///
  /// In en, this message translates to:
  /// **'Concurrent requests'**
  String get capConcurrency;

  /// No description provided for @capRpm.
  ///
  /// In en, this message translates to:
  /// **'Requests / minute'**
  String get capRpm;

  /// No description provided for @capRpd.
  ///
  /// In en, this message translates to:
  /// **'Requests / day'**
  String get capRpd;

  /// No description provided for @capTpm.
  ///
  /// In en, this message translates to:
  /// **'Tokens / minute'**
  String get capTpm;

  /// No description provided for @capTpd.
  ///
  /// In en, this message translates to:
  /// **'Tokens / day'**
  String get capTpd;

  /// No description provided for @capAddModel.
  ///
  /// In en, this message translates to:
  /// **'Add model'**
  String get capAddModel;

  /// No description provided for @capModelId.
  ///
  /// In en, this message translates to:
  /// **'Model id'**
  String get capModelId;

  /// No description provided for @capDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name (optional)'**
  String get capDisplayName;

  /// No description provided for @capModelRejected.
  ///
  /// In en, this message translates to:
  /// **'This connection cannot open model {model}.'**
  String capModelRejected(Object model);

  /// No description provided for @capOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get capOff;

  /// No description provided for @capAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get capAll;

  /// No description provided for @inspectorTabBasic.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get inspectorTabBasic;

  /// No description provided for @inspectorTabVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get inspectorTabVoice;

  /// No description provided for @provTabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get provTabOverview;

  /// No description provided for @provCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Capabilities'**
  String get provCapabilities;

  /// No description provided for @provCapUse.
  ///
  /// In en, this message translates to:
  /// **'Use {capability} on this connection'**
  String provCapUse(Object capability);

  /// No description provided for @provCapOffHint.
  ///
  /// In en, this message translates to:
  /// **'{capability} is off here; features will not route to this connection.'**
  String provCapOffHint(Object capability);

  /// No description provided for @provConnectionOff.
  ///
  /// In en, this message translates to:
  /// **'This connection is turned off. Switch it on in the list before features use its models.'**
  String get provConnectionOff;

  /// No description provided for @provSetDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get provSetDefault;

  /// No description provided for @provIsDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get provIsDefault;

  /// No description provided for @provSourceAdded.
  ///
  /// In en, this message translates to:
  /// **'Added by you'**
  String get provSourceAdded;

  /// No description provided for @provSourceFetched.
  ///
  /// In en, this message translates to:
  /// **'Fetched from the account'**
  String get provSourceFetched;

  /// No description provided for @provDiscoverLlm.
  ///
  /// In en, this message translates to:
  /// **'Discover from account'**
  String get provDiscoverLlm;

  /// No description provided for @provOtherModels.
  ///
  /// In en, this message translates to:
  /// **'Other fetched models'**
  String get provOtherModels;

  /// No description provided for @provCheckAll.
  ///
  /// In en, this message translates to:
  /// **'Check capabilities'**
  String get provCheckAll;

  /// No description provided for @provHealthOk.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get provHealthOk;

  /// No description provided for @provHealthFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get provHealthFailed;

  /// No description provided for @provHealthUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get provHealthUnavailable;

  /// No description provided for @provHealthUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get provHealthUnknown;

  /// No description provided for @provHealthNotChecked.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get provHealthNotChecked;

  /// No description provided for @provHealthSome.
  ///
  /// In en, this message translates to:
  /// **'Some capabilities failed: {list}'**
  String provHealthSome(Object list);

  /// No description provided for @provLimitsConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection limits'**
  String get provLimitsConnection;

  /// No description provided for @provLimitsPerCapability.
  ///
  /// In en, this message translates to:
  /// **'Per capability'**
  String get provLimitsPerCapability;

  /// No description provided for @provAddPick.
  ///
  /// In en, this message translates to:
  /// **'Choose a provider'**
  String get provAddPick;

  /// No description provided for @provAddHint.
  ///
  /// In en, this message translates to:
  /// **'Fill in the address and key on the Overview tab after creating it, then check its capabilities.'**
  String get provAddHint;

  /// No description provided for @featPresetVoices.
  ///
  /// In en, this message translates to:
  /// **'Preset voices'**
  String get featPresetVoices;

  /// No description provided for @featInstructions.
  ///
  /// In en, this message translates to:
  /// **'Style instructions'**
  String get featInstructions;

  /// No description provided for @featStreamingOutput.
  ///
  /// In en, this message translates to:
  /// **'Streaming'**
  String get featStreamingOutput;

  /// No description provided for @featCloudClone.
  ///
  /// In en, this message translates to:
  /// **'Cloud cloning'**
  String get featCloudClone;

  /// No description provided for @featZeroShotClone.
  ///
  /// In en, this message translates to:
  /// **'Zero-shot cloning'**
  String get featZeroShotClone;

  /// No description provided for @featFileTranscription.
  ///
  /// In en, this message translates to:
  /// **'File transcription'**
  String get featFileTranscription;

  /// No description provided for @featStreamingTranscription.
  ///
  /// In en, this message translates to:
  /// **'Streaming transcription'**
  String get featStreamingTranscription;

  /// No description provided for @featWordTimestamps.
  ///
  /// In en, this message translates to:
  /// **'Word timestamps'**
  String get featWordTimestamps;

  /// No description provided for @featDiarization.
  ///
  /// In en, this message translates to:
  /// **'Speaker labels'**
  String get featDiarization;

  /// No description provided for @featLanguageDetection.
  ///
  /// In en, this message translates to:
  /// **'Language detection'**
  String get featLanguageDetection;

  /// No description provided for @featKeywords.
  ///
  /// In en, this message translates to:
  /// **'Keywords'**
  String get featKeywords;

  /// No description provided for @featAudioOutput.
  ///
  /// In en, this message translates to:
  /// **'Audio output'**
  String get featAudioOutput;

  /// No description provided for @featTextOutput.
  ///
  /// In en, this message translates to:
  /// **'Text output'**
  String get featTextOutput;

  /// No description provided for @featToolCalls.
  ///
  /// In en, this message translates to:
  /// **'Tool calls'**
  String get featToolCalls;

  /// No description provided for @featServerVad.
  ///
  /// In en, this message translates to:
  /// **'Server VAD'**
  String get featServerVad;

  /// No description provided for @featInputTranscription.
  ///
  /// In en, this message translates to:
  /// **'Input transcript'**
  String get featInputTranscription;

  /// No description provided for @featSourceTranscript.
  ///
  /// In en, this message translates to:
  /// **'Source transcript'**
  String get featSourceTranscript;

  /// No description provided for @featStructuredOutput.
  ///
  /// In en, this message translates to:
  /// **'Structured output'**
  String get featStructuredOutput;

  /// No description provided for @featReasoning.
  ///
  /// In en, this message translates to:
  /// **'Reasoning'**
  String get featReasoning;

  /// No description provided for @featVocals.
  ///
  /// In en, this message translates to:
  /// **'Vocals'**
  String get featVocals;

  /// No description provided for @featTimedLyrics.
  ///
  /// In en, this message translates to:
  /// **'Timed lyrics'**
  String get featTimedLyrics;

  /// No description provided for @featImagePrompt.
  ///
  /// In en, this message translates to:
  /// **'Image prompt'**
  String get featImagePrompt;

  /// No description provided for @featLosslessOutput.
  ///
  /// In en, this message translates to:
  /// **'Lossless output'**
  String get featLosslessOutput;

  /// No description provided for @featZeroShot.
  ///
  /// In en, this message translates to:
  /// **'Zero-shot'**
  String get featZeroShot;

  /// No description provided for @featLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get featLocal;
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
