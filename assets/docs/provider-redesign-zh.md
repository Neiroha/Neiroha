# Provider 与适配层重构方案（v0.6 规划稿）

状态：草案，2026-11-22。目标版本 v0.6.0。本稿先定方向和分期，接口名、表名在 M1 评审时冻结。进度、优先级调整与模型目录数据化见 [第 11 节](#11-进度与调整2026-11-22)。

## 1. 结论

1. **一个 Provider = 一个账号连接**，不再是“一个 TTS 适配器”。一家订阅（如 OpenAI）配置一次，就同时提供 LLM、TTS、STT、实时对话、实时翻译等全部能力。
2. **能力（Capability）是一等概念**，模型挂在能力下面。界面、路由、校验都按能力走，模型名猜测（`_isTtsModelKey`）彻底退役。
3. **适配层拆成三层**：服务商插件（认证、地址、目录）→ 协议传输（OpenAI HTTP、SSE、WebSocket、WebRTC、本地 FFI）→ 能力接口（`SpeechSynthesizer`、`Transcriber` 等）。同一协议被多家复用，“OpenAI 兼容”从一种服务商降级为一种协议。
4. **模型标注三件事**：能做什么（能力 + 特性徽章）、在哪能用（桌面 / Web / Android）、还能用多久（预览 / GA / 弃用日期）。最后一项很急：OpenAI 的 `tts-1`、`tts-1-hd`、`gpt-4o-mini-tts` 将于 2027-01-06 停用，官方替代 `gpt-realtime-2.1-mini` 只走 Realtime API，不支持 `/v1/audio/speech`。
5. **分期交付**：先在不改行为的前提下把现有 12 个 TTS 适配器搬进新接口，再迁库、换界面，最后按价值顺序接入 STT → VAD → VC → 实时对话 / 翻译。

## 2. 现状与问题

| 现状 | 问题 |
| --- | --- |
| `TtsProviders` 一张表、`AdapterType` 12 个枚举值，每个值 = 一家服务商的 TTS 接口 | 同一个 OpenAI Key 要配两三次（TTS、兼容网关、LLM），各自测试、各自限额 |
| LLM 通过 `RoleAiConnection.supportsRoleAi` 借用 TTS 连接，`roleAiBaseUrl` 为 Gemini、MiniMax 硬编码改路径 | 能力和地址的对应关系散落在扩展方法里，新增一家要改多处 |
| `ModelBindings.supportedTaskModes` 只区分“模型 / 音色” | 无法表达一个模型属于哪类能力，界面只能按名字猜 LLM、ASR 徽章 |
| `AdapterType` 上有 `supportsModelQuery`、`hasSeparateModelAndVoice` 等 7 个布尔开关 | 能力是按适配器而非按模型描述，同一服务商不同模型的差异只能靠特判（如 `supportsStreamingModel`） |
| `ModelCapability` 证据存在 `AppSettings` 的哈希键里 | 难以查询、迁移和在界面上汇总 |
| 没有 ASR、VAD、VC 能力 | 克隆用的参考文本、视频字幕、录音切分都只能手工处理 |

可以保留的资产：`ModelCapability` 的证据来源与合并规则（catalog < provider < observed < user）、`.well-known/neiroha-capabilities` 网关声明、`ServiceEndpoint` 的路径与认证头校验、`TtsEvent` 流式事件、`TtsCancelToken`、`TaskProfile` 按项目指定模型的机制、历史 schema 迁移测试。

## 3. 能力分类

按指挥官的建议分为六类主能力，补充一类“语音翻译”。翻译可由专用模型完成，也可由 STT → LLM → TTS 组合完成，界面上单列更易理解。

| 能力 | 标识 | 输入 → 输出 | 典型交互 | 代表模型 |
| --- | --- | --- | --- | --- |
| 大语言模型 | `llm` | 文本(+音频/图像) → 文本 / 结构化 / 工具调用 | 请求或 SSE | GPT、Gemini、Qwen、MiniMax |
| 语音合成 | `tts` | 文本 → 音频 | 整段、HTTP 流、WebSocket 双向流 | GPT-SoVITS、ElevenLabs、MiniMax、Gemini TTS |
| 语音识别 | `stt` | 音频 → 文本（时间戳、说话人） | 文件转写、流式转写 | Whisper 系、Scribe、Qwen3-ASR、Gemini Transcribe |
| 实时对话 | `realtime` | 音频 ⇄ 音频（含转写、工具） | WebSocket / WebRTC 全双工 | gpt-realtime-2.1、Gemini Live、豆包实时语音 |
| 语音翻译 | `translate` | 音频 → 他语音频 + 文本 | 实时会话或文件 | gpt-realtime-translate、豆包同传 2.0 |
| 变声 | `vc` | 音频 + 目标音色 → 音频 | 文件或分块流 | ElevenLabs STS、Seed-VC、RVC |
| 语音活动检测 | `vad` | 音频 → 语音区间 / 轮次事件 | 本地逐帧 | Silero VAD（本地）、服务端 VAD |

说明：

- **能力 ≠ 协议**。`gpt-realtime-2.1-mini` 同时具有 `realtime` 能力和“可当 TTS 用”的特性，它在 TTS 能力下以 `realtime` 协议出现，在实时对话能力下也出现。一个模型可以挂在多个能力下，每个挂载各自声明协议。
- **VAD 主要在本地**。服务端 VAD（OpenAI `server_vad` / `semantic_vad`、Deepgram 类的轮次检测）作为 `stt` / `realtime` 会话的特性标注，不单独建连接。本地 VAD 是一个内置 Provider（无需 Key）。

### 3.1 特性徽章（模型级）

每个能力有自己的特性清单。界面只展示该能力相关的徽章，颜色按能力统一。

| 能力 | 特性 |
| --- | --- |
| `tts` | 预设音色、零样本克隆（每次带参考音频）、云端克隆（注册音色）、音色设计、情感/指令、SSML、流式输出、双向流输入、字级时间戳、多语言 |
| `stt` | 文件转写、流式转写、字级时间戳、说话人分离、语种识别、热词、情感、最长时长 |
| `realtime` | 音频输出、文本输出、工具调用、服务端 VAD、输入转写、可选音色、浏览器直连需短时凭据 |
| `translate` | 输入语种数、输出语种数、输出音频、保留音色 |
| `vc` | 零样本、需训练模型、实时、降噪 |
| `llm` | 结构化输出、工具调用、流式、音频输入、上下文长度、推理 |
| 通用 | 平台（桌面 / Web / Android）、生命周期（预览 / GA / 弃用于某日）、价格单位（可选） |

每个特性值都带来源：`目录`（内置）、`声明`（网关 `.well-known`）、`实测`（成功调用过）、`手动`。沿用现有 `CapabilityEvidence` 的合并优先级。

## 4. 适配层设计

### 4.1 分层

```
┌──────────────────────────────────────────────────────────────┐
│ 业务：Quick TTS / 小说 / Phase / 视频配音 / 本地 API / MCP     │
└───────────────┬──────────────────────────────────────────────┘
                │ 按能力取模型：router.tts(voice) / router.stt(task)
┌───────────────▼──────────────────────────────────────────────┐
│ 能力路由 CapabilityRouter                                     │
│  默认模型（全局）→ 项目覆盖（TaskProfile）→ 角色绑定           │
│  并发 / RPM 限额按“连接 × 能力”计量，取消令牌统一              │
└───────────────┬──────────────────────────────────────────────┘
                │ connection.model<Transcriber>('gpt-realtime-whisper')
┌───────────────▼──────────────────────────────────────────────┐
│ 服务商插件 ProviderPlugin（每家一个目录）                      │
│  认证字段 · 区域/地址 · 能力→服务地址映射 · 模型目录 · 发现     │
└───────────────┬──────────────────────────────────────────────┘
                │ 复用
┌───────────────▼──────────────────────────────────────────────┐
│ 协议传输 Protocol                                             │
│  openai-http（speech / transcriptions / chat / responses）    │
│  sse · websocket-realtime · webrtc（Web）· multipart 上传      │
│  本地：Neiroha 启动器 HTTP · sherpa-onnx FFI · 系统 TTS         │
└──────────────────────────────────────────────────────────────┘
```

### 4.2 能力接口（草案）

参考 Vercel AI SDK 的做法：Provider 暴露 `languageModel(id)`、`speechModel(id)`、`transcriptionModel(id)` 等可选工厂，调用方先查能力再取模型。Dart 版：

```dart
/// 一个已配置的账号连接。
abstract interface class ProviderConnection {
  String get id;
  ProviderPlugin get plugin;
  Future<ConnectionHealth> check();                 // 按能力分别报告
  Future<ProviderInventory> discover();             // 模型 + 音色 + 特性
  M? model<M extends CapabilityModel>(String modelId); // 不支持返回 null
}

sealed class CapabilityModel { ModelDescriptor get descriptor; }

abstract class SpeechSynthesizer extends CapabilityModel {
  Stream<TtsEvent> synthesize(TtsRequest r, {required TtsCancelToken cancel});
  Future<List<VoiceDescriptor>> voices();
}
abstract class VoiceCloner { Future<VoiceDescriptor> register(CloneRequest r); }

abstract class Transcriber extends CapabilityModel {
  Future<Transcript> transcribe(AudioInput a, TranscribeOptions o,
      {required TtsCancelToken cancel});
}
abstract class StreamingTranscriber extends CapabilityModel {
  TranscriptionSession open(TranscribeOptions o); // sink(pcm) → Stream<TranscriptEvent>
}

abstract class RealtimeModel extends CapabilityModel {
  Future<RealtimeSession> connect(RealtimeConfig c); // Stream<RealtimeEvent>, sendAudio, sendText, cancelResponse
}
abstract class SpeechTranslator extends CapabilityModel {
  Future<TranslationSession> open(TranslateConfig c);
}
abstract class VoiceConverter extends CapabilityModel {
  Stream<TtsEvent> convert(AudioInput a, VoiceRef target, {required TtsCancelToken cancel});
}
abstract class VoiceActivityDetector extends CapabilityModel {
  VadSession open(VadConfig c);                    // feed(pcm) → Stream<SpeechSegment>
  Future<List<SpeechSegment>> segments(AudioInput a);
}
abstract class LanguageModel extends CapabilityModel { /* 现有 LlmChatAdapter 的 chat / structured */ }
```

要点：

- **事件统一**：音频输出沿用 `TtsEvent`（`TtsAudioStarted` / `Chunk` / `Completed`）。新增 `TranscriptEvent`（partial / final、字时间戳、说话人）、`TurnEvent`（speechStarted / speechStopped）、`RealtimeEvent`（音频增量、转写、工具调用、响应结束），实时会话事件是前三者的并集。
- **会话型能力**（流式 STT、实时对话、翻译、VAD）都是“打开会话 → 推 PCM → 收事件 → 关闭”，共用一个 `AudioSession` 基类，取消与断线语义和现有流式 TTS 一致。
- **ModelDescriptor** 带能力、协议、特性证据、平台可用性、生命周期，界面和路由都只读它，不再查 `AdapterType` 的布尔开关。
- **兼容层**：M1 保留 `createAdapter()` 与 `TtsAdapter`，内部委托到新 `SpeechSynthesizer`，业务代码分批迁移。

### 4.3 服务商插件

```dart
class ProviderPlugin {
  final String id;                         // 'openai'、'elevenlabs'、'gpt-sovits'…
  final String displayName;
  final List<AuthField> auth;              // apiKey / region / appId+token / 无
  final List<RegionPreset> regions;        // 如 DashScope 北京/新加坡、MiniMax 国内/国际
  final Map<Capability, ServiceAddress> services; // 能力 → 基址 + 协议 + 认证头
  final ModelCatalog catalog;              // 内置目录（含弃用日期）
  final DiscoveryStrategy discovery;       // /v1/models、专用列表接口、.well-known、无
  final PlatformSupport platforms;
  ProviderConnection connect(ConnectionConfig c);
}
```

`services` 映射替代现在的 `roleAiBaseUrl` 特判：例如 Gemini 的 `llm` 走 `/v1beta/openai/`、`tts` 走原生 `generateContent`、`realtime` 走 Live WebSocket，都写在插件里。

“OpenAI 兼容”分成两种用法：

- **通用兼容网关插件**（`openai-compatible`）：用户填基址，能力默认未知，通过 `/v1/models`、`.well-known/neiroha-capabilities` 和用户勾选确定。
- **协议模块**（`openai-http`）：OpenAI、Speaches、DashScope 兼容模式、vLLM 等插件内部复用，不暴露给用户。

### 4.4 目录结构

遵守单文件 500 行上限，每家一个目录：

```
lib/domain/ai/            capability.dart · model_descriptor.dart · events/ · requests/
lib/data/ai/router/       capability_router.dart · quota.dart
lib/data/ai/protocols/    openai_http/ · sse/ · realtime_ws/ · webrtc_web/
lib/data/ai/providers/    registry.dart
                          openai/ gemini/ elevenlabs/ minimax/ azure_speech/
                          dashscope/ volcengine/ mimo/ openai_compatible/
                          local/{gpt_sovits,cosyvoice,index_tts,voxcpm2,speaches,seed_vc}/
                          on_device/{sherpa_onnx,system_tts}/
assets/model_catalog/     neiroha_catalog.json（自维护，带弃用日期）+ 现有 LiteLLM 快照
```

## 5. 服务商能力调研

下表为 2026-11 的调研结果，“待核实”项在实现对应插件前以官方文档复核。

| 服务商 | LLM | TTS | STT | 实时对话 | 翻译 | VC | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **OpenAI** | ✓ | Speech API（2027-01-06 停用）；`gpt-realtime-2.1-mini` 经 Realtime | `whisper-1` 等文件转写；`gpt-realtime-whisper` 流式 | `gpt-realtime-2.1` / `-mini` | `gpt-realtime-translate`（`/v1/realtime/translations`，70+ → 13 种语言） | — | 浏览器直连 Realtime 需短时凭据 |
| **Google Gemini** | ✓ | Gemini 3.8 TTS（已接入） | `gemini-3.5-transcribe-preview`（文件）、`-live-preview`（流式），说话人分离、字时间戳 | Gemini 3.8 Live | 待核实 | — | 转写为预览版，有时长上限；音乐生成 Lyria 3 / 3.5 走 Interactions API（已接入） |
| **ElevenLabs** | — | ✓（已接入，含 HTTP 流） | Scribe v2（文件）、Scribe v2 Realtime（WebSocket） | Agents 平台（暂不接） | Dubbing（待评估） | `/v1/speech-to-speech/{voice_id}`，`eleven_multilingual_sts_v2` | 另有 Voice Isolator 降噪 |
| **阿里云百炼 DashScope** | Qwen | Qwen3-TTS（含实时、音色设计、复刻） | Qwen3-ASR（实时 / 文件）、Fun-ASR（热词、方言、说话人分离） | 待核实 | 待核实 | — | 北京 / 新加坡两套地址 |
| **火山引擎豆包语音** | 方舟（豆包） | HTTP / WebSocket 单向与双向流、声音复刻、音色设计 | 大模型流式识别、录音文件识别 | 端到端实时语音大模型（3.0 邀测） | 同声传译 2.0 | — | 认证为 AppID + Token，与方舟 Key 分开 |
| **MiniMax** | ✓ | ✓（已接入） | 待核实 | 待核实 | — | — | 国内 / 国际地址 |
| **Azure Speech** | （Azure OpenAI 另配） | ✓（已接入） | 实时与批量转写 | — | 语音翻译 | — | 区域简写已支持 |
| **小米 MiMo** | ✓ | MiMo V2.5 TTS（已接入） | `mimo-v2.5-asr`，经 Chat Completions 的 `input_audio` 内容块（已接入；无 `/audio/transcriptions`） | — | — | — | 账号余额不足时所有请求先返回 402，ASR 真实效果待充值后实测 |
| **Speaches（自托管）** | — | Kokoro / Piper | faster-whisper，OpenAI 兼容 | `/v1/realtime`（待核实） | — | — | 本地 STT 首选后端 |
| **GPT-SoVITS / CosyVoice / IndexTTS / VoxCPM2** | — | ✓（已接入） | — | — | — | — | 本地 TTS，保持原接口 |
| **Seed-VC / RVC** | — | — | — | — | — | 零样本 VC，Seed-VC 约 300ms 算法延迟 | 官方无 HTTP 服务，需在 Neiroha 启动器中封装 |
| **sherpa-onnx（端侧）** | — | 离线 TTS | 离线 ASR（Paraformer、FunASR Nano 等） | — | — | — | Silero VAD；Flutter 支持桌面、移动、Web |
| **系统 TTS** | — | ✓ | — | — | — | — | Windows / macOS |

## 6. 数据模型与迁移

### 6.1 新表（schema v34）

| 表 | 关键字段 | 说明 |
| --- | --- | --- |
| `provider_connections` | id（沿用旧 provider id）、plugin_id、name、region、base_url、auth_json、options_json、enabled、position | 替代 `TtsProviders`。密钥字段见 6.3 |
| `connection_capabilities` | connection_id、capability、enabled、max_concurrency、rpm、rpd、tpm、tpd、service_override | 限额从连接级下沉到“连接 × 能力”，LLM 与 TTS 不再互相占额 |
| `provider_models` | id、connection_id、model_id、capability、route、display_name、features_json、lifecycle、shutdown_at、source、enabled | 替代 `ModelBindings`（模型部分）。同一模型多能力 = 多行 |
| `provider_voices` | id、connection_id、voice_id、name、languages、origin（预设 / 克隆 / 设计）、compatible_models、preview_url | 替代 `ModelBindings`（音色部分） |
| `capability_defaults` | capability、purpose（如 `clone_transcript`、`subtitle`、`role_analysis`）、connection_id、model_id | 全局默认路由；项目覆盖继续用 `TaskProfile` |

`VoiceAssets.providerId` 改为指向 `provider_connections.id`（id 不变，外键自然成立），`modelBindingId` 改指 `provider_models.id`。`ModelCapability` 证据从 `AppSettings` 迁入 `provider_models.features_json`。

### 6.2 迁移规则

1. 升级前自动备份数据库（沿用 v33 的做法）。
2. 每个 `TtsProviders` 行生成一个连接，`adapterType` 映射到插件：`openaiTts` → `openai`，`openaiCompatible` → `openai-compatible`，`chatCompletionsTts` → `mimo`（官方地址）或 `openai-compatible`，其余一一对应。
3. 旧模型绑定按内置目录判定能力；目录没有的，用现有名字规则兜底并标来源为 `手动`，界面提示用户确认。
4. 原来支持角色 AI 的连接自动启用 `llm` 能力；现有 `TaskProfile` 保持可解析。
5. **不自动合并**同一 Key 的多个旧连接。Provider 界面检测到“同插件、同地址、同密钥”的重复连接时给出合并向导，合并时改写角色引用。
6. 迁移测试接入 `database_migration_history_test.dart` 的历史快照。

### 6.3 密钥

现在 API Key 明文存 SQLite。重构时把 `auth_json` 中的密钥移到系统钥匙串（桌面 / Android 用 `flutter_secure_storage`），数据库只存引用；Web 无安全存储，继续存浏览器 SQLite 并在界面注明。`CapabilityRepository.scope()` 已用哈希区分账号，可直接沿用。

## 7. Provider 界面

### 7.1 列表：一眼看到每个连接能做什么

```
┌ 服务商 ───────────────────────── [+ 添加] ┐
│ ● OpenAI（个人）                           │
│   LLM  TTS  STT  实时  翻译        ⚠ 1 个模型将弃用 │
│ ● ElevenLabs                               │
│   TTS  STT  VC                             │
│ ● 本地 GPT-SoVITS          127.0.0.1:9880  │
│   TTS                                      │
│ ○ 端侧（内置）                             │
│   VAD  STT                                 │
└────────────────────────────────────────────┘
```

能力徽章颜色固定（LLM 蓝、TTS 紫、STT 绿、实时 橙、翻译 青、VC 粉、VAD 灰），未启用的能力显示为描边样式。健康点按能力汇总：全部可用为绿，部分失败为黄并在悬停时列出失败的能力。

### 7.2 添加：先选服务商，再一次性配置

1. 选服务商卡片，卡片上列出该家可提供的能力和平台限制（例如“实时对话：仅桌面”）。
2. 按插件的 `auth` 字段生成表单（Key、区域、AppID 等），而不是统一的“地址 + Key”。
3. 点“测试并发现”：逐个能力探测，结果以能力矩阵展示，可勾选启用哪些能力。
4. 完成后若尚未设置某能力的全局默认模型，直接询问是否设为默认。

### 7.3 编辑：按能力分页

```
OpenAI（个人）            [概览] [LLM] [语音合成] [语音识别] [实时] [翻译] [限额]
──────────────────────────────────────────────────────────────
语音合成                                         默认：gpt-realtime-2.1-mini
  gpt-realtime-2.1-mini   Realtime  预设音色 情感指令 流式   桌面    目录
  gpt-4o-mini-tts         Speech    预设音色 情感指令 流式   桌面 Web ⚠ 2027-01-06 停用
  [+ 手动添加模型]
音色（13）  alloy · ash · ballad · …                       [刷新]
```

- 每行显示协议、特性徽章、平台、来源；弃用模型显示红色日期，并在用到它的角色上同步提示。
- 概览页显示账号级信息：基址、区域、各能力健康状态、最近错误（含 #10 中修好的后端错误原因）。
- 通用兼容网关的能力页多一个“声明 / 手动勾选”入口。

### 7.4 能力路由页（设置 → AI 能力）

按用途列出默认模型，并标出缺口：

| 用途 | 能力 | 当前 |
| --- | --- | --- |
| 克隆参考音频自动转写 | STT | 未设置 → [选择] |
| 视频字幕生成 | STT（需时间戳） | ElevenLabs · scribe_v2 |
| 小说角色分析 / 复核 | LLM（需结构化输出） | OpenAI · gpt-6-luna |
| 录音切分、去静音 | VAD | 端侧 · Silero |
| 录音转角色音色 | VC | 未设置 |

候选模型按用途要求的特性过滤（如字幕要求“字级时间戳”）。项目级覆盖继续由 `TaskProfile` 承担。

### 7.5 角色（音色）编辑

角色只能选择 `tts` 能力下的模型，模型下拉显示特性徽章。克隆类角色在上传参考音频后，可一键调用默认 STT 填写参考文本。

## 8. 新能力的首批用途

按对配音工作站的价值排序：

1. **STT → 克隆参考文本**：上传或录制参考音频后自动填 `promptText`，减少克隆失败。
2. **STT → 视频字幕**：从视频音轨生成带时间戳的字幕，直接进入现有字幕 / 时间线流程。
3. **STT → 合成回听校验**：小说与 Phase 批量生成后转写比对原文，标出漏读、错读的句子。
4. **VAD → 录音处理**：录音自动去首尾静音、按停顿切分长录音为多条参考素材。
5. **VC → 录音转角色音色**：用户自己演绎台词，转换成角色音色，保留语气。
6. **翻译 → 视频配音**：字幕翻译（LLM）+ 目标语言 TTS；实时翻译模型作为预览。
7. **实时对话 → 角色试聊**：桌面端与角色实时对话，检验音色和人设。
8. **本地 API / MCP**：新增 `/v1/audio/transcriptions`，MCP 增加转写工具。

## 9. 分期计划

| 阶段 | 内容 | 验收 |
| --- | --- | --- |
| **M0 规格**（1 周） | 冻结能力、特性清单、插件接口、表结构；编写 `neiroha_catalog.json` 格式 | 本文档评审通过 |
| **M1 适配层骨架**（2 周） | 建 `domain/ai`、插件注册表、协议模块；12 个现有 TTS 适配器搬进 `SpeechSynthesizer`；`createAdapter` 改为委托 | 现有测试全过，行为无差异 |
| **M2 数据迁移**（1–2 周） | schema v34 新表、迁移、备份、钥匙串；历史快照迁移测试 | 所有历史 schema 快照升级成功，角色引用不丢 |
| **M3 新 Provider 界面**（2 周） | 列表徽章、添加向导、能力分页、弃用提示、能力路由页、重复连接合并 | 桌面、Web、320px 窄屏布局测试 |
| **M4 LLM 与 STT**（2 周） | 角色 AI 改走 `llm` 能力；STT 接入 OpenAI、ElevenLabs、Gemini、DashScope、Speaches；首个用途：克隆参考文本 | 各家假服务测试 + 真实凭据冒烟 |
| **M5 VAD 与 VC**（2 周） | 端侧 Silero VAD（sherpa_onnx 或 vad 包二选一）；ElevenLabs STS；启动器封装 Seed-VC | 录音切分、VC 转换端到端 |
| **M6 实时与翻译**（2–3 周） | 桌面 Realtime 对话、OpenAI 实时翻译；Web 端在有凭据服务时启用 | 首声、结束、中途取消 |

M1–M3 是 v0.6.0 的必需范围；M4 建议同版发布至少 STT 一项，否则新界面缺少能体现“多能力”的实例。M5、M6 可放 v0.6.x。

**和弃用日期的关系**：桌面端 OpenAI 官方适配器的默认模型已是 `gpt-realtime-2.1-mini`，但 Web 默认、显式选择 Speech 模型的角色，以及通用兼容适配器默认的 `tts-1` 都会在 2027-01-06 失效。v0.6.0 若赶不上这个日期，建议先发一个 v0.5.x：在这些角色上显示停用提示，并提供一键改用 Realtime 模型（桌面）或其他服务商（Web）。

## 10. 待指挥官决策

1. **能力粒度**：翻译单列（本稿方案），还是并入实时对话？
2. **端侧引擎**：采用 `sherpa_onnx`（VAD + 离线 ASR + 离线 TTS 一套）还是只用轻量 `vad` 包？前者包体积大但覆盖面广。
3. **密钥迁入钥匙串**是否放在 v0.6.0？会影响 Linux 依赖（libsecret）和备份导出。
4. **本地 VC 后端**：在 Neiroha 启动器中封装 Seed-VC，还是对接现有 RVC WebUI？
5. **首批接入的国内服务商**：DashScope 与火山引擎都覆盖 ASR / TTS / 实时，先接哪家？
6. **旧连接合并**：只提供向导（本稿方案），还是迁移时自动合并同 Key 连接？

## 11. 进度与调整（2026-11-22）

### 11.1 完成情况

| 阶段 | 状态 | 说明 |
| --- | --- | --- |
| M1 适配层骨架 | 已完成 | `domain/ai` 能力接口、插件注册表、`CapabilityRouter`；现有 TTS 适配器经 `SpeechSynthesizer` 委托 |
| M2 数据迁移 | 未开始 | 角色实时设置（`dialog.live.*`）与处理链（`voice.chain.*`）暂存 `AppSettings` JSON |
| M3 新 Provider 界面 | 部分 | 已有：模型行能力徽章（目录优先、名称兜底）、音色随 TTS 模型折叠、Azure 单行音色组。未做：连接列表徽章、添加向导、按能力分页、停用提示、能力路由页 |
| M4 LLM 与 STT | 基本完成 | LLM 发现与特性合并；STT 接入 OpenAI、Gemini、MiMo（Chat 音频输入） |
| M5 VAD 与 VC | 部分 | ElevenLabs STS 已接入；端侧 VAD、本地 VC 后端未做 |
| M6 实时与翻译 | 部分 | Gemini Live 与 OpenAI Realtime 可按角色选模型和该模型音色；Web Realtime 未做 |
| 计划外 | 已完成 | Gemini Lyria 歌曲创作页；角色处理链（LLM 翻译 / 改写 → TTS → VC），见 `lib/domain/synthesis/voice_chain.dart` |

### 11.2 调整后的优先级

1. **P0 停用提示（2027-01-06 前必须发布）。** `ModelDescriptor.shutdownAt` 已有数据，界面尚未使用。模型行显示红色停用日期；使用这些模型的角色显示警告，并提供一键迁移：桌面改用 Realtime 模型，Web 改用其他服务商。可先随 v0.5.x 发布，不等 v0.6。
2. **P1 schema v34。** 先建 `provider_models`、`capability_defaults` 和 `connection_capabilities`，再把角色实时设置、处理链迁入独立表或角色扩展表，避免继续在 `AppSettings` 里堆 JSON。限额下沉到“连接 × 能力”后，处理链中的 LLM 调用不再占用 TTS 服务商的队列名额。
3. **P2 界面。**
   - Provider 页（`provider_screen.dart` 1343 行）按能力拆为标签页，列表显示能力徽章与健康汇总。
   - 「设置 → AI 能力」路由页：字幕、歌曲、处理链、分角、选角各自的模型选择收拢为按用途的默认值，页面内仅保留覆盖入口。
   - 角色检查器分标签：基础 / 音色 / 处理链 / 实时对话；实时设置对话框并入检查器。
   - 工作页统一使用 `PageHeader`（52pt、可拖动窗口、主操作靠右）；新页面不再自写页头。
4. **处理链扩展。** 新增 ASR 回听校验步骤（转写比对原文、标出漏读）和 VAD 去静音步骤；小说缓存键加入处理链哈希，修改链后旧缓存失效；本机 API / MCP 增加是否应用处理链的参数；试听显示中间文本。

### 11.3 模型目录数据化

目标：LLM 不再手写模型表；云端语音模型只保留各家原生协议需要的少量条目；本地 TTS 由服务自行声明。

**公开来源实测（2026-11-22）**

| 来源 | 规模 | 可用字段 | 适用范围 |
| --- | --- | --- | --- |
| OpenRouter `GET /api/v1/models`（无需凭据） | 739 个模型 | 输入 / 输出模态（text、speech 42、transcription 30、image、embeddings 等）；`supported_parameters`（tools、structured_outputs、reasoning 等）；`reasoning.supported_efforts` 与默认档位；`endpoints`（`/chat/completions`、`/responses`、`/audio/speech`、`/audio/transcriptions`）；`supported_voices`（Gemini 3.8 TTS 30 个、ElevenLabs v4 21 个）；`expiration_date`（24 个）；上下文、最大输出、价格 | OpenRouter 连接的权威来源。id 带厂商前缀，参数是其多条上游线路的并集，不得按同名直接套给直连官方的连接 |
| models.dev `api.json` | 324 家、10022 个模型 | 按官方服务商与官方 id 组织（openai 53、google 39、xiaomi 6 并附官方 API 地址、deepseek、alibaba、moonshotai、zhipuai 等）；工具调用、结构化输出、推理与推理档位、输入输出模态、上下文与输出上限、知识截止、发布日期 | 直连官方 LLM 的主来源。许可证尚未核实，打包快照前须确认 |
| LiteLLM（现有快照） | 6969 条 | 价格、上下文、部分能力布尔值与端点 | 离线兜底，MIT |

现有代码在连接本身是 OpenRouter 时已读取模态与 `supported_parameters`（`llmTraitsFromListing`）；推理档位、端点、音色、下线日期尚未使用。

**LLM 取数顺序**

1. 账号实时列出的模型（决定“有哪些”）；
2. 联网刷新的公开目录（决定“能做什么”）：直连官方用 models.dev，OpenRouter 连接用其自身列表；按日缓存，带来源与时间；
3. 内置快照，离线时使用（LiteLLM，或许可证确认后的 models.dev）；
4. 实际成功证据与人工覆盖（沿用 `catalog < provider < observed < user`）。

落地后删除 `openai_catalog`、`gemini_catalog`、`mimo_catalog` 中的 LLM 条目，插件只保留推荐默认模型与协议特例（如 MiMo 的 `api-key` 头、Gemini 的 `/v1beta/openai/` 路径）。工作量：`scripts/tools/refresh_model_catalog.dart` 增加 models.dev 规范化；新增运行时刷新服务与缓存；`catalogVendor` 映射到 models.dev 服务商键；回归测试改为基于快照夹具。

**云端语音模型**

公开目录不描述各家原生协议（Gemini 原生 TTS、Azure SSML、MiMo Chat TTS / ASR、Realtime WebSocket、Lyria Interactions），这部分仍由插件目录手写，但只记录协议、流式与特性。音色表和下线日期用 OpenRouter 的 `supported_voices`、`expiration_date` 作为可刷新的提示；冲突时以账号实时列表为准。

**本地 TTS**

不再在应用内维护本地模型列表。扩展现有 `.well-known/neiroha-capabilities` 网关声明：模型、音色、语言、是否流式、接口路径与认证方式。Neiroha 启动器和自建服务按该格式自述，应用按声明挂载；未声明的服务回退为手动填写。

## 参考

- [OpenAI：新一代实时语音模型发布](https://openai.com/index/advancing-voice-intelligence-with-new-models-in-the-api/) · [Realtime 翻译指南](https://developers.openai.com/api/docs/guides/realtime-translation) · [TTS 指南与停用说明](https://developers.openai.com/api/docs/guides/text-to-speech) · [MarkTechPost 发布报道](https://www.marktechpost.com/2026/05/08/openai-releases-three-realtime-audio-models-gpt-realtime-2-gpt-realtime-translate-and-gpt-realtime-whisper-in-the-realtime-api/)
- [Google：Gemini 3.8 Live 与 3.5 Transcribe](https://blog.google/innovation-and-ai/technology/developers-tools/build-real-time-voice-applications-gemini-audio/) · [Gemini 3.5 Transcribe](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/gemini/3-5-transcribe?authuser=1) · [Live API](https://cloud.google.com/vertex-ai/generative-ai/docs/live-api)
- [ElevenLabs STT](https://elevenlabs.io/docs/capabilities/speech-to-text) · [Scribe v2 Realtime](https://elevenlabs.io/blog/introducing-scribe-v2-realtime) · [Speech to Speech](https://elevenlabs.io/docs/api-reference/speech-to-speech/convert) · [Voice Isolator](https://elevenlabs.io/docs/overview/capabilities/voice-isolator.md)
- [阿里云百炼 ASR 模型](https://help.aliyun.com/en/model-studio/asr-model/) · [Qwen-ASR 实时识别](https://help.aliyun.com/en/model-studio/real-time-speech-recognition-user-guide)
- [火山引擎豆包语音文档](https://www.volcengine.com/docs/6561) · [豆包实时语音模型 3.0 上线报道](https://news.10jqka.com.cn/20260618/c677581210.shtml)
- [Speaches](https://docsearch.algolia.com/mcp/docs/repo/speaches-ai/speaches) · [sherpa_onnx](https://pub.dev/packages/sherpa_onnx) · [vad 包](https://pub.dev/documentation/vad/latest/) · [Seed-VC](https://raw.githubusercontent.com/Plachtaa/seed-vc/main/README.md)
- 架构参考：[AI SDK Provider 规范（第三方整理）](https://tessl.io/registry/tessl/npm-ai-sdk--provider/files/docs/provider.md) · [Pipecat 语音输入与轮次检测](https://docs.pipecat.ai/guides/learn/speech-input)
