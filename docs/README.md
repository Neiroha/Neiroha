# Neiroha Docs

This directory keeps active product notes small and current. Historical session
notes and long-form research are intentionally separated so the root docs do not
turn into a second backlog.

Last organized: 2026-05-16.

## Active Documents

| File | Purpose |
|---|---|
| [`plan.md`](plan.md) | Current implementation queue and refactor priorities |
| [`bugs.md`](bugs.md) | Confirmed defects and known product risks |
| [`api.md`](api.md) | English local API and adapter reference |
| [`api-zh.md`](api-zh.md) | Chinese local API and adapter reference |

## Platform Scope

Neiroha currently treats platform support as product capabilities, not as a
promise that every screen can run every native feature everywhere.

| Platform | Current scope |
|---|---|
| Windows | Primary desktop target. Windows SAPI and external FFmpeg CLI are available. |
| Linux / macOS | Desktop target shape. External FFmpeg CLI is supported when installed/configured; platform-native system TTS is not implemented yet. |
| Android phone/tablet | UI and TTS client workflows are supported. Local FFmpeg muxing, trimming, waveform extraction and video export are disabled. |
| Web | UI/path-selection surface only for now. Full local file persistence, FFmpeg, and native filesystem workflows are out of scope. |

System TTS is currently implemented only for Windows SAPI. Do not expose Android,
Apple, Linux, or Web system TTS in the UI until native platform adapters exist.

## Archive And Research

- [`archive/`](archive/) contains dated implementation notes and old review
  records. These are historical, not active requirements.
- [`research/`](research/) contains long-form backend/API research that is still
  useful as reference material.
- Old one-off UI brainstorms that were already absorbed into `plan.md` have
  been removed to keep research focused.

## Maintenance Rules

- Update `plan.md` when a feature moves into or out of the active queue.
- Update `bugs.md` only for confirmed issues or concrete risks.
- Keep `api.md` and `api-zh.md` aligned whenever endpoint behavior changes.
- Put dated session notes in `archive/`, not in the docs root.
- Prefer linking to source files for implementation truth; docs should describe
  behavior and decisions, not duplicate entire code paths.
