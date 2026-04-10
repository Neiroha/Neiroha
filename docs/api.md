# Q-Vox-Lab — Audio API Reference

## Overview

Q-Vox-Lab exposes audio APIs at two levels:

1. **Local API Server** (`lib/server/api_server.dart`) — an OpenAI-compatible HTTP server that proxies TTS requests through configured voice characters
2. **Upstream Adapter Layer** (`lib/data/adapters/`) — client-side adapters that talk to external TTS backends

---

## 1. Local API Server (Shelf)

The built-in server runs on `0.0.0.0:8976` (configurable) and can be toggled from the Settings screen.

### Implemented Endpoints

| Method | Path | Description | Status |
|---|---|---|---|
| `POST` | `/v1/audio/speech` | Synthesize speech from text | **Implemented** |
| `GET` | `/v1/models` | List available voice characters | **Implemented** |
| `GET` | `/health` | Server health check | **Implemented** |

### `POST /v1/audio/speech`

OpenAI-compatible TTS endpoint. Looks up the voice character by name, resolves its provider + adapter, and returns raw audio bytes.

**Request body (JSON):**
```json
{
  "input": "Text to synthesize",
  "voice": "character_name",
  "speed": 1.0,
  "response_format": "wav"
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `input` | string | yes | Text to synthesize |
| `voice` | string | yes | Voice character name (matched against `VoiceAssets.name`) |
| `speed` | number | no | Playback speed multiplier (default: 1.0) |
| `response_format` | string | no | Output format hint passed to upstream adapter |

**Response:** Raw audio bytes with appropriate `Content-Type` header (`audio/mpeg`, `audio/wav`, etc.)

**Error responses:**
- `400` — Missing `input` or `voice` field
- `404` — Voice character not found
- `500` — Provider not found or upstream synthesis failed

### `GET /v1/models`

Lists all enabled voice characters as OpenAI-style model objects.

**Response:**
```json
{
  "object": "list",
  "data": [
    { "id": "character_name", "object": "model", "owned_by": "q-vox-lab" }
  ]
}
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
}
```

### 2.1 OpenAI Compatible (`openaiCompatible`)

For any server exposing the standard OpenAI TTS API.

| Operation | Method | Path | Status |
|---|---|---|---|
| Synthesize | `POST` | `/audio/speech` | **Implemented** |
| Health check | `GET` | `/models` | **Implemented** |
| List speakers | `GET` | `/audio/voices` then `/speakers` | **Implemented** |

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

For TTS providers using the Chat Completions format (e.g. MiMo TTS, Qwen-style audio models).

| Operation | Method | Path | Status |
|---|---|---|---|
| Synthesize | `POST` | `/chat/completions` | **Implemented** |
| Health check | `GET` | `/models` | **Implemented** |
| List speakers | `GET` | `/speakers` | **Implemented** |

**Synthesis payload:**
```json
{
  "model": "model_name",
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

Full CosyVoice feature support with multiple synthesis modes.

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
  "mode": "instruct",
  "profile": "speaker_name",
  "instruct_text": "style instruction",
  "prompt_text": "reference text",
  "prompt_lang": "zh"
}
```

**Multipart upload (`/cosyvoice/speech/upload`):**
Used for zero_shot mode with a reference audio file. Fields sent as `multipart/form-data`:
- `text`, `mode` (= `zero_shot`), `speed`, `response_format`
- `prompt_audio` — the reference audio file
- `prompt_text`, `prompt_lang`, `profile`, `instruct_text` (optional)

---

## 3. Not Yet Implemented

### Adapter stubs (planned but throw `UnimplementedError`)

| Adapter Type | Target Backend | Notes |
|---|---|---|
| `gptSovits` | GPT-SoVITS | Popular open-source voice cloning; typically serves on `localhost:9880` with `/tts` endpoint |
| `qwen3Native` | Qwen3 audio models | Native Qwen3 TTS API (not chat completions wrapper) |

### Missing local server endpoints

| Method | Path | Description | Priority |
|---|---|---|---|
| `GET` | `/v1/audio/voices` | List voices in OpenAI format (name, preview_url) | High — needed for OpenAI client compatibility |
| `GET` | `/v1/audio/speech/:id` | Retrieve previously generated audio by ID | Medium |
| `POST` | `/v1/audio/speech` | Support `model` field to select provider | Medium — currently ignores model, routes by voice name only |
| `GET` | `/speakers` | SillyTavern-compatible speaker list | Medium — enables SillyTavern integration |
| `POST` | `/v1/audio/transcriptions` | Speech-to-text (STT) proxy | Low — outside core TTS scope |
| `POST` | `/v1/audio/translations` | Audio translation proxy | Low |
| `DELETE` | `/v1/audio/speech/:id` | Delete cached audio | Low |

### Missing adapter capabilities

| Feature | Description | Priority |
|---|---|---|
| Streaming synthesis | Return audio as chunked stream instead of buffered response | High — improves perceived latency for long text |
| Voice cloning upload | Upload reference audio through the local API (not just UI) | Medium |
| Batch synthesis | Accept multiple inputs in one request | Medium |
| SSML support | Pass SSML markup to adapters that support it | Low |
| Pronunciation dictionary | Custom word pronunciations | Low |

---

## 4. Recommendations — Next APIs to Implement

### High Priority

1. **`GET /v1/audio/voices`** — Return voice character list in OpenAI format. This is the most commonly expected companion to `/v1/audio/speech` and is needed for any OpenAI-compatible client (SillyTavern, Open WebUI, etc.) to discover available voices.

2. **GPT-SoVITS adapter** — One of the most popular open-source voice cloning backends. Typical API:
   - `POST /tts` with `text`, `text_lang`, `ref_audio_path`, `prompt_text`, `prompt_lang`
   - `GET /speakers` for speaker list
   - Already has a table slot (`gptSovits` adapter type); just needs the Dio implementation.

3. **Streaming TTS** — Add `Transfer-Encoding: chunked` support to the local server's `/v1/audio/speech`. Long paragraphs currently block until the entire audio is generated. Streaming would enable playback-as-it-generates.

### Medium Priority

4. **`GET /speakers`** (local server) — SillyTavern-format speaker list. Many community tools expect this endpoint. Trivial to implement since voice data is already in the database.

5. **`model` field routing** — The local `/v1/audio/speech` currently ignores the `model` field. Supporting it would allow clients to target a specific provider (e.g. `model: "cosyvoice"` vs `model: "openai-tts"`).

6. **Qwen3 native adapter** — For direct Qwen3 audio model inference without the chat completions wrapper. Useful when running Qwen3 locally with vLLM or similar.

### Low Priority

7. **STT proxy** (`/v1/audio/transcriptions`) — Would enable full audio round-trip (TTS + STT) for dubbing QA workflows.

8. **WebSocket streaming** — Alternative to HTTP chunked for real-time synthesis in web clients.
