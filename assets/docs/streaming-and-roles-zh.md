# 流式试听、小说分角与平台开发说明

本说明对应 `dev@2d514adb` 之后的未发布改动。个人协作规范与进度文件保留本地，不随源码分发。

## Quick TTS

在角色的 Quick TTS 面板开启自动流式播放。OpenAI Realtime 使用同一请求边接收边播放，并把完整音频写入历史。旧适配器仍在整段生成后播放。停止会取消上游请求并丢弃不完整缓存；生成完成后，正在播放的流可以继续播完，随后可从文件回放。流播放期间不能跳转到尚未生成的位置。

音频由公共 `SynthesisService` 编排，格式由适配器声明；PCM 必须提供真实采样率和声道，压缩音频在同一个解码器中持续消费。队列并发占用持续到整个请求清理结束。小说当前句、Dialog/Phase/视频单句试听及本地 API 已接公共流服务。小说首块到达后预取后续句；完整缓存命中时直接播放文件，旧适配器继续整段生成。CosyVoice 后端接入继续跳过。

2026-11-17 已用用户提供的本地凭据通过 Speech 与 Realtime 的真实流式播放、完整缓存、暂停恢复和取消检查。默认测试仍只使用本地假服务；真实测试须主动执行 `dart scripts/tools/run_live_tests.dart streaming`，凭据由本地 `.env` 的 `OPENAI_KEY` / `OPENAI_API_KEY` / `OPENAI_TEST_API_KEY` 读取，只传给测试进程，不写入源码或音频。音频与测量结果保存在 Git 忽略的 `.dart_tool/live-streaming/`。这不替代麦克风、媒体按键等硬件验收或分角效果评分。

## 小说角色校对

新导入内容使用 semantic-v2：保留原始空白和段落，按引号层级、发言边界和带发送者的括号消息划分语义段。原始文本完整保留，TTS 的字数切片由音频流程单独处理。已有工程不会自动重写片段；旧混段会被独立规则提示，需人工按语义拆分。新分段与 skill 版本会使旧分析检查点要求重新开始，但不因此覆盖已确认或锁定标签。

进入小说后切换到“角色校对”。先创建作品人物并绑定语音库中的音色，再选择片段，修改人物、类别、句级音色或风格。应用范围可选当前句或本章同角色的未锁定片段。人工修改会标记为已确认；锁定内容不会被 AI 覆盖。可撤销最近 20 次标注动作，角色合并和音色绑定不属于标注撤销范围。

侧栏可修改人物名称、别名和描述、合并人物、查看台词数，并设置作品通用或本章声音。待确认列表可定位原句，片段可单独试听。音色优先级依次为：句级覆盖、章节人物绑定、作品人物绑定、语义类别默认、项目另一默认音色。阅读、试听、生成与导出使用同一解析规则。

自动分析需主动选择 Provider 和文本模型。首次规划后会暂停，供用户复核角色表；确认继续才进入批次标注和疑点复核。每次启动有调用上限，达到上限或暂停后可恢复，关闭面板不会丢失 checkpoint。正文或模型更改后须重新分析。AI 只返回稳定片段 ID 的标签，不返回替换正文；人工确认和锁定在公共写入层保护。角色身份可选具名、匿名或群体。自动选角与语气导演分别使用独立任务模型，每次一个有界任务，建议需审阅后应用。选角保留已有绑定；语气只处理最多 30 条未确认、未锁定且没有风格的片段，输入超过本地预算时拒绝发起调用。正文、角色或声音变化后，旧建议不能覆盖新编辑。

规划同时保存第一人称叙述者、在场人物、嵌套讲述者与消息渠道，使用稳定人物 ID；“场景理解”展示人物名称及证据，可通过反馈重新规划。标注同时获得前后文、引号/消息结构和已有标签。独立规则提示发送者/听者、提示语、混段与重名身份问题，并在预算内抽查部分 inferred；规则不直接改人，AI 复核也不等于人工确认。单次请求最多 64000 个 UTF-16 单位；批次按正文量缩小，背景上下文截短时明确标记，待标注的原文不截断。跨章场景只读取顺序上更早且已完成的章节。

