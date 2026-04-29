# Refactor Review — 2026-04-27

Assessment of the technical-debt cleanup that landed today on `dev`.
Two passes shipped: a first pass extracting `video_dub_screen.dart`, then
a second pass via Codex that broadened the cleanup to
`voice_character_screen.dart` and `app_database.dart`, and reorganised
the file layout.

## Scope

| File | Before | After | Δ |
| --- | --- | --- | --- |
| `lib/presentation/screens/video_dub_screen.dart` | 2540 | 1759 | −781 |
| `lib/presentation/screens/voice_character_screen.dart` | 2291 | 68 | −2223 |
| `lib/data/database/app_database.dart` | ~1200 | 309 | ~−890 |

`flutter analyze lib/` is clean. No logic changes — pure file moves and
extension splits.

## New layout

```
lib/data/database/queries/
  projects.dart      (48 methods — Phase/Dialog/VideoDub project + segment + cue)
  providers.dart     (12 methods — TTS provider + model bindings)
  storage.dart       (14 methods — paths, slugs, app_settings)
  tts.dart           (10 methods — quick TTS history + jobs)
  voice.dart         (24 methods — voice asset + bank + member)

lib/presentation/actions/
  video_dub/
    exporter.dart    (473 lines — exportVideoDubVideo / Audio / SubtitlesAndTts)

lib/presentation/widgets/video_dub/
  cue_card.dart      (195 lines)
  cue_dialogs.dart   (338 lines — showCueEditDialog / showImportSubtitlesDialog / showClearCuesConfirmDialog)
  timeline.dart      (1105 lines — split from old video_dub_timeline.dart)
  tracks.dart        (61 lines — DubLanes / DubImportKind / makeDubClipCompanion)

lib/presentation/widgets/voice_character/
  character_inspector.dart    (671 lines)
  create_character_dialog.dart (1234 lines)
  components.dart             (517 lines — _VoxCpm2ModeSelector / _CosyVoiceModeSelector / _RefAudioPicker / etc.)
```

## What works well

- **`actions/` is the right name for `exporter.dart`.** It is a
  side-effect orchestrator that takes `(BuildContext, WidgetRef, ...)`
  and runs ffmpeg / file pickers / dialogs — not a widget. Keeping it
  out of `widgets/` makes intent explicit.
- **`tracks.dart` extraction.** `DubLanes`, `DubImportKind`,
  `laneAndSourceForImport`, `makeDubClipCompanion` are domain types,
  not rendering code. Belongs in its own file.
- **Drift `part` pattern for `queries/`.** Idiomatic. Each query domain
  file declares `extension AppDatabaseXQueries on AppDatabase` so the
  `AppDatabase` class stays a single Dart entity while file-level
  cohesion is by domain.
- **Controller dispose in `cue_dialogs.dart`.** Codex added a
  `try/finally` around `showDialog` to dispose `TextEditingController`s
  — a memory leak the first pass missed.
- **Audio backend unification.** `_cuePlayer` switched from
  `audioplayers.AudioPlayer` to `media_kit.Player` so the editor
  drives one backend instead of two. One fewer transitive dep.
- **`voice_character_screen.dart` is now a thin dispatcher.** 68 lines:
  `selectedCharacterIdProvider` + `openCreateCharacterDialog()`. The
  rest moved to `widgets/voice_character/`.

## Inconsistency to resolve

The two extracted features use different file-organisation styles:

- `widgets/voice_character/*` — every file starts with
  `part of '../../screens/voice_character_screen.dart';` (Dart
  library/part).
- `widgets/video_dub/*` — regular `import`, public APIs.

There is no obvious reason for the asymmetry. The `part` style lets
private symbols (`_VoxCpm2ModeSelector`, the underscore helpers in
`character_inspector`) stay file-private without being duplicated, but
costs tooling friction (jump-to-symbol, file-move refactors) and makes
dependency direction less obvious.

**Recommendation:** pick one. The video_dub style (regular imports,
public symbols) is more modern and what the rest of the codebase uses.
Worth converting `voice_character/` to match in a follow-up — most of
the underscored types can be made package-public or kept file-private
under the existing names; only a handful actually share helpers across
files.

## Files still on the large side

- `widgets/voice_character/create_character_dialog.dart` (1234 lines)
  — largest remaining single file. Each provider's mode form (Cosy /
  VoxCPM2 / GPT-SoVITS) could become its own widget.
- `widgets/video_dub/timeline.dart` (1105 lines) — Codex only pulled
  61 lines (`tracks.dart`) out of the original 1085-line timeline.
  Painters / gesture handlers could be split if it becomes a hotspot.
- `widgets/voice_character/character_inspector.dart` (671 lines) —
  acceptable for an inspector with this many fields.

None of these are urgent. Address them only when the next functional
change touches them.

## Working-tree state at time of review

```
M  lib/data/database/app_database.dart
M  lib/presentation/screens/voice_character_screen.dart
M  lib/presentation/screens/video_dub_screen.dart
D  lib/presentation/screens/video_dub/exporter.dart   (committed at d3c68e0, then moved)
?? lib/data/database/queries/
?? lib/presentation/actions/
?? lib/presentation/widgets/voice_character/
```

The whole set forms one coherent refactor commit. Suggested message:
`refactor: split video_dub_screen, voice_character_screen, and app_database`.

## Open question

Should the `part`-vs-`import` style be unified before merge, or
deferred? Doing it now keeps the refactor tidy. Deferring is fine if
there is downstream work waiting on this branch.
