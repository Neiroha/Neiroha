# Plan

This file is the single active backlog for Neiroha. Historical notes live in
[`archive/`](archive/), research and long-form design notes live in
[`research/`](research/), and confirmed defects live in [`bugs.md`](bugs.md).

Last organized: 2026-04-29.

## Current Focus

### 1. LLM Role Assignment For Phase TTS

Goal: turn long-form text into speaker-aware Phase TTS segments.

- Add an LLM provider/model picker in Provider or Settings.
- Build the Role Assign dialog:
  - run role assignment from the current script;
  - show segment text, category, speaker label, confidence, suggested voice;
  - let the user override speaker-to-voice mappings before applying.
- Add the Phase TTS left/right redesign:
  - original text / segmented view toggle;
  - character mapping panel;
  - apply mappings to segment voice assignments.
- Decide whether to add `speakerLabel` to `phase_tts_segments`.
  Current milestone keeps LLM segment labels in memory and stores only
  character-to-voice mapping in `role_mapping.json`.

References:

- [`research/mimo-llm-asr-architecture.md`](research/mimo-llm-asr-architecture.md)
- [`research/llm-tts-adapter-guide.md`](research/llm-tts-adapter-guide.md)

## Next Implementation Queue

### 2. Fix Open Issues

Use [`bugs.md`](bugs.md) as the source of truth. Clear P0/P1 issues before
starting new UI work, especially the LLM config and role-assignment alignment
issues.

### 3. Phase TTS UX Follow-Ups

- Add bulk reassignment by detected speaker.
- Add manual segment editing after auto-split or LLM segmentation.
- Add regenerate options:
  - only missing audio;
  - regenerate selected speaker;
  - regenerate all.
- Add export options for generated Phase TTS audio:
  - merged audio;
  - per-segment folder;
  - manifest with segment order, speaker, voice, and file path.

### 4. Dialog TTS Follow-Ups

- Add export:
  - merged conversation audio;
  - per-line folder export;
  - optional silence gap between lines.
- Add speaker/voice usage stats.
- Add bulk voice reassignment for selected lines or speaker.

### 5. Video Dub Follow-Ups

- Keep Video Dub scoped as a single-video dubber.
- Finish export/playback rough edges listed in [`bugs.md`](bugs.md).
- Add cue overlap warnings.
- Add edit-cue auto-regeneration.
- Add A3 imported-audio preview playback.

### 6. Voice Asset / Dataset Workflow

- Build an audio dataset review surface:
  - generated/imported audio list;
  - editable transcript;
  - quality checkbox/status;
  - export dataset manifest.
- Add pronunciation dictionary support.
- Add lightweight post-processing options such as volume normalization,
  EQ presets, and optional reverb.

## Documentation Policy

- Root `docs/` should stay small:
  - `plan.md` for active work;
  - `bugs.md` for defects;
  - `api.md` / `api-zh.md` for public API reference.
- Completed session notes go to `docs/archive/`.
- Research, architecture, and long-form design notes go to `docs/research/`.
- Do not add new one-off root markdown files unless they are meant to become
  one of the root entry points above.
