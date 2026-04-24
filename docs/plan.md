# Plan — Next Change

## Current state (2026-04-24)

The Video Dub editor was restructured into a Premiere-style 5-track model
this session:

| Track | Lane | Source                              | Notes                                    |
| ----- | ---- | ----------------------------------- | ---------------------------------------- |
| V2    |  -2  | `TimelineClips` (`image`)           | images, renders above V1                 |
| V1    |  -1  | `TimelineClips` (`video`)           | imported videos                          |
| A1    |   1  | `TimelineClips` (`video-audio`)     | linked to V1 by `linkGroupId`; gates V1 audio |
| A2    |  n/a | `SubtitleCues`                      | TTS cues; not user-importable            |
| A3    |   3  | `TimelineClips` (`imported`)        | free-form imported audio                 |

All 5 tracks are always visible (V2/A3 hide toggles were removed). Imports
now reference source files by **absolute path** — no more copying into
`voice_asset/video_dub/{slug}/assets/`. Video import inserts two rows
(V1 + A1) sharing a `linkGroupId`. V1's audio plays only when an A1 clip
covers the current playhead, so deleting an A1 clip silences the V1
window; the `_muteVideoAudio` toggle is an additional override on top.

Schema at v14. Drop-and-recreate migration per repo convention.

See [`archive-2026-04-24.md`](archive-2026-04-24.md) (to write) for the
full surface area.

---

## Shipped this session

### Review 2026-04-22 sweep (🔴 + 🟡)

- `.gitignore` no longer excludes `docs/`; archives and plan live in the
  repo instead of being force-added one at a time.
- **Waveform extraction streaming** — `FFmpegService.extractWaveformPeaks`
  uses `Process.start` + a `PeakReducer` class so memory is flat
  regardless of video length. A 4-hour video no longer risks OOM.
  Duration is probed up-front via `ffprobe`.
- **`_onVideoTick` one-flight guard** — prevents overlapping stop→play→seek
  sequences on the ~30×/s position stream.
- **`_pxToMs` removed** — body width is now threaded directly from
  `LayoutBuilder` into the ruler tap handler. First tap after the editor
  opens seeks correctly (previously returned `_viewLeftMs`).
- Intent comment on `onDeleteClip` explaining the deliberate
  no-`File.delete` behavior.

### Premiere-style track restructure

- **Schema v14**: `TimelineClips.linkGroupId TEXT?` — pairs V1 with A1
  so a future drag/trim on V1 can move its A1 sibling in lock-step.
- **Lanes remapped** — `DubLanes` now: v1=-1, v2=-2, a1=1, a3=3. Lane 2 is
  reserved; A2 is rendered from `SubtitleCues`.
- **External-path imports** — `_importMedia` stores the absolute source
  path. No `File.copy`. Missing files light up red via the existing
  `clip.missing` flag (but nothing currently flips that flag yet — see
  below).
- **ffprobe-based duration** for imported video and audio so clips land
  at correct width instead of the 8 px minimum.
- **A1-gated V1 audio** — `_applyA1Gating(ms)` mutes `_player` when no
  A1 clip covers the playhead. Latched on transitions, so we don't
  thrash `setVolume` every tick.
- **`FFmpegService.probeDurationSeconds(path)`** — promoted from private
  helper to public API.

---

## Immediate next steps (in priority order)

### 1. Missing-media scan for external imports — **first**

Imports no longer live in the app-managed folder, so the existing orphan
scan in `StorageService` doesn't catch them. Today `clip.missing` is
always `false` for video-dub rows, and the renderer's red "missing" state
never fires.

**Fix**: in `StorageService` (or a dedicated pass on editor open), walk
every `TimelineClips` row with `projectType = 'videodub'` and
`File(c.audioPath).existsSync()`. Write `missing = true` for those that
fail the check. Do the same for `SubtitleCues.audioPath`. Cheap —
runs once per project open.

**Files**: `lib/data/storage/storage_service.dart`,
`lib/presentation/screens/video_dub_screen.dart` (trigger on project
open).

### 2. V1↔A1 drag/trim lock — piggyback on the old PR candidate (3)

Schema supports it (`linkGroupId`) and the import flow already pairs
rows. What's missing is the drag/trim UI itself. When drag lands:

- Dragging any row in a link group moves all rows in the group by the
  same delta.
- Trimming V1's right edge resizes A1 to match.
- A "Unlink" context-menu item writes `linkGroupId = null` on all group
  members so they can be edited independently.
- A "Split at playhead" action creates two new rows for each group
  member at `playheadMs`, both rows keep the group id so they still
  move together unless explicitly unlinked.

**Files**: `lib/presentation/widgets/video_dub_timeline.dart`
(`_buildClipBlock` gains pan handlers + edge hit-zones),
`lib/data/database/app_database.dart` (add `resizeTimelineClip`,
`moveLinkGroup(linkGroupId, dxMs)`).

Covers image stretch-by-drag for free, and is the natural home for a
keyboard Delete shortcut.

### 3. A3 layered playback during video play

Imported A3 audio clips sit on the timeline but don't play when the
video runs. This is the same gap that "candidate (2) Layered A2 playback"
in the old plan called out — just renumbered.

