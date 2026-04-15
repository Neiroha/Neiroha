<div align="center">

<img src="assets/images/neiroha_logo.png" alt="Neiroha Logo" width="160" />

# Neiroha

**AI Audio Middleware & Dubbing Workstation**

[![Language](https://img.shields.io/badge/language-Dart%20%2F%20Flutter-0553B1?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Windows-0078D4?logo=windows&logoColor=white)](https://github.com/flutter/flutter)
[![Release](https://img.shields.io/badge/release-Pre--release-orange)](https://github.com/Neiroha/Neiroha/releases)
[![Version](https://img.shields.io/badge/version-0.1.0-blue)](https://github.com/Neiroha/Neiroha/releases)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

[English](README.md) · [中文](README_zh.md)

</div>

---

<div align="center">
  <img src="assets/images/screenshot_overview.png" alt="Neiroha Overview" width="860" />
</div>

## What is Neiroha?

Neiroha is a **Flutter desktop application for Windows** that acts as a universal front-end for multiple text-to-speech engines. It lets you:

- Connect to any combination of TTS backends (cloud or local) through a single unified interface.
- Build a library of named **Voice Characters** — each character binds a specific provider, voice, speed, and optional reference audio.
- Organise characters into **Voice Banks** and switch between them per project.
- Produce speech through a built-in **OpenAI-compatible HTTP API**, so any tool that speaks the OpenAI TTS protocol can talk to Neiroha without modification.
- Work across three production modes: one-shot **Quick TTS**, multi-character **Dialog TTS**, and long-form **Phase TTS** for narration and audiobooks.

---

## Feature Overview

| Section | What it does |
|---|---|
| **Providers** | Connect to TTS backends (OpenAI, Azure, GPT-SoVITS, CosyVoice, System TTS, …) |
| **Voice Characters** | Define characters with a chosen provider, voice/model, speed, and reference audio |
| **Voice Banks** | Group characters into banks; activate a bank to make it available across all screens |
| **Quick TTS** | One-shot test: pick a character, type text, generate & play instantly |
| **Dialog TTS** | Multi-character conversation projects with Telegram-style chat view |
| **Phase TTS** | Long-form narration: paste a script, split into segments, batch-generate |
| **API Server** | Local HTTP server exposing an OpenAI-compatible `/v1/audio/speech` endpoint |

---

## Getting Started

### Requirements

- Flutter SDK ≥ 3.11
- Windows 10/11 (primary target)
- At least one TTS backend reachable on your network or localhost

### Run from source

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows
```

---

## Step-by-Step Usage

### 1. Configure a Provider

Go to the **Providers** tab in the sidebar.

Click **+** (top-right of the list pane) → choose a name and adapter type:

| Adapter | When to use |
|---|---|
| **OpenAI TTS API Compatible** | OpenAI, KoboldCpp, Kokoro/XTTS via OpenedAI-speech, Orpheus, etc. |
| **Azure Speech Service** | Microsoft Azure Cognitive Services TTS |
| **GPT-SoVITS** | Local GPT-SoVITS server (v2 API) |
| **CosyVoice Native** | Local CosyVoice inference server |
| **OpenAI Chat Completions TTS** | Models that emit audio via the chat completions endpoint |
| **Windows System TTS** | Windows SAPI voices — no server needed |

Fill in the fields for the selected provider:

- **Base URL** — e.g. `http://localhost:8880/v1` for a local OpenAI-compatible server, or `eastus` / `https://eastus.tts.speech.microsoft.com` for Azure.
- **API Key** — leave blank if your server doesn't require one.
- **Default Model Name** — for GPT-SoVITS / CosyVoice; ignored for Azure/System TTS.

Click **Fetch** (or **Fetch All**) to pull the available models/voices from the provider and cache them locally. You can also add entries manually with **+ Add**.

Click **Save**, then flip the toggle on the provider row to **enable** it. Run **Health Check** to confirm connectivity.

<div align="center">
  <img src="assets/images/screenshot_providers.png" alt="Providers screen" width="860" />
</div>

---

### 2. Create Voice Characters

Go to the **Voice Characters** tab.

Click **+ New Character** → fill in:

- **Name** — display name shown throughout the app.
- **Provider** — select an enabled provider.
- **Task Mode** — determines which fields appear:
  - *Preset Voice* — pick a voice from the provider's voice list (e.g. `alloy`, `en-US-AriaNeural`).
  - *Voice Clone with Prompt* — upload a reference audio clip + prompt text for models that support voice cloning (GPT-SoVITS, CosyVoice).
  - *Voice Design* — free-form instruction sent to models that accept a `voice_instruction` (e.g. MiMo v2 TTS, chat-completions TTS).
- **Speed** — synthesis speed multiplier (0.5 – 2.0).
- **Avatar** — optional image shown in chat bubbles.

Click **Save Character**.

---

### 3. Build a Voice Bank

Go to the **Voice Banks** tab.

Click **+ New Bank** → give it a name → then drag characters from the right panel into the bank, or click **Add to Bank** on any character row.

Click **Set Active** on the bank you want to use. Only one bank can be active at a time (the active bank feeds Quick TTS and Dialog TTS).

---

### 4. Quick TTS

Go to the **Quick TTS** tab.

1. Select a character from the left panel (voices from the active bank).
2. Type text in the input bar at the bottom.
3. Click the **generate** button (✨). Audio is synthesised, saved to disk, and played back automatically.
4. Previous generations appear as history cards with a waveform and duration. Click ▶ to replay any entry.
5. Use **Delete All** (top-right) to clear the history.

<div align="center">
  <img src="assets/images/screenshot_quick_tts.png" alt="Quick TTS screen" width="860" />
</div>

---

### 5. Dialog TTS

Go to the **Dialog TTS** tab. This screen is for producing multi-character audio like game dialogue or dub scripts.

#### Create a project

Click **New Project** → enter a name and choose a Voice Bank → click **Create**.

#### Add dialog lines

In the input bar (bottom of the right pane):

1. Pick a character from the **Voice** dropdown.
2. Type the line text.
3. Click **Send** (→). The line appears as a chat bubble.

Repeat for each line, switching characters as needed.

#### Generate audio

Click **Generate All** to synthesise every line that has no audio yet. Lines are processed in order; errors are shown as a red badge on the bubble.

Click ▶ on any bubble to play its audio. The waveform animates with a progress indicator and elapsed/total time.

<div align="center">
  <img src="assets/images/screenshot_dialog_tts.png" alt="Dialog TTS screen" width="860" />
</div>

---

### 6. Phase TTS

Go to the **Phase TTS** tab. This screen is for long narrations or audiobook-style content.

1. **Create a project** → paste your full script into the text area.
2. Use the **Split** button to divide the script into segments (splits on blank lines or sentence boundaries).
3. Review and edit individual segments.
4. Click **Generate All** to batch-synthesise every segment using the characters assigned to each one.
5. Export or copy the resulting audio files from the output directory shown in the status bar.

---

### 7. API Server

Neiroha exposes a local HTTP server so external tools (games, DAWs, scripts) can call TTS via a standard OpenAI-compatible interface.

#### Start the server

Open **Settings** → toggle **API Server** on. The default port is **8976**.

#### Endpoints

| Method | Path | Description |
|---|---|---|
| `POST` | `/v1/audio/speech` | Synthesise speech (OpenAI-compatible) |
| `GET` | `/v1/audio/voices` | List available voice characters |
| `GET` | `/v1/models` | List available providers/models |
| `GET` | `/speakers` | Alias for voices list |
| `GET` | `/health` | Health check — returns `{"status":"ok"}` |

#### Example request

```bash
curl http://localhost:8976/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Default Bank",
    "voice": "Default Voice",
    "input": "Hello, world!",
    "response_format": "wav",
    "speed": 1.0
  }' \
  --output hello.wav
```

**Fields:**

| Field | Type | Required | Notes |
|---|---|---|---|
| `input` | string | yes | Text to synthesise |
| `voice` | string | yes | Character name as configured in Voice Characters |
| `model` | string | no | Voice Bank name to scope the voice lookup; omit to search globally |
| `response_format` | string | no | `wav` (default), `mp3`, `ogg`, `opus`, `pcm` |
| `speed` | number | no | 0.5 – 2.0, default `1.0` |

The response body is the raw audio bytes with the appropriate `Content-Type` header.

---

## Supported Provider Reference

### OpenAI TTS API Compatible

Works with any server that implements `POST /v1/audio/speech`.

```
Base URL: http://localhost:8880/v1
API Key:  (server-specific, or blank)
Model:    tts-1  (or tts-1-hd, kokoro, etc.)
```

### OpenAI Chat Completions TTS

Works with any model that returns audio via the Chat Completions endpoint (e.g. MiMo v2 TTS).

### Azure Speech Service

```
Base URL: eastus              ← bare region name
          — OR —
          https://eastus.tts.speech.microsoft.com
API Key:  <Ocp-Apim-Subscription-Key>
```

Use **Fetch** to pull the full list of Azure Neural voices (~400+). Pick one as the preset voice on your character.

### GPT-SoVITS

```
Base URL: http://127.0.0.1:9880
```

Set **Default Model Name** to the GPT-SoVITS model path or leave blank to use the server default. Characters should use *Voice Clone with Prompt* mode, with a reference `.wav` and matching transcript text.
Related repo: [GPT-SoVITS](https://github.com/RVC-Boss/GPT-SoVITS)

### CosyVoice

```
Base URL: http://127.0.0.1:9880
```

Compatible with the CosyVoice inference server. Users need to upload audio to configure the voice cloning service. See [CosyVoiceDesktop](https://github.com/Moeary/CosyVoiceDesktop) for a companion GUI.

### Windows System TTS

No URL or key required. Fetches installed SAPI voices automatically. Characters use *Preset Voice* mode.

---

## Data Storage

All settings, characters, banks, and history are stored in a SQLite database at:

```
%APPDATA%\com.neiroha.neiroha\neiroha.db
```

Generated audio files are stored under:

```
%APPDATA%\com.neiroha.neiroha\quick_tts\      ← Quick TTS outputs
%APPDATA%\com.neiroha.neiroha\dialog_tts\     ← Dialog TTS outputs
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Health Check fails | Verify the Base URL is reachable and the API key is correct |
| No voices shown in Quick TTS | Activate a Voice Bank that contains at least one enabled character |
| Audio plays but shows `--:--` duration | Normal on first play — duration updates automatically after the first playback |
| `Platform channel threading` warning in logs | Fixed in this build — temporary AudioPlayer instances are no longer created |
