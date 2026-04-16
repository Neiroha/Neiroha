# How to Add a New LLM TTS Backend to Neiroha

**Audience:** An LLM (or developer) implementing a new upstream TTS adapter from scratch.  
**Scope:** Voice clone mode, instruct mode, and preset/design mode for any local or cloud LLM TTS server.

Read this document **fully before touching any code**. The system has several interdependent
touch points and missing one causes silent failures or incorrect UI.

---

## 1. Mental Model — The Three Synthesis Modes

Every LLM TTS backend maps to one or more of three universal modes. Neiroha tracks this via the
`TaskMode` enum (`lib/domain/enums/task_mode.dart`):

| `TaskMode` | When to use | Typical backend term |
|---|---|---|
| `cloneWithPrompt` | User supplies a reference audio sample to copy a voice | zero_shot, clone, voice clone |
| `voiceDesign` | User writes a text instruction that shapes the voice style | instruct, instruction, style control |
| `presetVoice` | Backend has named built-in voices; user picks by name | preset, speaker, voice ID |

A backend can support multiple modes simultaneously. CosyVoice supports all three. GPT-SoVITS
supports only clone. Many cloud TTS APIs support only preset.

---

## 2. Data Flow

```
VoiceAsset (SQLite)
  ├── providerId        →  TtsProvider  →  createAdapter()  →  YourAdapter
  ├── modelName         →  passed as modelName param to adapter constructor
  ├── taskMode          →  "cloneWithPrompt" | "voiceDesign" | "presetVoice"
  ├── refAudioPath      →  TtsRequest.refAudioPath   (clone modes)
  ├── promptText        →  TtsRequest.promptText     (clone mode transcript)
  ├── promptLang        →  TtsRequest.promptLang     (language code)
  ├── voiceInstruction  →  TtsRequest.voiceInstruction  (instruct mode)
  └── presetVoiceName   →  TtsRequest.presetVoiceName   (preset mode voice ID)
```

`TtsRequest` is the unified payload (defined in `lib/data/adapters/tts_adapter.dart`):

```dart
class TtsRequest {
  final String  text;
  final String  voice;           // asset.presetVoiceName ?? asset.name
  final double  speed;           // 0.5 – 2.0
  final String? responseFormat;  // "wav" | "mp3" | "flac" | null
  final String? refAudioPath;    // absolute local path to ref audio file
  final String? promptText;      // transcript of the ref audio
  final String? promptLang;      // "zh" | "en" | "ja" | …
  final String? textLang;        // output language (GPT-SoVITS)
  final String? voiceInstruction;// instruct / style text
  final String? presetVoiceName; // named preset speaker
}
```

---

## 3. Touch Points (all must be updated)

| # | File | What to change |
|---|---|---|
| 1 | `lib/data/adapters/<name>_adapter.dart` | Create new adapter class |
| 2 | `lib/domain/enums/adapter_type.dart` | Add enum value + capability getters |
| 3 | `lib/data/adapters/tts_adapter.dart` | Register in `createAdapter()` factory |
| 4 | `lib/presentation/screens/voice_character_screen.dart` | Add UI branch for the new adapter |
| 5 | `lib/data/database/app_database.dart` | Add seed provider (optional, for bundled defaults) |

---

## 4. Step-by-Step

### Step 1 — Create the adapter class

Create `lib/data/adapters/<your_backend>_adapter.dart`.

