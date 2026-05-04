# Bugs And Risks

Confirmed or likely defects are tracked here so review notes do not scatter
across root-level docs.

Last organized: 2026-05-03.

## P0 / P1

### API Server Has No Auth or Network Boundary

File: `lib/server/api_server.dart`

The shelf server starts on `InternetAddress.anyIPv4` with no authentication,
no CORS allowlist, no rate limiting, and no body-size limit. Any host on the
LAN can hit `/v1/audio/speech` and run arbitrary TTS jobs against the local
provider keys.

Fix: bind `127.0.0.1` by default; add an optional API key middleware, an
explicit CORS origin allowlist, and a per-IP request budget. Surface the
config in the Settings screen.

### Async Job Queue Is Unimplemented

Files:

- `lib/data/database/tables.dart` (`TtsJobs`)
- `lib/server/api_server.dart`

`TtsJobs` exists in the schema but the API only offers synchronous
`POST /v1/audio/speech`. There is no queue worker, no progress reporting,
no cancel/retry, and no version history for regenerated takes — so any
client wanting Voicebox-style background jobs has to poll on its own.

Fix: add a job runner that drains pending `TtsJobs`, expose
`POST /v1/jobs`, `GET /v1/jobs/:id`, `DELETE /v1/jobs/:id`,
`POST /v1/jobs/:id/retry`, and an SSE stream at `GET /v1/jobs/:id/events`.
Schema needs `parentJobId` (for retry/regen lineage), `attempt`, `progress`,
and `version` columns.

### LLM Chat Fallback Throws Raw DioException

File: `lib/data/adapters/llm_chat_adapter.dart`

If the first JSON-mode request fails due to `response_format`, the fallback
`_dio.post(...)` at line 104 is not wrapped, so a `DioException` from the
retry bubbles up untyped instead of as `LlmChatException`.

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

### Missing Media Scan Does Not Mark Video Dub Rows

Files:

- `lib/data/storage/storage_service.dart`
- `lib/presentation/screens/video_dub_screen.dart`

`clip.missing` is not written for Video Dub timeline rows, and subtitle audio
paths are not checked on project open.

Fix: scan Video Dub clips and subtitle cue audio paths when opening a project.

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