长段正文应先整理：单段超过 12000 个 UTF-16 单位会被分析器拒绝，以防无界输入。在校对面板选择正文范围，可将其拆为独立语义段；相邻多个片段也可合并。字符与空白完整保留，禁止切开 UTF-16 代理对；合并归属不一致时改为待确认。最近一次正文拆并可持久化撤销，后续正文、标注或音频变化后会拒绝恢复。人物拆分可选择本章多条台词，复制原声音绑定；标注撤销会恢复归属并保留新人物。人物类别风格支持章节类别 → 章节通用 → 作品类别 → 作品通用，再回退项目类别默认；音色和风格可各自继承，句级设置优先。

## 数据与缓存兼容性

首次打开旧数据库时，在迁移到 schema v33 前使用 SQLite `VACUUM INTO` 生成同目录的 `数据库路径.before-v33.bak`，已有同名备份不覆盖。备份保留迁移前数据库；需要回退时应先退出应用并保留当前数据库，再使用备份，勿在数据库打开时替换文件。全新数据库不额外备份。

新的小说缓存指纹使用 `novel-v2`，包含实际文本、过滤和切片设置、模型/协议、真实音色、参考音频内容、风格及速度。已有旧指纹会被视为待重新生成，**不会自动删除旧音频或自动发起合成**。人物改名或改颜色不会改变新指纹；换音色只影响实际使用该音色的片段。

## 动态模型目录

模型刷新优先读取当前 Provider 元数据，并用随应用发布的公共目录补充。能力有支持、不支持、未知三态；鉴权失败、限流和网络失败单独记录，不能当作模型不支持。网关的模型同名也不能证明它实现官方全部能力。未知模型可手填 ID、人工覆盖能力，再通过实际成功调用积累证据。

分析模型选择器可查看来源并覆盖能力。“任务模型配置”可分别保存分角、选角、语气、小说朗读的连接、模型、协议、相对端点和 API key 请求头名称。可执行 Chat Completions、Responses、Speech、Realtime 和现有 native 适配器；模型别名不决定显式协议。配置只引用现有连接，不复制 key。朗读配置覆盖本作品模型/协议，人物音色、参考音频及风格仍来自声音绑定，协议变更会使对应小说缓存失效。自定义路径必须在当前连接内，未知协议需新增适配器，不能只填名称启用。Responses 实现参照 [OpenAI 官方协议](https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=responses)。

更新公开离线目录（会联网下载公开数据，无推理费用）：

```powershell
dart scripts/tools/refresh_model_catalog.dart
```

工具校验和规范化 LiteLLM 官方目录，记录来源 SHA 和变化数量。手动触发模型目录工作流仅生成 artifact，不自动提交或发布。目录许可证随 `assets/model_catalog/model_capabilities.LICENSE` 保存。

## macOS

录音使用 `record_darwin`，与 Windows 共用采集/文件生命周期。Mac 工程加入麦克风用途说明及音频输入 entitlement。系统媒体桥接支持播放、暂停、切句和停止；关闭窗口会保留小说播放与本地 API，Dock 可重开窗口；真正退出时清理服务。

2026-11-17 已在 Apple Silicon macOS 26.6 上完成 Release 构建、基础窗口交互、原生 PCM/MP3 与真实 Speech/Realtime 流播验证；新增插件由 Swift Package Manager 解析，`Podfile.lock` 无变化。麦克风授权、媒体键、关窗/Dock、蓝牙与睡眠恢复仍需逐项实机验收。

正式签名打包在 Mac 的 Bash 中显式设置：

```bash
export NEIROHA_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export NEIROHA_NOTARY_PROFILE='your-existing-keychain-profile'
FLUTTER_XCODE_ARCHS=arm64 flutter build macos --release
bash scripts/tools/package_macos_dmg.sh Release arm64 build/Neiroha.dmg
```

`NEIROHA_SIGN_ENTITLEMENTS` 可覆盖默认 `macos/Runner/Release.entitlements`。需自行已有证书及 notarytool Keychain profile。脚本在架构裁剪结束后签署嵌套代码和应用，公证并 staple 应用，再生成、签署、公证并 staple DMG。未配置签名变量时沿用原 ad-hoc 打包；本次未执行正式签名、公证或发布。

