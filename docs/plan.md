# Plan

This file is the single active backlog for Neiroha. Historical notes live in
[`archive/`](archive/), research and long-form design notes live in
[`research/`](research/), and confirmed defects live in [`bugs.md`](bugs.md).

Last organized: 2026-05-14.

## Current Focus

### 1. Documentation And Release Readiness

Goal: keep the public docs aligned with the actual app before adding another
large surface.

- README / README_zh should describe Novel Reader, Video Dub, Settings Tasks,
  API log output, API security defaults and storage layout.
- `docs/api.md` and `docs/api-zh.md` should mirror the local API server's
  current host/auth/CORS/rate-limit/body-limit behavior.
- `docs/bugs.md` should track only current risks. Fixed API-server security and
  database-boundary issues should stay in the "Recently Fixed" section.
- Database migration compatibility is intentionally out of scope until the app
  has a stable public release.

### 2. Task System V2

Goal: evolve the current in-memory TTS queue into a durable task system.

- Use `TtsJobs` as the persistent job surface for API and GUI work.
- Add cancel/retry/history semantics for generated takes.
- Expose job endpoints:
  - `POST /v1/jobs`
  - `GET /v1/jobs/:id`
  - `DELETE /v1/jobs/:id`
  - `POST /v1/jobs/:id/retry`
  - optional `GET /v1/jobs/:id/events`
- Extend Settings > Tasks with cancellation, retry and fuller failure details.

## Next Implementation Queue

### 3. Fix Open Issues

Use [`bugs.md`](bugs.md) as the source of truth. Clear P0/P1 issues before
starting large new UI work.

### 4. Video Dub Polish

- Match export behavior to preview for A1 coverage gating.
- Scan missing video/audio/subtitle assets when opening a project.
- Add cue overlap warnings.
- Add edit-cue auto-regeneration.
- Add A3 imported-audio preview playback.

### 5. Phase TTS / Dialog TTS Export Follow-Ups

- Phase TTS:
  - merged audio export;
  - per-segment folder export;
  - manifest with segment order, speaker, voice and file path.
- Dialog TTS:
  - merged conversation audio;
  - per-line folder export;
  - configurable silence gap between lines.

### 6. LLM Role Assignment For Phase TTS

Goal: turn long-form text into speaker-aware Phase TTS segments.

- Add an LLM provider/model picker in Provider or Settings.
- Build the Role Assign dialog:
  - run role assignment from the current script;
  - show segment text, category, speaker label, confidence and suggested voice;
  - let the user override speaker-to-voice mappings before applying.
- Add the Phase TTS left/right redesign:
  - original text / segmented view toggle;
  - character mapping panel;
  - apply mappings to segment voice assignments.
- Use `speakerLabel` on `phase_tts_segments` where useful; the column already
  exists.

References:

- [`research/mimo-llm-asr-architecture.md`](research/mimo-llm-asr-architecture.md)
- [`research/llm-tts-adapter-guide.md`](research/llm-tts-adapter-guide.md)

### 7. Voice Asset / Dataset Workflow

- Build an audio dataset review surface:
  - generated/imported audio list;
  - editable transcript;
  - quality checkbox/status;
  - export dataset manifest.
- Add pronunciation dictionary support.
- Add lightweight post-processing options such as volume normalization,
  EQ presets and optional reverb.

## Refactor Queue

Large files that should be split before heavy feature work:

- `lib/presentation/screens/novel_reader_screen.dart`
- `lib/presentation/screens/settings_screen.dart`
- `lib/presentation/screens/video_dub_screen.dart`
- `lib/presentation/screens/provider_screen.dart`
- `lib/presentation/screens/voice_bank_screen.dart`

Prefer extracting services/controllers and focused widgets instead of adding
more screen-local state.

## Documentation Policy

- Root `docs/` should stay small:
  - `plan.md` for active work;
  - `bugs.md` for defects;
  - `api.md` / `api-zh.md` for public API reference.
- Completed session notes go to `docs/archive/`.
- Research, architecture and long-form design notes go to `docs/research/`.
- Do not add new one-off root markdown files unless they are meant to become
  one of the root entry points above.
