# Plan — Next Change

## Current state (2026-04-26, end of session)

The Video Dub editor is a **single-video dubber** (1V3A) with a
self-contained TTS + export workflow. Five passes landed in one long
session this date — see [`archive-2026-04-26.md`](archive-2026-04-26.md)
for the full surface area.

| Track | Lane | Source                         | Notes                                   |
| ----- | ---- | ------------------------------ | --------------------------------------- |
| V1    |  -1  | `TimelineClips` (`video`)      | exactly one clip, drives `videoPath`    |
| A1    |   1  | `TimelineClips` (`video-audio`)| linked to V1 by `linkGroupId`; mute toggle in track header + transport |
| A2    |  n/a | `SubtitleCues`                 | TTS cues; draggable on the lane         |
| A3    |   3  | `TimelineClips` (`imported`)   | free-form imported audio                |

**Top bar**: `[Back] [• Title] [voices] [Export Audio] [Export Video] [Save]`.
- **Save** persists `updatedAt` and stays in the editor (snackbar
  confirmation, no auto-exit).
- **Back** prompts on dirty state with Cancel / Don't save / Save & Exit.
- **Export Video** writes an MP4 + a sidecar `.srt` next to it.
- **Export Audio** writes a single mixed file in the user's chosen
  format (mp3 / wav / flac via ExportPrefs).
- Both exports show a modal progress dialog with Cancel + an
  "Export successful" dialog with **Open folder**.

**Subtitle pane header**: `Subtitles · Add cue · Add Subtitles · Export Subtitles · Clear`.
- **Add cue** opens a dialog with start/end/text + voice dropdown +
  optional **Auto-generate TTS** / **Auto-sync length** switches.
- **Add Subtitles** is the SRT/LRC bulk import; same auto switches,
  sticky across both flows.
- **Export Subtitles** writes `<project>.srt` + `tts/cue_NNN_…<ext>` +
  `manifest.tsv` into a chosen folder.

**Subtitle pane footer**: Sync cue lengths to TTS / Generate All
(stacked).

**Settings page** has an **Export Defaults** card with three dropdowns:
audio format (mp3 / wav / flac), video codec (copy / h264 / h265 /
av1), video audio codec (aac / mp3 / opus). Persisted in `AppSettings`
via `ExportPrefsService`.

The right-side subtitle pane is horizontally resizable
(`HorizontalResizableSplitPane`); the video/timeline split sits at
0.7 (more video, less timeline).

Schema still at v14; no DB changes this session.

---

## Shipped this session (2026-04-26)

### Pass 1 — Initial four follow-ups
- Export Video button (FFmpeg mux of V1 + cues + A3).
- Timeline V1 import → main video surface (`project.videoPath` is
  written on import).
- Batch subtitle + TTS folder export.
- A2 cue blocks horizontally draggable.

### Pass 2 — Simplification
- Dropped V2/image lane and `DubImportKind.image`.
- Single-video constraint on V1 (button disabled when occupied).
- A1 mute toggle in the track header.
- Toolbar redesign (popup → big buttons).
- Export-Video truncation fix (`amix duration=longest`, no `-shortest`).
- Audio-only WAV export.
- Vertical split top fraction 0.58 → 0.7.
- New `HorizontalResizableSplitPane` widget.
- Sync cue lengths to TTS.
- Generate All upgrade (Cancel / Only pending / Regenerate all).

### Pass 3 — Sidecar SRT + subtitle pane reshuffle
- Export Video writes a sidecar `.srt` alongside the MP4.
- SRT generation centralised in `_cuesToSrt`, reused by the batch
  exporter.
- Subtitle pane: full-width Export TTS+SRT button at top, Sync
  stacked above Generate All in the footer.
- SRT-import dialog gained sticky **Auto-TTS** + **Auto-sync** switches.
- `_generateAll` split into `_generateAll` (with confirm dialog) +
  `_runGenerateAll` (loop only) so the auto-flow doesn't show a
  redundant dialog.

### Pass 4 — Save UX + progress + ExportPrefs
- `_close` split into `_save` (persist + snackbar, stays in editor)
  and `_back` (dirty-confirm dialog).