```dart
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'tts_adapter.dart';

/// Adapter for <YourBackend>.
///
/// Synthesis modes:
///   cloneWithPrompt  → POST /tts/clone      (refAudioPath + promptText)
///   voiceDesign      → POST /tts/instruct   (voiceInstruction)
///   presetVoice      → POST /tts/generate   (presetVoiceName)
class YourBackendAdapter extends TtsAdapter {
  final String baseUrl;
  final String apiKey;
  // Use modelName to store the synthesis mode when the backend has
  // no separate "model" concept (same pattern as CosyVoice).
  final String modelName;
  late final Dio _dio;

  YourBackendAdapter({
    required this.baseUrl,
    required this.apiKey,
    this.modelName = '',
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
      headers: {
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      },
      responseType: ResponseType.bytes,
    ));
  }

  // ── Synthesize ──────────────────────────────────────────────────────────────

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    // Route by mode. If your backend infers mode from fields, skip routing.
    if (request.refAudioPath != null && request.refAudioPath!.isNotEmpty) {
      return _cloneMode(request);
    }
    if (request.voiceInstruction != null &&
        request.voiceInstruction!.isNotEmpty) {
      return _instructMode(request);
    }
    return _presetMode(request);
  }

  // ── Clone mode (zero_shot / voice clone) ────────────────────────────────────

  Future<TtsResult> _cloneMode(TtsRequest request) async {
    // Example: multipart upload. Adjust to your API.
    final formData = FormData.fromMap({
      'text': request.text,
      'speed': request.speed,
      'response_format': request.responseFormat ?? 'wav',
      'prompt_audio': await MultipartFile.fromFile(request.refAudioPath!),
      if (request.promptText != null && request.promptText!.isNotEmpty)
        'prompt_text': request.promptText,
      if (request.promptLang != null && request.promptLang!.isNotEmpty)
        'prompt_lang': request.promptLang,
    });
    try {
      final resp = await _dio.post('tts/clone', data: formData);
      return TtsResult(
        audioBytes: Uint8List.fromList(resp.data as List<int>),
        contentType: resp.headers.value('content-type') ?? 'audio/wav',
      );
    } on DioException catch (e) {
      throw Exception('Clone synthesis failed — ${_errMsg(e)}');
    }
  }

  // ── Instruct mode ───────────────────────────────────────────────────────────

  Future<TtsResult> _instructMode(TtsRequest request) async {
    // Example: JSON body. Adjust to your API.
    final body = {
      'text': request.text,
      'instruct': request.voiceInstruction,
      'speed': request.speed,
      'format': request.responseFormat ?? 'wav',
      if (request.refAudioPath != null && request.refAudioPath!.isNotEmpty)
        'ref_audio': request.refAudioPath,
    };
    try {
      final resp = await _dio.post('tts/instruct', data: body);
      return TtsResult(
        audioBytes: Uint8List.fromList(resp.data as List<int>),
        contentType: resp.headers.value('content-type') ?? 'audio/wav',
      );
    } on DioException catch (e) {
      throw Exception('Instruct synthesis failed — ${_errMsg(e)}');
    }
  }

  // ── Preset mode ─────────────────────────────────────────────────────────────

  Future<TtsResult> _presetMode(TtsRequest request) async {
    final body = {
      'text': request.text,
      'voice': request.presetVoiceName ?? request.voice,
      'speed': request.speed,
      'format': request.responseFormat ?? 'wav',
    };
    try {
      final resp = await _dio.post('tts/generate', data: body);
      return TtsResult(
        audioBytes: Uint8List.fromList(resp.data as List<int>),
        contentType: resp.headers.value('content-type') ?? 'audio/wav',
      );
    } on DioException catch (e) {
      throw Exception('Preset synthesis failed — ${_errMsg(e)}');
    }
  }

  // ── Health check ─────────────────────────────────────────────────────────────

  @override
  Future<bool> healthCheck() async {
    try {
      final resp = await _dio.get(
        'health',
        options: Options(responseType: ResponseType.json),
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Speaker list (preset voices) ─────────────────────────────────────────────

  @override
  Future<List<String>> getSpeakers() async {
    try {
      final resp = await _dio.get(
        'voices',
        options: Options(responseType: ResponseType.json),
      );
      if (resp.statusCode == 200 && resp.data is List) {
        return (resp.data as List)
            .map((e) => e is Map
                ? (e['name'] ?? e['id'] ?? e.toString()).toString()
                : e.toString())
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Error helper ─────────────────────────────────────────────────────────────

  String _errMsg(DioException e) {
    final raw = e.response?.data;
    if (raw != null) {
      try {
        // dart:convert must be imported at the top of the file
        return 'HTTP ${e.response?.statusCode}: ${utf8.decode(raw as List<int>)}';
      } catch (_) {}
    }
    return 'HTTP ${e.response?.statusCode ?? '?'}';
  }
}
```

> **Error decoding:** Always import `dart:convert` and UTF-8 decode the raw bytes in
> DioException so users see meaningful error messages in the Quick TTS history.

---

