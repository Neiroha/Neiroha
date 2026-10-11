# Neiroha — Audio API Reference

## Overview

Neiroha exposes audio APIs at two levels:

1. **Local API Server** (`lib/server/api_server.dart`) — an OpenAI-compatible HTTP server that proxies TTS requests through configured voice characters, scoped by active voice banks, plus an MCP endpoint for AI agents (`lib/server/mcp/`)
2. **Upstream Adapter Layer** (`lib/data/adapters/`) — client-side adapters that talk to external TTS backends

---

## 1. Local API Server (Shelf)

The built-in server defaults to `127.0.0.1:8976` and can be toggled from
**Settings → API Server**. Set the bind host to `0.0.0.0` only when you
intentionally want LAN access.

### Security and operational controls

The Settings screen persists the local API configuration in `AppSettings`:

| Setting | Default | Notes |
|---|---|---|
| Bind host | `127.0.0.1` | Loopback-only by default |
| Port | `8976` | Restart the server after changing |
| API key | empty | When set, requests must send `Authorization: Bearer <key>` or `X-API-Key: <key>` |
| CORS origins | empty | Empty denies browser cross-origin access; `*` allows any origin |
| Rate limit | `60` req/min/IP | `0` disables |
| Max body size | `1048576` bytes | `0` disables declared Content-Length check |
| API log output | off | Logs metadata only; request bodies and auth headers are never captured |

Every synthesis request goes through the shared `TtsQueueService`, so provider
concurrency and rate limits apply equally to desktop screens and external API
clients.

### Voice Bank as Model

The API uses **voice banks** as the `model` abstraction:
- Active voice bank rows appear as models in `/v1/models`
- The bank name is used as the `model` value in API requests
- Voices listed in `/v1/audio/voices` and `/speakers` are scoped to active banks

### Implemented Endpoints

| Method | Path | Description | Status |
|---|---|---|---|
| `POST` | `/v1/audio/speech` | Synthesize speech from text | **Implemented** |
| `GET` | `/v1/audio/voices` | List voices from active banks (OpenAI format) | **Implemented** |
| `GET` | `/v1/models` | List active voice banks as models | **Implemented** |
| `GET` | `/speakers` | List voices from active banks (SillyTavern format) | **Implemented** |
| `GET` | `/health` | Server health check | **Implemented** |
| `POST` | `/mcp` | Model Context Protocol endpoint for AI agents | **Implemented** |

### `POST /v1/audio/speech`

OpenAI-compatible TTS endpoint. Resolves voice by name (optionally scoped to a bank via `model`), finds the provider + adapter, and returns raw audio bytes.