- `_dirty` flag + `_markDirty()` helper sprinkled into every
  mutation path. Title bar shows `• ` when dirty.
- `runFfmpegWithProgress` (new shared widget): modal dialog with
  linear progress bar, parses `-progress pipe:1`, Cancel kills the
  child process.
- `showExportSuccessDialog` + `revealInFileManager` (Windows
  `explorer /select,`, macOS `open -R`, Linux `xdg-open` on parent).
- `ExportPrefs` (audio fmt + video/audio codec) with Settings card
  and provider, applied to both exports.
- Top-bar reorganisation that briefly carried Add Subtitles + Export
  Subtitles, partly reverted in Pass 5.

### Pass 5 — Add-cue auto-TTS + voice dropdown + race fix
- Add Subtitles + Export Subtitles moved back into subtitle pane
  header (right of `+` Add cue).
- Voice dropdown in the Add-cue dialog (driven by the bank's voices,
  defaulted to first), persisted via `_CueEdit.voiceAssetId`.
- Add-cue auto-flow chains insert → `_generateOne` → snap `endMs` to
  audio length, mirroring the SRT-import auto-flow.
- **Provider stream race fix** — `_generateOne` was reading an
  unwarmed `ttsProvidersStreamProvider`; first call returned `[]` and
  the function silently bailed. Now reads providers via
  `database.getAllProviders()`. No more "manually generate first" gotcha.

---

## Immediate next steps (in priority order)

### 1. Windows `explorer /select` arg-quoting fix — **trivial**

`revealInFileManager` passes `'/select,'` and `filePath` as separate
argv items. Process.run on Windows joins them with a space, so the
flag breaks and explorer opens at the default location. Fix is one
line:

```dart
await Process.run('explorer.exe', ['/select,$filePath']);
```

**Files**: `lib/presentation/widgets/export_progress.dart`.

### 2. Cancel-during-Process.start race in `runFfmpegWithProgress`

`process` is `late Process` and assigned only after `await
Process.start`. The cancel listener at line 94 is registered before
that await resolves, so an early Cancel click causes a
`LateInitializationError`. Fix: register the kill listener after
Process.start succeeds, or guard with the `cancelled` flag.

**Files**: `lib/presentation/widgets/export_progress.dart`.

### 3. Verify exports against a real long-form video

Both export paths shipped without a runtime smoke test (Flutter
desktop can't be launched from the CLI). Now that the progress
dialog exists, this is mostly about confirming:

- Output plays full-length (truncation fix).
- TTS cues land at the right offsets.
- Sidecar SRT actually appears next to the MP4 and is loaded by
  VLC / Premiere / DaVinci.
- Open-folder works on the user's OS (will fail on Windows until
  step 1 lands).
- Cancel mid-export actually kills ffmpeg + closes the dialog.

### 4. A1-coverage gating during export

Playback honours per-window A1 mute (`_applyA1Gating`) but the
muxed export still bakes V1 audio in whole-or-nothing. Build a
`volume='enable=between(t,X,Y)':0` chain from the A1 clip list
(zero outside coverage) and feed `[a1gated]` into amix.

**Files**: `lib/presentation/screens/video_dub_screen.dart`
(`_buildExportArgs`, `_buildAudioExportArgs`).

### 5. Edit-cue auto-regen

Edit dialog already wipes `audioPath`/`audioDuration` on save but
doesn't auto-regenerate. Trivial extension of the Add-cue auto-flow
— same switches, same chain.

**Files**: `lib/presentation/screens/video_dub_screen.dart`
(`_editCueDialog`).

### 6. A3 layered playback during preview

Imported A3 clips mix correctly into the export but don't play
during preview/scrub. Add a third `AudioPlayer` (`_a3Player`),
mirror the cue scheduler in `_onVideoTick`. Single-slot for now.

**Files**: `lib/presentation/screens/video_dub_screen.dart` only.

### 7. Missing-media scan for external imports

`clip.missing` is never written for video-dub rows, so red state
never paints. Walk every videodub row on project open and
`existsSync`-check `audioPath`; same for `SubtitleCues.audioPath`.

