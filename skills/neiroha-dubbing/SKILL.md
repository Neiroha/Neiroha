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
   Recommend turning on **Start API server on launch** in the same card, so
   the endpoint is up every time Neiroha opens. The server cannot be started
   through MCP itself.
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

Voice cloning works from three inputs:

1. **Reference audio**: a short clip of the target voice.
2. **Reference text**: the *exact* transcript of that clip, word for word, in
   the clip's language. A transcript that does not match the audio makes the
   clone mispronounce or drift.
3. **Target text**: the new line to speak. Every synthesis call produces a new
   audio file in the cloned voice.

Store the reference text on the clip (`ref_text` / `ref_lang` in
`import_audio_track`). `create_voice_character` copies it to the character as
`prompt_text` / `prompt_lang`. Provide it even when the engine can work without
it (MiMo voiceclone and IndexTTS clone from audio alone), because it keeps the
character portable to engines that require it (CosyVoice zero_shot,
GPT-SoVITS clone, VoxCPM2 ultimate_clone).

A good cloning reference:

- 5 to 15 s of a single speaker (MiniMax needs at least 10 s), with no music,
  SFX, laughter, crosstalk or reverb.
- Natural, mid-energy speech in the target language, if possible.
- **Short internal pauses.** Cloned voices copy the reference's pacing: a
  dramatic clip with 1–2 s gaps produces 2 s gaps inside every generated line.
  Compress pauses longer than ~0.3 s before importing, for example:
  `ffmpeg -i in.wav -af "silenceremove=start_periods=1:start_threshold=-40dB:stop_periods=-1:stop_duration=0.3:stop_threshold=-40dB:stop_silence=0.3" out.wav`.
  Never cut through a word: put cut points inside silences (find them with
  `-af silencedetect=n=-40dB:d=0.3`).

Getting the reference text:

- Use the official script or transcript when the source publishes one, but make
  sure it is the line in the clip's language. Fan wikis often show only a
  translation.
- Otherwise transcribe the clip with a speech-to-text service the user already
  has access to, in the clip's language. Then fix proper nouns and archaic or
  character-specific words by hand, using the known meaning of the line as a
  cross-check. ASR routinely mishears names and stylised speech.
- If you cannot produce a trustworthy transcript, say so instead of guessing.

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
- Cloned voice: `provider_id` + `audio_track_id`. The clip's reference text
  becomes `prompt_text` / `prompt_lang`; override them only to fix the
  transcript.
  - MiMo (`chatCompletionsTts`): set `model` to the voice-clone model (for
    example `mimo-v2.5-tts-voiceclone`) and `task_mode: cloneWithPrompt`.
  - ElevenLabs / MiniMax: leave `voice` empty. Neiroha clones the clip into a
    reusable account voice and stores its id.
  - IndexTTS: `model` is the output language (`auto`, `ZH`, `EN`, `JA`, `AR`,
    `ES`).
- `instruction`: the default style or emotion for the character.
- `bank_ids`: put the whole cast into one bank (`create_voice_bank` first).

Audition every character with `synthesize_speech` and one representative
line before the full run. Check the audition objectively, not only by ear:

- **Duration:** roughly 0.12–0.2 s per Japanese/Chinese character, or 2.5–3
  English words per second. A short line that comes back several times longer
  usually means long copied pauses (fix the reference, see section 3) or a
  repeated phrase.
- **Content:** run the clip through speech-to-text and compare it with the
  target text. Expect the recogniser to miss names and archaic words; whole
  missing or extra phrases mean a bad take.

If it sounds wrong, try another or a tighter reference clip, then
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

### Lyrics / subtitle file (LRC or SRT) for a multi-line take

Synthesize **one call per line**, never the whole script in one call, so that
each line's timing is measured rather than guessed:

1. For each line *i*, call `synthesize_speech` and keep `duration_sec`.
2. Join the clips in order with a fixed gap (0.4–0.8 s), for example with
   ffmpeg `apad=pad_dur=<gap>` per input followed by `concat`.
3. Line *i* starts at `sum(duration + gap)` of the previous lines. Add the
   clip's leading silence (`silencedetect`) so the timestamp lands on the first
   word.
4. Write `[mm:ss.xx]<text>` per line (LRC) or `HH:MM:SS,mmm --> …` blocks
   (SRT). End the LRC with a bare timestamp at the total length.

For a video project, use `export_video_dub` with `kind: srt` instead; its cue
timings already come from the project.

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
| HTTP 402 / `insufficient_balance` | the provider account is out of credit for that model. Paid add-ons such as ASR can fail while TTS still works; tell the user instead of retrying |
| Connection refused on `:8976` | the API server is off; ask the user to switch it on or enable **Start API server on launch** |
| Cloned lines have long silent gaps | the reference clip has long pauses; compress them (section 3) and update the character's `audio_track_id` |

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