**Request body (JSON):**
```json
{
  "input": "Text to synthesize",
  "model": "My Bank",
  "voice": "character_name",
  "speed": 1.0,
  "response_format": "wav"
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `input` | string | yes | Text to synthesize |
| `voice` | string | yes | Voice character name (matched against `VoiceAssets.name`) |
| `model` | string | no | Voice bank name — scopes voice lookup to that bank's members |
| `speed` | number | no | Playback speed multiplier (default: 1.0) |
| `response_format` | string | no | Output format hint passed to upstream adapter |

**Voice resolution order:**
1. If `model` is provided, find the active bank with that name and look up the voice within its members
2. Fallback: look up the voice by name globally across all voice assets

**Response:** Raw audio bytes with appropriate `Content-Type` header (`audio/mpeg`, `audio/wav`, etc.)

**Error responses:**
- `400` — Missing `input` or `voice` field
- `401` — Missing or invalid API key when auth is configured
- `413` — Request body exceeds configured limit
- `429` — Per-IP request budget exceeded
- `404` — Voice character not found
- `500` — Provider not found or upstream synthesis failed

### `GET /v1/audio/voices`

Lists voices from all active banks. Each voice includes its bank name as the `model` field.

**Response:**
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

Lists all active voice banks as OpenAI-style model objects.

**Response:**
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

SillyTavern-compatible speaker list, scoped to active banks.

**Response:**
```json
[
  { "name": "character_name", "voice_id": "asset-uuid", "model": "My Bank" }
]
```

### `GET /health`

Simple health check.

**Response:**
```json
{
  "status": "ok",
  "host": "127.0.0.1",
  "port": 8976,
  "authRequired": false
}
```

### MCP endpoint (`/mcp`) for AI agents

The same server also speaks the [Model Context Protocol](https://modelcontextprotocol.io)
over Streamable HTTP at `POST /mcp` (stateless; every response is plain
`application/json`, no SSE stream or session id). Agents can manage providers,
voice banks, the reference-audio library and voice characters, synthesize
speech, and run complete video-dub jobs (import subtitles → cast cues →
generate → export).

| Setting | Default | Notes |
|---|---|---|
| MCP server for AI agents | on | Settings → API Server; persisted as `api.mcpEnabled` |
| Start API server on launch | off | Starts the API + MCP server when the app opens; persisted as `api.autoStart` |
| Auth | API key above | `Authorization: Bearer <key>` / `X-API-Key` when a key is set |
| LAN safety | — | On a non-loopback bind host `/mcp` returns `403` unless an API key is configured |
| Browser origins | denied | Requests with an `Origin` header must match the CORS allow-list |

```bash
claude mcp add --transport http neiroha http://127.0.0.1:8976/mcp
```

Tools: `get_overview`, `list_adapter_types`, `list_providers`,
`create_provider`, `update_provider`, `delete_provider`, `check_provider`,
`list_provider_models`, `list_provider_voices`, `list_voice_banks`,
`create_voice_bank`, `update_voice_bank`, `delete_voice_bank`,
`add_characters_to_bank`, `remove_characters_from_bank`, `list_audio_tracks`,
`import_audio_track`, `delete_audio_track`, `list_voice_characters`,
`create_voice_character`, `update_voice_character`, `delete_voice_character`,
`synthesize_speech`, `list_video_dub_projects`, `create_video_dub_project`,
`attach_video_to_dub_project`, `import_subtitles`, `list_subtitle_cues`,
`add_subtitle_cues`, `update_subtitle_cues`, `delete_subtitle_cues`,
`generate_video_dub_audio`, `export_video_dub`, `delete_video_dub_project`.

Provider API keys are write-only through MCP (`list_providers` returns
`has_api_key`). A ready-made agent skill lives in
[`skills/neiroha-dubbing/SKILL.md`](../skills/neiroha-dubbing/SKILL.md).
---

## 2. Upstream Adapter Layer

Each adapter implements the `TtsAdapter` interface:

```dart
abstract class TtsAdapter {
  Future<TtsResult> synthesize(TtsRequest request);
  Future<bool> healthCheck();
  Future<List<String>> getSpeakers();
  Future<List<ModelInfo>> getModels();
}
```

### Platform availability

Provider and media capabilities are filtered by the running platform:

| Capability | Windows | Linux / macOS | Android |
|---|---|---|---|
| External FFmpeg CLI path / PATH detection | yes | yes | no |
| Local waveform extraction, trimming and muxed export | yes | yes | disabled |
| Windows SAPI system TTS | yes | no | no |

Unsupported providers are not offered in the Add Provider dialog. Existing
database rows from another platform remain visible as unavailable and cannot be
enabled or health-checked.

### 2.1 OpenAI Compatible (`openaiCompatible`)

For any server exposing the standard OpenAI TTS API.

| Operation | Method | Path | Status |
|---|---|---|---|
| Synthesize | `POST` | `/audio/speech` | **Implemented** |
| Health check | `GET` | `/models` | **Implemented** |
| List speakers | `GET` | `/audio/voices` then `/speakers` | **Implemented** |
| List models | `GET` | `/models` | **Implemented** |

**Synthesis payload:**
```json
{
  "model": "tts-1",
  "input": "text",
  "voice": "alloy",
  "speed": 1.0,
  "response_format": "wav"
}
```

### 2.2 Chat Completions TTS (`chatCompletionsTts`)

For TTS providers using the Chat Completions format (e.g. MiMo V2 TTS, Qwen-style audio models).

| Operation | Method | Path | Status |
|---|---|---|---|
| Synthesize | `POST` | `/chat/completions` | **Implemented** |
| Health check | `GET` | `/models` | **Implemented** |
| List speakers | `GET` | `/speakers` | **Implemented** |
| List models | `GET` | `/models` | **Implemented** |

**Synthesis payload:**
```json
{
  "model": "mimo-v2-tts",
  "messages": [
    { "role": "user", "content": "voice instruction (optional)" },
    { "role": "assistant", "content": "text to synthesize" }
  ],
  "audio": {
    "format": "wav",
    "voice": "mimo_default"
  }
}
```

**Response parsing:** Extracts base64 audio from `choices[0].message.audio.data`.

**Auth:** Uses `api-key` header (MiMo-style) by default instead of `Authorization: Bearer`.

### 2.3 CosyVoice Native (`cosyvoice`)

Full CosyVoice feature support with multiple synthesis modes via the native JSON API.

| Operation | Method | Path | Status |
|---|---|---|---|
| Synthesize (JSON) | `POST` | `/cosyvoice/speech` | **Implemented** |
| Synthesize (upload) | `POST` | `/cosyvoice/speech/upload` | **Implemented** |
| Health check | `GET` | `/health` | **Implemented** |
| List speakers | `GET` | `/speakers` | **Implemented** |
| List profiles | `GET` | `/cosyvoice/profiles` | **Implemented** |

Default local launcher URL: `http://127.0.0.1:9880`. Default model name:
`default`.