### Step 2 — Register the enum value

Edit `lib/domain/enums/adapter_type.dart`.

Add the new value and update **all five** switch expressions:

```dart
enum AdapterType {
  openaiCompatible,
  gptSovits,
  cosyvoice,
  chatCompletionsTts,
  azureTts,
  systemTts,
  yourBackend;        // ← add here

  String get displayName => switch (this) {
    // …existing cases…
    yourBackend => 'Your Backend Name',
  };

  String get defaultModel => switch (this) {
    // …existing cases…
    yourBackend => '',   // or the default model ID if applicable
  };

  bool get supportsModelQuery => switch (this) {
    // Set true if the backend has a GET /models endpoint.
    yourBackend => false,
    // …existing cases…
    _ => false,
  };

  bool get supportsVoiceQuery => switch (this) {
    // Set true if getSpeakers() returns a meaningful list.
    yourBackend => true,   // adjust
    // …existing cases…
    _ => false,
  };

  bool get hasSeparateModelAndVoice => switch (this) {
    // Set true ONLY if the backend has BOTH a "model" (inference engine) AND
    // a "voice" (speaker identity) as separate concepts (like OpenAI TTS).
    yourBackend => false,  // most LLM TTS backends: false
    // …existing cases…
    _ => false,
  };

  bool get showDefaultModelField => switch (this) {
    // Set false if you use modelName to store something else (e.g. the mode).
    yourBackend => false,  // adjust
    // …existing cases…
    _ => true,
  };
}
```

**Capability guide:**

| Your backend uses… | Set these getters |
|---|---|
| Named presets only | `supportsVoiceQuery=true`, others false |
| Clone from uploaded ref audio | `supportsVoiceQuery=false`, `supportsModelQuery=false` |
| Separate model + voice (like OpenAI) | `hasSeparateModelAndVoice=true`, both query=true |
| modelName stores synthesis mode | `showDefaultModelField=false` |

---

### Step 3 — Register in the factory

Edit `lib/data/adapters/tts_adapter.dart`, add a `case` to `createAdapter()`:

```dart
TtsAdapter createAdapter(db.TtsProvider provider, {String? modelName}) {
  final model = modelName ?? provider.defaultModelName;
  switch (provider.adapterType) {
    // …existing cases…
    case 'yourBackend':
      return YourBackendAdapter(
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        modelName: model,
      );
    default:
      throw UnimplementedError(
          'Adapter not implemented for: ${provider.adapterType}');
  }
}
```

Also add the import at the top of `tts_adapter.dart`:
```dart
import 'package:neiroha/data/adapters/your_backend_adapter.dart';
```

---

### Step 4 — Add UI in voice_character_screen

Open `lib/presentation/screens/voice_character_screen.dart`.

#### 4a — Add a getter to `_CreateCharacterDialogState`

```dart
// Near _isCosyVoice / _isGptSovits
bool get _isYourBackend => _adapterType == 'yourBackend';
```

#### 4b — Branch in the adapter-specific options section

Find the big `if (_isPresetVoiceProvider) … else if (_isCosyVoice) … else if (_isGptSovits) …`
block. Add your backend as a new branch **before** the final `else` fallback:

```dart
} else if (_isYourBackend) ...[
  // ── Your Backend UI ──────────────────────────────────────────────────────

  // MODE SELECTOR
  // Only include mode options that your backend actually supports.
  _SectionLabel('SYNTHESIS MODE'),
  const SizedBox(height: 8),
  _YourBackendModeSelector(        // see §4c
    selected: _cosyVoiceMode,      // reuse _cosyVoiceMode state field, or add your own
    onChanged: (mode) {
      setState(() {
        _cosyVoiceMode = mode;
        // Map backend mode → TaskMode
        if (mode == 'clone') {
          _taskMode = TaskMode.cloneWithPrompt;
        } else if (mode == 'instruct') {
          _taskMode = TaskMode.voiceDesign;
        } else {
          _taskMode = TaskMode.presetVoice;
        }
      });
    },
  ),
  const SizedBox(height: 20),

  if (_cosyVoiceMode == 'clone') ...[
    // CLONE MODE — requires ref audio
    ..._buildRefAudioPicker(),
    TextField(
      controller: _promptTextCtrl,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Prompt Text (transcript of ref audio)',
      ),
    ),
    const SizedBox(height: 10),
    TextField(
      controller: _promptLangCtrl,
      decoration: const InputDecoration(
        labelText: 'Language Code',
        hintText: 'zh / en / ja …',
      ),
    ),
  ] else if (_cosyVoiceMode == 'instruct') ...[
    // INSTRUCT MODE
    TextField(
      controller: _instructionCtrl,
      maxLines: 4,
      decoration: const InputDecoration(
        labelText: 'Voice Instruction *',
        hintText: 'e.g. "Speak softly and slowly"',
      ),
    ),
    const SizedBox(height: 12),
    // Optional ref audio for instruct (some backends support it)
    _SectionLabel('REFERENCE AUDIO (optional)'),
    const SizedBox(height: 8),
    ..._buildRefAudioPicker(),
  ] else if (_cosyVoiceMode == 'preset') ...[
    // PRESET MODE
    ..._buildSpeakerPicker(label: 'Select Voice'),
    TextField(
      controller: _voiceNameCtrl,
      decoration: const InputDecoration(
        labelText: 'Voice Name',
        hintText: 'e.g. "default", "female_1"',
      ),
    ),
  ],
],
```

#### 4c — Mode selector widget (optional)

If your backend has ≥2 modes, build a small mode selector widget (like `_CosyVoiceModeSelector`).
If only one mode exists, skip the selector and hard-code `_taskMode` in `initState`.

```dart
class _YourBackendModeSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onChanged;
  const _YourBackendModeSelector({required this.selected, required this.onChanged});

  static const _modes = [
    ('clone',   Icons.mic_rounded,         'Clone',   'Clone from\nreference audio'),
    ('instruct',Icons.text_fields_rounded,  'Instruct','Control style\nvia instruction'),
    ('preset',  Icons.library_music_rounded,'Preset',  'Use a built-in\nvoice'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _modes.mapIndexed((index, rec) {
        final (mode, icon, label, hint) = rec;
        final isSelected = selected == mode;
        final isLast = index == _modes.length - 1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 8),
            child: InkWell(
              onTap: () => onChanged(mode),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isSelected
                      ? AppTheme.accentColor.withValues(alpha: 0.15)
                      : AppTheme.surfaceDim,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentColor.withValues(alpha: 0.5)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20,
                        color: isSelected
                            ? AppTheme.accentColor
                            : Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(height: 6),
                    Text(label,
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.7))),
                    const SizedBox(height: 4),
                    Text(hint,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.4))),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
```

#### 4d — Validation in `_save()`

Add validation for your backend inside the `needsRefAudio` check (around line 1246):

```dart
final needsRefAudio = _isGptSovits ||
    (_isCosyVoice && _cosyVoiceMode == 'zero_shot') ||
    (_isCosyVoice && _cosyVoiceMode == 'cross_lingual' && _voiceNameCtrl.text.trim().isEmpty) ||
    (_isYourBackend && _cosyVoiceMode == 'clone');  // ← add
```

#### 4e — `modelName` in `_save()`

In the `VoiceAssetsCompanion` built inside `_save()`, the `modelName:` value assignment looks like:

```dart
modelName: Value(_isGptSovits
    ? (textLang)
    : (_adapterType == 'openaiCompatible' || _adapterType == 'chatCompletionsTts')
        ? (_modelNameCtrl.text.trim().isEmpty ? null : _modelNameCtrl.text.trim())
        : _isCosyVoice
            ? _cosyVoiceMode
            : null),
```

Extend the chain to store the mode for your backend too:

```dart
modelName: Value(_isGptSovits
    ? (textLang)
    : (_adapterType == 'openaiCompatible' || _adapterType == 'chatCompletionsTts')
        ? (_modelNameCtrl.text.trim().isEmpty ? null : _modelNameCtrl.text.trim())
        : _isCosyVoice
            ? _cosyVoiceMode
            : _isYourBackend
                ? _cosyVoiceMode   // stores 'clone' | 'instruct' | 'preset'
                : null),
```

---

### Step 5 — Seed a default provider (optional)

If you want the backend to appear pre-configured in the Providers list open
`lib/data/database/app_database.dart` and find the `_seedDefaultProviders` method. Add an entry:

```dart
db.TtsProvidersCompanion(
  id: const Value('your-backend-default'),
  name: const Value('Your Backend'),
  adapterType: const Value('yourBackend'),
  baseUrl: const Value('http://127.0.0.1:YOUR_PORT'),
  apiKey: const Value(''),
  defaultModelName: const Value(''),
  enabled: const Value(false),
  position: const Value(7),   // one more than the last seeded provider
),
```

Bump the schema version constant and add a migration step if needed.

---

## 5. Patterns Reference

### Pattern A — Clone-only backend (F5-TTS, E2-TTS)

- `hasSeparateModelAndVoice = false`, `supportsVoiceQuery = false`
- `modelName` unused (no mode concept; every request is a clone)
- UI: always show ref audio picker + prompt text; no mode selector
- `_taskMode` hard-coded to `TaskMode.cloneWithPrompt` at provider selection time

### Pattern B — Preset-only backend (Cloud TTS, Kokoro)

- `hasSeparateModelAndVoice = false`, `supportsVoiceQuery = true`
- `modelName` stores the model ID if backend has multiple models
- UI: speaker picker (fetched from `getSpeakers()`) + optional text field
- `_taskMode` hard-coded to `TaskMode.presetVoice`

### Pattern C — Multi-mode backend (CosyVoice, Fish Speech)

- `hasSeparateModelAndVoice = false`, `supportsVoiceQuery = false`, `showDefaultModelField = false`
- `modelName` stores the selected mode string (`zero_shot` / `instruct` / etc.)
- UI: mode selector + per-mode fields (ref audio, prompt text, instruct text)
- `_taskMode` set dynamically from the selected mode

### Pattern D — Model + Voice backend (OpenAI TTS, cloud APIs)

- `hasSeparateModelAndVoice = true`, `supportsModelQuery = true`, `supportsVoiceQuery = true`
- `modelName` stores the model ID; `presetVoiceName` stores the voice name
- UI: separate model picker + voice picker (both with search + chip cache)
- `_taskMode` hard-coded to `TaskMode.presetVoice`

---

## 6. Key Invariants — Do Not Break

1. **Never send a `profile` / `character_name` / `speaker` field in multipart upload requests**
   unless you have verified the name exists on the server. Server-side strict lookup causes 400.

2. **`TtsRequest.voice`** is always set to `asset.presetVoiceName ?? asset.name`. Adapters that
   don't use preset voices should ignore it and read mode-specific fields instead.

3. **`createAdapter()` receives `modelName: asset.modelName`**. For multi-mode backends, the
   `modelName` carries the synthesis mode; the adapter constructor must store it and use it in
   `synthesize()`.

4. **`TaskMode` drives the _character list labels_ in Quick TTS / Phase TTS / Dialog TTS**.
   Always set `_taskMode` accurately in the character dialog so users see "Voice Clone",
   "Voice Design", or "Preset Voice" against each character.

5. **`response_format`** defaults to `"wav"` when null. Return `TtsResult.contentType` accurately
   (`audio/wav`, `audio/mpeg`, etc.) — the audio player selects the decoder based on it.

6. **Health check** is called from the Voice Bank screen's "Health Check" button and from the
   Provider editor. It must return `true` (server alive) or `false` (unreachable), never throw.

---

## 7. Checklist

Before submitting your implementation:

- [ ] Adapter class created in `lib/data/adapters/`
- [ ] All three mode methods implemented (or stubs that throw `UnimplementedError` with a message)
- [ ] `healthCheck()` returns bool, never throws
- [ ] `getSpeakers()` returns empty list (not null) when not applicable
- [ ] Enum value added with all 5 switch cases updated
- [ ] Factory case added in `createAdapter()`
- [ ] Import added in `tts_adapter.dart`
- [ ] UI branch added in `voice_character_screen.dart`
- [ ] `_taskMode` set correctly for each mode
- [ ] `modelName` stored correctly in `_save()` if backend uses it for mode routing
- [ ] Validation in `needsRefAudio` check updated
- [ ] `flutter analyze lib/` passes with no errors
- [ ] Quick TTS smoke test: create a character → generate audio → verify no error in history card
