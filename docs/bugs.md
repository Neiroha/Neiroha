# Bugs And Risks

Confirmed or likely defects are tracked here so review notes do not scatter
across root-level docs.

Last organized: 2026-04-29.

## P0 / P1

### LLM Config Cannot Clear Provider

File: `lib/data/storage/llm_config.dart`

`LlmConfig.copyWith(providerId: null)` keeps the old provider because it uses
`providerId ?? this.providerId`. A settings UI will not be able to clear the
LLM provider selection.

Fix: use a sentinel value or add `clearProviderId`.

### Role Assignment Can Silently Drop Text

File: `lib/data/services/role_assignment_service.dart`

The alignment step checks that each LLM segment exists in the source, but does
not check that the aligned segments cover the full source. If the model skips a
sentence, auto-apply can lose text.

Fix: after alignment, detect compact-text gaps and trailing leftovers. Return a
warning or fail the assignment.

### Suggested Voice Uses Name But Mapping Expects ID

Files:

- `lib/data/services/role_assignment_service.dart`
- `lib/data/services/role_mapping_file.dart`

`RoleAssignment.suggestedVoice` is a voice config/name, while
`RoleMapping.speakerToVoice` is documented as `VoiceAsset.id`. The UI can
easily persist a display name into an id field.

Fix: return `suggestedVoiceAssetId`, or explicitly make the mapping name-based
and handle duplicate names.

### LLM Chat Fallback Throws Raw DioException

File: `lib/data/adapters/llm_chat_adapter.dart`

If the first JSON-mode request fails due to `response_format`, the fallback
request is retried without wrapping its failure into `LlmChatException`.

Fix: wrap the fallback `_dio.post` in the same error conversion path.

## P2

### Claude Local Permission Is Too Broad

File: `.claude/settings.local.json`

`Read(//d//**)` grants Claude read access to the whole D drive. This looks like
local debugging config and should not be committed.

Fix: remove the broad rule and keep project-scoped permissions only.

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