**JSON synthesis (`/cosyvoice/speech`):**
```json
{
  "text": "text to synthesize",
  "speed": 1.0,
  "response_format": "wav",
  "mode": "zero_shot",
  "profile": "speaker_name",
  "prompt_audio_path": "D:/voices/demo.wav",
  "prompt_text": "reference text",
  "instruct_text": "Read in a gentle and calm tone"
}
```

**Mode descriptions:**
| Mode | Description | Required fields |
|---|---|---|
| `zero_shot` | Voice cloning | `prompt_audio_path`/`prompt_audio` + `prompt_text` |
| `cross_lingual` | Cross-language clone | `prompt_audio_path`/`prompt_audio` |
| `instruct` | Instruction-controlled style | `prompt_audio_path`/`prompt_audio` + `instruct_text` |

**Multipart upload (`/cosyvoice/speech/upload`):**
Used when the user uploads a local reference audio. Fields sent as `multipart/form-data`:
- `text`, `mode`, `speed`, `response_format`
- `prompt_audio` — the reference audio file
- `prompt_text` (zero_shot required), `prompt_lang`, `instruct_text` (instruct required)

> **Important:** `profile` is **NOT sent** in the multipart path. The server's
> `build_runtime_char_config` does a strict lookup and raises 400 "未找到角色"
> if the name isn't registered. When uploading audio the upload fully defines
> the voice; no profile lookup is needed. Profile is only used in the JSON path
> when no audio is uploaded and the server must retrieve stored reference audio.

**Profile list (`GET /cosyvoice/profiles`):**
Returns server-registered profiles. Only names from this list are safe to send as `profile`.
```json
{
  "object": "list",
  "data": [
    { "id": "Neko",  "name": "Neko",  "mode": "zero_shot",    "mode_label": "语音克隆" },
    { "id": "Kuro",  "name": "Kuro",  "mode": "instruct",     "mode_label": "指令模式" }
  ]
}
```
The character creation dialog fetches this list and shows it as a dropdown so users cannot type arbitrary (non-existent) profile names.

**Synthesis mode stored in `VoiceAsset.modelName`:**
For CosyVoice native characters the `modelName` column stores the synthesis mode string
(`zero_shot` / `cross_lingual` / `instruct`). `createAdapter(provider, modelName: asset.modelName)`
passes it to `CosyVoiceAdapter(modelName: mode)` which uses it to route synthesis.

**`CosyVoiceProfile` data class** (returned by `getProfiles()`):
```dart
class CosyVoiceProfile {
  final String id;
  final String name;
  final String mode;       // zero_shot | cross_lingual | instruct
  final String modeLabel;  // Chinese label, e.g. 语音克隆
}
```

### 2.4 GPT-SoVITS (`gptSovits`)

Adapter for the Neiroha GPT-SoVITS launcher. It supports saved trained
speaker profiles and reference-audio clone mode.

| Operation | Method | Path | Status |
|---|---|---|---|
| Synthesize trained speaker | `POST` | `/v1/audio/speech` | **Implemented** |
| Synthesize clone | `POST` | `/api/gpt-sovits/clone` | **Implemented** |
| Health check | `GET` | `/health` | **Implemented** |
| List voice-set models | `GET` | `/v1/models` | **Implemented** |
| List speakers | `GET` | `/api/gpt-sovits/voices`, `/v1/audio/voices`, `/speakers` | **Implemented** |

Default local launcher URL: `http://127.0.0.1:9880`. The OpenAI-compatible
`model` value is a Neiroha voice set such as `default`; underlying GPT/SoVITS
weights are exposed as model presets through the native admin/API surface.

**Clone payload:**
```json
{
  "input": "text to synthesize",
  "speaker": "clone",
  "text_lang": "zh",
  "ref_audio_path": "/path/to/ref.wav",
  "prompt_text": "reference text",
  "prompt_lang": "zh",
  "speed": 1.0,
  "response_format": "wav",
  "text_split_method": "cut5",
  "batch_size": 1
}
```

