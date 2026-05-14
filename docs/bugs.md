# Bugs And Risks

Confirmed or likely defects are tracked here so review notes do not scatter
across root-level docs.

Last organized: 2026-05-14.

## P0 / P1

### Async Job Queue Is Still In-Memory

Files:

- `lib/data/services/tts_queue_service.dart`
- `lib/data/database/tables.dart` (`TtsJobs`)
- `lib/server/api_server.dart`

The shared TTS queue now enforces provider concurrency/rate limits and powers
the Settings task monitor, but it is still process-memory only. `TtsJobs`
exists in the schema, yet the API only exposes synchronous
`POST /v1/audio/speech`; there is no durable job API, cancel/retry endpoint,
progress persistence, or regenerated-take lineage.

Fix: add a durable job runner backed by `TtsJobs`, expose
`POST /v1/jobs`, `GET /v1/jobs/:id`, `DELETE /v1/jobs/:id`,
`POST /v1/jobs/:id/retry`, and optionally `GET /v1/jobs/:id/events`.
Because Neiroha has not shipped a stable release yet, schema/migration
compatibility is not a current blocker.

### LLM Chat Fallback Throws Raw DioException

File: `lib/data/adapters/llm_chat_adapter.dart`

If the first JSON-mode request fails due to `response_format`, the fallback
`_dio.post(...)` is not wrapped, so a `DioException` from the retry bubbles up
untyped instead of as `LlmChatException`.

Fix: wrap the fallback in the same try/catch path that the primary request
uses.

## P2

### Windows Open Folder Uses Broken Explorer Arguments

File: `lib/presentation/widgets/export_progress.dart`

`explorer.exe` needs `'/select,$filePath'` as one argument. Passing `/select,`
and the path separately opens the wrong location.

Fix:

```dart
await Process.run('explorer.exe', ['/select,$filePath']);
```

### Cancel During Process.start Can Race

File: `lib/presentation/widgets/export_progress.dart`

The cancel listener can fire before the process variable is assigned if the
user clicks Cancel while `Process.start` is still pending.

Fix: register the kill listener after `Process.start` resolves, or guard with a
nullable process plus cancelled flag.

### Video Dub Export Ignores A1 Coverage Gating

File: `lib/presentation/screens/video_dub_screen.dart`

Preview mutes V1 audio outside A1 coverage, but export still bakes V1 audio as
whole-or-nothing.

Fix: build an ffmpeg volume-enable chain from A1 clips and feed the gated audio
into the mix.

### Missing Media Scan Needs Video Dub Project-Open Coverage

Files:

- `lib/data/storage/storage_service.dart`
- `lib/presentation/screens/video_dub_screen.dart`

The global storage scan can mark timeline clips and archived audio rows, but
Video Dub should also run a focused scan when a project opens so missing video,
A1/A3 media and subtitle-generated audio are visible immediately.

Fix: scan Video Dub timeline rows and subtitle cue audio paths on project open.

## P3 / UX Risks

### Edit Cue Does Not Auto-Regenerate

File: `lib/presentation/screens/video_dub_screen.dart`

Editing a cue clears old audio but does not offer the same auto-TTS / auto-sync
flow as Add Cue.

### A3 Imported Audio Does Not Preview

File: `lib/presentation/screens/video_dub_screen.dart`

Imported A3 clips mix into export but do not play during preview/scrub.

### Cue Overlaps Are Easy To Create

File: `lib/presentation/screens/video_dub_screen.dart`

Import, drag, sync-length, and manual edits can create overlapping cues without
a warning.

### TTS Audio Can Overrun Cue Windows

File: `lib/presentation/screens/video_dub_screen.dart`

A cue whose generated audio is longer than its subtitle window keeps playing
until the next cue stops it. Sync length is post-hoc only.

### Provider / Model Helpers Are Duplicated

Files:

- `lib/presentation/screens/provider_screen.dart`
- voice creation dialog/widgets

TTS model-kind detection is duplicated and string-based.

Fix: extract a shared model-kind utility or persist model capabilities.

## Recently Fixed

- API server now defaults to loopback and has optional API key, CORS allowlist,
  request budget, body-size limit and in-app request logs.
- The shared TTS queue now enforces provider concurrency/rate limits across UI
  screens and the local API server.
- Settings includes a Tasks view for current queued/running TTS work.
- Novel Reader prefetch now uses concurrent workers instead of serial awaits.
- Voice Bank / Voice Asset delete paths now clean or block database boundaries
  for dependent rows.
- Unsupported SVG filters were removed from the logo asset, clearing the
  `flutter_svg` warning in widget tests.
