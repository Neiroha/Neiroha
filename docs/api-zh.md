# Neiroha — 音频 API 参考文档

## 概述

Neiroha 在两个层面上暴露音频 API：

1. **本地 API 服务器** (`lib/server/api_server.dart`) — 一个与 OpenAI 兼容的 HTTP 服务器，通过配置的声音角色代理 TTS 请求，并以活跃音色库（Voice Bank）为作用域
2. **上游适配器层** (`lib/data/adapters/`) — 与外部 TTS 后端通信的客户端适配器

---

## 1. 本地 API 服务器（Shelf）

内置服务器默认运行在 `127.0.0.1:8976`，可从 **设置 → API Server**
开关。只有在明确需要局域网访问时，才将绑定地址改为 `0.0.0.0`。

### 安全与运行配置

设置页会将本地 API 配置持久化到 `AppSettings`：

| 设置 | 默认值 | 说明 |
|---|---|---|
| 绑定地址 | `127.0.0.1` | 默认仅本机回环访问 |
| 端口 | `8976` | 修改后需要重启服务器 |
| API Key | 空 | 设置后请求需发送 `Authorization: Bearer <key>` 或 `X-API-Key: <key>` |
| CORS origins | 空 | 空值拒绝浏览器跨域访问；`*` 允许任意 origin |
| 限流 | `60` req/min/IP | `0` 表示禁用 |
| 最大请求体 | `1048576` 字节 | `0` 表示不检查声明的 Content-Length |
| API 日志输出 | 关闭 | 仅记录元数据；不会记录请求体和认证头 |

所有合成请求都会进入共享的 `TtsQueueService`，因此 Provider 并发数和
限流规则同时作用于桌面端界面和外部 API 客户端。

### 音色库作为模型

API 以**音色库（Voice Bank）**作为 `model` 的抽象层：
- 激活的音色库记录会在 `/v1/models` 中作为模型出现
- 音色库名称用作 API 请求中的 `model` 值
- `/v1/audio/voices` 和 `/speakers` 列出的声音均限定在激活的音色库范围内

### 已实现的端点

| 方法 | 路径 | 说明 | 状态 |
|---|---|---|---|
| `POST` | `/v1/audio/speech` | 将文本合成为语音 | **已实现** |
| `GET` | `/v1/audio/voices` | 列出激活音色库中的声音（OpenAI 格式） | **已实现** |
| `GET` | `/v1/models` | 将激活的音色库列为模型 | **已实现** |
| `GET` | `/speakers` | 列出激活音色库中的声音（SillyTavern 格式） | **已实现** |
| `GET` | `/health` | 服务器健康检查 | **已实现** |

### `POST /v1/audio/speech`

与 OpenAI 兼容的 TTS 端点。通过名称解析声音（可选地通过 `model` 限定到某个音色库），找到对应的 Provider 和适配器，返回原始音频字节。

**请求体（JSON）：**
```json
{
  "input": "要合成的文本",
  "model": "My Bank",
  "voice": "character_name",
  "speed": 1.0,
  "response_format": "wav"
}
```

| 字段 | 类型 | 是否必填 | 说明 |
|---|---|---|---|
| `input` | string | 是 | 要合成的文本 |
| `voice` | string | 是 | 声音角色名称（匹配 `VoiceAssets.name`） |
| `model` | string | 否 | 音色库名称 — 将声音查找限定在该库的成员范围内 |
| `speed` | number | 否 | 播放速度倍数（默认：1.0） |
| `response_format` | string | 否 | 输出格式提示，传递给上游适配器 |

**声音解析顺序：**
1. 如果提供了 `model`，则找到该名称的激活音色库，并在其成员中查找声音
2. 回退：在所有声音资产中按名称全局查找

**响应：** 原始音频字节，带有相应的 `Content-Type` 头（`audio/mpeg`、`audio/wav` 等）

**错误响应：**
- `400` — 缺少 `input` 或 `voice` 字段
- `401` — 配置鉴权后缺少或传入了错误的 API Key
- `413` — 请求体超过配置的大小限制
- `429` — 超过按 IP 统计的请求预算
- `404` — 未找到声音角色
- `500` — 未找到 Provider 或上游合成失败

### `GET /v1/audio/voices`

列出所有激活音色库中的声音。每个声音包含其音色库名称作为 `model` 字段。

**响应：**
```json
{
  "voices": [
    {
      "voice_id": "character_name",
      "name": "character_name",
      "description": "...",
      "provider": "OpenAI TTS",
      "model": "My Bank",
      "task_mode": "presetVoice"
    }
  ]
}
```

### `GET /v1/models`

将所有激活的音色库列为 OpenAI 风格的模型对象。

**响应：**
```json
{
  "object": "list",
  "data": [
    { "id": "Default Bank", "object": "model", "owned_by": "neiroha" },
    { "id": "Japanese Voices", "object": "model", "owned_by": "neiroha" }
  ]
}
```

### `GET /speakers`

与 SillyTavern 兼容的说话人列表，限定在激活的音色库范围内。