**Files**: `lib/data/storage/storage_service.dart`,
`lib/presentation/screens/video_dub_screen.dart` (call on open).

---

## Candidates for a later PR

### 8. LRC speaker tags → automatic voice assignment

Parse `[speaker] lyric` during LRC import. Match speaker name
(case-insensitive) against bank voices; fall back to the bank's
first voice. With the new voice dropdown in the Add-cue dialog,
this would also be a natural place to surface speaker info.

### 9. Cue overlap warning

Drag + sync make it easy to introduce overlaps. Detect on import +
edit + drag + sync, paint affected cue blocks with a red border,
surface a count.

### 10. TTS overrun handling

A cue whose audio is longer than `endMs - startMs` keeps playing
until the next cue stops it. The Sync button is post-hoc; a real
fix would auto-adjust via `speed` or warn at generation time.

### 11. Thumbnail for V1

V1 currently shows an icon + filename. `ffmpeg -i <src> -ss 0
-vframes 1 <thumb.jpg>` is cheap.

### 12. `TimelineClip.audioPath` → `mediaPath` rename

Column name is wrong for V1's video paths. Drop-and-recreate per
repo convention; piggyback on the next DAO-touching PR.

### 13. Codec availability detection

`ExportPrefs` exposes h264/h265/av1 unconditionally — if the user's
ffmpeg lacks the encoder, the export fails with the codec error in
the snackbar. Could parse `ffmpeg -codecs` once at startup and grey
out missing options. Heavy parsing, deferred.

### 14. Tests for pure helpers

`runFfmpegWithProgress` (with a fake Process), `_buildExportArgs`,
`_buildAudioExportArgs`, `ExportPrefs.audioExtension` etc. are all
testable. Repo's existing pattern is `@visibleForTesting` hooks
without tests; gap continues.

---

## Known rough edges (small fixes, not full PRs)

- **Windows Open-folder is broken** — see immediate (1).
- **Cancel-then-late-init crash** — see immediate (2).
- **A1 coverage isn't honoured by exports** — see immediate (4).
- **`linkGroupId` doesn't do anything at play time yet** — V1 + A1
  are paired on import but no drag/trim/split logic reads it. Less
  urgent now that V1 is single-clip.
- **Image-source legacy rows** — old DBs may have rows with
  `sourceType: 'image'` on the now-removed V2 lane. Render with
  their old colour/icon under no track header (effectively hidden).
  No migration; harmless.
- **Clip delete works only via the selection close-X** — no keyboard
  Delete shortcut, no right-click menu.
- **FFmpeg banner's "Settings" link** flips `selectedTabProvider`
  but doesn't scroll Settings to the FFmpeg card.
- **Generate-All choice mapping uses string sentinels** — three
  buttons, local to one method, would refactor on next touch.
- **Two `// ignore: use_build_context_synchronously`** lines on the
  `runFfmpegWithProgress` / `showExportSuccessDialog` calls. The
  helpers handle `mounted` internally; suppressions are correct
  but worth a one-line note.

---

## Still explicitly out of scope

- Multi-video crossfade / concat editing (V1 is single-clip by
  design).
- Burn-in subtitles onto the exported video (sidecar SRT covers the
  use case).
- Auto speaker diarization from SRT (handled upstream).
- Bundling `ffmpeg` with the installer — remains a user prerequisite
  (LGPL / GPL licensing).
- Image / multi-track compositing — removed deliberately.

---

## Unverified at ship time

The 2026-04-26 work wasn't runtime-smoke-tested. Manual verification
outstanding for:

- Both export paths against a real long video (truncation fix +
  progress + cancel + sidecar SRT + open-folder).
- Save / Back dirty-confirm dialog click paths.
- Voice dropdown defaulting + persistence across multiple Add cues.
- Auto-TTS first-cue path post provider-race fix.
- ExportPrefs round-trip (Settings change → next export honours new
  fmt/codec).
- HorizontalResizableSplitPane drag feel + min-width clamping.
- A1 mute toggle parity (transport ⇄ track header).
- Cue drag on A2 with the timeline zoomed.
- `flutter analyze` is clean on the whole repo ✅ (verified this
  session, multiple times).