## 本地检查

工具链跟随 CI：Flutter 3.47.7，Dart 3.13.5；最低 Dart 3.12。

默认单元与协议测试在 Windows、macOS、Linux CI 上执行，不读取 `.env`，不调用付费服务。播放状态测试注入媒体会话替身；macOS/Android 通道契约分别模拟，默认通道路由则随实际宿主验证。硬件音频测试仅在桌面宿主显式开启，缺少 FFmpeg 只跳过 MP3 编码，不跳过 PCM。音频输出设备不可用时，显式开启的硬件检查会报错，不将其算作通过。

Android 是编译目标，CI 宿主使用 Ubuntu。普通 push/PR 增加 Android 能力契约和 ARM64 debug APK 编译；原 PR/手动多架构 APK 打包及 tag Release APK 流程继续保留。这些不替代模拟器/真机的前台服务、通知、媒体键与后台播放验收。

```powershell
dart scripts/tools/check_code_size.dart
flutter analyze
flutter test scripts/tests
flutter build windows --debug
```

原生音频冒烟会播放轻声音调，需有 Windows/macOS/Linux 音频输出设备，MP3 测试另需 FFmpeg，默认不运行：

```powershell
$env:NEIROHA_AUDIO_SMOKE = '1'
flutter test scripts/tests/streaming_audio_sink_test.dart
Remove-Item Env:NEIROHA_AUDIO_SMOKE
```

十二组上游分角评测保留来源与 Apache-2.0 许可证。当前 fixture 测试验证原文和标注数据的确定性约束，不代表真实模型归属准确率。

跨平台真实测试入口（从仓库根目录执行，自动读取本地 `.env`，不执行其中命令）：

```bash
dart scripts/tools/run_live_tests.dart streaming --output .dart_tool/live-check/streaming
dart scripts/tools/run_live_tests.dart speech --output .dart_tool/live-check/speech
dart scripts/tools/run_live_tests.dart roles --output .dart_tool/live-check/roles
dart scripts/tools/evaluate_role_assignments.dart .dart_tool/live-check/roles .dart_tool/live-check/roles/report.md
```

支持 `OPENAI_TEST_API_KEY`、`OPENAI_API_KEY`、`OPENAI_KEY`（按此顺序取非空值），只传给子进程并脱敏其输出，不写入报告。分角默认使用 `gpt-6-luna`，可用 `--model`、`--cases id1,id2` 缩小运行范围；总上限 72 次结构化调用。`roles --replay --output 已有目录` 不需要 key。真实推理时应使用新目录；已有完整用例会复用捕获并明确提示，不代表一次新推理。Windows PowerShell 入口继续保留。

角色运行器和评分器均支持 `--fixtures scripts/tests/fixtures/role_holdout` 选择新增留出集。模型、协议、参数、skill SHA、分段版本、usage 与阶段耗时进入捕获；金标只在本地评分。留出集三轮对照是功能验证，更多题材和长章节的效果验收仍需继续。

## P1 局部工具校对与补人/合并

在小说“角色校对 → AI 分析 → 局部工具校对”中使用同一分析连接/模型（任务配置中的分角设置优先）。选中句子后默认只查当前片段，也可切换到本章疑点，最多 8 段/1,500 UTF-16 单位；长混段请先用正文结构工具拆开。校对独立按需运行，不会在普通分角的每个批次追加付费调用。

每轮最多 3 次模型调用、20,000 token 预算、6 次本地读取、8 条提案，单次输出上限 1,600 tokens。模型可读前后两段、在本章做字面搜索、查询本作品人物，以及提出标签修改、补人、合并或结束。查询结果只在输入字节预算内发送；超限停止，不隐式增大预算。每次发送前持久化调用数与保守 token 预留；正整数 usage 返回后对账，失败/取消时未知用量保留。暂停/恢复共享原预算；新一轮是明确的新付费任务。

