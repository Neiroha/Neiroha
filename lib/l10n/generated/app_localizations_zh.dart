// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Neiroha';

  @override
  String get navNovelReader => '小说阅读';

  @override
  String get navDialogTts => '对话配音';

  @override
  String get navPhaseTts => '分段 TTS';

  @override
  String get navVideoDub => '视频配音';

  @override
  String get navVoiceAssets => '音频素材';

  @override
  String get navVoiceBank => '语音库';

  @override
  String get navProviders => '服务商';

  @override
  String get navSettings => '设置';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsGeneralDescription => '启动页面和工作区行为';

  @override
  String get settingsTasks => '任务';

  @override
  String get settingsTasksDescription => '当前 TTS 工作、队列深度和最近结果';

  @override
  String get settingsApi => 'API 服务';

  @override
  String get settingsApiDescription => '本地中间件接口和访问控制';

  @override
  String get settingsStorage => '存储';

  @override
  String get settingsStorageDescription => '数据目录、磁盘同步和归档清理';

  @override
  String get settingsMedia => '媒体工具';

  @override
  String get settingsMediaDescription => 'FFmpeg 检测和导出默认值';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsAboutDescription => '版本和应用信息';

  @override
  String get languageTitle => '语言';

  @override
  String get languageSubtitle => '选择应用界面语言。';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String languageSaved(String language) {
    return '语言已切换为 $language。';
  }

  @override
  String get startupScreenTitle => '启动页面';

  @override
  String get startupScreenSubtitle => '选择 Neiroha 启动时打开的工作区，或恢复上次关闭前的页面。';

  @override
  String startupScreenSaved(String tab) {
    return '启动页面已设为 $tab。';
  }

  @override
  String get keepTtsRunningTitle => '切换页面时继续运行 TTS';

  @override
  String get keepTtsRunningSubtitle => '适合边听小说边查看任务进度或设置。';

  @override
  String get keepTtsRunningEnabled => '切换页面时 TTS 会继续运行。';

  @override
  String get keepTtsRunningDisabled => '离开小说阅读器时会停止播放。';

  @override
  String get aboutSubtitle => 'v0.1.0 - AI 音频中间件与配音工作站';

  @override
  String get uiUnassigned => '-- 未分配 --';

  @override
  String get uiOrUploadANewFile => '— 或上传新文件 —';

  @override
  String uiWillBeRemoved(Object name) {
    return '“$name”将被移除。';
  }

  @override
  String get uiCopyReusesTheSourceStreamFastLosslessH264H265Av1ForceA =>
      '“copy”会复用源视频流（快速、无损）。h264 / h265 / av1 会强制转码（较慢，且 ffmpeg 构建必须支持所选编码器）。';

  @override
  String uiArchivedFileSAreMissingOnDiskRowsFlaggedNotDeleted(Object count) {
    return '$count 个归档文件在磁盘上缺失，已标记记录但不会删除。';
  }

  @override
  String uiRequestS(Object count) {
    return '$count 个请求';
  }

  @override
  String uiRunningWaiting(Object running, Object queued) {
    return '$running 个运行中，$queued 个等待中';
  }

  @override
  String get uiABankWithThisNameAlreadyExists => '已存在同名语音库';

  @override
  String get uiALabelForThisClonedVoiceTheActualVoiceIsDerivedFrom =>
      '这个克隆音色的显示名称。实际音色会从参考音频中提取。';

  @override
  String get uiAProfileRegisteredOnTheCosyVoiceServerLeaveAsNoneToSynthesise =>
      'CosyVoice 服务器上注册的配置。选择“无”会完全基于上传的参考音频合成；如果输入服务器不认识的名称，会返回 400“未找到角色”。';

  @override
  String get uiAVoiceBankGroupsCharactersForAProject => '语音库用于按项目组织角色。\n';

  @override
  String get uiAVoiceBankGroupsCharactersForAProjectOnlyOneBankCan =>
      '语音库用于按项目组织角色。\n同一时间只能激活一个语音库。';

  @override
  String get uiAVoiceProfileRegisteredOnTheServerLeaveAsNoneToSynthesise =>
      '服务器上注册的音色配置。选择“无”会完全基于上传的参考音频合成；发送未注册的 ID 会被拒绝。';

  @override
  String get uiAYoungWomanGentleAndSweetVoice =>
      'A young woman, gentle and sweet voice';

  @override
  String get uiActive => '启用';

  @override
  String get uiAdapterUnavailableOnThisPlatform =>
      '当前平台不支持这个适配器，无法在这里启用或执行健康检查。';

  @override
  String get uiAdapterType => '适配器类型';

  @override
  String get uiAdd => '添加';

  @override
  String get uiAddChapter => '添加章节';

  @override
  String get uiAddCue => '添加片段';

  @override
  String get uiAddDialogLinesBelow => '在下方添加对话行';

  @override
  String get uiAddModel => '添加模型';

  @override
  String get uiAddProvider => '添加服务商';

  @override
  String get uiAddRule => '添加规则';

  @override
  String get uiAddSubtitlesImportSRTLRC => '添加字幕（导入 SRT/LRC）';

  @override
  String get uiAddToTimelineDragToPlace => '添加到时间线（拖拽放置）';

  @override
  String get uiAddVoice => '添加音色';

  @override
  String get uiAfterGeneratingSnapEachCueEndToItsTTSLength =>
      '生成后将每个片段的结束时间对齐到 TTS 音频长度。';

  @override
  String get uiAfterGeneratingSnapTheEndTimeToTheActualTTSLength =>
      '生成后将结束时间对齐到实际 TTS 长度。';

  @override
  String get uiAhead => '预取';

  @override
  String uiAllArchivedFileSArePresent(Object count) {
    return '$count 个归档文件都存在。';
  }

  @override
  String get uiAllCharactersFromThisBankAreAlreadyMembers => '该语音库中的角色都已加入';

  @override
  String get uiAlpha => '透明度';

  @override
  String get uiAPIConfigSaved => 'API 配置已保存。';

  @override
  String get uiAPIKey => 'API 密钥';

  @override
  String get uiAPIKeyOptional => 'API 密钥（可选）';

  @override
  String get uiAPILogOutput => 'API 日志输出';

  @override
  String get uiAPILogOutputDisabled => 'API 日志输出已关闭。';

  @override
  String get uiAPILogOutputEnabled => 'API 日志输出已开启。';

  @override
  String get uiAPIOff => 'API 关闭';

  @override
  String get uiAppSupportFallbackInstallDirIsReadOnly =>
      '应用支持目录 fallback（安装目录只读）';

  @override
  String get uiAppend => '追加';

  @override
  String get uiApply => '应用';

  @override
  String get uiApplyAll => '全部应用';

  @override
  String get uiApproxTokensDay => '约 tokens / 天';

  @override
  String get uiApproxTokensMin => '约 tokens / 分钟';

  @override
  String get uiArchivedAudioCleared => '已清理归档音频。';

  @override
  String get uiAssignAVoiceToThisCueFirst => '请先给这个片段分配音色';

  @override
  String get uiAudioCodecForTheMuxedMP4AACIsTheBroadestCompatibleDefault =>
      '封装到 MP4 时使用的音频编码。AAC 是兼容性最好的默认值。';

  @override
  String get uiAudioDurationUnknownCannotTrim => '音频时长未知，无法裁剪。';

  @override
  String get uiAudioFileIsMissingCannotSave => '音频文件缺失，无法保存';

  @override
  String get uiAudioFileMissingOnDisk => '磁盘上的音频文件缺失';

  @override
  String get uiAudioFormat => '音频格式';

  @override
  String get uiAudioLibraryIsEmpty => '音频库为空';

  @override
  String get uiAudioTagPrefix => '音频标签前缀';

  @override
  String get uiAutoSliceLongSegments => '自动切分长分段';

  @override
  String get uiAutoSplit => '自动拆分';

  @override
  String get uiAutoSwitchChaptersWhilePlaying => '播放时自动切换章节';

  @override
  String get uiAutoTurnPageWhilePlaying => '播放时自动翻页';

  @override
  String get uiAutoDetectFromPATH => '从 PATH 自动检测';

  @override
  String uiAutoGenerateFailed(Object error) {
    return '自动生成失败：$error';
  }

  @override
  String get uiAutoGenerateOnSend => '发送后自动生成';

  @override
  String get uiAutoGenerateTTS => '自动生成 TTS';

  @override
  String get uiAutoGenerateTTSAfterImport => '导入后自动生成 TTS';

  @override
  String get uiAutoPlayAfterGenerate => '生成后自动播放';

  @override
  String get uiAutoSyncCueLengthsToAudio => '自动同步片段长度到音频';

  @override
  String get uiAutoSyncLengthToAudio => '自动同步长度到音频';

  @override
  String get uiBack => '返回';

  @override
  String get uiBackToNovels => '返回小说列表';

  @override
  String get uiBackToProjects => '返回项目列表';

  @override
  String get uiBankHasNoCharacters => '语音库中没有角色';

  @override
  String get uiBankName => '语音库名称';

  @override
  String get uiBANKS => '语音库';

  @override
  String get uiBanksCharactersAndInspector => '语音库、角色与检查器';

  @override
  String get uiBaseURL => 'Base URL';

  @override
  String get uiBearerTokenXAPIKey => 'Bearer token / X-API-Key';

  @override
  String get uiBindHost => '绑定主机';

  @override
  String get uiBoundTo0000WithNoAPIKeyAnyoneOn =>
      '当前绑定到 0.0.0.0 且未设置 API 密钥，局域网内任何人都能调用你的服务商。请设置 API 密钥或改回 127.0.0.1。';

  @override
  String get uiBrowse => '浏览…';

  @override
  String get uiBuiltIn => '内置';

  @override
  String get uiCACHE => '缓存';

  @override
  String get uiCacheHighlightColor => '缓存高亮颜色';

  @override
  String get uiCancel => '取消';

  @override
  String get uiChange => '更改';

  @override
  String get uiChanged => '已变化';

  @override
  String get uiChapterText => '章节正文';

  @override
  String get uiChapterTitle => '章节标题';

  @override
  String get uiChapters => '章节';

  @override
  String get uiCharacterName => '角色名称 *';

  @override
  String get uiCharacterNotFound => '未找到角色';

  @override
  String get uiCHARACTERS => '角色';

  @override
  String get uiCharacters => '角色';

  @override
  String get uiCharactersAreSharedImportingJustAddsThemAsMembersOfThisBank =>
      '角色是共享的，导入只会把它们加入当前语音库。';

  @override
  String get uiChooseExportFolder => '选择导出文件夹';

  @override
  String get uiChooseExportFolderForSubtitlesTTSFiles => '选择字幕和 TTS 文件导出文件夹';

  @override
  String get uiClear => '清空';

  @override
  String get uiClearAllArchivedAudio => '清空所有归档音频';

  @override
  String get uiClearAllArchivedAudio2 => '清空所有归档音频？';

  @override
  String get uiClearAllCues => '清空所有片段';

  @override
  String get uiClearAllCues2 => '清空所有片段？';

  @override
  String get uiClearAudio => '清空音频';

  @override
  String uiClearFailed(Object error) {
    return '清理失败：$error';
  }

  @override
  String get uiClearHistoryForThisCharacter => '清空该角色的历史';

  @override
  String get uiClear2 => '清空…';

  @override
  String get uiClickToSelectAudioFile => '点击选择音频文件';

  @override
  String get uiClose => '关闭';

  @override
  String get uiClosePlayer => '关闭播放器';

  @override
  String get uiComfort => '舒适';

  @override
  String get uiConcurrency => '并发数';

  @override
  String get uiConcurrency1IsSafestForLocalGPUTTSLeaveRateFieldsBlank =>
      'Concurrency 1 is safest for local GPU TTS. Leave rate fields blank for unlimited.';

  @override
  String get uiConfirm => '确认';

  @override
  String get uiContainerCodecForExportAudioWAVFLACKeepFullQualityMP3Is =>
      '“导出音频”使用的容器和编码。WAV/FLAC 保留完整质量；MP3 体积更小。';

  @override
  String get uiCopyPath => '复制路径';

  @override
  String get uiCORSOriginAllowlistCSVEmptyDenyAll => 'CORS 来源白名单（CSV，留空表示全部拒绝）';

  @override
  String uiCouldNotUseThatFolder(Object error) {
    return '无法使用该文件夹：$error';
  }

  @override
  String get uiCreate => '创建';

  @override
  String get uiCreateAVoiceBankFirst => '请先创建语音库';

  @override
  String get uiCreateCharacter => '创建角色';

  @override
  String get uiCuesWillBeAddedToThisProject => '片段会被添加到此项目。';

  @override
  String get uiCuesWillBeRemovedGeneratedAudioFilesOnDiskAreKeptBut =>
      '片段会被移除，已生成的磁盘音频仍会保留，但引用会被清掉。';

  @override
  String get uiCuesWillBeRemovedGeneratedAudioFilesOnDiskAreKeptFor =>
      '片段会被移除，已生成的磁盘音频暂时保留。';

  @override
  String get uiCurrent => '当前';

  @override
  String get uiCurrentTTSTasks => '当前 TTS 任务';

  @override
  String get uiCustomLocation => '自定义位置';

  @override
  String get uiCustomVoices => '自定义音色';

  @override
  String get uiDark => '深色';

  @override
  String get uiDataDirectory => '数据目录';

  @override
  String get uiDefault => '默认';

  @override
  String get uiDefaultLocation => '默认位置';

  @override
  String get uiDefaultMicrophone => '默认麦克风';

  @override
  String get uiDefaultModelName => '默认模型名';

  @override
  String get uiDelete => '删除';

  @override
  String get uiDeleteAudioTrack => '删除音轨？';

  @override
  String get uiDeleteChapter => '删除章节';

  @override
  String get uiDeleteChapter2 => '删除章节？';

  @override
  String get uiDeleteClip => '删除片段';

  @override
  String get uiDeleteProvider => '删除服务商？';

  @override
  String get uiDeleteSegment => '删除分段';

  @override
  String get uiText => '删除所有生成音频和导入的参考音频。项目、角色和语音库会保留。';

  @override
  String get uiDescribeTheVoiceYouWantToCreateThisWillBeUsedTo =>
      '描述你想创建的声音，这会用于生成新音色。';

  @override
  String get uiDescription => '描述';

  @override
  String get uiDescriptionOptional => '描述（可选）';

  @override
  String get uiDesignModeRequiresAVoiceDescription => '设计模式需要填写音色描述';

  @override
  String get uiDetectedUsedForWaveformExtractionAndImportedMediaAnalysis =>
      '已检测到。用于波形提取和导入媒体分析。';

  @override
  String get uiDialogue => '对话';

  @override
  String get uiDialogueRules => '对话规则';

  @override
  String get uiDone => '完成';

  @override
  String get uiDropAVoiceHereOrClickAddToTimelineOnASegment =>
      '把音频拖到这里，或点击分段上的“添加到时间线”';

  @override
  String get uiDubTimeline => '配音时间线';

  @override
  String get uiDubVideoWithTTSFromSubtitleCues => '使用字幕片段生成 TTS 视频配音';

  @override
  String get uiDuplicate => '复制';

  @override
  String get uiDuplicateAsTemplate => '复制为模板';

  @override
  String get uiDuplicateProvider => '复制服务商';

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
  String get uiEdit => '编辑';

  @override
  String get uiEDIT => '编辑';

  @override
  String get uiEditChapter => '编辑章节';

  @override
  String get uiEditCue => '编辑片段';

  @override
  String get uiEditNovelText => '编辑小说文本';

  @override
  String get uiEditSplitRule => '编辑拆分规则';

  @override
  String get uiEnableAtLeastOneProviderFirstProvidersTab =>
      '请先在“服务商”页面启用至少一个服务商';

  @override
  String get uiEnabled => '已启用';

  @override
  String get uiEncoding => '编码中…';

  @override
  String get uiEnd => '结束';

  @override
  String get uiEndMmSsMs => '结束（mm:ss.ms）';

  @override
  String get uiEndMustBeGreaterThanStart => '结束时间必须大于开始时间';

  @override
  String get uiError => '错误';

  @override
  String uiError2(Object error) {
    return '错误：$error';
  }

  @override
  String get uiExecutablePath => '可执行文件路径';

  @override
  String get uiExportAudio => '导出音频';

  @override
  String get uiExportBook => '导出整本书';

  @override
  String get uiExportCancelled => '导出已取消';

  @override
  String get uiExportDefaults => '导出默认值';

  @override
  String get uiExportDubbedAudio => '导出配音音频';

  @override
  String get uiExportDubbedVideo => '导出配音视频';

  @override
  String uiExportFailed(Object error) {
    return '导出失败：$error';
  }

  @override
  String get uiExportMerged => '导出合并音频';

  @override
  String get uiExportMergedAudio => '导出合并音频';

  @override
  String get uiExportSubtitlesSingleTTSAudio => '导出字幕 + 单条 TTS 音频';

  @override
  String get uiExportSuccessful => '导出成功';

  @override
  String get uiExportingAudio => '正在导出音频…';

  @override
  String get uiExportingVideo => '正在导出视频…';

  @override
  String get uiFailed => '失败';

  @override
  String uiFailedToDeleteCharacter(Object error) {
    return '删除角色失败：$error';
  }

  @override
  String uiFailedToFetch(Object error) {
    return '获取失败：$error';
  }

  @override
  String uiFailedToSave(Object error) {
    return '保存失败：$error';
  }

  @override
  String get uiFFmpegIsRequiredForExportConfigureItInSettings =>
      '导出需要 FFmpeg，请在设置中配置。';

  @override
  String get uiFFmpegIsRequiredForExportConfigureItInSettings2 =>
      '导出需要 FFmpeg，请在设置中配置。';

  @override
  String get uiFFmpegNotDetectedWaveformsAndMediaProbingAreSkipped =>
      '未检测到 FFmpeg，波形和媒体探测会被跳过。';

  @override
  String uiFFmpegUnavailableOnPlatform(String platform) {
    return '$platform 平台不支持 FFmpeg CLI 功能。本地混音、裁剪、波形提取和视频导出已禁用。';
  }

  @override
  String get uiFFmpegUnavailableWaveformsAndLocalExportsAreDisabled =>
      '当前平台不支持 FFmpeg CLI，波形和本地音频/视频导出已禁用。';

  @override
  String get uiFFmpegRequiredForTrimming => '裁剪需要 FFmpeg。';

  @override
  String get uiFFmpegTrimFailed => 'FFmpeg 裁剪失败。';

  @override
  String get uiFilledAutomaticallyWhenYouPickAboveOrTypeManually =>
      '选择上方项目后会自动填充，也可以手动输入';

  @override
  String get uiFont => '字号';

  @override
  String get uiGenerate => '生成';

  @override
  String get uiGenerateAll => '全部生成';

  @override
  String uiGenerateAll2(Object count) {
    return '全部生成（$count）';
  }

  @override
  String get uiGenerateAllCues => '生成所有片段';

  @override
  String get uiGenerateBook => '生成整本书';

  @override
  String get uiGenerated => '已生成';

  @override
  String get uiGenerating => '生成中…';

  @override
  String get uiGENERATION => '生成';

  @override
  String get uiGPTSoVITSCloneModeNeedsPromptText => 'GPT-SoVITS 克隆模式需要填写提示文本';

  @override
  String get uiHealthCheck => '健康检查';

  @override
  String get uiHealthCheckResults => '健康检查结果';

  @override
  String get uiHexColor => '十六进制颜色';

  @override
  String get uiHttpsExampleComHttpLocalhost3000 =>
      'https://example.com, http://localhost:3000';

  @override
  String get uiIUnderstandThisCannotBeUndone => '我理解此操作无法撤销。';

  @override
  String get uiImport => '导入';

  @override
  String uiImportCues(Object count) {
    return '导入 $count 个片段？';
  }

  @override
  String get uiImportAVideoOntoTheV1TrackFromTheTimeline => '从时间线把视频导入到 V1 轨道。';

  @override
  String get uiImportAll => '全部导入';

  @override
  String get uiImportAudio => '导入音频';

  @override
  String get uiImportFolder => '导入文件夹';

  @override
  String get uiImportFromAnotherBank => '从其他语音库导入';

  @override
  String get uiImportFromAudioLibrary => '从音频库导入';

  @override
  String get uiImportOrAddAChapterToEditNovelText => '导入或添加章节后即可编辑小说文本。';

  @override
  String get uiImportSFXFromFile => '从文件导入音效';

  @override
  String get uiImportThisCharacter => '导入此角色';

  @override
  String get uiImportTXTFiles => '导入 TXT 文件';

  @override
  String get uiImportTXTFilesImportAFolderOrAddAChapter =>
      '导入 TXT 文件、导入文件夹或添加章节。';

  @override
  String get uiImportVideo => '导入视频';

  @override
  String uiImported(Object name) {
    return '已导入“$name”';
  }

  @override
  String uiImportedCharacterS(Object count) {
    return '已导入 $count 个角色';
  }

  @override
  String uiImportedCues(Object count) {
    return '已导入 $count 个片段';
  }

  @override
  String get uiInputDevice => '输入设备';

  @override
  String get uiInstructText => '指令文本 *';

  @override
  String uiInvalidRegex(Object error) {
    return '正则无效：$error';
  }

  @override
  String get uiLanguageCode => '语言代码';

  @override
  String get uiLeaveBlankToAutoDetectEGCFfmpegBinFfmpegExe =>
      '留空自动检测（例如 C:\\ffmpeg\\bin\\ffmpeg.exe）';

  @override
  String get uiLine => '行距';

  @override
  String get uiLines => '行数';

  @override
  String get uiLoadingModels => '正在加载模型...';

  @override
  String get uiLoadingRegisteredVoices => '正在加载已注册音色...';

  @override
  String get uiLoadingServerProfiles => '正在加载服务器配置...';

  @override
  String get uiLoadingVoices => '正在加载音色...';

  @override
  String get uiManageRules => '管理规则';

  @override
  String get uiMergingAudio => '正在合并音频...';

  @override
  String get uiMode => '模式';

  @override
  String get uiModelName => '模型名';

  @override
  String get uiMultiCharacterConversations => '多角色对话';

  @override
  String get uiName => '名称';

  @override
  String get uiNameIsRequired => '名称不能为空';

  @override
  String get uiNarrator => '旁白';

  @override
  String get uiNaturalLanguageVoiceDescriptionAtSynthesisTimeThisIsSentToThe =>
      '自然语言音色描述，合成时会发送给服务商。';

  @override
  String
  get uiNaturalLanguageVoiceDescriptionAtSynthesisTimePrependItToTheText =>
      '自然语言音色描述。合成时会把它以括号形式加到文本前，例如：\n(A young woman, gentle and sweet voice)';

  @override
  String get uiNewBank => '新建语音库';

  @override
  String get uiNewCharacter => '新建角色';

  @override
  String get uiNewCharacterAddedToThisBank => '新建角色（加入此语音库）';

  @override
  String get uiNewDialogTTSProject => '新建对话配音项目';

  @override
  String get uiNewName => '新名称';

  @override
  String get uiNewNovel => '新建小说';

  @override
  String get uiNewPhaseTTSProject => '新建分段 TTS 项目';

  @override
  String get uiNewProject => '新建项目';

  @override
  String get uiNewSplitRule => '新建拆分规则';

  @override
  String get uiNewVideoDubProject => '新建视频配音项目';

  @override
  String get uiNewVoiceBank => '新建语音库';

  @override
  String get uiNewVoiceCharacter => '新建语音角色';

  @override
  String get uiNextChapter => '下一章';

  @override
  String get uiNextPage => '下一页';

  @override
  String get uiNextVoice => '下一个音色';

  @override
  String get uiNoAPIRequestsLoggedYet => '还没有 API 请求日志。';

  @override
  String get uiNoAudioTracksYet => '还没有音轨';

  @override
  String get uiNoBanksYet => '还没有语音库';

  @override
  String get uiNoCharactersInThisBankYet => '这个语音库还没有角色';

  @override
  String get uiNoCuesFoundInFile => '文件中没有找到片段';

  @override
  String get uiNoCuesYetImportAnSRTLRCFileOrAddOneManually =>
      '还没有片段。\n请导入 SRT/LRC 文件或手动添加。';

  @override
  String get uiNoDialogProjectsYet => '还没有对话配音项目';

  @override
  String get uiNoGeneratedSegmentsToMerge => '没有可合并的已生成分段。';

  @override
  String get uiNoMatches => '没有匹配项';

  @override
  String get uiNoModelsOrVoicesYetUseFetchAllOrAddManually =>
      '还没有模型或音色。请使用“全部获取”或手动添加。';

  @override
  String get uiNoPerSentenceStyleControls => '没有逐句风格控制';

  @override
  String get uiNoProjectsYet => '还没有项目';

  @override
  String get uiNoProvidersAvailable => '没有可用服务商';

  @override
  String get uiNoProvidersYet => '还没有服务商';

  @override
  String get uiNoRule => '无规则';

  @override
  String get uiNoRules => '没有规则';

  @override
  String get uiNoTTSModelsFoundGoToProvidersFetchAllToCacheAvailable =>
      '没有找到 TTS 模型。请到“服务商”页面点击“全部获取”缓存模型。';

  @override
  String get uiNoUnfinishedTTSTasksRightNow => '当前没有未完成的 TTS 任务。';

  @override
  String get uiNoVideoDubProjectsYet => '还没有视频配音项目';

  @override
  String get uiNoVideoLoaded => '未加载视频';

  @override
  String get uiNoVoicesInThisBankAddVoicesInVoiceBank => '这个语音库还没有音色，请在语音库中添加。';

  @override
  String get uiNoVoicesYetUseFetchToGetAvailableVoices =>
      '还没有音色。请使用“获取”加载可用音色。';

  @override
  String get uiNoneUploadManually => '无（手动上传）';

  @override
  String get uiNoneUseUploadedAudioOnly => '无（仅使用上传音频）';

  @override
  String get uiNotFoundInstallFfmpegOrSetAPathBelowTheAppWorks =>
      '未找到。请安装 ffmpeg（或在下方设置路径）。应用可以继续使用，但会跳过波形和媒体探测。';

  @override
  String get uiNothingToExportNoGeneratedTTSA3AudioOrUnmutedV1 =>
      '没有可导出的内容：没有已生成 TTS、A3 音频或未静音的 V1';

  @override
  String get uiNovelLongFormNarration => '小说与长篇旁白';

  @override
  String get uiOK => '确定';

  @override
  String get uiOnlyPending => '仅未完成';

  @override
  String get uiOpenFolder => '打开文件夹';

  @override
  String get uiOutputSpeakerNameOptional => '输出说话人名称（可选）';

  @override
  String get uiOverwriteWhileReading => '阅读时覆盖缓存';

  @override
  String get uiPaper => '纸张';

  @override
  String uiParseFailed(Object error) {
    return '解析失败：$error';
  }

  @override
  String get uiPasteYourNovelTextHereEachParagraphBecomesATTSSegment =>
      '在这里粘贴小说文本...\n\n每个段落会变成一个 TTS 分段。';

  @override
  String get uiPasteYourNovelTextHereUseAutoSplitToBreakItInto =>
      '在这里粘贴小说文本...\n\n使用“自动拆分”把它拆成 TTS 分段。';

  @override
  String get uiPatternIsRequired => '正则表达式不能为空';

  @override
  String get uiPending => '待处理';

  @override
  String get uiPickAClipCollectedInTheApp => '选择应用中收集的片段';

  @override
  String get uiPickAnAudioFileFromDisk => '从磁盘选择音频文件';

  @override
  String get uiPickAudio => '选择音频';

  @override
  String get uiPlayAllGeneratedAudio => '播放所有已生成音频';

  @override
  String get uiPlayFromHere => '从这里播放';

  @override
  String get uiPLAYBACK => '播放';

  @override
  String get uiPlaysTheNewLineOnceItFinishes => '新行生成完成后自动播放';

  @override
  String get uiPort => '端口';

  @override
  String get uiPortableNextToExecutable => '便携模式（位于可执行文件旁）';

  @override
  String get uiPreview => '预览';

  @override
  String get uiPreviousChapter => '上一章';

  @override
  String get uiPreviousPage => '上一页';

  @override
  String get uiPreviousVoice => '上一个音色';

  @override
  String get uiProbing => '检测中…';

  @override
  String get uiProjectName => '项目名称';

  @override
  String get uiPromptLanguage => '提示文本语言';

  @override
  String get uiPromptTextSpokenInRefAudio => '提示文本（参考音频中朗读）';

  @override
  String get uiPromptTextSpokenInRefAudio2 => '提示文本（参考音频中朗读）*';

  @override
  String get uiProvider => '服务商';

  @override
  String get uiProviderNotFoundForThisCharacter => '未找到此角色对应的服务商';

  @override
  String get uiQueueRateLimits => '队列与速率限制';

  @override
  String get uiQueued => '排队中';

  @override
  String get uiQUICKTEST => '快速测试';

  @override
  String get uiRateLimitReqMinIP0Off => '速率限制（请求/分钟/IP，0 为关闭）';

  @override
  String get uiReCheck => '重新检查';

  @override
  String get uiReRecord => '重新录制';

  @override
  String get uiReaderAppearance => '阅读器外观';

  @override
  String get uiReaderAppearance2 => '阅读器外观';

  @override
  String get uiRecent => '最近';

  @override
  String get uiRecord => '录制';

  @override
  String get uiRecordAudio => '录制音频';

  @override
  String
  get uiRecordExternalAPIRequestMetadataInThisPanelRequestBodiesAndAuth =>
      '在此面板记录外部 API 请求元数据。请求正文和认证头不会被保存。';

  @override
  String uiRecordingFailed(Object error) {
    return '录音失败：$error';
  }

  @override
  String get uiREFERENCEAUDIO => '参考音频';

  @override
  String get uiReferenceLanguage => '参考语言';

  @override
  String get uiReferenceText => '参考文本';

  @override
  String get uiReferenceTranscript => '参考转写';

  @override
  String get uiRegenerate => '重新生成';

  @override
  String get uiRegenerateAll => '全部重新生成';

  @override
  String get uiRegexPattern => '正则表达式';

  @override
  String get uiRegisteredVoice => '已注册音色';

  @override
  String get uiRemoveFromBank => '从语音库移除';

  @override
  String get uiRename => '重命名';

  @override
  String get uiRenameVoiceBank => '重命名语音库';

  @override
  String get uiReplace => '替换';

  @override
  String get uiReplaceOriginal => '替换原文件';

  @override
  String get uiRequestsDay => '请求 / 天';

  @override
  String get uiRequestsMin => '请求 / 分钟';

  @override
  String get uiReset => '重置';

  @override
  String get uiRunAutoSplitToCreateSegments => '运行自动拆分来创建分段';

  @override
  String get uiRunGenerateAllImmediatelyCuesWithoutAVoiceAreSkipped =>
      '立即运行全部生成。没有分配音色的片段会被跳过。';

  @override
  String get uiRunTTSForThisCueImmediatelyAfterSavingNeedsAVoiceIn =>
      '保存后立即为此片段运行 TTS。需要语音库中有可用音色。';

  @override
  String get uiRunning => '运行中';

  @override
  String uiRunningOn(Object address) {
    return '运行于 $address';
  }

  @override
  String get uiSave => '保存';

  @override
  String get uiSaveExit => '保存并退出';

  @override
  String get uiSaveLeave => '保存并离开';

  @override
  String get uiSaveRestart => '保存并重启';

  @override
  String get uiSaveAsNew => '另存为新音频';

  @override
  String get uiSaveAsVoiceAsset => '保存为音频素材';

  @override
  String get uiSaveChanges => '保存更改';

  @override
  String get uiSaveSegment => '保存分段';

  @override
  String get uiSaved => '已保存';

  @override
  String uiSavedToVoiceAssets(Object name) {
    return '已将“$name”保存到音频素材';
  }

  @override
  String uiScanFailed(Object error) {
    return '扫描失败：$error';
  }

  @override
  String get uiScanNow => '立即扫描';

  @override
  String get uiScanning => '扫描中…';

  @override
  String get uiSCRIPT => '脚本';

  @override
  String get uiSearchCharacters => '搜索角色...';

  @override
  String get uiSearchProjects => '搜索项目';

  @override
  String get uiSearchVoices => '搜索音色';

  @override
  String get uiSearch => '搜索…';

  @override
  String get uiSEGMENTS => '分段';

  @override
  String get uiSelectABankAndCharacterToEdit => '选择语音库和角色进行编辑';

  @override
  String get uiSelectACharacterToEdit => '选择角色进行编辑';

  @override
  String get uiSelectACharacterToQuickTest => '选择角色进行快速测试';

  @override
  String get uiSelectATrack => '选择音轨';

  @override
  String get uiSelectAVoxCPM2Mode => '选择 VoxCPM2 模式';

  @override
  String get uiSelectFromVoiceAssets => '从音频素材中选择';

  @override
  String get uiSelectModel => '选择模型';

  @override
  String get uiSelectOrAddAProvider => '选择或添加服务商';

  @override
  String get uiSelectOrCreateAVoiceBank => '选择或创建语音库';

  @override
  String get uiSelectOrEnterAGPTSoVITSSpeaker => '选择或输入 GPT-SoVITS 说话人';

  @override
  String get uiSelectSpeaker => '选择说话人';

  @override
  String get uiSelectVoice => '选择音色';

  @override
  String uiSendFailed(Object error) {
    return '发送失败：$error';
  }

  @override
  String get uiSentenceVoice => '句子音色';

  @override
  String get uiServerProfile => '服务器配置';

  @override
  String get uiSETTINGS => '设置';

  @override
  String get uiSingleAudioTracksForVoiceCloning => '用于声音克隆的单条音轨';

  @override
  String get uiSkipPunctuationOnlyText => '跳过纯标点文本';

  @override
  String get uiSlice => '切分长度';

  @override
  String get uiSliceAfterPunctuation => '仅在标点后切分';

  @override
  String get uiSourceBank => '来源语音库';

  @override
  String get uiSourceVideoMissingOnDisk => '源视频文件在磁盘上缺失';

  @override
  String get uiSpaceEnterPToPlayOrStop => '空格 / Enter / P 播放或停止';

  @override
  String get uiSpeakerVoiceID => '说话人 / 音色 ID *';

  @override
  String get uiSpeed10Normal => '语速（1.0 = 正常）';

  @override
  String get uiSplitAtBlankLines => '按空行拆分';

  @override
  String get uiSplitAtRegexMatch => '按正则匹配拆分';

  @override
  String get uiSplitRules => '拆分规则';

  @override
  String get uiStart => '开始';

  @override
  String get uiStartMmSsMs => '开始（mm:ss.ms）';

  @override
  String get uiSTATS => '统计';

  @override
  String get uiStopped => '已停止';

  @override
  String get uiStyleDirection => '风格 / 指令';

  @override
  String get uiStyleInstruction => '风格指令';

  @override
  String get uiStyleInstructionOptional => '风格指令（可选）';

  @override
  String get uiSubtitleText => '字幕文本';

  @override
  String get uiSubtitles => '字幕';

  @override
  String get uiSyncCueLengthsToTTS => '同步片段长度到 TTS';

  @override
  String get uiSyncWithDisk => '与磁盘同步';

  @override
  String get uiSynthesizeTTSRightAfterSending => '发送后立即合成 TTS';

  @override
  String get uiTapToChange => '点击更改';

  @override
  String get uiTextIsRequired => '文本不能为空';

  @override
  String get uiTextLanguageOptional => '文本语言（可选）';

  @override
  String get uiTextLanguageSynthesisOutput => '文本语言（合成输出）';

  @override
  String uiThisProjectAlreadyHasCuesReplaceThemOrAppendTheNewCues(
    Object count,
  ) {
    return '此项目已有 $count 个片段。要替换它们，还是追加到后面？';
  }

  @override
  String get uiTimeline => '时间线';

  @override
  String get uiTotalLength => '总时长';

  @override
  String get uiTranscriptOfTheAudioUsedByVoiceCloningModelsThatNeedIt =>
      '音频转写（供需要转写的声音克隆模型使用）';

  @override
  String get uiTranscriptOfTheReferenceAudio => '参考音频的转写文本';

  @override
  String get uiTrim => '裁剪';

  @override
  String get uiTrimApplied => '裁剪已应用';

  @override
  String get uiTTSQueueIsIdle => 'TTS 队列空闲';

  @override
  String get uiTypeBelowToTestThisVoice => '在下方输入文本测试该音色';

  @override
  String get uiTypeDialogLineEnterToSendCtrlEnterForNewline =>
      '输入对话行…（Enter 发送，Ctrl+Enter 换行）';

  @override
  String get uiTypeSomethingToTest => '输入内容进行测试...';

  @override
  String get uiUltraCloneModeRequiresAPromptText => '极速克隆模式需要填写提示文本';

  @override
  String get uiUnknown => '未知';

  @override
  String get uiUnsavedChanges => '未保存的更改';

  @override
  String get uiUnavailableOnThisPlatform => '当前平台不可用';

  @override
  String get uiUploadAVoiceSampleTheModelWillCloneItsToneAndSpeak =>
      '上传音频样本，模型会克隆其音色并用任意语言朗读合成文本。';

  @override
  String get uiUploadAVoiceSampleToUseAsTheBaseVoiceInsteadOf =>
      '上传音频样本作为基础音色，而不是使用预设配置。';

  @override
  String get uiUploadAnAudioFileOrRecordANewSampleToGetStarted =>
      '上传音频文件或录制新样本即可开始。';

  @override
  String get uiUploadAudio => '上传音频';

  @override
  String get uiUseChaptersBelowToImportTXTImportAFolderOrAddA =>
      '使用下方章节区导入 TXT、导入文件夹或添加章节。';

  @override
  String get uiUseFormatMmSsMsOrHHMmSsMs => '请使用 mm:ss.ms 或 HH:mm:ss.ms 格式';

  @override
  String get uiUsedByTheVideoDubEditorSExportAudioExportVideoButtons =>
      '用于视频配音编辑器中的“导出音频 / 导出视频”按钮。';

  @override
  String get uiUsingOverride => '正在使用自定义路径';

  @override
  String get uiVideoAudioCodec => '视频音频编码';

  @override
  String get uiVideoCodec => '视频编码';

  @override
  String get uiVoice => '音色';

  @override
  String get uiVoiceSpeakerID => '音色 / 说话人 ID';

  @override
  String get uiVoiceSpeakerName => '音色 / 说话人名称';

  @override
  String get uiVoiceAssetDirectory => '音频素材目录';

  @override
  String get uiVoiceAssetDirectoryResetToDefault => '音频素材目录已重置为默认值';

  @override
  String uiVoiceAssetDirectorySetTo(Object path) {
    return '音频素材目录已设置为 $path';
  }

  @override
  String get uiVoiceBank => '语音库';

  @override
  String get uiVoiceDescription => '音色描述 *';

  @override
  String get uiVoiceDesignRequiresAVoiceDescription => '声音设计需要填写音色描述';

  @override
  String get uiVoiceForAll => '全部使用的音色';

  @override
  String get uiVoiceInstruction => '音色指令';

  @override
  String get uiVoiceName => '音色名称';

  @override
  String get uiVoiceSettings => '音色设置';

  @override
  String get uiVOICES => '音色';

  @override
  String get uiVOICESINBANK => '语音库中的音色';

  @override
  String get uiWaiting => '等待中';

  @override
  String get uiYouCanConfigureTheURLAPIKeyAndModelAfterCreation =>
      '创建后可以配置 URL、API 密钥和模型。';

  @override
  String get uiYouHaveUnsavedChangesInThisProjectSaveBeforeLeaving =>
      '此项目有未保存的更改，离开前保存吗？';

  @override
  String get uiZhEnJaKo => 'zh / en / ja / ko ...';

  @override
  String uiAudioExportFailed(Object error) {
    return '音频导出失败：$error';
  }

  @override
  String uiExportedCuesAudioFilesTo(
    Object cueCount,
    Object audioCount,
    Object path,
  ) {
    return '已导出 $cueCount 个片段 + $audioCount 个音频文件到 $path';
  }

  @override
  String uiExportedCuesAudioFilesToMissing(
    Object cueCount,
    Object audioCount,
    Object path,
    Object missingCount,
  ) {
    return '已导出 $cueCount 个片段 + $audioCount 个音频文件到 $path（$missingCount 个缺失）';
  }

  @override
  String get uiNoNovelProjectsYet => '还没有小说项目';

  @override
  String uiSidecarSRTFailed(Object error) {
    return 'SRT 字幕文件写入失败：$error';
  }

  @override
  String uiSRTSidecarWrittenTo(Object name) {
    return 'SRT 字幕文件已写入 $name。';
  }

  @override
  String get startupLastPage => '上次关闭前的页面';

  @override
  String get fontSettingsTitle => '界面字体';

  @override
  String get fontSettingsSubtitle => '使用应用默认字体或操作系统界面字体。';

  @override
  String get fontModeAppDefault => '应用默认';

  @override
  String get fontModeSystem => '系统字体';

  @override
  String fontModeSaved(String font) {
    return '字体已设为 $font。';
  }

  @override
  String get uiVideoDubUnavailableOnAndroidPhone => 'Android 手机端已禁用视频配音';

  @override
  String get uiVideoDubUnavailableOnAndroidPhoneDescription =>
      '视频剪辑需要比长屏手机更多的横向空间。请使用平板、折叠屏宽屏布局、桌面端或 Web 窗口编辑视频配音项目。';

  @override
  String get uiDetails => '详情';
}