**响应：**
```json
[
  { "name": "character_name", "voice_id": "asset-uuid", "model": "My Bank" }
]
```

### `GET /health`

简单健康检查。

**响应：**
```json
{
  "status": "ok",
  "host": "127.0.0.1",
  "port": 8976,
  "authRequired": false
}
```

---

## 2. 上游适配器层

每个适配器实现 `TtsAdapter` 接口：

```dart
abstract class TtsAdapter {
  Future<TtsResult> synthesize(TtsRequest request);
  Future<bool> healthCheck();
  Future<List<String>> getSpeakers();
  Future<List<ModelInfo>> getModels();
}
```

### 2.1 OpenAI 兼容适配器（`openaiCompatible`）

适用于任何暴露标准 OpenAI TTS API 的服务器。

| 操作 | 方法 | 路径 | 状态 |
|---|---|---|---|
| 合成 | `POST` | `/audio/speech` | **已实现** |
| 健康检查 | `GET` | `/models` | **已实现** |
| 列出说话人 | `GET` | `/audio/voices` 然后 `/speakers` | **已实现** |
| 列出模型 | `GET` | `/models` | **已实现** |

**合成请求体：**
```json
{
  "model": "tts-1",
  "input": "text",
  "voice": "alloy",
  "speed": 1.0,
  "response_format": "wav"
}
```

### 2.2 Chat Completions TTS 适配器（`chatCompletionsTts`）

适用于使用 Chat Completions 格式的 TTS Provider（如 MiMo V2 TTS、Qwen 风格音频模型）。

| 操作 | 方法 | 路径 | 状态 |
|---|---|---|---|
| 合成 | `POST` | `/chat/completions` | **已实现** |
| 健康检查 | `GET` | `/models` | **已实现** |
| 列出说话人 | `GET` | `/speakers` | **已实现** |
| 列出模型 | `GET` | `/models` | **已实现** |

**合成请求体：**
```json
{
  "model": "mimo-v2-tts",
  "messages": [
    { "role": "user", "content": "语音指令（可选）" },
    { "role": "assistant", "content": "要合成的文本" }
  ],
  "audio": {
    "format": "wav",
    "voice": "mimo_default"
  }
}
```

**响应解析：** 从 `choices[0].message.audio.data` 提取 base64 音频。

**认证：** 默认使用 `api-key` 头（MiMo 风格），而非 `Authorization: Bearer`。

### 2.3 CosyVoice 原生适配器（`cosyvoice`）

通过原生 JSON API 支持多种合成模式的完整 CosyVoice 功能。

| 操作 | 方法 | 路径 | 状态 |
|---|---|---|---|
| 合成（JSON） | `POST` | `/cosyvoice/speech` | **已实现** |
| 合成（上传） | `POST` | `/cosyvoice/speech/upload` | **已实现** |
| 健康检查 | `GET` | `/health` | **已实现** |
| 列出说话人 | `GET` | `/speakers` | **已实现** |

**JSON 合成（`/cosyvoice/speech`）：**
```json
{
  "text": "要合成的文本",
  "speed": 1.0,
  "response_format": "wav",
  "mode": "zero_shot",
  "profile": "speaker_name",
  "prompt_audio_path": "D:/voices/demo.wav",
  "prompt_text": "参考文本",
  "instruct_text": "用温柔平静的语气朗读"
}
```

**合成模式说明：**
| 模式 | 说明 | 必填字段 |
|---|---|---|
| `zero_shot` | 声音克隆 | `prompt_audio_path`/`prompt_audio` + `prompt_text` |
| `cross_lingual` | 精细控制 | `prompt_audio_path`/`prompt_audio` |
| `instruct` | 指令模式 | `prompt_audio_path`/`prompt_audio` + `instruct_text` |

**Multipart 上传（`/cosyvoice/speech/upload`）：**
用于 zero_shot 模式上传参考音频文件。字段以 `multipart/form-data` 发送：
- `text`、`mode`（= `zero_shot`）、`speed`、`response_format`
- `prompt_audio` — 参考音频文件
- `prompt_text`、`prompt_lang`、`profile`、`instruct_text`（可选）

### 2.4 GPT-SoVITS 适配器（`gptSovits`）

适用于 Neiroha GPT-SoVITS 本地启动器，支持已训练说话人 profile 和参考音频克隆模式。

| 操作 | 方法 | 路径 | 状态 |
|---|---|---|---|
| 已训练说话人合成 | `POST` | `/v1/audio/speech` | **已实现** |
| 克隆合成 | `POST` | `/gpt-sovits/clone` | **已实现** |
| 健康检查 | `GET` | `/health` | **已实现** |
| 列出原生模型 | `GET` | `/gpt-sovits/models` | **已实现** |
| 列出说话人 | `GET` | `/gpt-sovits/voices`、`/v1/audio/voices`、`/speakers` | **已实现** |

