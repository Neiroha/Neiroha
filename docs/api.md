# Q-Vox-Lab — Audio API Reference

## Overview

Q-Vox-Lab exposes audio APIs at two levels:

1. **Local API Server** (`lib/server/api_server.dart`) — an OpenAI-compatible HTTP server that proxies TTS requests through configured voice characters, scoped by active voice banks
2. **Upstream Adapter Layer** (`lib/data/adapters/`) — client-side adapters that talk to external TTS backends

---

## 1. Local API Server (Shelf)

The built-in server runs on `0.0.0.0:8976` (configurable) and can be toggled from the Settings screen.

### Voice Bank as Model

The API uses **voice banks** as the `model` abstraction:
- Multiple voice banks can be **active simultaneously**
- Each active bank appears as a model in `/v1/models`
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
    { "id": "Default Bank", "object": "model", "owned_by": "q-vox-lab" },
    { "id": "Japanese Voices", "object": "model", "owned_by": "q-vox-lab" }
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
{ "status": "ok", "port": 8976 }
```

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
| `cross_lingual` | Fine control | `prompt_audio_path`/`prompt_audio` |
| `instruct` | Instruction mode | `prompt_audio_path`/`prompt_audio` + `instruct_text` |

**Multipart upload (`/cosyvoice/speech/upload`):**
Used for zero_shot mode with a reference audio file. Fields sent as `multipart/form-data`:
- `text`, `mode` (= `zero_shot`), `speed`, `response_format`
- `prompt_audio` — the reference audio file
- `prompt_text`, `prompt_lang`, `profile`, `instruct_text` (optional)

### 2.4 GPT-SoVITS (`gptSovits`)

Adapter for the GPT-SoVITS TTS backend (api_v2.py style).

| Operation | Method | Path | Status |
|---|---|---|---|
| Synthesize | `POST` | `/tts` | **Implemented** |
| Health check | `GET` | `/control` | **Implemented** |
| List speakers | — | — | Not supported (uses ref audio files) |

**Synthesis payload:**
```json
{
  "text": "text to synthesize",
  "text_lang": "zh",
  "ref_audio_path": "/path/to/ref.wav",
  "prompt_text": "reference text",
  "prompt_lang": "zh",
  "speed_factor": 1.0,
  "media_type": "wav",
  "text_split_method": "cut5",
  "batch_size": 1,
  "streaming_mode": false
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

| Operation | Method | Path | Status |
|---|---|---|---|
| Synthesize | PowerShell `SpeechSynthesizer` | — | **Implemented** |
| Health check | PowerShell assembly load | — | **Implemented** |
| List speakers | PowerShell `GetInstalledVoices()` | — | **Implemented** |

**Configuration:** No base URL or API key needed. Voice selection via `presetVoiceName` (matched to installed SAPI voice name). Speed is mapped from 0.5–2.0 range to SAPI's -10..10 rate scale. Output is always WAV.

---

## 3. Model Management

Providers that support it can auto-query available models from their API. The provider editor UI allows:

- **Auto Fetch** — queries `GET /models` (OpenAI/Chat) or voice list (Azure) to discover available models
- **Manual Add** — user types in model name/ID
- Models are stored in the `ModelBindings` table and persist across sessions
- Voice assets can reference specific models within a provider

Supported adapters: `openaiCompatible`, `chatCompletionsTts`, `azureTts`

---

## 4. Not Yet Implemented

### Adapter stubs (planned)

| Adapter Type | Target Backend | Notes |
|---|---|---|
| `qwen3Native` | Qwen3 audio models | Native Qwen3 TTS API (not chat completions wrapper) |

### Missing local server endpoints

| Method | Path | Description | Priority |
|---|---|---|---|
| `GET` | `/v1/audio/speech/:id` | Retrieve previously generated audio by ID | Medium |

### Missing adapter capabilities

| Feature | Description | Priority |
|---|---|---|
| Streaming synthesis | Return audio as chunked stream instead of buffered response | High |
| Voice cloning upload | Upload reference audio through the local API (not just UI) | Medium |
| Batch synthesis | Accept multiple inputs in one request | Medium |
| SSML support | Pass SSML markup to adapters that support it | Low |
| Pronunciation dictionary | Custom word pronunciations | Low |