### 2.5 Azure Speech Service (`azureTts`)

Microsoft Azure Cognitive Services Text-to-Speech REST API. Free tier provides 500k characters/month.

| Operation | Method | Path | Status |
|---|---|---|---|
| Synthesize | `POST` | `/cognitiveservices/v1` | **Implemented** |
| Health check | `GET` | `/cognitiveservices/voices/list` | **Implemented** |
| List speakers | `GET` | `/cognitiveservices/voices/list` | **Implemented** |
| List models | `GET` | `/cognitiveservices/voices/list` | **Implemented** (returns locales) |

**Configuration:**
- Base URL: `https://{region}.tts.speech.microsoft.com` (e.g. `eastus`, `westus2`, `southeastasia`)
- API Key: Azure subscription key (set as `Ocp-Apim-Subscription-Key` header)

**Synthesis:** Uses SSML format with voice name, prosody rate, and text. Supports output formats: wav (default), mp3, opus/ogg, pcm.

### 2.6 Windows System TTS (`systemTts`)

Built-in Windows SAPI (System.Speech.Synthesis) via PowerShell. Zero setup — works on any Windows 10/11 installation.
This provider is seeded and shown only on Windows. Android, Apple and Linux
system TTS backends are intentionally hidden until native platform adapters are
implemented.

| Operation | Method | Path | Status |
|---|---|---|---|
| Synthesize | PowerShell `SpeechSynthesizer` | — | **Implemented** |
| Health check | PowerShell assembly load | — | **Implemented** |
| List speakers | PowerShell `GetInstalledVoices()` | — | **Implemented** |

**Configuration:** No base URL or API key needed. Voice selection via `presetVoiceName` (matched to installed SAPI voice name). Speed is mapped from 0.5–2.0 range to SAPI's -10..10 rate scale. Output is always WAV.

### 2.7 Google Gemini TTS (`geminiTts`)

| Operation | Method | Path | Status |
|---|---|---|---|
| Synthesize (Gemini 3.8+) | `POST` | `/v1beta/interactions` | **Implemented** |
| Synthesize (2.5 / 3.1 preview) | `POST` | `/v1beta/models/{model}:generateContent` | **Implemented** |
| List voices | `GET` | `/v1beta/voices` (+ 30 built-in prebuilt voices) | **Implemented** |
| Health check | `GET` | `/v1beta/models` | **Implemented** |

Models: `gemini-3.8-flash-tts` (default), `gemini-3.8-flash-lite-tts`,
`gemini-3.1-flash-tts-preview`, `gemini-2.5-flash-preview-tts`,
`gemini-2.5-pro-preview-tts`. For Interactions requests the text is read
verbatim and the character instruction is sent as
`speech_metadata.style`; legacy models still get the instruction prepended.
Interactions returns WAV directly; legacy PCM is wrapped in a WAV header.
A 404 from `/interactions` falls back to `generateContent`.

### 2.8 ElevenLabs (`elevenLabs`)

| Operation | Method | Path | Status |
|---|---|---|---|
| Synthesize | `POST` | `/v1/text-to-speech/{voice_id}?output_format=mp3_44100_128` | **Implemented** |
| List models / health | `GET` | `/v1/models` | **Implemented** |
| List voices | `GET` | `/v2/voices` (paginated) | **Implemented** |
| Instant voice clone | `POST` | `/v1/voices/add` (multipart) | **Implemented** |

Header `xi-api-key`. Models: `eleven_v4` (default), `eleven_v4_turbo`,
`eleven_v3`, `eleven_multilingual_v2`, `eleven_flash_v2_5`,
`eleven_flash_v2`. Voices are shown as `Name [voice_id]`. On v3/v4 the
instruction becomes a leading audio tag (`[whispers] …`). Speed maps to
`voice_settings.speed` (0.7–1.2).

### 2.9 MiniMax Speech (`minimaxTts`)

| Operation | Method | Path | Status |
|---|---|---|---|
| Synthesize | `POST` | `/v1/t2a_v2` (hex audio) | **Implemented** |
| List voices / health | `POST` | `/v1/get_voice` | **Implemented** |
| Voice clone | `POST` | `/v1/files/upload` (`purpose=voice_clone`) → `/v1/voice_clone` | **Implemented** |