提案持久化，关闭再开仍可审阅。勾选默认清空；依赖 `new:<key>` 的重标需要同时选补人。证据必须是模型实际看到的正文短引文，命名人物及别名需要字面证据。采纳在一个事务中完成，仍标为 AI inferred/conflict，不替代人工确认。正文、标注、角色、音色库/绑定或 skill 改变后拒绝旧提案。现有锁定/已确认内容受保护。

合并会把来源人物的未确认标注迁到目标人物、并入别名和兼容绑定、删除来源身份；审阅框列出所有受影响片段。超过 30 条、包含人工保护或旧版本标注、群体与个人合并、声音/风格冲突，以及新增绑定会改变目标回退播放时，必须先用人工人物工具处理。应用不删除已有音频文件；缓存是否可复用仍由真实合成指纹判断。

本地设置保留会话与动作记录，数据库租约阻止同章重复运行。暂不提供整次人物合并的一键撤销；请在勾选前检查证据及影响列表。内置 skill 已升级为 1.3.0 七阶段内容指纹，旧分析检查点须重启，已有人工标注保留。

真实微型测试需显式运行，读取本地 `.env`，默认两个短样本总上限 6 次调用/40,000 保守预算 tokens；不会重跑十二组全文。另选 `--cases merge` 仅单目标、最多 1 次；每次命令是独立预算，运行多个命令时须累计成本。

```bash
dart scripts/tools/run_live_tests.dart review --model gpt-6-luna --output .dart_tool/review-check
dart scripts/tools/evaluate_role_review.dart .dart_tool/review-check/capture.json
```

报告按带金标范围统计改对/改坏/净收益、人物召回/重复、送审精确率/召回率、用量及耗时，未做的多轮一致率显示 null。微型用例的初始错标由测试植入，金标不发送给模型；它验证补人/合并链路，不代表完整小说准确率。详情见 [评测标准](../skills/novel-role-assign/EVALUATION.md)。

## 可编辑的分角色配置

打开“设置 → 分角色 AI”。内置默认模型为 `gpt-6-luna`，可选择默认连接、编辑模型并复制出多个配置，保存后启用。小说阅读器与长文本入口共用；作品的专属任务设置及入口手动选择优先。默认模型用于新任务，暂停任务仍按记录的连接/模型恢复。

七个提示阶段分别为人物规划、批次标注、疑点复核、工具校对、反馈重规划、音色选角和语气建议。当前 Flutter 客户端用 Dart 状态机执行这些节点；语义分段、数据库保护和确定性验证继续由程序执行。提示词编译打包在 `assets/skills/novel-role-assign/SKILL.md`，用户覆盖保存于本地设置，不修改应用资源。配置数量最多 20，每个阶段最多 16,000 UTF-16 单位；实际任务还有独立输入/调用预算。

“还原此阶段提示词”清除当前阶段覆盖，再保存生效；“一键还原当前配置”立即恢复该配置的内置提示词、默认模型及入口连接规则并保存，保留其他配置。切换配置或修改提示词会改变有效 skill 指纹；进行中的小说/工具校对收到配置变更会取消，旧检查点与旧提案不能静默套用。

## 长文本自动分角色

在长文本项目的脚本工具栏点击“AI 自动分角色”，填写配音意图并分析。例如同一段嵌套故事，可选择“全部引用由现场讲述者朗读”，也可选择“广播剧演绎，内层直接引语另分角色”。用户意图进入规划、标注与复核，正文始终按原文 UTF-16 分区。

分析在临时内存工作区复用小说人物规划、语义分段、疑点检测与 Reviewer，不创建持久化阅读器工程。最多 360 个语义片段、64,000 UTF-16 单位、40 次调用；可取消，不会触发音频生成。先预览逐段人物/类别/证据，再按人物选择本音色库的音色（同名唯一匹配可预填），未分配音色保留待选。

点击“应用分角与音色”才一次事务替换当前分段并写入人物标签，之后使用原有逐句/批量生成。原正文保持不变、旧音频文件保留。正文、分段、音色库或提示词变化后拒绝旧分析；已有时间线片段时拒绝覆盖，先处理引用。生成列表显示人物标签；AI inferred/conflict 信息保留在分析记录中，不冒充人工确认。

