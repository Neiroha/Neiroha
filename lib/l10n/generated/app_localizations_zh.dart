// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get webFeatureUnavailable => '这个功能依赖桌面文件或媒体工具，请在 Neiroha 桌面端使用。';

  @override
  String get webStorageUnavailable => 'Neiroha 无法打开浏览器存储。请允许站点存储，或换用新版浏览器。';

  @override
  String get webStorageDescription =>
      '服务商、音色、音色库和偏好保存在当前浏览器。生成的音频留在本页内存中，刷新或关闭标签页后清除。';

  @override
  String get webSessionAudio => '刷新后会清空试听历史。需要保留的片段可以下载。';

  @override
  String get webLocalAudioUnavailable => '参考音频和头像文件需要使用桌面端。';

  @override
  String get webSpeechAdapterUnavailable =>
      '此服务商适配器不支持 Web 试听。请在角色设置中选择可在浏览器使用的服务商。';

  @override
  String get webSpeechProviderDisabled => '此角色的服务商已禁用。请启用服务商，或在角色设置中更换。';

  @override
  String get webSpeechEndpointInvalid => '服务商地址无效。请在服务商设置中填写完整的 HTTP(S) 地址。';

  @override
  String get webRealtimeUnavailable =>
      'Web 暂不支持 OpenAI Realtime。请在角色设置中选择 Speech 模型，或使用桌面端。';

  @override
  String get webGeminiLiveUnavailable =>
      '此模型需要 Gemini Live。请选择 gemini-3.8-flash-tts 等 Gemini TTS 模型。';

  @override
  String get webOpenAiRealtimeWrongAdapter =>
      '在 Web 使用 OpenAI 官方地址时请选择 Speech 模型。桌面端使用 Realtime 时请选择 OpenAI 官方适配器。';

  @override
  String get webMiMoModelRetired => 'MiMo V2 TTS 已停用。请选择 mimo-v2.5-tts。';

  @override
  String get webSpeechLocalReference => '此角色的合成需要本地参考音频，请使用桌面端或选择预设音色角色。';

  @override
  String get webSpeechPresetRequired => '请在角色设置中选择 OpenAI 预设音色。';

  @override
  String get webSpeechIncompatibleVoice => '此音色与所选模型不兼容。请在角色设置中重新选择音色。';

  @override
  String get quickTtsPlaybackMode => '试听播放方式';

  @override
  String get quickTtsStreamPlayback => '优先流式';

  @override
  String get quickTtsFullPlayback => '整段生成';

  @override
  String get webProviderNetworkError => '浏览器无法连接服务商。请检查地址，并在服务商侧允许本站来源（CORS）。';

  @override
  String get webDownloadAudio => '下载音频';

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
  String get navProviders => 'AI 服务';

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
  String get aboutSubtitle => 'v0.5.1 - AI 音频中间件与配音工作站';

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
  String get uiAppSupportMacOs => '应用支持目录（macOS 标准位置）';

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
  String get uiExportVideo => '导出视频';

  @override
  String get uiExportBook => '导出整本书';

  @override
  String get uiExportNovelAudio => '导出小说音频';

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
  String get uiExporting => '正在导出…';

  @override
  String get uiExportingAudio => '正在导出音频…';

  @override
  String get uiExportingNovelAudio => '正在导出小说音频…';

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
  String get uiGenerateFullBookCacheBeforeExporting => '请先生成整本书缓存再导出。';

  @override
  String uiGenerateAllStopped(Object error) {
    return '全部生成已停止：$error';
  }

  @override
  String get uiGenerated => '已生成';

  @override
  String uiGeneratedCues(Object done) {
    return '已生成 $done 个片段';
  }

  @override
  String uiGeneratedCuesWithFailures(Object done, Object failed) {
    return '已生成 $done 个片段，$failed 个失败';
  }

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
  String get uiLeaveBlankToAutoDetectMacOsFfmpeg =>
      '留空自动检测（例如 /opt/homebrew/bin/ffmpeg）';

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
  String get uiNoCuesToGenerateAssignVoiceFirst => '没有可生成的片段，请先分配音色';

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
  String get uiNoReadableSegmentsToExport => '没有可导出的可读分段。';

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
  String get uiNovelCacheCompleted => '小说缓存已完成。';

  @override
  String uiNovelCacheCompletedWithFailures(Object failed) {
    return '小说缓存已完成，$failed 个分段失败。';
  }

  @override
  String get uiNovelCacheOverwritten => '小说缓存已覆盖。';

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
  String get uiProjectSettings => '项目设置';

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
  String get uiDontSave => '不保存';

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
  String get splitRuleNewlineName => '按段落（空行分隔）';

  @override
  String get splitRuleSentenceName => '按句号（中英文）';

  @override
  String get splitRuleQuotesName => '按引号（中英文）';

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
  String uiVoiceCount(Object count) {
    return '$count 个音色';
  }

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
  String get healthCheckTimeoutTitle => '健康检查超时';

  @override
  String get healthCheckTimeoutSubtitle => '超过时限就停止服务商和语音库健康检查。';

  @override
  String healthCheckTimeoutSaved(int seconds) {
    return '健康检查超时已保存：$seconds 秒';
  }

  @override
  String get healthCheckFailedTooltip => '健康检查失败';

  @override
  String get uiDisabled => '已禁用';

  @override
  String get uiProviderMissing => '服务商缺失';

  @override
  String get uiReachable => '可访问';

  @override
  String get uiUnreachable => '不可访问';

  @override
  String get uiNoHealthCheckResults => '没有健康检查结果。';

  @override
  String unhealthyVoiceWarning(String voice) {
    return '$voice 的健康检查失败，生成可能会失败。';
  }

  @override
  String get novelPureReadingMode => '纯阅读模式';

  @override
  String get novelPlaybackGap => '停顿';

  @override
  String get novelTextFilters => '文本过滤';

  @override
  String get novelTextFilterRules => '文本过滤规则';

  @override
  String get novelNewTextFilterRule => '新建文本过滤规则';

  @override
  String get novelEditTextFilterRule => '编辑文本过滤规则';

  @override
  String get novelReplacement => '替换为';

  @override
  String get novelReplacementHint => '留空则删除匹配文本。';

  @override
  String get novelPatternRequired => '正则不能为空';

  @override
  String get novelSaveApply => '保存并应用';

  @override
  String get pressBackAgainToExit => '再按一次返回键退出。';

  @override
  String uiVideoDubMissingVoiceSkippedText(Object missingVoice) {
    return '$missingVoice 个未分配音色的片段会被跳过。';
  }

  @override
  String uiVideoDubRegenerateExistingCuesPrompt(
    Object alreadyDone,
    Object pending,
    Object missingVoiceText,
  ) {
    return '$alreadyDone 个片段已有音频，$pending 个待生成。$missingVoiceText是否也重新生成已有音频，还是只补齐缺口？';
  }

  @override
  String get uiAutoTtsSkippedNoVoices => '自动 TTS 已跳过，语音库中没有音色';

  @override
  String get uiVideoDubUnavailableOnAndroidPhone => 'Android 手机端已禁用视频配音';

  @override
  String get uiVideoDubUnavailableOnAndroidPhoneDescription =>
      '视频剪辑需要比长屏手机更多的横向空间。请使用平板、折叠屏宽屏布局或桌面端编辑视频配音项目。';

  @override
  String get uiDetails => '详情';

  @override
  String get uiVoiceForImportedCues => '导入片段使用的音色';

  @override
  String get uiVoiceForImportedCuesHint => '从本项目语音库中选择角色，或保持未分配，稍后逐条指定。';

  @override
  String get uiLeaveUnassigned => '暂不分配';

  @override
  String get uiCloudVoiceCloneHint => '请在上方选择音色，或添加参考音频，保存时在服务商账号上克隆新音色。';

  @override
  String uiCloudVoiceCloneFailed(Object error) {
    return '音色克隆失败：$error';
  }

  @override
  String get uiIndexTtsEmotionHint => '可选的情感描述（需 WebUI 开启实验性情感模式）';

  @override
  String get uiApiAutoStart => '启动时自动开启 API 服务';

  @override
  String get uiApiAutoStartDescription =>
      'Neiroha 打开时自动启动本地 API 与 MCP 服务，Agent 无需手动开启即可连接。';

  @override
  String get uiMcpEndpoint => '供 AI Agent 使用的 MCP 服务';

  @override
  String uiMcpEndpointDescription(Object url) {
    return '允许 Agent 通过 $url（Streamable HTTP）管理服务商、音色与配音任务。若上方设置了 API Key 则需携带。';
  }

  @override
  String get loudnessAction => '统一音量';

  @override
  String get loudnessActionTooltip => '把所有已生成音频调整到相同响度';

  @override
  String get loudnessTitle => '统一音量';

  @override
  String loudnessIntro(Object count) {
    return '逐段测量 $count 段已生成音频的感知响度（LUFS），再把每段调整到同一目标。只改变增益，限幅器防止峰值削波。文件原地改写，时间线与导出会自动使用新音量。';
  }

  @override
  String get loudnessTarget => '目标响度';

  @override
  String get loudnessPresetLoud => '响亮';

  @override
  String get loudnessPresetLoudHint => '-14 LUFS · 短视频、音乐平台';

  @override
  String get loudnessPresetStandard => '标准';

  @override
  String get loudnessPresetStandardHint => '-16 LUFS · 播客、有声书、旁白';

  @override
  String get loudnessPresetSoft => '柔和';

  @override
  String get loudnessPresetSoftHint => '-20 LUFS · ASMR、助眠、耳语内容';

  @override
  String get loudnessPresetBroadcast => '广播';

  @override
  String get loudnessPresetBroadcastHint => '-23 LUFS · EBU R128 广播标准';

  @override
  String get loudnessPresetCustom => '自定义';

  @override
  String get loudnessPresetCustomHint => '在 -30 ~ -10 LUFS 之间自选目标';

  @override
  String get loudnessKeepBackup => '保留原始音频备份';

  @override
  String get loudnessKeepBackupHint =>
      '原件存入音频旁的 _original_audio 文件夹；之后再次统一会从原件处理，更换目标也不会叠加音质损失。';

  @override
  String get loudnessAnalyze => '分析';

  @override
  String loudnessAnalyzing(Object done, Object total) {
    return '正在分析 $done / $total';
  }

  @override
  String loudnessApplying(Object done, Object total) {
    return '正在处理 $done / $total';
  }

  @override
  String loudnessApply(Object count) {
    return '统一 $count 段';
  }

  @override
  String get loudnessRange => '当前范围';

  @override
  String get loudnessSpread => '最大差值';

  @override
  String get loudnessNeedsChange => '需调整';

  @override
  String loudnessSummary(
    Object adjusted,
    Object onTarget,
    Object silent,
    Object failed,
  ) {
    return '已调整 $adjusted 段 · 已达标 $onTarget 段 · 静音跳过 $silent 段 · 失败 $failed 段';
  }

  @override
  String loudnessLastError(Object error) {
    return '最近错误：$error';
  }

  @override
  String get loudnessNoAudio => '还没有可统一的已生成音频。';

  @override
  String get loudnessFfmpegRequired => '统一音量需要 FFmpeg，请在设置中配置。';

  @override
  String get loudnessStop => '停止';

  @override
  String phaseStatsGenerated(Object done, Object total) {
    return '已生成 $done/$total';
  }

  @override
  String phaseStatsFailed(Object count) {
    return '失败 $count';
  }

  @override
  String phaseStatsUnassigned(Object count) {
    return '未分配音色 $count';
  }

  @override
  String get phaseFilterAll => '全部';

  @override
  String get phaseFilterPending => '待生成';

  @override
  String get phaseFilterDone => '已生成';

  @override
  String get phaseFilterFailed => '失败';

  @override
  String get phaseNoFilterMatches => '没有符合筛选条件的分段。';

  @override
  String get phaseApplyVoiceToAll => '应用到全部';

  @override
  String get phaseEditText => '编辑文本';

  @override
  String get phaseEditTextHint => '保存修改后的文本会清除该段已生成的音频。';

  @override
  String get phaseResplitTitle => '重新拆分文稿？';

  @override
  String phaseResplitBody(Object count) {
    return '这会替换当前 $count 个分段，以及它们的音色分配、风格设置和已生成音频的关联。';
  }

  @override
  String get phaseResplitConfirm => '重新拆分';

  @override
  String phaseCharCount(Object count) {
    return '$count 字';
  }

  @override
  String get phasePlay => '播放';

  @override
  String get phasePlayAll => '播放全部';

  @override
  String get phaseStopPlayback => '停止';

  @override
  String get phaseMoreActions => '更多操作';

  @override
  String get loudnessAutoTitle => '生成后自动统一音量';

  @override
  String loudnessAutoHint(Object target) {
    return '新生成的音频自动调整到语音库基准（$target LUFS），再叠加各角色的音量偏移。';
  }

  @override
  String get loudnessCharacterOffset => '音量偏移';

  @override
  String get loudnessCharacterOffsetHint =>
      '相对语音库基准响度。例如旁白设 -3 dB 压在角色之下，主角设 +1 ~ +2 dB 略微突出。';

  @override
  String get loudnessBankTarget => '基准响度';

  @override
  String get loudnessBankTargetHint =>
      '开启音量统一的工程会把该语音库的音频调整到此响度，再叠加各角色偏移。旁白约 -16 LUFS，ASMR 约 -20 LUFS 较合适。';

  @override
  String get bankDeactivate => '取消激活';

  @override
  String get bankSetActive => '设为激活';

  @override
  String get bankSettingsMenu => '设置…';

  @override
  String get bankSettingsTitle => '语音库设置';

  @override
  String get loudnessUseOffsets => '应用角色音量偏移';

  @override
  String get loudnessUseOffsetsHint => '每位说话人对齐到“目标 + 自身偏移”，例如旁白低几 dB。';

  @override
  String loudnessRestore(Object count) {
    return '还原原始音量（$count）';
  }

  @override
  String loudnessRestored(Object count) {
    return '已将 $count 段还原为原始音量。';
  }

  @override
  String get phaseStopGenerating => '停止生成';

  @override
  String phaseRetryFailed(Object count) {
    return '重试失败（$count）';
  }

  @override
  String get phaseSelectMode => '多选';

  @override
  String get phaseAddSegment => '添加分段';

  @override
  String phaseSelectedCount(Object count) {
    return '已选 $count';
  }

  @override
  String get phaseSelectAll => '全选';

  @override
  String get phaseAssignVoice => '指定音色';

  @override
  String get phaseRegenerateSelected => '重新生成所选';

  @override
  String get phaseDeleteSelected => '删除所选';

  @override
  String get phaseExitSelect => '退出多选';

  @override
  String get phaseInsertBelow => '在下方插入';

  @override
  String get phaseMergeNext => '与下一段合并';

  @override
  String get phaseSplit => '拆分…';

  @override
  String get phaseSplitTitle => '拆分分段';

  @override
  String get phaseSplitHint => '点击第二段开始的位置。';

  @override
  String get phaseSplitAction => '在光标处拆分';

  @override
  String get phaseInsertTitle => '新分段';

  @override
  String get phaseInsertAction => '插入';

  @override
  String phaseDeletedCount(Object count) {
    return '已删除 $count 个分段';
  }

  @override
  String get phaseUndo => '撤销';

  @override
  String get phaseDragToReorder => '拖动排序';

  @override
  String get phaseShortcuts =>
      '快捷键：↑/↓ 切换 · 空格 播放/停止 · 回车 生成 · F2 编辑 · Delete 删除 · Esc 取消 · Ctrl+A 全选（多选模式）· Ctrl+S 保存';

  @override
  String get phaseMergeSettings => '播放与导出设置';

  @override
  String get phaseMergeGap => '段间停顿';

  @override
  String get phaseMergeGapHint => '用于「播放全部」与「导出合并音频」。';

  @override
  String get phaseFadeIn => '淡入';

  @override
  String get phaseFadeOut => '淡出';

  @override
  String get phaseFadeHint => '合并导出时作用于每一段：10–50 ms 可消除拼接处的爆音，更长则让每句起落更柔和。';

  @override
  String get sectionReferenceAudio => '参考音频';

  @override
  String get sectionCharacterInfo => '角色信息';

  @override
  String get sectionProvider => '服务商';

  @override
  String get sectionModel => '模型';

  @override
  String get sectionVoice => '音色';

  @override
  String get sectionVoiceNameOptional => '音色名称（可选）';

  @override
  String get sectionVoiceDescription => '音色描述';

  @override
  String get sectionCosyvoiceMode => 'CosyVoice 模式';

  @override
  String get sectionServerProfileOptional => '服务器配置（可选）';

  @override
  String get sectionInstruct => '指令';

  @override
  String get sectionVoxcpm2Mode => 'VoxCPM2 模式';

  @override
  String get sectionGptSovitsMode => 'GPT-SoVITS 模式';

  @override
  String get sectionTrainedSpeaker => '训练好的说话人';

  @override
  String get sectionVoiceClone => '音色克隆';

  @override
  String get sectionVoiceDesign => '音色设计';

  @override
  String get sectionOutput => '输出';

  @override
  String get autoFillProviderSpeaker => '自动填充：服务商 + 说话人';

  @override
  String get statusIdle => '空闲';

  @override
  String get statusPreview => '试听';

  @override
  String novelGeneratingSegments(Object count) {
    return '正在生成 $count 段';
  }

  @override
  String novelGeneratingShort(Object count) {
    return '生成中 $count';
  }

  @override
  String get novelEpubReserved => '暂不支持导入 EPUB，已导入其中的 TXT 文件。';

  @override
  String novelImportFailed(Object error) {
    return '导入失败：$error';
  }

  @override
  String get novelSegmentSaved => '分段已保存。';

  @override
  String get novelSegmentDeleted => '分段已删除。';

  @override
  String novelDeleteChapterMessage(Object title) {
    return '将删除《$title》及其缓存音频。';
  }

  @override
  String get novelChapterDeleted => '章节已删除。';

  @override
  String novelDialogueRulesSaved(Object count) {
    return '对话规则已保存，重建了 $count 个分段。';
  }

  @override
  String get novelTextFiltersSaved => '文本过滤规则已保存，过期的音频会在需要时重新生成。';

  @override
  String novelPlaybackStopped(Object error) {
    return '播放已停止：$error';
  }

  @override
  String get novelNarrator => '旁白';

  @override
  String get novelDialogue => '对白';

  @override
  String novelSegmentLabel(Object index) {
    return '第 $index 段';
  }

  @override
  String get phaseNoAudioToPlay => '没有可播放的已生成音频。';

  @override
  String get dialogLineFallback => '台词';

  @override
  String get videoDubDeleteV1First => '请先删除 V1 片段，只允许一个源视频。';

  @override
  String get statusWritingWav => '正在录制 WAV';

  @override
  String novelImported(Object chapters, Object segments) {
    return '已导入 $chapters 章、$segments 个分段。';
  }

  @override
  String get novelImportFolderTitle => '导入小说文件夹';

  @override
  String get uiStopSynthesis => '停止生成';

  @override
  String get uiAudioBuffering => '正在缓冲…';

  @override
  String get roleReadMode => '阅读';

  @override
  String get roleReviewMode => '角色校对';

  @override
  String get roleCharacters => '作品角色';

  @override
  String get roleAddCharacter => '添加人物';

  @override
  String get roleName => '人物名';

  @override
  String get roleAliases => '别名（用逗号分隔）';

  @override
  String get roleDescription => '人物描述';

  @override
  String get roleNoCharacter => '未确定人物';

  @override
  String get roleVoice => '音色';

  @override
  String get roleDefaultVoice => '使用项目默认音色';

  @override
  String get roleChapterOverride => '仅覆盖当前章节的音色';

  @override
  String get roleSelected => '校对所选句';

  @override
  String get rolePickSentence => '点选正文中的一句开始校对';

  @override
  String get roleCategory => '类型';

  @override
  String get roleNarrator => '旁白';

  @override
  String get roleDialogue => '对白';

  @override
  String get roleThought => '心理活动';

  @override
  String get roleSystem => '系统文本';

  @override
  String get roleScope => '修改范围';

  @override
  String get roleOnlySentence => '仅这一句';

  @override
  String get roleChapterUnlocked => '本章同人物的未锁定句';

  @override
  String get roleLock => '锁定人工结果';

  @override
  String get roleApply => '应用修改';

  @override
  String get roleUndo => '撤销上次台词修改';

  @override
  String get rolePending => '待确认';

  @override
  String get roleInferred => '根据上下文推断';

  @override
  String get roleConflict => '存在冲突';

  @override
  String get roleConfirmed => '人工已确认';

  @override
  String get roleInstruction => '本句风格覆盖（可留空）';

  @override
  String get roleSentenceVoice => '本句音色覆盖';

  @override
  String get roleMerge => '合并人物';

  @override
  String get roleMergeInto => '合并到';

  @override
  String get roleManualReason => '人工校对';

  @override
  String get roleCached => '音频缓存有效';

  @override
  String get roleStaleCache => '音频需要重新生成';

  @override
  String get roleNoCache => '尚未生成音频';

  @override
  String get roleRename => '编辑人物';

  @override
  String get rolePreview => '试听所选句';

  @override
  String get rolePendingList => '待确认台词';

  @override
  String get roleNoPending => '当前章节无待确认台词';

  @override
  String get roleAnalysisModel => '角色分析模型（文本模型 ID）';

  @override
  String get roleAnalysisProvider => '分析连接';

  @override
  String get roleAnalysisStart => '分析当前章节';

  @override
  String get roleAnalysisResume => '确认角色表并继续 / 恢复';

  @override
  String get roleAnalysisPause => '暂停分析';

  @override
  String get roleAnalysisFeedback => '补充人物或校对意见';

  @override
  String get roleAnalysisReplan => '按新意图重规划角色表';

  @override
  String get roleAnalysisBudget =>
      '仅分析当前章节；每次最多 12 次分析请求，未验证模型另有一次工具检查，可能计费。人工锁定与已确认句会保留。';

  @override
  String get roleAnalysisOffline => '在服务商页配置连接后，再选择分析模型。';

  @override
  String get modelDiscover => '发现模型 / 能力';

  @override
  String get modelRefresh => '从当前连接刷新';

  @override
  String get modelManual => '手动使用此模型';

  @override
  String get modelUnknown => '未知';

  @override
  String get modelSupported => '支持';

  @override
  String get modelUnsupported => '不支持';

  @override
  String get roleToolModelHint => '仅使用支持文本与函数调用的模型。首次使用能力未知的模型时，会先用短示例验证工具调用。';

  @override
  String get modelCapabilityHint => '目录描述能力；当前账号是否可用，需要实际成功调用确认。不会自动发起付费探测。';

  @override
  String get modelOverride => '覆盖此路由的任务能力';

  @override
  String get modelNoModels => '暂无缓存模型，可刷新或手填模型 ID。';

  @override
  String get roleStagePlan => '规划人物';

  @override
  String get roleStageRoster => '等待角色表复核';

  @override
  String get roleStageLabel => '标注台词';

  @override
  String get roleStageValidate => '校验结果';

  @override
  String get roleStageReview => '复核疑点';

  @override
  String get roleStageReplan => '按反馈调整角色';

  @override
  String get roleStagePaused => '已暂停';

  @override
  String get roleStageCompleted => '已完成';

  @override
  String get roleStageFailed => '分析失败';

  @override
  String get roleAnalysisSentences => '句';

  @override
  String get roleAnalysisCalls => '次调用';

  @override
  String get roleSplitText => '拆分正文';

  @override
  String get roleSplitTextHelp => '选择正文范围可拆出该段，或将光标放在拆分点；保留所有原文和现有标注。';

  @override
  String get roleMergeText => '合并正文';

  @override
  String get roleMergeTextHelp =>
      '合并从当前片段到所选末段。人物或风格不一致时清除归属并标记待确认；旧音频保留但不再使用。';

  @override
  String get roleMergeUntil => '合并至';

  @override
  String get roleMergeNewline => '片段间保留换行';

  @override
  String get roleUndoStructure => '撤销最近正文拆并';

  @override
  String get roleStyleMatrix => '人物类别风格';

  @override
  String get roleStyleHelp => '留空继承默认音色或风格；全部留空会移除此项覆盖。';

  @override
  String get roleSplitCharacter => '拆分人物';

  @override
  String get roleSplitCharacterHelp => '将本章所选台词移至新人物，复制原音色绑定；可用标注撤销恢复归属，新人物保留。';

  @override
  String get roleIdentityKind => '人物身份类型';

  @override
  String get roleIdentityNamed => '具名人物';

  @override
  String get roleIdentityAnonymous => '匿名说话人';

  @override
  String get roleIdentityGroup => '群体';

  @override
  String get roleDirectionHelp =>
      '选角与语气每次各发起一个有界模型任务；先审阅建议再应用。选角保留已有绑定，语气仅处理最多 30 条未确认、未锁定且没有风格的片段。';

  @override
  String get roleSuggestCast => '自动音色选角';

  @override
  String get roleSuggestTone => '语气导演';

  @override
  String get roleDirectionReview => '审阅建议';

  @override
  String get roleDirectionEmpty => '模型没有提出可应用建议。';

  @override
  String get taskProfiles => '任务模型配置';

  @override
  String get taskProfilesHelp =>
      '分别设置分角、选角、语气和朗读的连接、模型、协议。朗读配置覆盖本作品的模型/协议，人物音色和参考音频仍来自绑定音色。未配置的任务沿用现有选择。';

  @override
  String get taskSynthesis => '小说朗读';

  @override
  String get taskProtocol => '服务协议';

  @override
  String get taskEndpoint => '相对端点路径（留空使用协议默认值）';

  @override
  String get taskKeyHeader => 'API key 请求头名称';

  @override
  String get taskUseDefaults => '恢复此任务默认配置';

  @override
  String get modelReadDeclaration => '读取后端能力声明';

  @override
  String get uiLiveSentencePreview => '即时试听并保存完整音频';

  @override
  String get roleSceneTitle => '场景理解';

  @override
  String get roleSceneFirstPerson => '第一人称叙述者';

  @override
  String get roleScenePresent => '在场人物';

  @override
  String get roleSceneNested => '嵌套讲述者';

  @override
  String get roleSceneHelp => '请与角色表一并核对；如需纠正，可填写反馈并重新规划，再继续分析。';

  @override
  String get roleToolReview => '局部工具校对';

  @override
  String get roleToolBudget =>
      '每轮最多 3 次调用、20,000 token 预算、6 次本地查询、8 条提案；输出上限 1,600 token。失败保留未知用量预留，恢复不重置预算。';

  @override
  String get roleToolCurrent => '仅当前片段';

  @override
  String get roleToolDoubts => '本章疑点（最多 8 段）';

  @override
  String get roleToolStart => '开始新一轮局部校对';

  @override
  String get roleToolReviewProposals => '审阅补人、合并与修改提案';

  @override
  String get roleToolApplyHint =>
      '勾选后才会应用。采纳仍是 AI 推断，不等于人工确认；正文、锁定与已确认标注受保护。合并会迁移所列片段与兼容的声音绑定，并移除来源人物，请仔细核对。';

  @override
  String get roleToolDependency => '修改依赖新增人物，请同时勾选对应补人提案。';

  @override
  String get roleToolAdd => '补人';

  @override
  String get roleToolPatch => '修改标注';

  @override
  String get roleToolMerge => '合并身份';

  @override
  String get roleToolReady => '待审阅';

  @override
  String get roleToolBudgetExhausted => '预算已用尽';

  @override
  String get roleToolApplied => '已应用所选提案';

  @override
  String get roleToolEmpty => '本轮未提出修改';

  @override
  String get roleToolEvidence => '正文证据';

  @override
  String get roleToolAffected => '受影响片段';

  @override
  String get roleToolReserved => '计费预算用量（含未知预留）';

  @override
  String get settingsRoleAi => '分角色 AI';

  @override
  String get settingsRoleAiDescription => '小说与长文本共用的模型、配置和阶段提示词';

  @override
  String get roleSkillSettingsHint =>
      '选择生效配置，编辑各阶段提示词。小说校对与长文本自动分角色共用此配置；作品的专属任务连接和手动模型优先。内置默认值随应用打包，恢复当前配置会立即保存。修改后未完成的分析需要重新开始。';

  @override
  String get roleSkillProfile => '分角色配置';

  @override
  String get roleSkillDefault => '内置默认配置';

  @override
  String get roleSkillClone => '复制为新配置';

  @override
  String get roleSkillRestoreProfile => '一键还原当前配置';

  @override
  String get roleSkillProfileName => '配置名称';

  @override
  String get roleSkillUseEntryConnection => '使用当前入口选择的连接';

  @override
  String get roleSkillNode => '分析阶段';

  @override
  String get roleSkillPrompt => '阶段提示词';

  @override
  String get roleSkillRestoreNode => '还原此阶段提示词';

  @override
  String get roleSkillSave => '保存并启用配置';

  @override
  String get phaseAutoRoles => 'AI 自动分角色';

  @override
  String get phaseRoleIntent => '配音意图（可选）';

  @override
  String get phaseRoleIntentHint => '例如：保留原文；角色分声线；引用故事由讲述者朗读。';

  @override
  String get phaseRoleReviewHint =>
      '分析不会直接改工程。先核对人物、原文片段和音色，再应用；未分配音色的片段保留待选。应用会替换当前分段，已有音频保留在磁盘。';

  @override
  String get phaseRoleAnalyze => '分析并预览';

  @override
  String get phaseRoleApply => '应用分角与音色';

  @override
  String get phaseRoleUnknown => '待确认人物';

  @override
  String get phaseRoleNarrator => '旁白默认音色';

  @override
  String get phaseRoleNoVoice => '稍后选择音色';

  @override
  String get phaseRoleStatus => '分析调用与预算内进度见任务监视器。最多 40 次调用，分析期间可取消；不会自动合成音频。';

  @override
  String get phaseRoleStale => '正文、已有分段、音色库或分角配置已变化，请重新分析。';

  @override
  String get dubbingMode => '配音模式';

  @override
  String get dubbingModeAutomatic => '自动判断';

  @override
  String get dubbingModeStoryteller => '讲述者朗读';

  @override
  String get dubbingModeDramatized => '广播剧演绎';

  @override
  String get dubbingModeScript => '台本与聊天';

  @override
  String get dubbingModeAutomaticHelp => '根据叙述视角、发言提示和上下文判断归属。';

  @override
  String get dubbingModeStorytellerHelp => '故事中的引用沿用外层讲述者的声音。';

  @override
  String get dubbingModeDramatizedHelp => '为人物明确的直接引语分配角色声线，引语结束后回到讲述者。';

  @override
  String get dubbingModeScriptHelp => '按人物前缀或发送者分配对白，舞台说明归旁白。';

  @override
  String get phaseRoleEditSegment => '调整片段归属';

  @override
  String get phaseRoleModelEvidence => 'AI 原始依据';

  @override
  String get phaseRoleContext => '查看前后文';

  @override
  String get phaseRolePrevious => '前一段';

  @override
  String get phaseRoleFollowing => '后一段';

  @override
  String get phaseRoleCategory => '片段类别';

  @override
  String get phaseRoleSpeaker => '归属人物';

  @override
  String get phaseRoleNoCharacter => '暂不指定人物';

  @override
  String get phaseRoleAddCharacter => '新增人物';

  @override
  String get phaseRoleCharacterName => '人物名称';

  @override
  String get phaseRoleNameRequired => '请输入未使用的人物名称';

  @override
  String get phaseRoleSegments => '片段';

  @override
  String get phaseRoleVoices => '角色音色';

  @override
  String get phaseRoleNeedsReview => '待核对';

  @override
  String get phaseRoleSearch => '搜索正文或人物';

  @override
  String get phaseRoleVoiceHelp => '为同一角色的所有片段选择音色。也可以稍后在生成列表中分配。';

  @override
  String get phaseRoleNoMatches => '没有符合条件的片段。';

  @override
  String get phaseRoleEdited => '已手动调整';

  @override
  String get phaseRolePreviewTitle => '审阅角色归属';

  @override
  String get phaseRoleStop => '停止分析';

  @override
  String get phaseRoleStopping => '正在停止…';

  @override
  String get phaseRoleStopped => '分析已停止。可以调整后再试。';

  @override
  String get phaseRolePreparing => '正在准备文本…';

  @override
  String get phaseRoleAdjustIntent => '调整配音意图';

  @override
  String get phaseRoleBackToPreview => '返回已有预览';

  @override
  String get phaseRoleLengthLimit =>
      '文本超出单次分析上限（360 段或 64,000 UTF-16 单位），请拆成较短的文本。';

  @override
  String get phaseRoleConnectionSettings => '连接与分析模型';

  @override
  String get phaseRoleRestoreSuggestion => '还原 AI 建议';

  @override
  String get roleAnalysisPanelTitle => 'AI 自动分角色';

  @override
  String get roleAnalysisApproveRoster => '确认人物并分配台词';

  @override
  String get roleAnalysisResumeShort => '继续分析';

  @override
  String get roleAnalysisRestart => '重新分析';

  @override
  String get roleAnalysisRosterHint => '先核对下方人物表和场景判断，再继续分配台词。';

  @override
  String get rolePollOnlyUncertain => '只看疑点';

  @override
  String get roleNoUncertain => '当前章节没有需要优先核对的疑点。';

  @override
  String phaseRoleReviewSummary(int total, int uncertain, int missing) {
    return '$total 个片段 · $uncertain 段待核对 · $missing 类归属未分音色';
  }

  @override
  String phaseRoleReplaceExisting(int count) {
    return '应用后将替换现有的 $count 个片段。原始脚本和已生成音频文件会保留。';
  }

  @override
  String phaseRoleKeepUncertain(int count) {
    return '还有 $count 个片段待核对。可返回调整，或将当前归属带入生成列表。';
  }

  @override
  String phaseRoleInputSummary(int count) {
    return '已识别 $count 个语义片段。分析最多发起 40 次模型调用。未验证模型会额外发起一次工具检查。';
  }

  @override
  String phaseRoleProgress(int processed, int total, int calls) {
    return '已处理 $processed/$total 段 · 已发起 $calls 次调用';
  }

  @override
  String get roleShowMorePending => '显示更多待确认片段';

  @override
  String get playbackLoop => '循环播放';

  @override
  String get playbackLoopOn => '已开启循环';

  @override
  String get playbackDownload => '下载音频';

  @override
  String get playbackMoreActions => '更多播放操作';

  @override
  String get navSubtitles => '转写翻译';

  @override
  String get transcribeFromAudio => '用语音识别填写参考文本';

  @override
  String get transcribeNeedsStt => '启用带语音识别的服务商（如 OpenAI、ElevenLabs）后即可识别';

  @override
  String get transcribeFilled => '已根据音频填写参考文本，请核对后保存。';

  @override
  String transcribeFailed(String error) {
    return '识别失败：$error';
  }

  @override
  String get liveModeScript => '剧本';

  @override
  String get liveModeRealtime => '实时对话';

  @override
  String get liveModeCompanion => '陪聊';

  @override
  String get liveModeScriptHint => '编写台词，为每句生成角色语音';

  @override
  String get liveModeRealtimeHint => '接入 Realtime 模型的全双工语音对话';

  @override
  String get liveModeCompanionHint => '语音识别 → 大模型 → 角色自己的 TTS 音色';

  @override
  String get liveNeedsRealtime => '需要带 Realtime 模型的服务商（如 OpenAI）';

  @override
  String get liveNeedsCompanion => '需要启用语音识别和大模型能力';

  @override
  String get liveStateIdle => '未开始';

  @override
  String get liveStateConnecting => '连接中';

  @override
  String get liveStateListening => '聆听中';

  @override
  String get liveStateThinking => '思考中';

  @override
  String get liveStateSpeaking => '说话中';

  @override
  String get liveNoCharacter => '选择角色';

  @override
  String get liveVcActive => '回复会转换为角色音色';

  @override
  String get liveSettings => '角色对话设置';

  @override
  String get liveStart => '开始';

  @override
  String get liveStop => '结束';

  @override
  String get liveEmptyRealtime => '点击开始后直接说话，角色会实时回应；想随时打断请戴耳机并在设置中开启。';

  @override
  String get liveEmptyCompanion => '点击开始后直接说话，停顿后角色会用自己的声音回答。';

  @override
  String get liveTypeHint => '也可以输入文字';

  @override
  String liveSettingsTitle(String name) {
    return '实时对话 · $name';
  }

  @override
  String get livePersona => '人设';

  @override
  String get livePersonaHint => '角色的性格与说话方式。留空则使用音色名称、描述和语气指令。';

  @override
  String get liveRealtimeVoice => 'Realtime 音色';

  @override
  String get liveDefault => '默认';

  @override
  String get liveAllowInterrupt => '允许打断（需戴耳机）';

  @override
  String get liveAllowInterruptHint => '角色说话时也保持麦克风开启；不戴耳机会把自己的声音录进去。';

  @override
  String get liveVcTitle => '音色转换';

  @override
  String get liveVcHint => '用音色转换模型把每句回复换成角色音色：情感来自对话模型，音色来自角色，无需训练。会增加延迟。';

  @override
  String get liveVcProvider => '转换服务商';

  @override
  String get liveVcOff => '关闭';

  @override
  String get liveVcVoice => '目标音色 ID';

  @override
  String get liveVcVoiceHint => '要转换成的服务商音色，例如 ElevenLabs 的 voice ID';

  @override
  String get subtitlePickMedia => '选择视频或音频文件';

  @override
  String get subtitleSourceLanguage => '原始语言';

  @override
  String get subtitleSourceLanguageHint => '可选，如 ja；留空自动识别';

  @override
  String get subtitleTargetLanguage => '翻译为';

  @override
  String get subtitleNoTranslation => '不翻译（仅转写）';

  @override
  String get subtitleContext => '翻译背景';

  @override
  String get subtitleContextHint => '标题、人名、类型或术语表';

  @override
  String get subtitleFormat => '输出格式';

  @override
  String get subtitleModeOriginal => '原文';

  @override
  String get subtitleModeTranslation => '译文';

  @override
  String get subtitleModeBilingual => '双语';

  @override
  String get subtitleRun => '开始转写';

  @override
  String get subtitleExport => '导出字幕';

  @override
  String subtitleSaved(String path) {
    return '已保存 $path';
  }

  @override
  String get subtitlePreview => '预览';

  @override
  String get subtitleEmpty => '选择文件并开始转写后，字幕会显示在这里。';

  @override
  String get subtitleMissingCapability => '未启用';

  @override
  String get subtitleStageDecoding => '解码中';

  @override
  String get subtitleStageDetecting => '检测人声';

  @override
  String get subtitleStageTranscribing => '转写中';

  @override
  String get subtitleStageTranslating => '翻译中';

  @override
  String get subtitleStageDone => '完成';

  @override
  String get modalityText => '文本';

  @override
  String get modalityImage => '图片';

  @override
  String get modalityAudio => '音频';

  @override
  String get modalityVideo => '视频';

  @override
  String get modalityPdf => 'PDF';

  @override
  String get llmThinkUnknown => '思考 ?';

  @override
  String get llmThinkNone => '不支持思考';

  @override
  String get llmThinkLevelsUnknown => '支持思考（档位未知）';

  @override
  String llmThinkLevels(int count, String from, String to) {
    return '思考 $count 档 $from→$to';
  }

  @override
  String get llmThinkCanDisable => '，可关闭';

  @override
  String llmThinkDefault(String level) {
    return '默认：$level';
  }

  @override
  String llmThinkModes(String modes) {
    return '模式：$modes';
  }

  @override
  String get llmTools => '工具调用';

  @override
  String get llmToolsNo => '不支持工具调用';

  @override
  String get llmToolsUnknown => '工具调用 ?';

  @override
  String get llmToolsParallel => '支持一次并行调用多个工具';

  @override
  String get llmInputsUnknown => '输入 ?';

  @override
  String get llmSchema => '结构化输出';

  @override
  String llmContext(String tokens) {
    return '$tokens 上下文';
  }

  @override
  String get llmSourceCatalog => '内置目录';

  @override
  String get llmSourceAccount => '账号中发现';

  @override
  String get llmSourceUnlisted => '内置目录 · 账号未列出';

  @override
  String llmPickerTitle(String provider) {
    return '语言模型 · $provider';
  }

  @override
  String get llmPickerSearch => '搜索，或直接输入模型 ID';

  @override
  String get llmPickerToolsOnly => '仅显示支持工具调用';

  @override
  String get llmPickerLoading => '正在读取模型列表…';

  @override
  String llmPickerFound(int count) {
    return '账号列出 $count 个模型；能力来自公开目录。';
  }

  @override
  String llmPickerDenied(String error) {
    return '凭据被拒绝：$error';
  }

  @override
  String get llmPickerOffline => '该服务商未提供模型列表，显示内置目录。';

  @override
  String llmPickerUse(String id) {
    return '使用 $id';
  }

  @override
  String get llmNeedsToolsNo => '该模型不支持工具调用，小说分角色需要工具调用。';

  @override
  String get llmNeedsToolsUnknown => '工具调用能力未知，首次分析前会发一次小请求验证。';

  @override
  String get llmProviderDisabled => '（已停用）';

  @override
  String get llmProviderHint => '只列出提供语言模型能力的服务商';

  @override
  String get voiceFilterHint => '筛选音色';

  @override
  String voiceMoreHidden(int count) {
    return '还有 $count 个，输入关键字筛选';
  }

  @override
  String voiceEngineVoices(String engine) {
    return '$engine 音色';
  }

  @override
  String get navMusic => '歌曲创作';

  @override
  String get musicModel => '模型';

  @override
  String get musicTitle => '标题';

  @override
  String get musicTitleHint => '未命名歌曲';

  @override
  String get musicPrompt => '风格与编曲';

  @override
  String get musicPromptHint => '曲风、情绪、乐器、演唱者、速度、时长……';

  @override
  String get musicLyrics => '歌词';

  @override
  String get musicLyricsHint => '留空则由模型作词；[Verse]、[Chorus] 等段落标签可安排歌曲结构。';

  @override
  String get musicInstrumental => '纯音乐（无人声）';

  @override
  String get musicLossless => '模型支持时输出无损 WAV';

  @override
  String get musicImages => '参考图片';

  @override
  String get musicAddImage => '添加图片';

  @override
  String get musicGenerate => '生成歌曲';

  @override
  String musicGenerating(int seconds) {
    return '生成中…… $seconds 秒';
  }

  @override
  String get musicNoModel => '没有已启用的服务商提供歌曲生成，请添加 Google Gemini。';

  @override
  String get musicEmpty => '生成的歌曲会显示在这里。';

  @override
  String get musicShowInFolder => '在文件夹中显示';

  @override
  String get musicSaveAs => '另存为……';

  @override
  String get musicDelete => '删除';

  @override
  String get musicReuse => '沿用此设定';

  @override
  String get musicNoLyrics => '纯音乐，无歌词。';

  @override
  String get musicWatermark => 'Lyria 生成的音频带有不可听的 SynthID 水印。';

  @override
  String musicSaved(String path) {
    return '已保存到 $path';
  }

  @override
  String get liveRealtimeModel => '实时模型';

  @override
  String get chainTitle => '处理链';

  @override
  String get chainHint =>
      '像函数一样串在角色 TTS 前后：文本步骤先改写台词，变声步骤再把音频换成目标音色。角色在任何地方发声都会生效。';

  @override
  String get chainInput => '台词';

  @override
  String get chainOutput => '音频';

  @override
  String get chainAdd => '添加步骤';

  @override
  String get chainTranslate => '翻译（LLM）';

  @override
  String get chainRewrite => '改写（LLM）';

  @override
  String get chainConvert => '变声（VC）';

  @override
  String chainTranslateTo(String language) {
    return '翻译 → $language';
  }

  @override
  String chainConvertTo(String voice) {
    return '变声 → $voice';
  }

  @override
  String get chainTargetLanguage => '目标语言';

  @override
  String get chainTargetLanguageHint => '如：日语、英语、粤语';

  @override
  String get chainInstruction => '改写要求';

  @override
  String get chainInstructionHint => '如：用沉稳、略带古风的口吻说，保持简短。';

  @override
  String get chainTargetVoice => '目标音色';

  @override
  String get chainModel => '模型';

  @override
  String get chainNoModels => '还没有启用的服务商提供这项能力。';

  @override
  String get chainNeedsSetup => '待配置';

  @override
  String get chainNoStreaming =>
      '变声逐句进行：首句转换完成即开始播放。网页端使用只返回文件的变声服务时，会整句转换后再播放。';

  @override
  String retireBadge(Object date) {
    return '$date 停用';
  }

  @override
  String retireHint(Object model, Object date, Object replacement) {
    return '$model 将于 $date 停用，建议改用 $replacement。';
  }

  @override
  String retireHintNoReplacement(Object model, Object date) {
    return '$model 将于 $date 停用，请改用其他服务商的模型。';
  }

  @override
  String retireBanner(Object count, Object date, Object days) {
    return '$count 个角色使用的模型将于 $date 停用（还剩 $days 天）。';
  }

  @override
  String get retireMigrate => '一键迁移';

  @override
  String get retireMigrateTitle => '将角色迁移到替代模型？';

  @override
  String get retireMigrateManual => '以下角色在当前平台没有可用的替代模型，请在角色检查器中改用其他服务商：';

  @override
  String retireMigrated(Object count) {
    return '已迁移 $count 个角色。';
  }

  @override
  String retireSwitchTo(Object model) {
    return '改用 $model';
  }

  @override
  String get retireLater => '稍后';

  @override
  String get chainTrim => '去静音';

  @override
  String get chainVerify => '回听校验（ASR）';

  @override
  String get chainTrimHint => '裁掉每句首尾的静音，并把超过 0.35 秒的停顿缩短。';

  @override
  String get chainVerifyHint => '用语音识别听一遍合成结果，与台词比对并列出漏读，不影响播放。';

  @override
  String get chainVerifyLanguage => '识别语言（可选）';

  @override
  String chainCheckMissing(Object score, Object missing) {
    return '回听 $score% · 漏读：$missing';
  }

  @override
  String chainCheckClean(Object score) {
    return '回听 $score%，未发现漏读';
  }

  @override
  String chainCheckFailed(Object error) {
    return '回听失败：$error';
  }

  @override
  String get chainCheckNone => '还没有回听结果，试听角色后显示。';

  @override
  String get settingsAiCapabilities => 'AI 能力';

  @override
  String get settingsAiCapabilitiesDescription => '默认模型、按能力的限额与自行添加的模型';

  @override
  String get capLlm => '大模型';

  @override
  String get capTts => '语音合成';

  @override
  String get capStt => '语音识别';

  @override
  String get capRealtime => '实时语音';

  @override
  String get capTranslate => '语音翻译';

  @override
  String get capVc => '变声';

  @override
  String get capVad => '人声检测';

  @override
  String get capMusic => '音乐';

  @override
  String get capDefaultModel => '默认模型';

  @override
  String get capAutomatic => '自动（第一个可用）';

  @override
  String get capConnections => '连接';

  @override
  String get capNoConnections => '还没有启用的连接提供这项能力。';

  @override
  String get capLimits => '限额';

  @override
  String capLimitsTitle(Object capability, Object connection) {
    return '$capability限额 · $connection';
  }

  @override
  String get capLimitsHint => '留空即沿用连接自身的限额。各能力分开排队，大模型调用不再占用语音合成名额。';

  @override
  String get capInherited => '沿用';

  @override
  String get capConcurrency => '并发请求';

  @override
  String get capRpm => '每分钟请求';

  @override
  String get capRpd => '每日请求';

  @override
  String get capTpm => '每分钟 Token';

  @override
  String get capTpd => '每日 Token';

  @override
  String get capAddModel => '添加模型';

  @override
  String get capModelId => '模型 ID';

  @override
  String get capDisplayName => '显示名称（可选）';

  @override
  String capModelRejected(Object model) {
    return '该连接无法打开模型 $model。';
  }

  @override
  String get capOff => '已关闭';

  @override
  String get capAll => '全部';

  @override
  String get inspectorTabBasic => '基本';

  @override
  String get inspectorTabVoice => '音色';

  @override
  String get provTabOverview => '概览';

  @override
  String get provCapabilities => '能力';

  @override
  String provCapUse(Object capability) {
    return '在此连接使用$capability';
  }

  @override
  String provCapOffHint(Object capability) {
    return '此连接已关闭$capability，功能不会路由到这里。';
  }

  @override
  String get provConnectionOff => '此连接未启用。在左侧列表开启后，各功能才会使用它的模型。';

  @override
  String get provSetDefault => '设为默认';

  @override
  String get provIsDefault => '默认';

  @override
  String get provSourceAdded => '手动添加';

  @override
  String get provSourceFetched => '已从账号获取';

  @override
  String get provDiscoverLlm => '从账号发现';

  @override
  String get provOtherModels => '其他已获取模型';

  @override
  String get provCheckAll => '检测各能力';

  @override
  String get provHealthOk => '可用';

  @override
  String get provHealthFailed => '失败';

  @override
  String get provHealthUnavailable => '不可用';

  @override
  String get provHealthUnknown => '未知';

  @override
  String get provHealthNotChecked => '尚未检测';

  @override
  String provHealthSome(Object list) {
    return '部分能力不可用：$list';
  }

  @override
  String get provLimitsConnection => '连接限额';

  @override
  String get provLimitsPerCapability => '按能力';

  @override
  String get provAddPick => '选择服务商';

  @override
  String get provAddHint => '创建后在概览中填写地址与密钥，再检测各能力。';

  @override
  String get featPresetVoices => '预设音色';

  @override
  String get featInstructions => '情感指令';

  @override
  String get featStreamingOutput => '流式输出';

  @override
  String get featCloudClone => '云端克隆';

  @override
  String get featZeroShotClone => '零样本克隆';

  @override
  String get featFileTranscription => '文件转写';

  @override
  String get featStreamingTranscription => '流式转写';

  @override
  String get featWordTimestamps => '字级时间戳';

  @override
  String get featDiarization => '说话人区分';

  @override
  String get featLanguageDetection => '语种识别';

  @override
  String get featKeywords => '热词';

  @override
  String get featAudioOutput => '音频输出';

  @override
  String get featTextOutput => '文本输出';

  @override
  String get featToolCalls => '工具调用';

  @override
  String get featServerVad => '服务端断句';

  @override
  String get featInputTranscription => '输入转写';

  @override
  String get featSourceTranscript => '原文转写';

  @override
  String get featStructuredOutput => '结构化输出';

  @override
  String get featReasoning => '推理';

  @override
  String get featVocals => '人声';

  @override
  String get featTimedLyrics => '时间轴歌词';

  @override
  String get featImagePrompt => '图片提示';

  @override
  String get featLosslessOutput => '无损输出';

  @override
  String get featZeroShot => '零样本';

  @override
  String get featLocal => '本地';

  @override
  String get sidebarExpand => '展开侧栏';

  @override
  String get sidebarCollapse => '收起侧栏';

  @override
  String get musicSearch => '搜索歌曲';

  @override
  String musicCount(Object count) {
    return '共 $count 首';
  }

  @override
  String get musicNoMatch => '没有匹配的歌曲。';

  @override
  String get musicStyle => '风格';

  @override
  String get musicGenre => '曲风';

  @override
  String get musicMood => '情绪';

  @override
  String get musicInstruments => '乐器';

  @override
  String get musicVoice => '人声';

  @override
  String get musicTempo => '速度';

  @override
  String get musicStyleHint => '点击标签加入风格描述，再点一次移除。';

  @override
  String musicLyricsStats(Object lines, Object chars) {
    return '$lines 行 · $chars 字';
  }

  @override
  String get musicOptions => '选项';

  @override
  String get musicNowPlaying => '正在播放';

  @override
  String get musicPlay => '播放';

  @override
  String get musicPause => '暂停';

  @override
  String get musicLyricsTitle => '歌词';

  @override
  String get musicSeekHint => '点击带时间的歌词可跳转。';

  @override
  String get musicGenPop => '流行';

  @override
  String get musicGenRock => '摇滚';

  @override
  String get musicGenElectronic => '电子';

  @override
  String get musicGenFolk => '民谣';

  @override
  String get musicGenChinese => '古风';

  @override
  String get musicGenJazz => '爵士';

  @override
  String get musicGenHipHop => '嘻哈';

  @override
  String get musicGenLofi => 'Lo-fi';

  @override
  String get musicGenOrchestral => '管弦';

  @override
  String get musicGenAnime => '动漫';

  @override
  String get musicMoodHappy => '欢快';

  @override
  String get musicMoodSad => '忧伤';

  @override
  String get musicMoodEpic => '热血';

  @override
  String get musicMoodCalm => '治愈';

  @override
  String get musicMoodDreamy => '梦幻';

  @override
  String get musicMoodDark => '暗黑';

  @override
  String get musicInsPiano => '钢琴';

  @override
  String get musicInsGuitar => '木吉他';

  @override
  String get musicInsSynth => '合成器';

  @override
  String get musicInsStrings => '弦乐';

  @override
  String get musicInsGuzheng => '古筝';

  @override
  String get musicInsDrums => '鼓组';

  @override
  String get musicVoxFemale => '女声';

  @override
  String get musicVoxMale => '男声';

  @override
  String get musicVoxChoir => '合唱';

  @override
  String get musicTempoSlow => '慢速';

  @override
  String get musicTempoMid => '中速';

  @override
  String get musicTempoFast => '快速';

  @override
  String chainCheckExtra(Object extra) {
    return '多读：$extra';
  }

  @override
  String capModelUnavailable(Object model) {
    return '$model（当前不可用）';
  }

  @override
  String capFollowDefault(Object model) {
    return '跟随默认（$model）';
  }

  @override
  String get capFollowDefaultNone => '跟随默认';

  @override
  String get subtitleModels => '使用的模型';

  @override
  String get subtitleTranslateModel => '翻译用大模型';

  @override
  String get provHubDefaults => '默认模型';

  @override
  String get provHubDefaultsHint => '各能力默认用哪个模型；点服务商名可打开它的设置';

  @override
  String get provHubDefaultsShort => '各能力默认用哪个模型';

  @override
  String get provHubRoleAiShort => '方案、模型与阶段提示词';

  @override
  String get provHubConnections => '服务商';

  @override
  String get provHubFeatureModels => '功能单独指定的模型';

  @override
  String get provHubFeatureModelsHint => '这些功能不跟随下方的默认模型';

  @override
  String get provHubResetFeatureModel => '恢复跟随默认';

  @override
  String provModelCount(int count) {
    return '$count 个模型';
  }

  @override
  String get provConnection => '连接';

  @override
  String get settingsAiServicesHint => '服务商、默认模型与分角色 AI';

  @override
  String capAutomaticInOrder(Object model) {
    return '自动：按下方顺序（$model）';
  }

  @override
  String get capAutoOrderHint =>
      '未指定默认模型时，按下方顺序取第一个可用的连接及其首选模型。拖动左侧手柄调整顺序；关闭的连接会被跳过。';

  @override
  String get capPreferred => '首选';

  @override
  String capPreferredModel(Object model) {
    return '首选 $model';
  }

  @override
  String get capModelAdded => '自添加';

  @override
  String get capModelOrder => '模型顺序';

  @override
  String capUseCustomModel(Object model, Object connection) {
    return '在 $connection 使用“$model”';
  }

  @override
  String provHubConnectionsShort(int count, int enabled) {
    return '$count 个连接 · $enabled 个已启用';
  }

  @override
  String get provProvidersHint => '点按进入设置；拖动手柄调整顺序';

  @override
  String get roleAnalysisModelPick => '分析模型';

  @override
  String roleModelFollowDefault(Object model) {
    return '跟随默认大模型（$model）';
  }

  @override
  String get roleModelHint =>
      '分角色依靠工具调用（function calling）来校对和纠错；可输入搜索，选择后会自动测试。';

  @override
  String get roleToolChecking => '正在测试工具调用…';

  @override
  String get roleToolSupported => '支持工具调用';

  @override
  String get roleToolUnsupported => '不支持工具调用，分角色无法纠错，请换一个模型';

  @override
  String get roleToolUnknown => '尚未测试工具调用';

  @override
  String roleToolFailed(Object error) {
    return '工具调用测试失败：$error';
  }

  @override
  String get roleToolTest => '测试';
}
