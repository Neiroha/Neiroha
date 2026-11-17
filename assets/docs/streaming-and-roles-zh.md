# 流式试听、小说分角与平台开发说明

本说明对应 `dev@2d514adb` 之后的未发布改动。个人协作规范与进度文件保留本地，不随源码分发。

## Quick TTS

在角色的 Quick TTS 面板开启自动流式播放。OpenAI Realtime 使用同一请求边接收边播放，并把完整音频写入历史。旧适配器仍在整段生成后播放。停止会取消上游请求并丢弃不完整缓存；生成完成后，正在播放的流可以继续播完，随后可从文件回放。流播放期间不能跳转到尚未生成的位置。

音频由公共 `SynthesisService` 编排，格式由适配器声明；PCM 必须提供真实采样率和声道，压缩音频在同一个解码器中持续消费。队列并发占用持续到整个请求清理结束。小说当前句、Dialog/Phase/视频单句试听及本地 API 已接公共流服务。小说首块到达后预取后续句；完整缓存命中时直接播放文件，旧适配器继续整段生成。CosyVoice 后端接入继续跳过。

2026-11-17 已用用户提供的本地凭据通过 Speech 与 Realtime 的真实流式播放、完整缓存、暂停恢复和取消检查。默认测试仍只使用本地假服务；真实测试须主动执行 `pwsh -File scripts/tools/test_openai_streaming.ps1`，凭据由本地 `.env` 的 `OPENAI_KEY` / `OPENAI_API_KEY` / `OPENAI_TEST_API_KEY` 读取，只传给测试进程，不写入源码或音频。音频与测量结果保存在 Git 忽略的 `.dart_tool/live-streaming/`。这不替代 Mac 实机或分角效果验收。

## 小说角色校对

进入小说后切换到“角色校对”。先创建作品人物并绑定语音库中的音色，再选择片段，修改人物、类别、句级音色或风格。应用范围可选当前句或本章同角色的未锁定片段。人工修改会标记为已确认；锁定内容不会被 AI 覆盖。可撤销最近 20 次标注动作，角色合并和音色绑定不属于标注撤销范围。

侧栏可修改人物名称、别名和描述、合并人物、查看台词数，并设置作品通用或本章声音。待确认列表可定位原句，片段可单独试听。音色优先级依次为：句级覆盖、章节人物绑定、作品人物绑定、语义类别默认、项目另一默认音色。阅读、试听、生成与导出使用同一解析规则。

自动分析需主动选择 Provider 和文本模型。首次规划后会暂停，供用户复核角色表；确认继续才进入批次标注和疑点复核。每次启动有调用上限，达到上限或暂停后可恢复，关闭面板不会丢失 checkpoint。正文或模型更改后须重新分析。AI 只返回稳定片段 ID 的标签，不返回替换正文；人工确认和锁定在公共写入层保护。角色身份可选具名、匿名或群体。自动选角与语气导演分别使用独立任务模型，每次一个有界任务，建议需审阅后应用。选角保留已有绑定；语气只处理最多 30 条未确认、未锁定且没有风格的片段，输入超过本地预算时拒绝发起调用。正文、角色或声音变化后，旧建议不能覆盖新编辑。

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

这些代码尚未在本机 Windows 上完成 Mac 编译或硬件验收。首次在 Mac 上构建需正常执行 Flutter/CocoaPods 依赖安装并检查 `Podfile.lock` 变化，然后验证录音权限、媒体键、关窗/Dock、蓝牙与睡眠恢复。

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

```powershell
dart scripts/tools/check_code_size.dart
flutter analyze
flutter test scripts/tests
flutter build windows --debug
```

原生音频冒烟会播放轻声音调，需有 Windows 音频设备及可运行的 FFmpeg，默认不运行：

```powershell
$env:NEIROHA_AUDIO_SMOKE = '1'
flutter test scripts/tests/streaming_audio_sink_test.dart
Remove-Item Env:NEIROHA_AUDIO_SMOKE
```

十二组上游分角评测保留来源与 Apache-2.0 许可证。当前 fixture 测试验证原文和标注数据的确定性约束，不代表真实模型归属准确率。

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