**Approach**: add a third `AudioPlayer` (`_a3Player`) to
`_VideoDubEditorState`. In `_onVideoTick`, find the A3 clip whose window
contains `ms` and mirror the stop/start/offset-seek pattern used for
cues. Single-slot for now; revisit pooling if we support overlapping A3
clips later.

**Files**: `lib/presentation/screens/video_dub_screen.dart` only.

---

## Candidates for a later PR

### 4. LRC speaker tags → automatic voice assignment

Parse `[speaker] lyric` during LRC import. When the bank contains a
voice whose name matches `speaker` (case-insensitive), pre-assign it on
the cue. Fall back to the bank's first voice otherwise.

**Files**: `lib/data/storage/subtitle_parser.dart` (emit speaker in
`ParsedCue`), `lib/presentation/screens/video_dub_screen.dart`
(`_importSubtitles` maps speaker → voice). Low risk.

### 5. Cue overlap warning

Auto-transcription often produces overlapping cues. Detect overlap on
import + edit, highlight affected cue blocks in the timeline (red
border), show a panel count ("2 overlapping cues"). Pure UI.

### 6. TTS overrun handling

A generated cue whose audio is longer than `endMs - startMs` keeps
playing until the next cue stops it. Options:
- **(a)** auto-adjust via the voice asset's `speed` field if the
  overrun is small
- **(b)** warn in the cue card with the overrun duration
- **(c)** offer a per-cue "fit to window" toggle

(b) is the minimum viable. (c) is the most user-controllable.

### 7. Export dubbed video

Two shapes:
- **Audio-only export** — mix A1 (video-audio), A2 (TTS cue audio), and
  A3 (imported audio) onto a silent stereo rail aligned to start times,
  write a WAV/MP3. Same scheduler logic as `_onVideoTick`, offline.
- **Muxed MP4 export** — audio rail from (a) muxed back onto the
  original video:
  ```
  ffmpeg -i <video> -i <audio.wav> -c:v copy -map 0:v -map 1:a <out.mp4>
  ```

Ship (a) first; (b) as a second PR. Depends on candidate (3) for A3 to
be included.

### 8. Thumbnail for video / image clips

V1 currently shows an icon + filename. Thumbnail extraction via
`ffmpeg -i <src> -ss 0 -vframes 1 <thumb.jpg>`. Cheap add now that
`FFmpegService.probeDurationSeconds` lands — the same shape applies.

### 9. `TimelineClip.audioPath` → `mediaPath` rename

The column name is slightly wrong — it holds video/image paths for
video-dub rows. Deferred deliberately this session to avoid widening
scope. Best piggybacked on the drag/trim PR (candidate 2) since that
work touches the DAO anyway. Drop-and-recreate, matching the repo
pattern.

---

## Known rough edges (small fixes, not full PRs)

- **Missing-media flag isn't written** — see immediate step (1).
- **`linkGroupId` doesn't do anything at play time yet** — it's
  populated on import and stored, but no drag/trim/split logic reads it.
  See immediate step (2).
- **Track visibility is no longer configurable** — all 5 lanes always
  show. If users complain about screen-estate on small windows we can
  add per-lane collapse back. Cheaper than before now that the
  `_showV2` / `_showA3` toggle code is gone.
- **Legacy copied imports** in `voice_asset/video_dub/{slug}/assets/`
  still play fine. They'll stay orphaned in that folder forever; not
  worth a migration.
- **Clip delete works only via the selection close-X** — no keyboard
  Delete shortcut, no right-click menu. Easy to add alongside
  candidate (2)'s drag work.
- **FFmpeg banner's "Settings" link** flips `selectedTabProvider` but
  doesn't scroll Settings to the FFmpeg card. Minor polish.
- **LRC speaker tags dropped during parse** — `_stripTags` in
  `SubtitleParser` removes `[speaker]` alongside SRT's `<b>` / `{i}`.
  See candidate (4) — that's where we'd start preserving them.

---

## Still explicitly out of scope

- Multi-video crossfade / concat editing (only stacked independent
  clips on V1).
- Burn-in subtitles onto the exported video.
- Auto speaker diarization from SRT (handled upstream).
- Bundling `ffmpeg` with the installer — remains a user prerequisite
  (LGPL / GPL licensing). The Settings card makes it a one-time setup.

---

## Unverified at ship time

Neither the 2026-04-22 review sweep nor the 2026-04-24 track restructure
was runtime-smoke-tested from this session — the Flutter desktop app
can't be launched from the CLI. Manual verification outstanding for:

- Video import → two rows (V1 + A1) land with the correct
  `durationSec`, same start, same `linkGroupId`.
- Image import → one row on V2 at 3 s default.
- Audio import → one row on A3 with probed duration.
- Source-path imports play correctly (media_kit / audioplayers can both
  read from an arbitrary absolute path).
- A1 deletion silences V1's audio in that window when
  `_muteVideoAudio = false`.
- `_muteVideoAudio` toggle override still works regardless of A1
  coverage.
- Waveform renders on the A1 lane (not behind TTS cues anymore).
- FFmpeg banner still flips to Settings tab.
- `flutter analyze` is clean on the whole repo ✅ (verified this
  session).
