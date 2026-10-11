---
name: neiroha-dubbing
description: Drive the Neiroha desktop dubbing workstation through its MCP server to run voice-over and video-dubbing jobs end to end - configure TTS providers (ElevenLabs, MiniMax, Gemini, IndexTTS, CosyVoice, GPT-SoVITS, OpenAI-compatible...), collect and import reference audio, create cloned or preset voice characters and voice banks, audition lines, import subtitles, cast every cue, generate all dub audio and export the dubbed video, audio mix or SRT. Use when the user asks to dub a video, voice subtitles, build a cast of voices, clone a character voice for TTS, or batch-generate speech with Neiroha.
---

# Neiroha Dubbing via MCP

Neiroha is a local desktop app. Its MCP server runs inside the app, so
everything you do appears live in the Neiroha UI, and every synthesis request
goes through the same queue and per-provider rate limits as the desktop app.

All file paths you pass or receive are **absolute paths on the machine that
runs Neiroha**.

## 0. Connect

Prerequisites, all done by the user inside Neiroha:

1. Neiroha is running.
2. **Settings → API Server** is switched on (default bind `127.0.0.1:8976`).
3. **MCP server for AI agents** is switched on (on by default).

The endpoint is `http://127.0.0.1:8976/mcp` (Streamable HTTP, stateless JSON).

```bash
# Claude Code
claude mcp add --transport http neiroha http://127.0.0.1:8976/mcp
# if an API key is set in Neiroha:
claude mcp add --transport http neiroha http://127.0.0.1:8976/mcp \
  --header "Authorization: Bearer <key>"
```

```toml
# Codex (~/.codex/config.toml)
[mcp_servers.neiroha]
url = "http://127.0.0.1:8976/mcp"
# bearer_token_env_var = "NEIROHA_API_KEY"
```

If the tools are missing, ask the user to check the three prerequisites. When
Neiroha listens on a non-loopback host, MCP only works with an API key.

## 1. Orient yourself

Always start with:

1. `get_overview`: counts, enabled providers, audio-library root, and whether
   ffmpeg is available (export and audio trimming need it).
2. `list_adapter_types`: read the `guide` of each engine you plan to use. The
   meaning of `model`, `voice` and `instruction` differs per engine.
3. `list_providers`, `list_voice_banks` and `list_voice_characters`: reuse what
   already exists before creating duplicates.

## 2. Choose an engine

| Need | Engine (`adapter_type`) | Notes |
|---|---|---|
| Best cloud quality, many languages, cloning | `elevenLabs` | model `eleven_v4`; voice `Name [voice_id]`; reference audio without a voice creates an instant clone on the account |
| Strong Chinese, cheap cloning | `minimaxTts` | model `speech-2.8-hd`; instruction = one emotion keyword; clones expire after 7 days unused; mainland accounts use `https://api.minimaxi.com` |
| Free or low-cost, no cloning | `geminiTts` | model `gemini-3.8-flash-tts`; 30 prebuilt voices (Kore, Puck, Charon...); instruction = delivery style |
| Local zero-shot cloning, no cloud | `indexTts` | IndexTTS 2.5 WebUI from a community one-click package (`start-webui.bat`, port 7860); every character needs reference audio |
| Local, other | `cosyvoice`, `gptSovits`, `voxcpm2Native`, `openaiCompatible` | see each guide |

Creating a provider needs the user's API key. **Never invent keys.** Ask the
user for one, or reuse an enabled provider. Run `check_provider` after
creating or changing a provider.

## 3. Collect reference audio (for cloned voices)

A good cloning reference:

- 5 to 15 s of a single speaker (MiniMax needs at least 10 s), with no music,
  SFX, laughter, crosstalk or reverb.
- Natural, mid-energy speech in the target language, if possible.
- An exact transcript, passed as `ref_text`. Some engines (CosyVoice
  zero_shot, GPT-SoVITS, VoxCPM2 ultimate_clone) need it.

Sources, best first: clips the user provides; the source video itself (cut a
clean line from it); clips you find online. When you search online, prefer
official material, download it with a tool available to you, and record the
source in `description`.

Then call `import_audio_track` with `file_path` or `url`. Use
`start_sec`/`end_sec` to cut the clean segment. Video files are converted to
mono WAV automatically. You can import several candidates per character and
keep the best one.

**Rights and consent:** clone only voices that the user owns, has permission
to use, or that the user explicitly directs you to use for personal,
non-deceptive work such as fan dubs or localization drafts. Refuse to clone
private individuals without consent. Do not produce content meant to
impersonate a real person deceptively. If the purpose is unclear, ask.

## 4. Create the cast

For each character, call `create_voice_character` with the following inputs.

