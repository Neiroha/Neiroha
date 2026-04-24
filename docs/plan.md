# Plan — Next Change

## Start here next session

The Video Dub multi-track editor shipped (2026-04-22). A self-review
surfaced one 🔴 meta-issue (the docs themselves are outside git), one
🔴 correctness bug (waveform extraction OOM on long videos), and a
handful of 🟡 paint-jobs. **Read [`review-2026-04-22.md`](review-2026-04-22.md)
first** — it has a merge-order recommendation at the bottom.

Once the review's 🔴 items are cleared, pick **one numbered candidate**
from "Candidates for the next PR" and ship it end-to-end — don't bundle.

**First-ship recommendation**: **(2) Layered A2 playback** — the
imported-audio feature looks complete but doesn't actually play when
you hit play. That's the most jarring gap for a user.

**Second-ship recommendation**: **(4) FFprobe duration** — imported
videos land with `durationSec = null` and render as zero-width
placeholders on V1, which is confusing.

See [`archive-2026-04-22.md`](archive-2026-04-22.md) for the full
surface area of what just shipped.

---

## Known rough edges (small fixes, not full PRs)

These are landmines a user will hit within a minute of opening the
editor. Worth sweeping in passing when touching the nearby code.

- **Imported videos show as zero-width placeholders on V1** —
  `durationSec = null` means the clip tile shrinks to its minimum
  width (~8 px). Users won't find them to click. See PR candidate (4).

- **A2 imported audio is silent during playback** — clip is on the
  timeline, visible on the scrubber, but the `_onVideoTick` scheduler
  only drives the A1 cue player. See PR candidate (2).

- **Images get a hard-coded 3 s duration** — no way to stretch them
  yet, so every image is the same visual length regardless of intent.
  See PR candidate (3) — stretch-by-drag is the right fix.

- **Track visibility (V2 / A3 shown?) is not persisted** — toggling
  them on doesn't survive a project close/reopen because state lives
  in `_VideoDubTimelineState`. If we want persistence, add two bool
  columns on `VideoDubProjects` (`showV2`, `showA3`). Probably fine as
  local state until users complain.

- **`TimelineClip.audioPath` holds video / image paths too** — the
  column name is slightly wrong now. Left as-is to avoid a schema
  migration. If we do the schema change for track visibility above,
  bundle a rename to `mediaPath`.

- **No thumbnail for video / image clips** — V1 shows an icon +
  filename. Thumbnail extraction needs ffmpeg (`ffmpeg -i -ss 0
  -vframes 1 ...`). Cheap add once `FFmpegService.probeDuration`
  lands.

- **Clip delete works only when selected (close-X on the tile)** —
  no keyboard Delete shortcut, no right-click menu. Easy to add alongside
  candidate (3)'s drag work.

- **FFmpeg banner's "Settings" link just flips `selectedTabProvider`**
  — it doesn't scroll Settings to the FFmpeg card or highlight it.
  Minor UX polish; not worth its own PR.

- **LRC speaker tags dropped during parse** — `_stripTags` in
  `SubtitleParser` removes `[speaker]` alongside SRT's `<b>` / `{i}`.
  See PR candidate (1) — that's where we'd start preserving them.

---

## Candidates for the next PR (pick one; don't bundle)

### 1. LRC speaker tags → automatic voice assignment

Parse `[speaker] lyric` during LRC import. When the bank contains a
voice whose name matches `speaker` (case-insensitive), pre-assign it
on the cue. Fall back to the bank's first voice otherwise.

**Files**: `lib/data/storage/subtitle_parser.dart` (emit speaker in
`ParsedCue`), `lib/presentation/screens/video_dub_screen.dart`
(`_importSubtitles` maps speaker → voice). Low risk. Unblocks
multi-character dubbing without per-cue reassignment.

### 2. Layered A2 playback during video play — **recommended first**

Imported A2 audio clips sit on the timeline but don't play when the
video runs. Today only V1 video audio + A1 TTS are in sync.

**Approach**: add a third `AudioPlayer` (`_a2Player`) to
`_VideoDubEditorState`. In `_onVideoTick`, find the A2 clip whose
window contains `ms` and mirror the same stop/start/offset-seek
pattern we use for cues. Watch out for **two A2 clips at the same
time** once we support that (pool of players, or declare A2 as
single-slot in this PR and revisit with (3)).

**Files**: `lib/presentation/screens/video_dub_screen.dart` only.

### 3. Clip drag / trim

Drag a clip horizontally to reposition on its lane; drag either edge
to change start/end. DB already supports it via `moveTimelineClip`;
end-trim needs a new `resizeTimelineClip` (write `durationSec`).

**Files**: `lib/presentation/widgets/video_dub_timeline.dart`
(`_buildClipBlock` gets pan handlers + edge hit-zones),
`lib/data/database/app_database.dart` (add `resizeTimelineClip`).
Covers image stretch-by-drag for free.

### 4. FFprobe-based duration for imported videos — **recommended second**

Right now imported videos render at minimum width because we never
probe their duration.

**Approach**: add `FFmpegService.probeDuration(mediaPath)` — shells
out to
```
ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 <path>
```
Same install tree as ffmpeg (ships in the same zip on every platform).
Call from `_importMedia` for video + image (ffprobe reports 0 for
images, fall back to 3 s). If `ffmpegAvailable == false`, skip the
probe and keep the placeholder.

**Files**: `lib/data/storage/ffmpeg_service.dart`,
`lib/presentation/screens/video_dub_screen.dart`.

### 5. Cue overlap warning

Subtitle files from auto-transcription often produce overlapping cues
when two speakers are on top of each other. Detect overlap on import
+ edit, highlight affected cue blocks in the timeline (red border),
show a panel count ("2 overlapping cues"). Pure UI; low risk.

### 6. Offset ducking when TTS runs long

A generated cue whose audio is longer than `endMs - startMs` keeps
playing until the next cue stops it. Options:
 - **(a)** auto-adjust via the voice asset's `speed` field if the
   overrun is small
 - **(b)** warn in the cue card with the overrun duration
 - **(c)** offer a per-cue "fit to window" toggle

(b) is the minimum viable. (c) is the most user-controllable.

### 7. Export dubbed video

Two shapes:

 - **Audio-only export** — mix A1 cue audio + A2 clips onto a silent
   stereo rail aligned to start times, write a WAV/MP3. Same scheduler
   logic as `_onVideoTick`, offline.
 - **Muxed MP4 export** — audio rail from (a) above, muxed back onto
   the original video:
   ```
   ffmpeg -i <video> -i <audio.wav> -c:v copy -map 0:v -map 1:a <out.mp4>
   ```
   Needs ffmpeg (already configurable).

Ship (a) first; (b) as a second PR. Depends on (2) for A2 to be
included.

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

Neither Part 1 nor Part 2 was runtime-smoke-tested from this session
— the Flutter desktop app can't be launched from the CLI. Manual
verification still outstanding for:

- SRT import on a real file → generate all → synced dub playback.
- FFmpeg detection on a clean system (auto-detect via PATH).
- FFmpeg override path — set, save, re-check badge flips green.
- Waveform strip appears behind A1 cues after loading a video.
- Range scrubber handles drag smoothly; visible window honours them.
- All three import kinds copy into `voice_asset/video_dub/{slug}/assets/`
  and appear on the correct lane.
- Banner "Settings" click flips to the Settings tab.