Base URL `https://api.minimax.io` (mainland China: `https://api.minimaxi.com`),
`Authorization: Bearer`. Models: `speech-2.8-hd` (default), `speech-2.8-turbo`,
`speech-2.6-hd/turbo`, `speech-02-hd/turbo`. A character instruction equal to
one of `happy, sad, angry, fearful, disgusted, surprised, calm, fluent,
whisper` is sent as `voice_setting.emotion`. `base_resp.status_code != 0`
is treated as an error. Cloned voices unused for 7 days are deleted upstream.

### 2.10 IndexTTS 2.5 WebUI (`indexTts`)

Neiroha does not ship an IndexTTS launcher yet; this adapter drives the
official Gradio WebUI (`webui.py`) that community one-click packages start
(e.g. `opc-run/tts-index-tts-bundle` → `start-webui.bat`, default
`http://127.0.0.1:7860`).

| Operation | Method | Path | Status |
|---|---|---|---|
| Endpoint schema / health | `GET` | `/gradio_api/info` | **Implemented** |
| Upload reference audio | `POST` | `/gradio_api/upload` | **Implemented** |
| Generate | `POST` + `GET` (SSE) | `/gradio_api/call/gen_single[/{event_id}]` | **Implemented** |
| Download result | `GET` | `/gradio_api/file={path}` | **Implemented** |

Gradio 4 servers without the `/gradio_api` prefix are detected
automatically. Arguments are filled by parameter name from `/info` (unknown
sampling knobs keep the WebUI defaults). Characters always clone from their
reference audio. `modelName` holds the output language (`auto`, `ZH`, `EN`,
`JA`, `AR`, `ES`; `auto` detects from the text). Speed maps to the 2.5
`duration_factor` (`1 / speed`). The instruction is sent as emotion text
only when the WebUI exposes the experimental emotion-text mode.
---

## 3. Model Management

Providers that support it can auto-query available models from their API. The provider editor UI allows:

- **Auto Fetch** — queries `GET /models` (OpenAI/Chat) or voice list (Azure) to discover available models
- **Manual Add** — user types in model name/ID
- Models are stored in the `ModelBindings` table and persist across sessions
- Voice assets can reference specific models within a provider

Supported adapters:

| Adapter type | Model query | Voice query |
|---|---|---|
| `openaiCompatible` | yes | yes |
| `chatCompletionsTts` | yes | yes |
| `azureTts` | locales via voice list | yes |
| `systemTts` | no | yes, Windows only |
| `cosyvoice` | profiles | profiles |
| `gptSovits` | voice-set models via `/v1/models` | yes |
| `geminiTts` | yes, built-in TTS model list | yes, prebuilt + voice library |
| `elevenLabs` | yes, `/v1/models` | yes, `/v2/voices` |
| `minimaxTts` | yes, built-in list | yes, `/v1/get_voice` |
| `indexTts` | output languages | no (reference audio only) |
| `voxcpm2Native` | yes | yes |

---

## 4. Not Yet Implemented

### Adapter stubs (planned)

| Adapter Type | Target Backend | Notes |
|---|---|---|
| `qwen3Native` | Qwen3 audio models | Native Qwen3 TTS API (not chat completions wrapper) |
| `fishSpeech` | Fish Speech | Voice clone / instruct / preset modes |
| `kokoro` | Kokoro-TTS | Preset + voice design modes |
| `f5Tts` | F5-TTS / E2-TTS | Zero-shot voice clone mode |

Backend wiring notes live in the project Wiki and local design notes, keeping this
directory focused on published API references.

### Missing local server endpoints

| Method | Path | Description | Priority |
|---|---|---|---|
| `POST` | `/v1/jobs` | Create a durable async TTS job | High |
| `GET` | `/v1/jobs/:id` | Inspect job status/progress/result metadata | High |
| `DELETE` | `/v1/jobs/:id` | Cancel a queued/running job | High |
| `POST` | `/v1/jobs/:id/retry` | Retry a failed or completed job as a new attempt | Medium |
| `GET` | `/v1/jobs/:id/events` | Optional SSE progress stream | Medium |
| `GET` | `/v1/audio/speech/:id` | Retrieve previously generated audio by ID | Medium |

### Missing adapter capabilities

| Feature | Description | Priority |
|---|---|---|
| Streaming synthesis | Return audio as chunked stream instead of buffered response | High |
| Voice cloning upload | Upload reference audio through the local API (not just UI) | Medium |
| Batch synthesis | Accept multiple inputs in one request | Medium |
| SSML support | Pass SSML markup to adapters that support it | Low |
| Pronunciation dictionary | Custom word pronunciations | Low |
