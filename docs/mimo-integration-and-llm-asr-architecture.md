# Xiaomi MiMo 接入与 LLM/ASR 子系统架构设计

> 调研日期：2026-04-28
> 范围：小米 MiMo 开放平台（[platform.xiaomimimo.com](https://platform.xiaomimimo.com)）TTS / ASR / LLM 全套能力的接入方案，
> 以及在 Neiroha 现有 TTS Adapter 体系上扩展 ASR + LLM 子系统的架构设计。
> 平台原始文档已镜像保存在 [docs/research/mimo-llms-full.txt](research/mimo-llms-full.txt)（10151 行，469 KB）。

---

## 第一部分：MiMo 开放平台 — 接口梳理

### 1.1 平台概览

MiMo 开放平台的所有推理接口都遵循 **OpenAI Chat Completions 协议**（也提供 Anthropic Messages 兼容端点）。
**单一入口：所有模型 — LLM、Audio Understanding、TTS — 都通过 `/v1/chat/completions` 调用，靠 `model` 字段区分。**

| 接入方式 | Base URL | 鉴权 |
|---|---|---|
| OpenAI 兼容 | `https://api.xiaomimimo.com/v1` | `api-key: $KEY` 或 `Authorization: Bearer $KEY` |
| Anthropic 兼容 | `https://api.xiaomimimo.com/anthropic` | 同上，端点 `/v1/messages` |

> 实际调用方法：直接用 `openai` 或 `anthropic` 官方 SDK，把 `base_url` 改成上表。 Dart 端继续使用 `dio` 即可。

### 1.2 模型矩阵

| 模型 ID | 类别 | 上下文 | 能力 | RPM/TPM |
|---|---|---|---|---|
| `mimo-v2.5-pro` / `mimo-v2-pro` | 文本 LLM 旗舰 | 1 M | 文本生成、深度思考、流式、function call、结构化输出、联网搜索 | 100 / 10 M |
| `mimo-v2.5` | 全模态理解 | 1 M | **接受文本/图像/音频/视频输入**，支持思考/工具调用 | 100 / 10 M |
| `mimo-v2-omni` | 全模态理解 | 256 K | 同上（旧版） | 100 / 10 M |
| `mimo-v2.5-flash` | 轻量 LLM | 256 K | 高效推理、function call | 100 / 10 M |
| `mimo-v2-flash` | 代码/Agent | 256 K | 代码、Agent、function call | 100 / 10 M |
| `mimo-v2.5-tts` | 语音合成 | 8 K | 内置高质量音色（中文 4 个 + 英文 4 个） | 100 / 10 M |
| `mimo-v2.5-tts-voicedesign` | 语音设计 | 8 K | 自然语言描述生成全新音色 | 100 / 10 M |
| `mimo-v2.5-tts-voiceclone` | 语音克隆 | 8 K | 上传 base64 参考音频克隆音色 | 100 / 10 M |
| `mimo-v2-tts` | 语音合成 | 8 K | V2 旧版（项目已接入） | 100 / 10 M |

**计费**：TTS 系列限时免费；`mimo-v2.5-pro` $1/1M cache miss、$3/1M output；`mimo-v2.5` $0.4/1M cache miss、$2/1M output（海外定价，国内同结构 ¥7/¥21 等）。Cache hit 价格约 1/5。

### 1.3 内置音色清单（`mimo-v2.5-tts`）

| Voice ID | 语言 | 性别 |
|---|---|---|
| `mimo_default` | 自动（中国集群=`冰糖`，海外=`Mia`） | — |
| `冰糖` / `茉莉` | 中文 | 女 |
| `苏打` / `白桦` | 中文 | 男 |
| `Mia` / `Chloe` | 英文 | 女 |
| `Milo` / `Dean` | 英文 | 男 |

### 1.4 三种 TTS 调用模式

> **共同约束**：要合成的目标文本永远放在 `assistant` role 的 `content`；可选的风格/导演指令放在 `user` role 的 `content`。
> 流式调用必须 `audio.format = "pcm16"`，输出 24 kHz PCM16LE 单声道。

#### 模式 A：内置音色（preset）

```json
POST https://api.xiaomimimo.com/v1/chat/completions
{
  "model": "mimo-v2.5-tts",
  "messages": [
    { "role": "user",      "content": "Bright, bouncy, slightly sing-song tone..." },
    { "role": "assistant", "content": "Hey boss — guess what..." }
  ],
  "audio": { "format": "wav", "voice": "Chloe" }
}
```

返回：`choices[0].message.audio.data`（base64）。

#### 模式 B：语音设计（VoiceDesign）

`audio.voice` **不传**，由 `user` 的描述文本驱动音色生成；`assistant` 是要朗读的内容。

```json
{
  "model": "mimo-v2.5-tts-voicedesign",
  "messages": [
    { "role": "user",      "content": "Heavy Russian accent, gruff middle-aged male, blunt and matter-of-fact." },
    { "role": "assistant", "content": "Yes, I had a sandwich." }
  ],
  "audio": { "format": "wav" }
}
```

#### 模式 C：语音克隆（VoiceClone）

`audio.voice` 传 data URL（`data:audio/mpeg;base64,...`），格式仅支持 `mp3` / `wav`，base64 不超过 10 MB。

```json
{
  "model": "mimo-v2.5-tts-voiceclone",
  "messages": [
    { "role": "user",      "content": "" },
    { "role": "assistant", "content": "Yes, I had a sandwich." }
  ],
  "audio": {
    "format": "wav",
    "voice": "data:audio/mpeg;base64,$BASE64_AUDIO"
  }
}
```

#### 风格控制：两条路径

1. **Natural Language**（放在 `user.content`）— 一句话描述风格；进阶用「**导演模式**」三段式：
   - **Character**（身份/性格/外貌/说话习惯）
   - **Scene**（时空/对象/情绪状态）
   - **Direction**（语速、停顿、气息、共鸣、咬字、情绪波动）
2. **Audio Tag**（放在 `assistant.content` 内文）—
   - 整段开头 `(style)`：`(磁性)夜深了……`、`(Northeast dialect)…`、`(singing)…`
   - 内联 `[audio tag]`：`(紧张，深呼吸) 嘶……冷静`、`(轻笑｜释然) 也挺好`
   - 支持半角 `()`、全角 `（）`、`[]`，多个 tag 用空格或 `|` 分隔

### 1.5 ASR：开放平台无独立 ASR 接口（已二次确认）

**结论（2026-04-28 二次联网核实）**：

- 开放平台 sitemap、`llms-full.txt`（10151 行全文档）、官方发布博客均无任何 ASR REST 端点；
- Hugging Face 模型卡明确说明仅提供权重 + 代码，部署依赖 **CUDA ≥ 12.0 + flash-attn 2.7.4 + Python 3.12 + Transformers**（参数量 8B，F32 safetensors）；
- 推理用 `MimoAudio` Python 类或自带 Gradio demo；Hugging Face Space 上有免费 demo 但不可用于商用集成。

> 一句话：**MiMo-V2.5-ASR 是纯开源模型，官方平台不托管。** 想用 hosted ASR 必须曲线救国。

平台层面的"语音转文本"只能通过 `mimo-v2.5` / `mimo-v2-omni` **多模态 chat 接口**实现（音频理解）：

```json
{
  "model": "mimo-v2.5",
  "messages": [{
    "role": "user",
    "content": [
      { "type": "input_audio",
        "input_audio": { "data": "https://example.com/audio.wav" } },
      { "type": "text",
        "text": "Transcribe verbatim with timestamps and speaker labels." }
    ]
  }],
  "max_completion_tokens": 1024
}
```

**约束**：
- 格式：MP3/WAV/FLAC/M4A/OGG
- URL 输入 ≤ 100 MB；Base64 输入 ≤ 50 MB；不支持本地文件直传
- Token 估算：`总 token ≈ 时长(秒) × 6.25`
- 输出依赖 prompt 引导（不像专用 ASR 自动给时间戳/说话人分离）

如果需要专用 ASR（高质量、多说话人、强噪、方言、Code-Switch），有两条路：
1. **自部署 MiMo-V2.5-ASR**：拉 [`XiaomiMiMo/MiMo-V2.5-ASR`](https://github.com/XiaomiMiMo/MiMo-V2.5-ASR) 代码 + [HF 权重](https://huggingface.co/XiaomiMiMo/MiMo-V2.5-ASR) + 起 Python 推理服务（需独立 GPU 节点，desktop 客户端不友好）
2. **降级方案**：用 `mimo-v2.5` 多模态接口配合 prompt 工程（够用但精度/分轨能力弱）

下文架构以 **AsrAdapter 抽象** 同时支持两种来源 + Whisper 兜底。

### 1.6 错误码与限流

- `400` 参数/格式错误；`401` Auth 失败（注意 Token Plan 与 Pay-as-you-go 用 **不同 Base URL 与 Key**，混用会 401）
- `402` 余额不足；`403` 风控/区域限制；`421` 内容过滤；`429` 频控（建议指数退避）
- `500` / `503` 服务端错误，重试

---

## 第二部分：Neiroha 现有架构与扩展点

### 2.1 现状审计

#### 2.1.1 TTS Adapter 体系（已成熟）

- 抽象类 [`TtsAdapter`](../lib/data/adapters/tts_adapter.dart#L66) — `synthesize / healthCheck / getSpeakers / getModels`
- 工厂函数 [`createAdapter`](../lib/data/adapters/tts_adapter.dart#L81) — 按 `AdapterType` enum 分发
- 统一 IO：`TtsRequest` / `TtsResult` / `ModelInfo`
- 现有 8 个适配器：`openaiCompatible` / `gptSovits` / `cosyvoice` / `voxcpm2Native` / `chatCompletionsTts` / `azureTts` / `systemTts` / `geminiTts`
- **MiMo 已部分接入**：[`ChatCompletionsTtsAdapter`](../lib/data/adapters/chat_completions_tts_adapter.dart) 默认 `apiKeyHeader: 'api-key'`、`defaultModel: 'mimo-v2-tts'`，但只调用 V2 + preset voice，**未支持 V2.5 / VoiceDesign / VoiceClone**。

#### 2.1.2 数据库表（[lib/data/database/tables.dart](../lib/data/database/tables.dart)）

| 表 | 用途 |
|---|---|
| `TtsProviders` | 服务商配置（baseUrl / apiKey / adapterType） |
| `VoiceAssets` | 音色资产（含 `taskMode`：preset / cloneWithPrompt / voiceDesign） |
| `AudioTracks` | 原始音频片段库（来源：upload/record/quickTts/phaseTts/dialogTts） |
| `VoiceBanks` / `VoiceBankMembers` | 音色库分组 |
| `PhaseTtsProjects` / `PhaseTtsSegments` | **段落 TTS** 项目 |
| `DialogTtsProjects` / `DialogTtsLines` | **对话 TTS** 项目 |
| `VideoDubProjects` / `SubtitleCues` | **视频配音**项目 |
| `TimelineClips` | 多轨时间线编辑 |

#### 2.1.3 三大工作流

- **Phase TTS**（[phase_tts_screen.dart](../lib/presentation/screens/phase_tts_screen.dart)）— 长文本/小说，`_autoSplit` 按双换行切段，每段绑定一个 voice asset 后批量合成。
- **Dialog TTS**（[dialog_tts_screen.dart](../lib/presentation/screens/dialog_tts_screen.dart)）— 多角色对话，每行手动选 voice。
- **Video Dub**（[video_dub_screen.dart](../lib/presentation/screens/video_dub_screen.dart)）— 视频字幕配音，目前 `_importSubtitles` 只能从 srt/lrc/vtt/txt **文件**导入。

### 2.2 关键缺口

| 用户需求 | 现状 | 缺口 |
|---|---|---|
| MiMo V2.5 TTS 三件套 | 仅接 V2 + preset | 需 VoiceDesign / VoiceClone 数据流贯通 |
| 段落 TTS 自动分角色 + 打标 | 无 | 缺 LLM Adapter + 剧本分析服务 |
| 视频 ASR → 翻译 → 洗稿 | 仅字幕文件导入 | 缺 ASR Adapter + LLM 翻译/改写 + 流水线编排 |
| LLM 接口 | 完全没有 | 全新模块 |
| ASR 接口 | 完全没有 | 全新模块 |

---

## 第三部分：架构设计

### 3.1 Capability 绑在模型上，不绑在 Provider 上

**核心设计原则**：

> **Provider 只是一个共享 baseUrl + apiKey 的"账号"**，里面装了一组 model。
> **每个 model 可以打 capability tag**：`tts` / `llm` / `asr`（多值，因为 `mimo-v2.5` 多模态既能做 LLM 又能做 ASR）。

这样一个 MiMo Provider 行就能同时承载所有能力，**无需让用户配三遍 API Key**，且**完全不破坏现有 Provider 编辑器的布局**（截图里那个页面）。

#### 截图分析：现状的"噪音"

看现有 Provider 编辑器（OpenAI Chat Completions TTS）一次 Fetch All 出 8 个模型：

| modelKey | 实际能力 | 当前 UI 处境 |
|---|---|---|
| `mimo-v2-pro` / `mimo-v2.5-pro` | **LLM（不能 TTS）** | ❌ 误入 TTS 模型下拉 |
| `mimo-v2-omni` / `mimo-v2.5` | **多模态（LLM + ASR）** | ❌ 同上 |
| `mimo-v2-tts` / `mimo-v2.5-tts` | TTS preset | ✅ 该出现 |
| `mimo-v2.5-tts-voiceclone` | TTS clone | ✅ 该出现 |
| `mimo-v2.5-tts-voicedesign` | TTS design | ✅ 该出现 |

只要给每个模型打 `[tts]` / `[llm]` / `[asr]` chip，就能：
- TTS 选择器只显示 capability ⊇ `{tts}` 的模型
- LLM 服务（auto-annotate / translate）启动时去找 capability ⊇ `{llm}` 的模型
- ASR 服务找 capability ⊇ `{asr}` 的模型

#### 三种 capability 与适配器路由

| Capability | 路由到 | 实现量 |
|---|---|---|
| **tts** | 走 `Provider.adapterType` 决定的 TTS adapter（现有 8 个，补 V2.5 形态） | **已有，仅扩展** |
| **llm** | 一律走 `OpenAiCompatibleLlmAdapter`（baseUrl/apiKey 取自 Provider） | **极轻，1 个新类** |
| **asr** | 按 modelKey 路由：`whisper-*` / `gpt-4o-transcribe` → `OpenAiWhisperAdapter`；`mimo-v2.5` / `mimo-v2-omni` → `MimoAudioUnderstandingAsrAdapter`；本地档 → `WhisperLocalAdapter` | **中，2-3 个新类** |

> 关键点：`Provider.adapterType` 字段语义不变 —— 它仍然只决定 **TTS** 调用走哪个 adapter（"OpenAI Chat Completions TTS" / "GPT-SoVITS" / "Azure" 等）。LLM 和 ASR 是新增的正交维度，跟 adapterType 无关，由 modelKey 自身决定路由。

### 3.2 总览

```
┌──────────────── lib/data/adapters ─────────────────────────────┐
│  TTS family ── tts_adapter.dart (existing) + 8 实现            │
│                chat_completions_tts_adapter.dart (升级 V2.5)   │
│                                                                │
│  LLM family ── llm_adapter.dart                  ← NEW         │
│                openai_compatible_llm_adapter.dart ← NEW (单一) │
│                                                                │
│  ASR family ── asr_adapter.dart                  ← NEW         │
│                openai_whisper_adapter.dart       ← NEW (主)    │
│                whisper_local_adapter.dart        ← NEW (本地)  │
│                mimo_audio_understanding_asr.dart ← NEW (兜底)  │
└────────────────────────────────────────────────────────────────┘
                       ▼
┌──────────────── lib/data/services ─────────────────────────────┐
│  script_analysis_service.dart  ← NEW   (Phase TTS 自动打标)    │
│  translation_service.dart      ← NEW   (字幕翻译/洗稿)          │
│  asr_service.dart              ← NEW   (视频抽音轨 + 转写)      │
└────────────────────────────────────────────────────────────────┘
                       ▼
┌──────────────── lib/presentation ──────────────────────────────┐
│  phase_tts_screen   "Auto-Annotate" 按钮                       │
│  video_dub_screen   "Extract from Video" 按钮                  │
│  provider_screen    Models 列表每行加 capability chip          │
│                     （现有布局不变 —— 只是 chip 增量）         │
└────────────────────────────────────────────────────────────────┘
```

### 3.3 数据库 schema 变更（schema v16）

> **注意**：当前 `app_database.dart` 已是 `schemaVersion => 15`，且 onUpgrade 使用 drop-all 开发迁移。
> 本次升级必须 bump 到 **v16**，并将 onUpgrade 改为增量 `addColumn` 迁移（替换掉开发期的 drop-all 逻辑），
> 否则老用户升级时不会跑 `from < 15` 分支，且 drop-all 会丢失所有用户数据。

#### 扩展 `TtsProviders`（加 `apiKeyHeader`），扩展 `ModelBindings`

`TtsProviders` 表的 `adapterType` 字段含义不变（仍然只决定 TTS 走哪个 adapter）。

> **`supportedTaskModes` 哨兵值警告**：当前 `providers.dart:72` 用 `supportedTaskModes == 'voice'` 来区分"voice 条目"和"model 条目"。
> 新增的 `capabilities` 字段**不得混入此语义**——两个字段各管各的。
> `supportedTaskModes` 继续只管 TTS 内部的任务模式（preset / clone / voiceDesign / voice 哨兵）；
> `capabilities` 只管跨域能力标记（tts / llm / asr）。
但当前表**缺少 `apiKeyHeader` 字段**——MiMo 用 `api-key`，OpenAI/Groq 用 `Authorization`，Gemini 用 `x-goog-api-key`。
`ChatCompletionsTtsAdapter` 目前硬编码默认 `api-key`，无法适配其他服务商。需要加字段：

```dart
class TtsProviders extends Table {
  // ... 已有字段
  TextColumn get apiKeyHeader => text().withDefault(const Constant('Authorization'))();
  // 'api-key' | 'Authorization' | 'x-goog-api-key' | 自定义
}
```

所有 capability 信息加到模型行：

```dart
class ModelBindings extends Table {
  // ... 已有字段
  TextColumn get providerId => text().references(TtsProviders, #id)();
  TextColumn get modelKey => text()();
  TextColumn get supportedTaskModes => text().withDefault(const Constant(''))();
  // ↑ 已有：'preset,clone,voiceDesign' — TTS 内部如何用

  // ↓ 新增
  TextColumn get capabilities => text().withDefault(const Constant(',tts,'))();
  // 存储格式：',tts,' 或 ',tts,llm,' 或 ',llm,asr,'
  // 前后都带逗号，查询时用 LIKE '%,cap,%' 匹配，避免子串误匹配。
  //
  // 默认 ',tts,' —— 老数据迁移后所有现有 modelBinding 都标 tts，
  // 行为完全不变。新增模型时由前端按 modelKey 自动推断初值。
}
```

#### 自动推断规则（Fetch All 时初始化 capability）

```dart
/// 返回值为逗号分隔的 capability 字符串，前后带逗号。
/// 例：',tts,' 或 ',llm,asr,'
String inferCapabilities(String modelKey) {
  final k = modelKey.toLowerCase();
  // ASR
  if (k.contains('whisper') ||
      k.contains('transcrib') ||
      k.contains('asr')) {
    return ',asr,';
  }
  // TTS
  if (k.contains('tts') ||
      k.contains('speech-synthesis') ||
      k.endsWith('-voice')) {
    return ',tts,';
  }
  // 多模态：既是 LLM 又能 ASR（音频理解）
  // 注意：mimo-v2 / mimo-v2.5 的正则必须排除已匹配 TTS 的情况（TTS 分支在前已 return）
  if (k.contains('omni') ||
      RegExp(r'mimo-v2(\.5)?$').hasMatch(k) ||
      k.contains('-vision') ||
      (k.contains('gpt-4o') && !k.contains('transcribe') && !k.contains('tts'))) {
    return ',llm,asr,';
  }
  // 默认：纯 LLM
  return ',llm,';
}
```

用户可以在 UI 上手动调整每行的 chip（多选）；推断只决定初值。

#### Phase TTS 段落表加字段（不变）

```dart
class PhaseTtsSegments extends Table {
  // ... 已有
  TextColumn get speakerLabel => text().nullable()();
  TextColumn get audioTagPrefix => text().nullable()();
  TextColumn get styleNotes => text().nullable()();
}
```

#### SubtitleCues 加字段（不变）

```dart
class SubtitleCues extends Table {
  TextColumn get sourceLang => text().nullable()();
  TextColumn get originalText => text().nullable()();
  TextColumn get translatedText => text().nullable()();
}
```

#### 老数据迁移

```dart
// app_database.dart
@override
int get schemaVersion => 16;  // ← 从 15 bump 到 16

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) async {
    await m.createAll();
    await _seedDefaults();
  },
  onUpgrade: (m, from, to) async {
    if (from < 16) {
      // 1. TtsProviders 加 apiKeyHeader 字段（默认 'Authorization'，兼容现有 provider）
      await m.addColumn(ttsProviders, ttsProviders.apiKeyHeader);

      // 2. ModelBindings 加 capabilities 字段，默认 'tts' 不破坏现状
      await m.addColumn(modelBindings, modelBindings.capabilities);

      // 3. Phase / Subtitle 业务字段
      await m.addColumn(phaseTtsSegments, phaseTtsSegments.speakerLabel);
      await m.addColumn(phaseTtsSegments, phaseTtsSegments.audioTagPrefix);
      await m.addColumn(phaseTtsSegments, phaseTtsSegments.styleNotes);
      await m.addColumn(subtitleCues, subtitleCues.sourceLang);
      await m.addColumn(subtitleCues, subtitleCues.originalText);
      await m.addColumn(subtitleCues, subtitleCues.translatedText);
    }
  },
);
```

> **重要**：必须替换掉当前 `app_database.dart` 中开发期的 drop-all 迁移逻辑（`m.drop(...)` 循环），
> 改为上面的增量 `addColumn` 迁移。否则老用户升级会丢失所有数据。
>
> 老用户的所有现有 modelBindings 自动得到 `capabilities = 'tts'`，行为零变化。
> 老用户的所有现有 ttsProviders 自动得到 `apiKeyHeader = 'Authorization'`，
> 对 MiMo 用户需要手动改成 `'api-key'`（或在 Provider 编辑器 UI 上加一个下拉选择）。

#### `AdapterType` 枚举：**不扩展**，保持 TTS-only

**关键修正**：`AdapterType` 枚举**不加入 LLM/ASR 类型**。原因：

1. `createAdapter()` 工厂函数（`tts_adapter.dart:81`）的 switch 只处理 TTS adapter，加 LLM/ASR 分支会导致未实现的 case 抛异常
2. `provider_screen.dart` 的 Fetch All / Health Check 直接调 `createAdapter(tmp)`，如果 adapterType 是 `openaiCompatibleLlm` 会找不到对应 TTS adapter 而崩溃
3. `AdapterType` 在 UI 下拉里用于选择"TTS 服务商类型"，语义不应混入 LLM/ASR

**正确做法**：`AdapterType` 保持现有 8 个 TTS 类型不变。LLM/ASR 路由完全由 **`ModelBinding.capabilities` + `modelKey`** 决定，与 `adapterType` 无关：

| 维度 | 路由依据 | 示例 |
|---|---|---|
| TTS | `Provider.adapterType` → `createAdapter()` | `chatCompletionsTts` → `ChatCompletionsTtsAdapter` |
| LLM | `ModelBinding.capabilities` 含 `llm` → `OpenAiCompatibleLlmAdapter` | 任何 model 都走同一 adapter |
| ASR | `ModelBinding.capabilities` 含 `asr` + `modelKey` 字符串匹配 | `whisper-*` → `OpenAiWhisperAdapter`，`mimo-v2.5` → `MimoAudioUnderstandingAsrAdapter` |

> **删除项**：原方案有的 `anthropicCompatibleLlm` 不做。MiMo 的 Anthropic 端点也只是同一组模型的另一种协议封装，OpenAI 端点已能完整覆盖；真要接原生 Claude 再说，等需求来了再加。
>
> **Provider preset 层**：preset 中的 `adapterType` 字段仍然只填 TTS adapter 类型（如 `'chatCompletionsTts'`）。
> 对于纯 LLM/ASR 服务商（如 Groq、OpenAI），preset 的 `adapterType` 填 `'openaiCompatible'` 作为占位（因为这些服务商不做 TTS，adapterType 不会被实际调用）。

#### Provider 模板预设（前端层）

为了让用户加 Provider 时只输 API Key 就能跑起来，在前端硬编码一份 **预设清单**，覆盖常见服务商。新增 [`lib/domain/llm_provider_presets.dart`](../lib/domain/llm_provider_presets.dart)：

```dart
class LlmProviderPreset {
  final String id;            // 'mimo' | 'openai' | 'deepseek' | 'gemini' | ...
  final String displayName;   // 'Xiaomi MiMo' | 'OpenAI' | ...
  final String baseUrl;
  final String adapterType;   // TTS adapter type（仅用于 TTS，纯 LLM/ASR 服务商填 'openaiCompatible' 占位）
  final String apiKeyHeader;  // 'api-key' | 'Authorization' | 'x-goog-api-key'
  final List<String> defaultModels;  // 下拉直接列出
  final String? signupUrl;    // 一键跳转 console
}

const llmProviderPresets = [
  LlmProviderPreset(
    id: 'mimo',
    displayName: 'Xiaomi MiMo',
    baseUrl: 'https://api.xiaomimimo.com/v1',
    adapterType: 'chatCompletionsTts',  // MiMo TTS 走 chat completions 形态
    apiKeyHeader: 'api-key',
    defaultModels: ['mimo-v2.5-tts', 'mimo-v2.5-tts-voiceclone', 'mimo-v2.5-tts-voicedesign',
                    'mimo-v2.5-pro', 'mimo-v2.5', 'mimo-v2.5-flash'],
    signupUrl: 'https://platform.xiaomimimo.com/#/console/api-keys',
  ),
  LlmProviderPreset(
    id: 'openai',
    displayName: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    adapterType: 'openaiCompatible',  // 占位：OpenAI TTS 走 /audio/speech
    apiKeyHeader: 'Authorization',
    defaultModels: ['gpt-4o', 'gpt-4o-mini', 'whisper-1'],
    signupUrl: 'https://platform.openai.com/api-keys',
  ),
  LlmProviderPreset(
    id: 'deepseek',
    displayName: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com/v1',
    adapterType: 'openaiCompatible',  // 纯 LLM，无 TTS
    apiKeyHeader: 'Authorization',
    defaultModels: ['deepseek-chat', 'deepseek-reasoner'],
    signupUrl: 'https://platform.deepseek.com/api_keys',
  ),
  LlmProviderPreset(
    id: 'qwen',
    displayName: 'Aliyun Qwen (DashScope)',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    adapterType: 'openaiCompatible',
    apiKeyHeader: 'Authorization',
    defaultModels: ['qwen-max', 'qwen-plus', 'qwen-turbo'],
    signupUrl: 'https://bailian.console.aliyun.com/?apiKey=1',
  ),
  LlmProviderPreset(
    id: 'kimi',
    displayName: 'Moonshot Kimi',
    baseUrl: 'https://api.moonshot.cn/v1',
    adapterType: 'openaiCompatible',
    apiKeyHeader: 'Authorization',
    defaultModels: ['moonshot-v1-8k', 'moonshot-v1-32k', 'moonshot-v1-128k'],
    signupUrl: 'https://platform.moonshot.cn/console/api-keys',
  ),
  LlmProviderPreset(
    id: 'openrouter',
    displayName: 'OpenRouter (聚合)',
    baseUrl: 'https://openrouter.ai/api/v1',
    adapterType: 'openaiCompatible',
    apiKeyHeader: 'Authorization',
    defaultModels: ['anthropic/claude-3.5-sonnet', 'google/gemini-2.0-flash'],
    signupUrl: 'https://openrouter.ai/keys',
  ),
  LlmProviderPreset(
    id: 'gemini',
    displayName: 'Google Gemini',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    // 走 OpenAI 兼容端点，不需要单独的 GeminiLlmAdapter
    adapterType: 'openaiCompatible',
    apiKeyHeader: 'x-goog-api-key',
    defaultModels: ['gemini-2.5-pro', 'gemini-2.5-flash'],
    signupUrl: 'https://aistudio.google.com/apikey',
  ),
  LlmProviderPreset(
    id: 'groq',
    displayName: 'Groq (推荐 — 含 Whisper)',
    baseUrl: 'https://api.groq.com/openai/v1',
    adapterType: 'openaiCompatible',  // 纯 LLM/ASR，无 TTS
    apiKeyHeader: 'Authorization',
    defaultModels: ['whisper-large-v3-turbo', 'whisper-large-v3', 'llama-3.3-70b-versatile'],
    signupUrl: 'https://console.groq.com/keys',
  ),
  LlmProviderPreset(
    id: 'custom',
    displayName: 'Custom (OpenAI 兼容)',
    baseUrl: '',
    adapterType: 'openaiCompatible',
    apiKeyHeader: 'Authorization',
    defaultModels: [],
    signupUrl: null,
  ),
];
```

UI 流程（`provider_screen` "Add Provider" 弹窗增强）：
1. 用户先选 preset（卡片网格，带 logo）
2. 选 MiMo / OpenAI 等已知服务时只需填 API Key（baseUrl / adapterType / model 自动填好）
3. 选 "Custom" 时回退到当前手填模式

加新服务商时只在 `llmProviderPresets` 数组里加一行，**完全不动 adapter 代码**。

> Phase TTS 段落表和 SubtitleCues 的字段变更见 §3.3，此处不重复。

### 3.4 LLM Adapter 抽象（精简版）

**只做一个 `OpenAiCompatibleLlmAdapter`**。所有兼容服务商（MiMo、OpenAI、DeepSeek、Qwen、Kimi、OpenRouter…）走同一份代码，差异 = `baseUrl` + `apiKey` + `apiKeyHeader` + `modelName`，从 Provider 行直接读取。

新文件 [`lib/data/adapters/llm_adapter.dart`](../lib/data/adapters/llm_adapter.dart)：

```dart
class LlmMessage {
  final String role;        // system | user | assistant
  final dynamic content;    // String | List<ContentPart>（多模态时用 List）
  final List<ToolCall>? toolCalls;
}

class LlmRequest {
  final String model;
  final List<LlmMessage> messages;
  final double? temperature;
  final double? topP;
  final int? maxTokens;
  final bool stream;
  final List<ToolDef>? tools;
  final Map<String, dynamic>? responseFormat;  // JSON schema 强制结构化
}

class LlmResult {
  final String content;
  final String? reasoningContent;   // MiMo / DeepSeek-R1 等思考链
  final List<ToolCall>? toolCalls;
  final TokenUsage usage;
}

abstract class LlmAdapter {
  Future<LlmResult> complete(LlmRequest request);
  Stream<LlmResult> stream(LlmRequest request);
  Future<List<ModelInfo>> getModels();
  Future<bool> healthCheck();
}

/// 工厂：LLM 一律走 OpenAiCompatibleLlmAdapter（99% 场景）。
/// 路由不依赖 provider.adapterType（那是 TTS 的事），直接构造 adapter。
/// Gemini 也走 OpenAI 兼容端点，不需要单独的 GeminiLlmAdapter。
LlmAdapter createLlmAdapter(db.TtsProvider provider, {String? modelName}) {
  return OpenAiCompatibleLlmAdapter(
    baseUrl: provider.baseUrl,
    apiKey: provider.apiKey,
    modelName: modelName ?? provider.defaultModelName,
    apiKeyHeader: provider.apiKeyHeader,  // 从 TtsProviders 表读取
  );
}
```

#### 单一实现：`OpenAiCompatibleLlmAdapter`

```dart
class OpenAiCompatibleLlmAdapter extends LlmAdapter {
  OpenAiCompatibleLlmAdapter({
    required this.baseUrl,
    required this.apiKey,
    required this.modelName,
    this.apiKeyHeader = 'Authorization',  // MiMo 用 'api-key'，其他多用 'Authorization'
  });

  @override
  Future<LlmResult> complete(LlmRequest req) async {
    final body = {
      'model': req.model,
      'messages': req.messages.map(_serializeMsg).toList(),
      if (req.temperature != null) 'temperature': req.temperature,
      if (req.topP != null) 'top_p': req.topP,
      if (req.maxTokens != null) 'max_completion_tokens': req.maxTokens,
      if (req.tools != null) 'tools': req.tools!.map(_serializeTool).toList(),
      if (req.responseFormat != null) 'response_format': req.responseFormat,
      'stream': false,
    };
    final r = await _dio.post('chat/completions', data: body);
    final msg = r.data['choices'][0]['message'];
    return LlmResult(
      content: msg['content'] ?? '',
      reasoningContent: msg['reasoning_content'],
      toolCalls: _parseToolCalls(msg['tool_calls']),
      usage: TokenUsage.fromJson(r.data['usage']),
    );
  }

  // stream() 用 SSE 流式解析 data: {...} 行；遇 [DONE] 收尾
}
```

> 这个 adapter 一份代码同时支持 MiMo / OpenAI / DeepSeek / Qwen / Kimi / GLM / Doubao / OpenRouter / SiliconFlow / 火山方舟 / 任何兼容形态。新增服务商只需在 §3.2 的 preset 数组加一行配置。

#### 仅当需要 Gemini 时的二号实现：`GeminiLlmAdapter`

Gemini 原生用 `generateContent` 协议（不是 OpenAI 形态），但 Google 也提供了 OpenAI 兼容的 endpoint（`/v1beta/openai/chat/completions`）。**首选直接走 OpenAI 兼容端点**，把 Gemini 当成普通 `openaiCompatibleLlm`，preset 里 baseUrl 改成 `https://generativelanguage.googleapis.com/v1beta/openai`。这样能彻底避开 `GeminiLlmAdapter` 这一档，**实际上一档就够**。

> **结论**：LLM 适配器实现量 = 1 个类（`OpenAiCompatibleLlmAdapter`）+ N 个前端 preset。新增服务商零代码。

### 3.5 ASR Adapter 抽象

新文件 [`lib/data/adapters/asr_adapter.dart`](../lib/data/adapters/asr_adapter.dart)：

```dart
class AsrCue {
  final int startMs;
  final int endMs;
  final String text;
  final String? speaker;     // "Speaker 0" / 角色名
  final String? language;    // BCP-47 / ISO-639
  final double? confidence;
}

class AsrRequest {
  final String audioPath;        // 本地路径（adapter 自行决定上传策略）
  final String? language;        // 可选语言提示
  final bool diarize;            // 是否分离说话人
  final bool wordTimestamps;
}

abstract class AsrAdapter {
  Future<List<AsrCue>> transcribe(AsrRequest request);
  Future<bool> healthCheck();
}
```

#### 工厂（按 modelKey 路由，不依赖 Provider.adapterType）

```dart
/// ASR 工厂：根据 modelKey 选择具体实现。
/// 同一个 Provider 行可以同时承载 whisper-large-v3-turbo (走 Whisper API) 和
/// mimo-v2.5 (走多模态兜底)，因为路由由 modelKey 决定，与 Provider.adapterType 无关。
AsrAdapter createAsrAdapter({
  required db.TtsProvider provider,
  required String modelKey,
}) {
  final k = modelKey.toLowerCase();

  // 本地档：Provider 是用 'whisper-local' preset 建的特殊行
  if (provider.adapterType == 'whisperLocal') {
    return WhisperLocalAdapter(modelType: WhisperModel.fromString(modelKey));
  }

  // 走 OpenAI Whisper 兼容端点（Groq / OpenAI / Fireworks / 自部署）
  if (k.contains('whisper') || k.contains('transcribe')) {
    return OpenAiWhisperAdapter(
      baseUrl: provider.baseUrl,
      apiKey: provider.apiKey,
      modelName: modelKey,
    );
  }

  // MiMo 多模态兜底（mimo-v2.5 / mimo-v2-omni）
  if (k.startsWith('mimo-v2')) {
    return MimoAudioUnderstandingAsrAdapter(
      baseUrl: provider.baseUrl,
      apiKey: provider.apiKey,
      modelName: modelKey,
    );
  }

  throw UnimplementedError('No ASR adapter for model: $modelKey');
}
```

ASR 三档实现，覆盖远端 API、本地推理、多模态兜底：

#### 主路径：`OpenAiWhisperAdapter`（OpenAI `audio/transcriptions` 兼容）

`/v1/audio/transcriptions` 已成为事实标准协议，**一份代码同时跑下面所有服务**：

| 服务 | baseUrl | 推荐 model | 备注 |
|---|---|---|---|
| OpenAI 官方 | `https://api.openai.com/v1` | `whisper-1` / `gpt-4o-transcribe` | 计费稳定 |
| **Groq**（最快） | `https://api.groq.com/openai/v1` | `whisper-large-v3-turbo` | 1 小时音频 ~4 秒，免费档量大 |
| Fireworks | `https://api.fireworks.ai/inference/v1` | `whisper-v3` | 服务器端口比 OpenAI 快 20× |
| LocalAI / vllm-whisper / 自部署 whisper.cpp HTTP | 用户自填 | 自定 | 完全离线但需用户起服务 |

**文件大小与格式约束**（必须在 adapter 内处理）：

| 服务 | 单文件上限 | 推荐格式 | `verbose_json` 支持 | `diarized_json` 支持 |
|---|---|---|---|---|
| Groq 免费层 | 25 MB | 16k mono FLAC/WAV | ✅ | ❌（无说话人分离） |
| Groq dev 层 | 100 MB | 同上 | ✅ | ❌ |
| OpenAI | 25 MB | 16k mono WAV/FLAC/MP3 | ✅（whisper-1） | ✅（gpt-4o-transcribe 系列） |
| Fireworks | 25 MB | 16k mono FLAC | ✅ | ❌ |

**实现要求**：
1. 超限时自动用 ffmpeg 按 10 分钟切片，逐片 ASR 后合并，累加时间戳偏移
2. 输入非 16k mono WAV 时自动用 ffmpeg 转码
3. `verbose_json` 优先；不支持时降级为 `json`（无 segments，只有全文）
4. 不支持 diarization 的服务，`AsrCue.speaker` 返回 null

实现：

```dart
class OpenAiWhisperAdapter extends AsrAdapter {
  OpenAiWhisperAdapter({required this.baseUrl, required this.apiKey, required this.modelName});

  static const _maxFileSizeBytes = 25 * 1024 * 1024; // 25 MB

  @override
  Future<List<AsrCue>> transcribe(AsrRequest req) async {
    // 1. 检查文件大小，超限时切片
    final fileSize = await File(req.audioPath).length();
    if (fileSize > _maxFileSizeBytes) {
      return _transcribeInChunks(req);
    }

    // 2. 转码为 16k mono WAV（如果不是）
    final audioPath = await _ensureCorrectFormat(req.audioPath);

    // 3. 上传并转写
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(audioPath),
      'model': modelName,
      'response_format': 'verbose_json',
      if (req.language != null) 'language': req.language,
      if (req.wordTimestamps) 'timestamp_granularities[]': ['word', 'segment'],
    });
    final r = await _dio.post('audio/transcriptions',
        data: form,
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}));
    final segments = r.data['segments'] as List;
    return segments.map((s) => AsrCue(
      startMs: ((s['start'] as num) * 1000).round(),
      endMs:   ((s['end']   as num) * 1000).round(),
      text:    s['text'] as String,
      language: r.data['language'] as String?,
    )).toList();
  }
}
```

#### 服务商 preset 清单（与 LLM 共用 `providerPresets`）

由于 LLM 和 ASR 都是基于 OpenAI 兼容形态，且 capability 已经在 model 层做了区分，**前端 preset 清单可以合并成一份**：[`lib/domain/provider_presets.dart`](../lib/domain/provider_presets.dart)。每条 preset 只描述"账号"信息（baseUrl / apiKey 头格式 / signup URL）+ 一组带 capability tag 的初始模型清单。

```dart
class ProviderPreset {
  final String id;
  final String displayName;
  final String baseUrl;
  final String adapterType;        // TTS 调用走哪个；非 TTS 用户填 'openaiCompatibleLlm' 等占位
  final String apiKeyHeader;       // 'api-key' | 'Authorization'
  final List<PresetModel> models;  // 每个模型自带 capabilities
  final String? signupUrl;
}

class PresetModel {
  final String key;
  final List<String> capabilities;  // ['tts'] | ['llm'] | ['asr'] | ['llm','asr']
}

const providerPresets = [
  // —— 同时承载 TTS + LLM + ASR 的 MiMo ——
  ProviderPreset(
    id: 'mimo',
    displayName: 'Xiaomi MiMo',
    baseUrl: 'https://api.xiaomimimo.com/v1',
    adapterType: 'chatCompletionsTts',  // 决定 TTS 走 MiMo chat-completions 形态
    apiKeyHeader: 'api-key',
    signupUrl: 'https://platform.xiaomimimo.com/#/console/api-keys',
    models: [
      PresetModel(key: 'mimo-v2.5-tts',             capabilities: ['tts']),
      PresetModel(key: 'mimo-v2.5-tts-voiceclone',  capabilities: ['tts']),
      PresetModel(key: 'mimo-v2.5-tts-voicedesign', capabilities: ['tts']),
      PresetModel(key: 'mimo-v2-tts',               capabilities: ['tts']),
      PresetModel(key: 'mimo-v2.5-pro',             capabilities: ['llm']),
      PresetModel(key: 'mimo-v2.5-flash',           capabilities: ['llm']),
      PresetModel(key: 'mimo-v2.5',                 capabilities: ['llm','asr']),
      PresetModel(key: 'mimo-v2-omni',              capabilities: ['llm','asr']),
    ],
  ),
  // —— 纯 LLM ——
  ProviderPreset(id: 'openai',     baseUrl: 'https://api.openai.com/v1', ...),
  ProviderPreset(id: 'deepseek',   baseUrl: 'https://api.deepseek.com/v1', ...),
  ProviderPreset(id: 'qwen',       baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1', ...),
  ProviderPreset(id: 'kimi',       baseUrl: 'https://api.moonshot.cn/v1', ...),
  ProviderPreset(id: 'gemini',     baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai', ...),
  ProviderPreset(id: 'openrouter', baseUrl: 'https://openrouter.ai/api/v1', ...),
  // —— 纯 ASR ——
  ProviderPreset(
    id: 'groq',
    displayName: 'Groq (推荐 — 含 Whisper)',
    baseUrl: 'https://api.groq.com/openai/v1',
    adapterType: 'openaiCompatibleLlm',  // 占位：Groq 不做 TTS
    apiKeyHeader: 'Authorization',
    signupUrl: 'https://console.groq.com/keys',
    models: [
      PresetModel(key: 'whisper-large-v3-turbo', capabilities: ['asr']),
      PresetModel(key: 'whisper-large-v3',       capabilities: ['asr']),
      PresetModel(key: 'llama-3.3-70b-versatile',capabilities: ['llm']),  // 顺手提供
    ],
  ),
  // —— 离线 ASR ——
  ProviderPreset(
    id: 'whisper-local',
    displayName: '本地 Whisper（whisper.cpp / GGML，离线）',
    baseUrl: '',  // 不用
    adapterType: 'whisperLocal',
    apiKeyHeader: '',
    signupUrl: null,
    models: [
      PresetModel(key: 'base',          capabilities: ['asr']),
      PresetModel(key: 'small',         capabilities: ['asr']),
      PresetModel(key: 'medium',        capabilities: ['asr']),
      PresetModel(key: 'largeV3Turbo',  capabilities: ['asr']),
    ],
  ),
  ProviderPreset(id: 'custom', displayName: 'Custom (OpenAI 兼容)', ...),
];
```

UI 流程（"Add Provider" 弹窗）：
1. 用户从卡片网格里选 preset
2. 自动填入 baseUrl / adapterType / apiKeyHeader / 模型清单（每个模型已带 capability chip）
3. 用户只输 API Key 即可使用
4. 选 "Custom" 时仍走当前手填路径

> **首发版本只交付 `OpenAiWhisperAdapter` + preset 清单就够**。本地方案和 MiMo 兜底排到 P3。

#### 备选 1：`WhisperLocalAdapter`（本地推理，离线）

调研结果：Dart 生态有 **3 个 whisper.cpp 包**，唯一同时支持 Windows/Linux/macOS/iOS/Android 的是 [`whisper_ggml_plus`](https://pub.dev/packages/whisper_ggml_plus)（27 天前发布，160 pub points）。

| 包 | 平台 | Pub 点 | 备注 |
|---|---|---|---|
| **`whisper_ggml_plus`** ★ | Win / Linux / macOS / iOS / Android | 160 | **唯一覆盖 Windows 桌面**；fork 自 whisper_ggml；FFI 绑 whisper.cpp；可下载或打包 GGML 权重；支持词级时间戳；可选 `whisper_ggml_plus_ffmpeg` 插件转换 MP3/M4A |
| `whisper_ggml` | Android / iOS / macOS | 150 | **不支持 Windows** —— 对桌面客户端致命 |
| `whisper_flutter_new` | Android / iOS / macOS | 130 | 22 个月没更新；不支持 Windows / Linux |

接入示例（用 `whisper_ggml_plus`）：

```dart
class WhisperLocalAdapter extends AsrAdapter {
  WhisperLocalAdapter({required this.modelType});
  final WhisperModel modelType;
  late final WhisperController _ctrl = WhisperController();

  @override
  Future<List<AsrCue>> transcribe(AsrRequest req) async {
    // 首次会触发 _ctrl.downloadModel(modelType) 从 ggerganov/whisper.cpp 拉权重
    await _ensureModelReady();

    final result = await _ctrl.transcribe(
      model: modelType,
      audioPath: req.audioPath,
      lang: req.language ?? 'auto',
      withTimestamps: true,
      splitOnWord: req.wordTimestamps,
      threads: 6,
      vadMode: WhisperVadMode.auto,
    );
    return result.segments.map((s) => AsrCue(
      startMs: s.startMs,
      endMs: s.endMs,
      text: s.text.trim(),
    )).toList();
  }
}
```

**模型策略**：

- 默认下载到 `<voiceAssetRoot>/.cache/whisper/`（首次推理触发，UI 显示进度）
- 推荐档位：`base`（74 MB）做实时口播 / `small`（244 MB）做日常视频 / `largeV3Turbo`（809 MB 量化版）做高质量配音
- 不要打包进 app 安装包 —— 包体会爆；运行时下载是更合适的方式
- 首次需要 ffmpeg 把视频音轨转 16 kHz mono WAV（Neiroha 已有 `FFmpegService`）

**pubspec.yaml 改动**：

```yaml
dependencies:
  whisper_ggml_plus: ^<latest>
  whisper_ggml_plus_ffmpeg: ^<latest>  # 可选：直接喂 mp4/m4a 不用 ffmpeg 预处理
```

#### 备选 2：`MimoAudioUnderstandingAsrAdapter`（MiMo 多模态兜底）

通过 `mimo-v2.5` 多模态 chat 实现 ASR：
- 把 audio 上传到 Neiroha 内置 storage，得到公网 URL（或转 base64 直传，受 50 MB 限制 / 切片）
- `prompt`：要求 JSON 输出 `[{startMs,endMs,text,speaker,language}]`
- 用 `response_format: { type: "json_schema", ... }` 强制结构化（MiMo Pro 支持）
- 解析 JSON → `AsrCue`

> 局限：精度依赖 prompt，时间戳准确性低于专用 ASR。**适合用户已经买了 MiMo Token Plan、不想再开 Groq 账号时使用。** 不推荐作为默认。

> ~~`MimoLocalAsrAdapter`（自部署 MiMo V2.5 ASR HTTP 服务）~~ — 暂不交付。要求用户搭 8B 模型 + GPU + flash-attn 服务，对桌面客户端用户门槛过高；真有这种用户，他们也可以包装成 OpenAI Whisper 兼容形态接进 `OpenAiWhisperAdapter`。

### 3.6 ChatCompletionsTtsAdapter 的 V2.5 升级

不新增 adapter 类型，**复用 `chatCompletionsTts`**，靠 `modelName` 路由到三种模式。让 `TtsRequest` 多两个字段：

```dart
class TtsRequest {
  // 已有字段...
  final String? voiceClonePromptBase64;   // data:audio/mpeg;base64,...
  final String? audioTagPrefix;           // 拼到 text 前，如 "(磁性)"
}
```

**VoiceClone 数据流**（从本地文件到 API 请求）：

1. `VoiceAsset.refAudioPath` 存的是本地 mp3/wav 文件路径
2. 调用前需要：读取文件 → base64 编码 → 拼成 `data:audio/mpeg;base64,{data}` 格式
3. **格式校验**：仅支持 mp3 / wav；其他格式需先用 ffmpeg 转换
4. **大小校验**：base64 后不超过 10 MB（MiMo 平台限制）；超限时截取前 N 秒或压缩
5. 拼好的 data URL 填入 `TtsRequest.voiceClonePromptBase64`

```dart
// 在 VoiceAsset → TtsRequest 转换处
Future<String?> _encodeRefAudio(String? refAudioPath) async {
  if (refAudioPath == null || refAudioPath.isEmpty) return null;
  final file = File(refAudioPath);
  if (!await file.exists()) return null;

  final ext = p.extension(refAudioPath).toLowerCase();
  final bytes = await file.readAsBytes();

  // 大小校验（base64 膨胀 ~33%，所以原始文件限制 ~7.5 MB）
  if (bytes.length > 7.5 * 1024 * 1024) {
    throw Exception('Reference audio too large for VoiceClone (> 7.5 MB)');
  }

  final mime = ext == '.mp3' ? 'audio/mpeg' : 'audio/wav';
  return 'data:$mime;base64,${base64Encode(bytes)}';
}
```

`ChatCompletionsTtsAdapter.synthesize()` 改造（伪代码）：

```dart
final isVoiceDesign  = modelName.contains('voicedesign');
final isVoiceClone   = modelName.contains('voiceclone');

final assistantText = (request.audioTagPrefix?.isNotEmpty == true
    ? '${request.audioTagPrefix}${request.text}'
    : request.text);

final messages = [
  if (request.voiceInstruction != null && request.voiceInstruction!.isNotEmpty)
    {'role': 'user', 'content': request.voiceInstruction},
  // VoiceDesign 强制要求 user message 非空
  if (isVoiceDesign && (request.voiceInstruction ?? '').isEmpty)
    {'role': 'user', 'content': 'Generate a natural voice.'},
  if (isVoiceClone)  // VoiceClone 通常 user message 留空
    {'role': 'user', 'content': ''},
  {'role': 'assistant', 'content': assistantText},
];

final audioField = <String, dynamic>{
  'format': request.responseFormat ?? 'wav',
};
if (isVoiceClone && request.voiceClonePromptBase64 != null) {
  audioField['voice'] = request.voiceClonePromptBase64;  // data URL
} else if (!isVoiceDesign) {
  audioField['voice'] = request.presetVoiceName ?? 'mimo_default';
}
```

`AdapterType.chatCompletionsTts.supportsVoiceQuery` 已为 true；前端把内置音色清单（§1.3）当作"已知 voices"返回即可（MiMo 没有 `/speakers` 端点，先 hardcode）。

### 3.7 Provider Riverpod 暴露

新增 [`lib/providers/llm_providers.dart`](../lib/providers/llm_providers.dart) 与 [`lib/providers/asr_providers.dart`](../lib/providers/asr_providers.dart)。Riverpod 聚合所有 enabled provider 的 modelBindings，按 capability 过滤模型，再 join 回 Provider 行拿到 baseUrl/apiKey 来构造 adapter：

```dart
// 通用：按 capability 过滤可用的 (provider, modelBinding) 对
typedef AvailableModel = ({TtsProvider provider, ModelBinding binding});

final availableModelsByCapabilityProvider =
    StreamProvider.family<List<AvailableModel>, String>((ref, capability) {
  final db = ref.watch(databaseProvider);
  return db.watchAvailableModelsByCapability(capability);
});

// llm_providers.dart
final llmAvailableModelsProvider =
    Provider<List<AvailableModel>>((ref) {
  return ref.watch(availableModelsByCapabilityProvider('llm')).valueOrNull ?? [];
});

final defaultLlmAdapterProvider = Provider<LlmAdapter?>((ref) {
  final all = ref.watch(llmAvailableModelsProvider);
  if (all.isEmpty) return null;
  final pick = all.first;  // 或者从 settings 读用户选的默认
  return OpenAiCompatibleLlmAdapter(
    baseUrl: pick.provider.baseUrl,
    apiKey: pick.provider.apiKey,
    modelName: pick.binding.modelKey,
    apiKeyHeader: _resolveAuthHeader(pick.provider),
  );
});

// asr_providers.dart  ← 同构，但 adapter 路由根据 modelKey 决定
final defaultAsrAdapterProvider = Provider<AsrAdapter?>((ref) {
  final all = ref.watch(availableModelsByCapabilityProvider('asr')).valueOrNull ?? [];
  if (all.isEmpty) return null;
  final pick = all.first;
  final modelKey = pick.binding.modelKey.toLowerCase();
  // 按模型名路由 — adapter 类与 provider.adapterType 解耦
  if (modelKey.contains('whisper') || modelKey.contains('transcribe')) {
    return OpenAiWhisperAdapter(
      baseUrl: pick.provider.baseUrl,
      apiKey: pick.provider.apiKey,
      modelName: pick.binding.modelKey,
    );
  }
  if (modelKey.startsWith('mimo-v2')) {
    return MimoAudioUnderstandingAsrAdapter(
      baseUrl: pick.provider.baseUrl,
      apiKey: pick.provider.apiKey,
      modelName: pick.binding.modelKey,
    );
  }
  // 本地档（用户在 UI 选 "Whisper Local" preset 时存的特殊 modelKey）
  if (pick.provider.adapterType == 'whisperLocal') {
    return WhisperLocalAdapter(modelType: WhisperModel.fromString(modelKey));
  }
  return null;
});
```

**DAO 端的核心查询**（`lib/data/database/queries/providers.dart` 增补）：

```dart
Stream<List<AvailableModel>> watchAvailableModelsByCapability(String cap) {
  // capabilities 存储格式：',tts,' 或 ',tts,llm,' 或 ',llm,asr,'
  // 前后都带逗号，查询时用 ',cap,' 匹配，避免 'asr' 误匹配 'basr' 等
  final paddedCap = ',$cap,';
  return (select(modelBindings).join([
    innerJoin(ttsProviders, ttsProviders.id.equalsExp(modelBindings.providerId))
  ])
    ..where(ttsProviders.enabled.equals(true) &
            modelBindings.capabilities.like('%$paddedCap%')))
    .watch()
    .map((rows) => rows.map((r) => (
      provider: r.readTable(ttsProviders),
      binding: r.readTable(modelBindings),
    )).toList());
}
```

#### Provider 编辑器 UI 改动（最小侵入）

参考截图，现有 Provider 编辑面板已经有 Models 列表 + 每行的 modelKey + 删除按钮 + Fetch All / Add 按钮。**只需要给每行加一个 capability chip 区域**：

```
┌─────────────────────────────────────────────────────┐
│  🎤 mimo-v2.5-tts            [tts]              ✕   │
│  🎤 mimo-v2.5-tts-voiceclone [tts]              ✕   │
│  🎤 mimo-v2.5-tts-voicedesign[tts]              ✕   │
│  💬 mimo-v2.5-pro            [llm]              ✕   │
│  🎬 mimo-v2.5                [llm] [asr]        ✕   │
│  🎬 mimo-v2-omni             [llm] [asr]        ✕   │
└─────────────────────────────────────────────────────┘
```

- **Chip 颜色**：`tts` 紫 / `llm` 蓝 / `asr` 绿（语义色，跟 sidebar 的 tab 配色一致）
- **点击 chip**：弹出多选 popover，勾选 capability
- **加新 model**："Add" 按钮弹窗：modelKey 输入 + capability 多选 + 确定。modelKey 输完后，焦点离开时自动用 `inferCapabilities()` 预填默认值
- **Fetch All**：拉到的每个 modelKey 走 `inferCapabilities()` 自动打 chip，用户可后期调整

> 现有 `Provider.adapterType` 字段（OpenAI Chat Completions TTS / GPT-SoVITS / ...）含义不变，**只决定 TTS 调用走哪个 adapter**。LLM 和 ASR 由 capability + modelKey 路由，跟 adapterType 无关。
> 这意味着用户老的 MiMo Provider 行不需要任何改动 —— 只要 fetch 一次让 capability 自动归位，新功能就能用。

---

## 第四部分：业务流水线设计

### 4.1 段落 TTS：自动打标 + 分角色映射

#### 4.1.1 用户流程

1. 用户在 Phase TTS 编辑器粘贴整段剧本 / 小说
2. 点击 **「Auto-Annotate」** 按钮（替代或补充现有 `_autoSplit`）
3. UI 显示 LLM 分析进度
4. 完成后段落列表展示：每段带 **角色名 chip + 风格 tag chip + voice 绑定下拉**
5. 用户审阅/修改 → 点 Generate All

#### 4.1.2 ScriptAnalysisService

```dart
class AnalyzedSegment {
  final String text;
  final String speaker;          // "旁白" | "甲" | "李雷" ...
  final String? audioTagPrefix;  // "(沉思)" | "(兴奋|颤抖)"
  final String? styleNotes;      // 自由文本，灌入 user message
  final String? voiceMatchHint;  // "中年男性低沉" 用于自动绑定
}

class ScriptAnalysisService {
  ScriptAnalysisService(this._llm);
  final LlmAdapter _llm;

  Future<List<AnalyzedSegment>> analyze(String script) async {
    final result = await _llm.complete(LlmRequest(
      model: 'mimo-v2.5-pro',  // 1M context, 最适合长文本
      messages: [
        LlmMessage(role: 'system', content: _systemPrompt),
        LlmMessage(role: 'user', content: script),
      ],
      responseFormat: _jsonSchema,  // 强制结构化输出
      temperature: 0.3,
    ));
    return _parseJson(result.content);
  }
}
```

`_systemPrompt`（关键 — 决定标注质量）：

```
你是一名剧本/小说的语音化分析师。给定一段中文文本，按以下规则切分并标注：

1. 切分粒度：以"对话/独白/旁白"为单位，每段不超过 200 字。
2. 角色识别：
   - 直接引语用引号定语之外的提示词推断（"他低声说"→ 上一个登场的男性角色）
   - 旁白统一标 "narrator"
   - 角色名沿用全文最显著的一种写法
3. 音频标签：从 [基础情绪/复杂情绪/语气/咳叹/呼吸] 选 0-3 个，
   格式 (标签1|标签2)，附在文本最前面。例：(沉思|轻声) ……
4. 风格备注：仅在场景剧烈变化时填，1 句话以内。
5. voiceMatchHint：1 句话描述合适音色，如 "中年男性，沙哑磁性"。

输出严格 JSON：
[{ "text": "...", "speaker": "...", "audioTagPrefix": "(...)|null",
   "styleNotes": "..."|null, "voiceMatchHint": "..." }]
```

#### 4.1.3 自动 Voice Mapping

第二次 LLM 调用（或同一次输出）将 **不同 speaker → bank 中已有 voice asset** 做匹配：
- 准备 `bankAssets` 的 (name, description) 列表
- LLM 拿到 [speakers] + [bankVoices] → 输出 `{speaker → voiceAssetId}` 映射
- 没有匹配的 speaker 标 `null`，UI 上提示用户手动绑定或用 VoiceDesign 现场生成

#### 4.1.4 写回数据库

新增 `db.batchUpsertPhaseTtsSegments(...)`：
- 清空现有 segments
- 按 LLM 输出批量插入，填 `segmentText / speakerLabel / audioTagPrefix / styleNotes / voiceAssetId`

#### 4.1.5 合成阶段拼装

`_generateOne` 现有逻辑增强：

```dart
final asset = bankAssets.firstWhere((a) => a.id == seg.voiceAssetId);
final req = TtsRequest(
  text: seg.segmentText,
  voice: asset.presetVoiceName ?? asset.name,
  speed: asset.speed,
  responseFormat: 'wav',
  audioTagPrefix: seg.audioTagPrefix,         // ← 新
  voiceInstruction: [asset.voiceInstruction, seg.styleNotes]
      .whereType<String>().where((s) => s.isNotEmpty).join('\n'),  // ← 合并
  presetVoiceName: asset.presetVoiceName,
  voiceClonePromptBase64: _maybeBase64(asset.refAudioPath),  // ← VoiceClone
);
```

### 4.2 视频 TTS：ASR → 翻译 → 洗稿 流水线

#### 4.2.1 用户流程

```
[导入视频] → [Extract Audio] → [ASR 转写] → [审阅原文]
                                              ↓
                         [选目标语言] → [LLM 翻译] → [审阅译文]
                                              ↓
                         [LLM 洗稿适配 TTS] → [审阅最终稿]
                                              ↓
                                          [批量 TTS]
                                              ↓
                                     [导出带字幕视频]
```

每步都可单独触发/重跑/编辑，不强制连贯执行。

#### 4.2.2 Step 1 — 抽音轨（已有 FFmpegService）

新增 [`FFmpegService.extractAudio(videoPath, targetSampleRate=24000)`](../lib/data/storage/ffmpeg_service.dart) 方法：
```bash
ffmpeg -i {video} -vn -ac 1 -ar 24000 -f wav {output}
```

#### 4.2.3 Step 2 — ASR 转写

```dart
class AsrService {
  AsrService(this._adapter, this._db, this._ffmpeg);

  Future<List<db.SubtitleCue>> transcribeVideo(db.VideoDubProject project) async {
    final audioPath = await _ffmpeg.extractAudio(project.videoPath!);
    final cues = await _adapter.transcribe(AsrRequest(
      audioPath: audioPath,
      diarize: true,
      wordTimestamps: false,
    ));
    // 写回 SubtitleCues：originalText = cue.text, cueText = cue.text（初值）
    await _db.batchInsertCues(project.id, cues);
    return _db.getSubtitleCues(project.id);
  }
}
```

UI 在 `video_dub_screen` 增加 **「Extract from Video」** 按钮（与现有 `_importSubtitles` 并列），背后跑 `transcribeVideo`。

#### 4.2.4 Step 3 — LLM 翻译

```dart
Future<void> translateAll(
  String projectId,
  String srcLang,   // 'auto' | 'zh' | 'en' ...
  String tgtLang,
) async {
  final cues = await _db.getSubtitleCues(projectId);
  // 关键：批量 + 上下文 — 单条翻译会丢失代词指向
  final batches = _chunkByContextWindow(cues, maxTokens: 8000);
  for (final batch in batches) {
    final result = await _llm.complete(LlmRequest(
      model: 'mimo-v2.5-pro',
      messages: [
        LlmMessage(role: 'system', content: _translationPrompt(srcLang, tgtLang)),
        LlmMessage(role: 'user', content: jsonEncode(batch.map((c) => {
          'id': c.id, 'text': c.originalText ?? c.cueText,
        }).toList())),
      ],
      responseFormat: _translationSchema,
      temperature: 0.3,
    ));
    final translations = _parseJson(result.content);
    for (final t in translations) {
      await _db.updateSubtitleCue(translatedText: t.text, sourceLang: srcLang);
    }
  }
}
```

`_translationPrompt`：

```
你是字幕翻译师。任务：把 ${src} 字幕翻译成 ${tgt}。
规则：
- 保留专有名词；语气符合口语化字幕
- 不解释、不增删意思
- 输入 JSON [{id,text}]，输出严格匹配的 JSON [{id,text}]
- text 是译文。
```

#### 4.2.5 Step 4 — 洗稿（适配 TTS）

翻译后的字幕直接合成往往不顺：
- 长度可能不匹配原视频段落（口播节奏不同）
- 缺少自然停顿/语气词
- 含书面化表达（"在某种程度上"）不适合朗读

洗稿调用：

```
你是 TTS 改稿编辑。输入是翻译好的字幕段，每段附带原视频时长（毫秒）。
目标：把每段改写为「**适合 TTS 朗读** + **时长不超过原段** + **保留语义**」的版本。
- 加适度的停顿、语气词（嗯/啊）让节奏自然
- 删减冗余措辞控制时长（按平均语速 4 字/秒估算）
- 可选：在段落最前加 audio tag (兴奋|疲惫) 等，与上下文情绪一致
输出：[{id, text, audioTagPrefix}]
```

`SubtitleCues.cueText` 字段最终值 = 洗稿结果（`audioTagPrefix` 拼接后）；
`originalText` / `translatedText` 留作可回退的中间版本。

#### 4.2.6 Step 5 — 批量 TTS（复用现有 `_runGenerateAll`）

无需改动逻辑，因为 `cueText` 已经是 final 文本。

### 4.3 用户体验：流水线节点全部"半自动"

每个流水线节点都给一个 **审阅 / 重跑 / 跳过** 三选项：
- 流水线启动时弹一个 stepper 对话框，用户勾选要运行的步骤
- 每步完成后弹"审阅"列表（带 diff 视图，左原文右改写）
- 节点失败不阻塞下一节点（`originalText` / `translatedText` 任一为 null 时降级）

---

## 第五部分：实施 Roadmap（建议顺序）

| 阶段 | 工作 | 预计代码量 | 依赖 |
|---|---|---|---|
| **P0** | DB schema v16（`TtsProviders.apiKeyHeader` + `ModelBindings.capabilities` + Phase/Subtitle 业务字段 + 替换 drop-all 迁移） | ~150 行 + 迁移 | drift codegen |
| **P0** | `ChatCompletionsTtsAdapter` 升级支持 V2.5 三模式 + 内置 voice 列表 | ~80 行 | 无 |
| **P0** | Provider 编辑器 Models 列表加 capability chip + popover 多选编辑 + Fetch All 时 `inferCapabilities()` 自动打 chip | ~150 行 | P0 schema |
| **P0** | "Add Provider" 弹窗加 preset 卡片网格 + `providerPresets` 清单（合并 LLM/ASR/TTS） | ~200 行 | P0 |
| **P1** | `LlmAdapter` 抽象 + 单一 `OpenAiCompatibleLlmAdapter` 实现 + Riverpod 暴露（按 capability 跨 provider 聚合） | ~300 行 | P0 |
| **P1** | `AsrAdapter` 抽象 + 主路径 `OpenAiWhisperAdapter` + `createAsrAdapter` 按 modelKey 路由 + Riverpod 暴露 | ~250 行 | P0 |
| **P2** | `ScriptAnalysisService` + Phase TTS Auto-Annotate UI | ~500 行 | P1 LLM |
| **P2** | `AsrService` + `FFmpegService.extractAudio` + Video Dub "Extract from Video" 按钮 | ~400 行 | P1 ASR |
| **P3** | `TranslationService` + Video Dub 翻译/洗稿 stepper UI | ~600 行 | P1 LLM, P2 ASR |
| **P3** | `WhisperLocalAdapter`（基于 `whisper_ggml_plus`，覆盖离线场景） + 模型下载 UI | ~350 行 | P1 ASR |
| **P3** | `MimoAudioUnderstandingAsrAdapter`（多模态兜底，给已有 MiMo Token Plan 用户用） | ~150 行 | P1 ASR |
| **P4** | Voice Auto-Mapping（speaker → bank asset） | ~200 行 | P2 |
| **P4** | 流水线 stepper 对话框、diff 审阅视图、错误降级 | ~400 行 | P2/P3 |

**最小可用集合（MVP）= P0 + P1**：
- 用户能用上 MiMo V2.5 TTS 三件套
- 用户能配置任意 OpenAI 兼容 LLM 服务
- 用户能用 Groq Whisper（免费档量大）做 ASR 转写

P2/P3 各自独立，可并行开发。

---

## 第六部分：风险与决策点

### 6.1 ASR 路径选择（决策已落地）

| 选项 | 优点 | 缺点 | 角色 |
|---|---|---|---|
| **Groq Whisper** ★ | OpenAI 协议、免费档量大、超快（1h 音频 ≈ 4s）；中英文准；时间戳原生 | 中文方言一般；不分说话人 | **MVP 默认推荐** |
| **OpenAI / Fireworks Whisper** | 同上，更稳定 | 计费 | 同协议 preset，一行加 |
| **本地 `whisper_ggml_plus`** | 完全离线 / 隐私 / 无配额 | 首次下载 74 MB ~ 1.5 GB；Win/Mac/Linux 上需 ffmpeg | **P3 离线场景** |
| **MiMo Audio Understanding** | 已有 MiMo 账号可复用 | 时间戳依赖 prompt；50 MB 上限；不便宜 | **P3 兜底，给已经买了 MiMo 的用户** |
| ~~自部署 MiMo-V2.5-ASR~~ | 高精度方言/分轨 | 需 GPU + flash-attn | **不交付**；如要用，让用户包装成 OpenAI Whisper 兼容形态 |

**结论**：MVP 只交付 `OpenAiWhisperAdapter`（一份代码覆盖 Groq/OpenAI/Fireworks/任意自部署 Whisper 兼容服务）；后续 P3 加本地 + MiMo 多模态兜底。

### 6.2 本地 Whisper 落地细节

`whisper_ggml_plus` 是 Dart 生态唯一同时支持 Win/macOS/Linux/iOS/Android 的 whisper.cpp FFI 包。决策点：

| 问题 | 选择 |
|---|---|
| 模型权重打包 vs 运行时下载 | **运行时下载**。即使 base 模型也有 74 MB；large-v3-turbo 量化后还有 800+ MB。打进 app 安装包不可接受 |
| 默认下载到哪 | `<voiceAssetRoot>/.cache/whisper/<modelName>.bin`，用户切换 voice asset root 时一并迁移 |
| ffmpeg 依赖 | Neiroha 已要求用户自带 ffmpeg。**复用现有 `FFmpegService`** 把视频/任意音频转 16 kHz mono WAV 再送给 whisper |
| 多平台 ffmpeg | 也可以装 `whisper_ggml_plus_ffmpeg` 副包内置一份 ffmpeg 给 whisper 自己用，但会让安装包变大；当前 ffmpeg 复用现有方案就够 |
| 模型档位 UI | Provider 编辑器里给一个下拉：tiny / base / small / medium / large-v3 / large-v3-turbo（带磁盘占用提示） |
| 首次推理 UX | 模型不在本地时弹下载对话框，显示进度条 + 大小 + 速度，用户可取消 |
| GPU 加速 | `whisper_ggml_plus` 在 macOS 走 Metal、Win/Linux 走 CPU（CUDA 编译需自己 build whisper.cpp）。CPU 推理 base 模型 ~5× 实时速度，对 desktop 用户够用 |

> **关键提醒**：把 ASR 做成 capability 后，「本地 whisper」就是 Provider 列表里普普通通的一行，**不需要额外 UI 模式**。用户体验和"我配了一个 Groq ASR provider"完全一致 —— 这是这次重构最大的红利。

### 6.3 Schema 变更：capability 加在 ModelBinding 而不是 Provider

经过迭代后的决策（最终方案）：

| 方案 | 评价 |
|---|---|
| ~~Provider 行加 `capability` 单值字段，让用户配 3 条 MiMo~~ | ❌ 用户体验差（粘 3 次 Key） |
| ~~Provider 行加 `capability` 多值字段~~ | ❌ UI 复杂；与 `adapterType` 语义冲突 |
| ~~分 `LlmProviders` / `AsrProviders` 三张表~~ | ❌ 三倍 schema / 查询 / UI 工作量 |
| **ModelBinding 加 `capabilities` 多值字段** ⭐ | ✅ 一个 Provider 行管所有；现有 UI 只增量加 chip；老数据零迁移成本 |

最终方案的关键属性：
- `TtsProviders` 表的 `adapterType` 字段语义完全不变 —— 老用户的 MiMo / OpenAI / Azure provider 行原样工作
- `TtsProviders` 新增 `apiKeyHeader` 字段（默认 `'Authorization'`），MiMo 用户需手动改为 `'api-key'`
- `ModelBindings` 新增 `capabilities` 字段（默认 `',tts,'`），使用边界逗号格式避免子串误匹配
- 老用户升级到 schema v16 后，所有现有 modelBinding 自动得到 `capabilities = ',tts,'`，TTS 行为零变化
- 老用户想用新 LLM/ASR 功能，只需要去 Provider 编辑器点 "Fetch All" 重新拉一次模型列表（`inferCapabilities()` 自动打 chip）—— 或者手动给现有行加 chip

### 6.4 LLM 输出可靠性

LLM 自动打标会犯错（误判说话人、生成奇怪 audio tag）。**所有 LLM 节点都必须可手动 override**：
- DB 永远存原文 + 标注两份
- UI 上"撤销 LLM 标注"按钮一键清空 `speakerLabel/audioTagPrefix/styleNotes`
- `responseFormat: json_schema` 强约束，挡掉 80% 的解析失败

### 6.5 计费与限流

Pro 模型 $1/1M 输入 + $3/1M 输出，长视频（30 分钟，约 11k tokens 音频 + 翻译 + 洗稿三轮）单次约 $0.1 量级。但 RPM=100 在批量场景容易触顶 — `LlmAdapter` 内置令牌桶 + 指数退避 / 指数重试。

---

## 附录 A：关键链接

- 平台文档全文：[docs/research/mimo-llms-full.txt](research/mimo-llms-full.txt)
- 平台主页：https://platform.xiaomimimo.com
- TTS V2.5 文档：https://platform.xiaomimimo.com/docs/zh-CN/usage-guide/speech-synthesis-v2.5
- Audio Understanding：https://platform.xiaomimimo.com/docs/zh-CN/usage-guide/multimodal-understanding/audio-understanding
- OpenAI 兼容 API：https://platform.xiaomimimo.com/docs/zh-CN/api/chat/openai-api
- Anthropic 兼容 API：https://platform.xiaomimimo.com/docs/zh-CN/api/chat/anthropic-api
- ASR 开源仓库：https://github.com/XiaomiMiMo/MiMo-V2.5-ASR
- ASR HF 权重：https://huggingface.co/XiaomiMiMo/MiMo-V2.5-ASR
- ASR 在线 Demo：https://mimo.xiaomi.com/mimo-v2-5-asr
- TTS Skills（官方 Agent 工具）：https://github.com/XiaomiMiMo/MiMo-Skills
- 现有 Adapter 文档：[add-llm-tts-adapter.md](add-llm-tts-adapter.md)
- **OpenAI Whisper API 兼容生态**
  - OpenAI `audio/transcriptions`：https://platform.openai.com/docs/api-reference/audio/createTranscription
  - Groq Whisper：https://console.groq.com/docs/speech-to-text
  - Fireworks audio：https://fireworks.ai/blog/audio-transcription-launch
- **Dart 生态本地 Whisper 包**
  - `whisper_ggml_plus`（推荐，跨平台含 Windows）：https://pub.dev/packages/whisper_ggml_plus
  - `whisper_ggml`（不支持 Windows）：https://pub.dev/packages/whisper_ggml
  - `whisper_flutter_new`（不支持 Windows / Linux）：https://pub.dev/packages/whisper_flutter_new
  - 上游 whisper.cpp + GGML 权重：https://github.com/ggerganov/whisper.cpp

## 附录 B：可直接复用的 dart-side 改动清单

代码骨架，可作为 P0 / P1 第一个 PR 的起点：

```dart
// lib/data/database/tables.dart  ← MODIFY
//   TtsProviders 加 apiKeyHeader 字段
//   ModelBindings 加 capabilities 字段（',tts,' | ',llm,' | ',asr,' 逗号分隔，前后带逗号）
class TtsProviders extends Table {
  // 已有字段...
  TextColumn get apiKeyHeader => text().withDefault(const Constant('Authorization'))();
}
class ModelBindings extends Table {
  // 已有：providerId / modelKey / supportedTaskModes
  TextColumn get capabilities => text().withDefault(const Constant(',tts,'))();
}

// lib/data/adapters/tts_adapter.dart  ← MODIFY
class TtsRequest {
  // ... existing
  final String? voiceClonePromptBase64;
  final String? audioTagPrefix;
}

// lib/data/adapters/chat_completions_tts_adapter.dart  ← MODIFY
//   合成时按 modelName 分发到 preset / voicedesign / voiceclone 三种 payload

// lib/data/adapters/llm_adapter.dart  ← NEW
abstract class LlmAdapter { ... }
class LlmMessage { ... }
class LlmRequest { ... }
class LlmResult { ... }

// lib/data/adapters/openai_compatible_llm_adapter.dart  ← NEW
//   一份代码同时跑 MiMo / OpenAI / DeepSeek / Qwen / Kimi / OpenRouter / Gemini-OpenAI 兼容端点
class OpenAiCompatibleLlmAdapter extends LlmAdapter { ... }

// lib/data/adapters/asr_adapter.dart  ← NEW
abstract class AsrAdapter { ... }
class AsrCue { ... }
class AsrRequest { ... }

// 工厂按 modelKey 路由（不依赖 provider.adapterType）
AsrAdapter createAsrAdapter({
  required db.TtsProvider provider,
  required String modelKey,
}) { ... }

// lib/data/adapters/openai_whisper_adapter.dart  ← NEW (P1 主路径)
//   /v1/audio/transcriptions 兼容；同时跑 OpenAI / Groq / Fireworks / 自部署
class OpenAiWhisperAdapter extends AsrAdapter { ... }

// lib/data/adapters/whisper_local_adapter.dart  ← NEW (P3，离线场景)
//   依赖 pubspec.yaml 中的 whisper_ggml_plus
class WhisperLocalAdapter extends AsrAdapter { ... }

// lib/data/adapters/mimo_audio_understanding_asr.dart  ← NEW (P3，兜底)
class MimoAudioUnderstandingAsrAdapter extends AsrAdapter { ... }

// lib/domain/provider_presets.dart  ← NEW
//   合并 LLM/ASR/TTS preset；每条 preset 自带带 capability 的初始模型清单
class ProviderPreset {
  final String id, displayName, baseUrl, adapterType, apiKeyHeader;
  final List<PresetModel> models;
  final String? signupUrl;
}
class PresetModel {
  final String key;
  final List<String> capabilities;  // ['tts'] | ['llm'] | ['asr'] | ['llm','asr']
}
const providerPresets = [
  ProviderPreset(id: 'mimo', adapterType: 'chatCompletionsTts', models: [
    PresetModel(key: 'mimo-v2.5-tts',             capabilities: ['tts']),
    PresetModel(key: 'mimo-v2.5-tts-voiceclone',  capabilities: ['tts']),
    PresetModel(key: 'mimo-v2.5-tts-voicedesign', capabilities: ['tts']),
    PresetModel(key: 'mimo-v2.5-pro',             capabilities: ['llm']),
    PresetModel(key: 'mimo-v2.5',                 capabilities: ['llm','asr']),
    // ... 见 §3.5
  ]),
  ProviderPreset(id: 'openai',     adapterType: 'openaiCompatibleLlm', models: [...]),
  ProviderPreset(id: 'groq',       adapterType: 'openaiCompatibleLlm', models: [
    PresetModel(key: 'whisper-large-v3-turbo', capabilities: ['asr']),
    PresetModel(key: 'llama-3.3-70b-versatile',capabilities: ['llm']),
  ]),
  ProviderPreset(id: 'whisper-local', adapterType: 'whisperLocal', models: [
    PresetModel(key: 'base',         capabilities: ['asr']),
    PresetModel(key: 'largeV3Turbo', capabilities: ['asr']),
  ]),
  // ... 见 §3.5
];

// lib/domain/capability_inference.dart  ← NEW
//   Fetch All 时按 modelKey 自动推断 capability 初值
List<String> inferCapabilities(String modelKey) { ... }

// lib/data/services/script_analysis_service.dart  ← NEW
class ScriptAnalysisService { ... }

// lib/data/services/translation_service.dart  ← NEW
class TranslationService { ... }

// lib/data/services/asr_service.dart  ← NEW
class AsrService { ... }

// lib/data/database/queries/providers.dart  ← MODIFY
//   新增按 capability 跨 provider 聚合查询
extension AvailableModelsQueries on AppDatabase {
  Stream<List<AvailableModel>> watchAvailableModelsByCapability(String cap) { ... }
}

// lib/providers/llm_providers.dart  ← NEW
final llmAvailableModelsProvider = Provider<List<AvailableModel>>((ref) =>
    ref.watch(availableModelsByCapabilityProvider('llm')).valueOrNull ?? []);
final defaultLlmAdapterProvider = Provider<LlmAdapter?>((ref) { ... });

// lib/providers/asr_providers.dart  ← NEW
final asrAvailableModelsProvider = Provider<List<AvailableModel>>((ref) =>
    ref.watch(availableModelsByCapabilityProvider('asr')).valueOrNull ?? []);
final defaultAsrAdapterProvider = Provider<AsrAdapter?>((ref) { ... });
```

数据库迁移（**必须替换掉当前 drop-all 开发迁移**）：

```dart
// lib/data/database/app_database.dart
@override
int get schemaVersion => 16;  // ← 从 15 bump 到 16

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) async {
    await m.createAll();
    await _seedDefaults();
  },
  onUpgrade: (m, from, to) async {
    if (from < 16) {
      // ★ TtsProviders 加 apiKeyHeader
      await m.addColumn(ttsProviders, ttsProviders.apiKeyHeader);
      // ★ capabilities 加在 ModelBindings 上
      await m.addColumn(modelBindings, modelBindings.capabilities);
      // 业务字段
      await m.addColumn(phaseTtsSegments, phaseTtsSegments.speakerLabel);
      await m.addColumn(phaseTtsSegments, phaseTtsSegments.audioTagPrefix);
      await m.addColumn(phaseTtsSegments, phaseTtsSegments.styleNotes);
      await m.addColumn(subtitleCues, subtitleCues.sourceLang);
      await m.addColumn(subtitleCues, subtitleCues.originalText);
      await m.addColumn(subtitleCues, subtitleCues.translatedText);
    }
  },
);
```

> 老用户的所有现有 modelBinding 会自动得到默认值 `',tts,'`，TTS 行为零变化。
> 老用户的所有现有 ttsProvider 会自动得到 `apiKeyHeader = 'Authorization'`，
> MiMo 用户需手动改为 `'api-key'`。
> 新功能需要时提示用户去 Provider 编辑器点 Fetch All 让 capability 自动归位，或手动给现有行加 chip。