## 扩大分角质量评测与费用账本

`run_role_quality.dart` 固定使用 `gpt-6-luna`，冻结 skill 和 21 组原文/金标，分别运行基线/候选各三轮。六组新增原创样本含台本、混合语言、身份揭晓、心理/信件和两篇跨批次长章节；不把金标发给模型。已有完成捕获复用，失效配置拒绝混跑。

```bash
dart scripts/tools/run_role_quality.dart --variant baseline --skill-file scripts/tests/fixtures/role_skill_history/SKILL.md --runs 3
dart scripts/tools/run_role_quality.dart --variant candidate --skill-file assets/skills/novel-role-assign/SKILL.md --runs 3
dart scripts/tools/evaluate_role_quality.dart .dart_tool/role-quality-2026-11-17
```

所有矩阵与额外意图测试共用 `.dart_tool/role-quality-2026-11-17/budget.json` 的 50 美元上限。调用前按 UTF-8 输入字节、schema、输出上限和余量保守预留，再按返回 usage 对账；失败或中断的未知用量不退款。并发进程用阻塞文件锁；价格守门按每百万总 tokens 2 美元计算，高于本轮核对的标准 Luna 文本价格。另列已知 usage 的标准价格上界估算，不能替代服务商账单。程序不自动切换昂贵模型。

传输失败的指标与原始输出在重启前复制到 `failed-attempts/`。再次显式启动同一矩阵时，先验证原文、模型和 skill 指纹，离线重建成功阶段，再在共享预算内继续；纯 `roles --replay` 仍绝不回退到联网。中断时需等旧进程结束，再续跑同一目录。

测试进程可显式设置 `NEIROHA_EVAL_PROXY=http://127.0.0.1:端口` 使用现有本地代理，不修改系统或应用网络设置。额外的同文不同配音意图真实测试也需启用共享账本：

```bash
NEIROHA_EVAL_BUDGET_FILE=.dart_tool/role-quality-2026-11-17/budget.json dart scripts/tools/run_live_tests.dart text-roles --model gpt-6-luna --output .dart_tool/text-intent
```