- Preset voice: `provider_id`, `model`, `voice`. Find voices with
  `list_provider_voices` (use `query` to filter).
- Cloned voice: `provider_id` + `audio_track_id` (+ `prompt_text` /
  `prompt_lang` when the engine needs them).
  - ElevenLabs / MiniMax: leave `voice` empty. Neiroha clones the clip into a
    reusable account voice and stores its id.
  - IndexTTS: `model` is the output language (`auto`, `ZH`, `EN`, `JA`, `AR`,
    `ES`).
- `instruction`: the default style or emotion for the character.
- `bank_ids`: put the whole cast into one bank (`create_voice_bank` first).

Audition every character with `synthesize_speech` and one representative
line before the full run. If it sounds wrong, try another reference clip, then
`update_voice_character` (for example a new `audio_track_id`, `instruction` or
`speed`).

## 5. Dub a video

1. `create_video_dub_project` with `name`, `bank_id` (the cast bank) and
   `video_path`.
2. `import_subtitles` with `file_path` (SRT, VTT or LRC) or `subtitle_text`.
   - If the script still needs translating or rewriting, write the new SRT
     yourself and import it with `subtitle_text`, or add cues with
     `add_subtitle_cues`.
   - Use `character_id` to cast every cue at once when there is one speaker.
3. Cast per cue with `list_subtitle_cues`, then `update_subtitle_cues` with
   `updates: [{cue_id, character_id}]`. Infer speakers from speaker tags
   (`NAME:`, `[Name]`, `- `), from scene context, or from a script the user
   supplies. Remove speaker tags from the spoken text while you are at it
   (`text`).
4. `generate_video_dub_audio`. Use `sync_cue_length: true` to snap each cue's
   end to the real audio length. It returns failures per cue. Fix the cause
   (disabled provider, missing reference audio, rate limit) and run it again;
   cues that already have audio are skipped unless `regenerate: true`.
5. Quality pass: in `list_subtitle_cues`, compare `audio_duration_sec` with
   the cue window (`end_ms - start_ms`). For lines that overrun badly, shorten
   the text, raise the character `speed`, or move the timing with
   `update_subtitle_cues`, then regenerate those `cue_ids`.
6. `export_video_dub` with `kind`:
   - `video`: MP4 with the dub mixed over the source video, plus a sidecar
     `.srt`. Use `include_original_audio: true` to keep the original track
     under the dub.
   - `audio`: a single mixed audio file (the extension picks the codec:
     `.wav`, `.mp3`, `.flac`, `.m4a`).
   - `srt`: subtitles only.

## 6. Batch voice-over without video

Call `synthesize_speech` per line with `output_path` set to name the files.
The results also appear in the Quick TTS history of the app.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Provider "..." is disabled` | `update_provider` with `enabled: true` |
| `check_provider` reports `healthy: false` | wrong URL or key, or the local server is not started (IndexTTS: run the package's `start-webui.bat`) |
| HTTP 401 / 403 from a cloud engine | invalid or expired key; ask the user |
| HTTP 429 or MiniMax `1002` / `1039` | rate limited; lower `max_concurrency` or set `requests_per_minute` |
| MiniMax `2038` | the account lacks cloning permission |
| `ffmpeg is required` | the user must install ffmpeg or set its path in Neiroha Settings |
| IndexTTS ignores `instruction` | the WebUI did not load its experimental emotion model; that is expected |
| `delete_voice_bank` fails | a project still uses the bank; delete or rebind the project first |

## Tool reference

| Area | Tools |
|---|---|
| Overview | `get_overview`, `list_adapter_types` |
| Providers | `list_providers`, `create_provider`, `update_provider`, `delete_provider`, `check_provider`, `list_provider_models`, `list_provider_voices` |
| Banks | `list_voice_banks`, `create_voice_bank`, `update_voice_bank`, `delete_voice_bank`, `add_characters_to_bank`, `remove_characters_from_bank` |
| Reference audio | `list_audio_tracks`, `import_audio_track`, `delete_audio_track` |
| Characters | `list_voice_characters`, `create_voice_character`, `update_voice_character`, `delete_voice_character` |
| Speech | `synthesize_speech` |
| Video dub | `list_video_dub_projects`, `create_video_dub_project`, `attach_video_to_dub_project`, `import_subtitles`, `list_subtitle_cues`, `add_subtitle_cues`, `update_subtitle_cues`, `delete_subtitle_cues`, `generate_video_dub_audio`, `export_video_dub`, `delete_video_dub_project` |

Ids and names are interchangeable for providers, characters and banks; ids
are safer when names repeat. Destructive tools (`delete_*`) cannot be undone,
so confirm with the user before deleting anything you did not create in this
session.
