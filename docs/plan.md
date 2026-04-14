# Q-VOX-LAB Development Plan (Flutter Multi-Platform)

> **Objective**: Build a multi-platform (Android, Windows, Linux) AI audio middleware and dubbing workstation.
> **Core Architecture**: Flutter-based Client + Local Dart HTTP Server (Middleware). It acts as a local API hub (similar to `new-api`) for various TTS providers and features a professional timeline-based dubbing GUI.

---

## 1. Core Architecture & Tech Stack

### 1.1 The "Thin Backend" + "Fat Client" Approach
**Why this approach?** Unlike enterprise-heavy Docker/NestJS/Postgres architectures, Neiroha is a *Workstation App*. The user simply opens the app on Windows/Linux/Android, and it runs natively.
- **Frontend (GUI)**: Flutter (Responsive layout: mobile -> tablet -> split-screen desktop).
- **Local Middleware (API Server)**: Runs a local HTTP server in-app via the Dart `shelf` package. It exposes standard OpenAI-compatible endpoints (`/v1/audio/speech`).
- **State & Local Storage**: `Riverpod` (state), `Isar` or `Drift` (high-performance local SQLite).
- **Background Task Queue**: Dart `Isolates` or `flutter_background_service` to manage TTS synthesis jobs asynchronously without freezing the UI.

---

## 2. Core Domain Models (The Translation Abstraction)

This is the most critical part. TTS models behave differently (OpenAI uses standard requests, GPT-SoVITS requires reference audio + prompt text, Qwen3 has voice_design). Thus, we use a unified abstraction:

### 2.1 Provider (`Provider`)
An upstream service instance (local or remote).
- **Fields**: `id`, `name`, `adapter_type` (`openai_compatible`, `qwen3_native`, `gpt_sovits`, `cosyvoice`), `baseUrl`, `apiKey`.

### 2.2 Model Binding (`ModelBinding`)
The model/entrypoint exposed by a Provider.
- **Fields**: `id`, `providerId`, `modelKey`, `supportedTaskModes`.

### 2.3 Voice Asset / Character (`VoiceAsset`)
The actual "Voice" seen by the user and exposed via API. 
- **Fields**: `id`, `name`, `providerId`, `taskMode` (e.g., `clone_with_prompt`, `preset_voice`), parameters (reference audio paths, instruction text, speed).
- **Behavior**: When an external app calls `/v1/audio/speech` requesting `voice: "hutao"`, the middleware looks up the `VoiceAsset`, sees it's mapped to a GPT-SoVITS `Provider` using the `clone_with_prompt` task mode, and reconstructs the API call automatically.

---

## 3. Core Modules & GUI Design

### 3.1 Local API Middleware (The "New-API" Hub)
- **OpenAI-Compatible Interfaces**: 
  - `POST /v1/audio/speech` (Synthesize text into audio)
  - `GET /v1/models` (List available Voice Assets)
- **Adapter Engine**: Translates unified `TaskMode` requests into underlying provider payloads. 
  - *GPT-SoVITS Adapter*: Translates to `text, text_lang, ref_audio_path, prompt_text`.
  - *Qwen3 Adapter*: Translates to `preset/design` tasks.
  - *OpenAI Adapter*: Direct passthrough.

### 3.2 Voice Manager (Asset Library)
- **GUI**: Manage Providers, test endpoint health, and create unified Character Voices.
- **Capabilities**: Upload reference audio, edit instruction/prompt hints, and preview the synthesized character voice.

### 3.3 PR-Style Dubbing Studio (Non-Linear Editor)
- **Project Structure**: `.qvox` JSON projects (Tracks, Script, Settings).
- **Timeline UI**: Multi-track video/audio synchronized editor.
  - Video Preview Track (`media_kit` synced strictly to the timeline).
  - Background Music / SFX Tracks.
  - TTS Voice Tracks.
- **Interaction**: Drag/drop audio blocks, bulk generate TTS from scripts, timeline trimming.

---

## 4. Execution Roadmap (MVP Phasing)

### Phase 1: Core Skeleton & Local Server
- [ ] Initialize multi-platform Flutter project.
- [ ] Setup `Isar`/`Drift` DB (`Providers`, `VoiceAssets`, `Jobs`).
- [ ] Implement the local Dart HTTP server (`shelf`).
- [ ] Create basic provider architecture with an `openai_compatible` generic adapter.

### Phase 2: The "Oddball" Integration (Proving the Abstraction)
- [ ] Implement the UI for "Voice Asset" creation.
- [ ] Implement the `gpt_sovits` adapter (proving the abstraction works for models requiring reference text/audio).
- [ ] Integrate a background job queue for async generation instead of blocking HTTP tasks.

### Phase 3: Exposing the API & External Testing
- [ ] Finalize the `/v1/audio/speech` endpoint.
- [ ] Test integration: Point a third-party app (e.g., a text-reader or tavern-like app) to `localhost:YOUR_PORT` to verify it triggers local GPT-SoVITS/OpenAI generation successfully.

### Phase 4: The Dubbing Studio (Timeline)
- [ ] Implement custom timeline painter for multi-track audio.
- [ ] Integrate `media_kit` for video playback reference.
- [ ] Connect the Voice Assets into the timeline for script-to-audio block generation.
- [ ] Polish audio rendering and timeline UX gestures.