**克隆请求体：**
```json
{
  "input": "要合成的文本",
  "speaker": "clone",
  "text_lang": "zh",
  "ref_audio_path": "/path/to/ref.wav",
  "prompt_text": "参考文本",
  "prompt_lang": "zh",
  "speed": 1.0,
  "response_format": "wav",
  "text_split_method": "cut5",
  "batch_size": 1
}
```

### 2.5 Azure 语音服务适配器（`azureTts`）

Microsoft Azure 认知服务文本转语音 REST API。免费层每月 50 万字符。

| 操作 | 方法 | 路径 | 状态 |
|---|---|---|---|
| 合成 | `POST` | `/cognitiveservices/v1` | **已实现** |
| 健康检查 | `GET` | `/cognitiveservices/voices/list` | **已实现** |
| 列出说话人 | `GET` | `/cognitiveservices/voices/list` | **已实现** |
| 列出模型 | `GET` | `/cognitiveservices/voices/list` | **已实现**（返回语音区域设置） |

**配置：**
- Base URL：`https://{region}.tts.speech.microsoft.com`（如 `eastus`、`westus2`、`southeastasia`）
  - 也接受裸区域名（`eastus`）或认知服务管理端点（`*.api.cognitive.microsoft.com`），自动标准化
- API Key：Azure 订阅密钥（设置为 `Ocp-Apim-Subscription-Key` 头）

**合成：** 使用 SSML 格式，包含语音名称、韵律速率和文本。支持输出格式：wav（默认）、mp3、opus/ogg、pcm。

### 2.6 Windows 系统 TTS 适配器（`systemTts`）

通过 PowerShell 调用内置 Windows SAPI（System.Speech.Synthesis）。零配置 — 适用于任何 Windows 10/11。

| 操作 | 方法 | 路径 | 状态 |
|---|---|---|---|
| 合成 | PowerShell `SpeechSynthesizer` | — | **已实现** |
| 健康检查 | PowerShell 程序集加载 | — | **已实现** |
| 列出说话人 | PowerShell `GetInstalledVoices()` | — | **已实现** |

**配置：** 无需 base URL 或 API Key。通过 `presetVoiceName` 选择语音（匹配已安装的 SAPI 语音名称）。速度从 0.5–2.0 范围映射到 SAPI 的 -10..10 速率刻度。输出始终为 WAV。

---

## 3. 模型管理

支持此功能的 Provider 可以从 API 自动查询可用模型。Provider 编辑器 UI 支持：

- **自动获取（Auto Fetch）** — 查询 `GET /models`（OpenAI / Chat）或语音列表（Azure）以发现可用模型
- **手动添加（Manual Add）** — 用户手动输入模型名称 / ID

对于具有独立模型和语音概念的适配器（`openaiCompatible`、`chatCompletionsTts`），Provider 编辑器会分别显示**模型**和**语音**两个区块，各自支持自动获取和手动添加。

模型/语音存储在 `ModelBindings` 表中，`supportedTaskModes='voice'` 区分语音条目与模型条目，跨会话持久化。

支持的适配器：

| 适配器类型 | 支持模型查询 | 支持语音查询 |
|---|---|---|
| `openaiCompatible` | 是 | 是 |
| `chatCompletionsTts` | 是 | 是 |
| `azureTts` | 通过语音列表返回 locale | 是 |
| `systemTts` | 否 | 是 |
| `cosyvoice` | profile | profile |
| `gptSovits` | 原生模型列表 | 是 |
| `geminiTts` | 否 | 手动配置预设/指令 |
| `voxcpm2Native` | 否 | 手动配置参考音频/指令 |

---

## 4. 尚未实现

### 适配器存根（计划中）

| 适配器类型 | 目标后端 | 备注 |
|---|---|---|
| `qwen3Native` | Qwen3 音频模型 | 原生 Qwen3 TTS API（非 Chat Completions 包装） |

### 缺少的本地服务器端点

| 方法 | 路径 | 说明 | 优先级 |
|---|---|---|---|
| `POST` | `/v1/jobs` | 创建持久化异步 TTS 任务 | 高 |
| `GET` | `/v1/jobs/:id` | 查看任务状态、进度和结果元数据 | 高 |
| `DELETE` | `/v1/jobs/:id` | 取消排队/运行中的任务 | 高 |
| `POST` | `/v1/jobs/:id/retry` | 将失败或完成的任务作为新 attempt 重试 | 中 |
| `GET` | `/v1/jobs/:id/events` | 可选 SSE 进度流 | 中 |
| `GET` | `/v1/audio/speech/:id` | 通过 ID 检索之前生成的音频 | 中 |

### 缺少的适配器功能

| 功能 | 说明 | 优先级 |
|---|---|---|
| 流式合成 | 以分块流而非缓冲响应返回音频 | 高 |
| 声音克隆上传 | 通过本地 API 上传参考音频（而非仅通过 UI） | 中 |
| 批量合成 | 一次请求接受多个输入 | 中 |
| SSML 支持 | 将 SSML 标记传递给支持的适配器 | 低 |
| 发音词典 | 自定义单词发音 | 低 |