结果同时记录完成率、配对数、严格类别/人物分数、人物召回/重复、Reviewer 改对/改坏、抽查集合精确率/召回率、三轮一致率及 tokens/耗时。失败单列；无分母为 null。嵌套引语的表演策略差异保留原始严格分数，不通过改金标或事后改名掩盖。参考本轮读取的 [旧项目节点与 skill 快照](https://github.com/Moeary/CosyVoiceDesktop/tree/df564890eb1cffb42bd87ab7cd2c2aa1f13e9ad0/core/role_agent)。

## 后端能力声明

模型选择器中的“读取后端能力声明”只向当前 API base 下的 `.well-known/neiroha-capabilities` 发送 GET，不进行推理或部署。后端可返回以下协议；缺失或 null 为未知，声明不替代真实调用验证，也不覆盖用户证据。完整文档校验后才原子保存并供离线目录使用。

```json
{"version":1,"models":[{"id":"my-speaker","name":"本地语音模型","routes":{"speech":{"speech":true,"streaming":true,"instructions":null}}}]}
```

`routes` 使用 `chatCompletions`、`responses`、`speech`、`realtime`、`native`。能力字段支持 `text`、`speech`、`streaming`、`structuredOutput`、`audioInput`、`audioOutput`、`instructions`。这套客户端协议不要求接入 CosyVoice 后端。

## 本地 API 增量 PCM

向 `/v1/audio/speech` 提交 `stream: true` 和 `response_format: "pcm"`。只对实现增量音频的适配器开放；不支持时返回 400，不将整段生成冒充流式。响应为 `audio/pcm`，通过 `x-audio-encoding`、`x-audio-sample-rate`、`x-audio-channels` 声明真实格式。Speech 网关可通过相同格式头声明 PCM 参数。客户端须持续消费响应；断连取消当前上游请求。正常完成才写出 HTTP chunked 终止标记，失败时截断连接。关闭本地 API 也会取消音频连接。

流播不等待整段响度归一化。完整流播放结束后可在副本归一化，再更新工程缓存指针，当前播放文件不变；生成和导出共用同一次生成的完整缓存。

## 离线分角效果评分

```powershell
dart scripts/tools/evaluate_role_assignments.dart path/to/predictions path/to/report.md
```

每个预测文件以评测 fixture 的 `id` 命名，包含 `sourceRevision`（原文 UTF-8 SHA-256，与 `novelTextRevision(text)` 一致）和 `labels`。标签形如 `{"start":0,"end":10,"kind":"dialogue","speaker":"林舟"}`；偏移为 UTF-16，标签须连续、不重叠地覆盖全文。`kind` 使用 narrator/dialogue/thought/system。工具输出 Markdown 和相邻 JSON 明细，计算类别与人物正确率并处理别名；无法唯一定位的金标片段单列排除。缺失预测标为“未运行”且退出码为 2，不会替用户调用模型或产生推理费用。

## 真实小说分角评测（显式运行）

内置提示词已迁到 [novel-role-assign skill](../skills/novel-role-assign/SKILL.md)，版本与内容指纹随检查点和新捕获保存；详见 [评测标准](../skills/novel-role-assign/EVALUATION.md)。旧检查点没有指纹时需重新开始分析，已有人工标注仍由写入层保护。回放捕获会分别记录原始推理 skill 与当前处理 skill，不将旧响应冒充新提示词的推理结果。评分工具另写 `.metadata.json` 保留模型与版本。

```powershell
pwsh -File scripts/tools/test_novel_roles.ps1 -Model gpt-6-luna
dart scripts/tools/evaluate_role_assignments.dart .dart_tool/live-novel-roles .dart_tool/live-novel-roles/strict.md
```

脚本从未跟踪的本地 `.env` 读取 `OPENAI_TEST_API_KEY`、`OPENAI_API_KEY` 或 `OPENAI_KEY`，只交给测试子进程，结束后恢复环境变量。默认 `flutter test scripts/tests` 跳过这 12 项付费评测。真实测试使用生产分段、角色规划、复核检查点、逐批标注及 Reviewer，不向模型发送金标或金标人物表。每组最多 12 次结构化调用，一次进程总上限 72 次；传输错误不自动重试。输出、usage 与错误记录写入已忽略的 `.dart_tool/live-novel-roles`。已有完整且模型/正文版本相符的结果直接复用，另行重测应指定新输出目录。

可用 `-Cases 'xiyou,bookstore'` 限定样本；`-Replay` 仅回放同目录保存的响应以验证解析和数据库流程，捕获不完整时失败，绝不回退到付费请求。类别与人物金标都允许备选值；人物正确率同时要求类别正确。匿名/第一人称命名差异应由人按原文核对，再将显式 JSON 对应表作为评分器第三个参数输入，例如 `{"bookstore":{"第一人称叙述者":"我"}}`。严格匹配报告和人工对应后的报告应同时保留，不能把单纯改名当成模型重新答对，也不能通过对应表纠正真正分错的人物。小样本成绩不代表整本小说或其他题材的总体准确率。

2026-11-17 的 `gpt-6-luna` 实测已完成 12/12 组，共 420 个导入片段，原文 UTF-16 标签覆盖 100%。类别正确率为 **245/249（98.4%）**；人物严格姓名及既有别名匹配为 **200/240（83.3%）**，仅人工对齐七种明确同人名称后为 **219/240（91.3%）**。真实误分、未确认人物和保守保留的匿名身份差异仍存在，复杂对白应人工复核。

本轮修复了评分器不支持备选人物数组，以及解析器清除 system/有明确人物的 narrator 标签身份的问题。后者使同批输出的严格人物命中从 194 增至 200，无须重新推理。最终捕获 57 次成功请求、110424 tokens；额外早期规划及连接失败单独记录。严格分数、人工名称对应表、错例和调用明细保存在本机已忽略的 `.dart_tool/live-novel-roles-corrected/report.md`；修复前结果保存在 `.dart_tool/live-novel-roles/`。全量本地测试 194 通过、24 项显式运行测试跳过；修复后已离线回放十二组，模型提示词未针对样本调优。
