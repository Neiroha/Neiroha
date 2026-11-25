part of 'neiroha_mcp_tools.dart';

/// Reference audio, voice characters and synthesis tools.
extension _VoiceTools on NeirohaMcpTools {
  List<McpTool> _voiceTools() => [
    // ── Reference audio library ──
    McpTool(
      name: 'list_audio_tracks',
      title: 'List reference audio',
      description:
          'Audio clips in the library (reference audio for voice cloning).',
      inputSchema: _obj({'query': _str('Case-insensitive name filter.')}),
      readOnly: true,
      handler: (args) async {
        final q = _opt(args, 'query')?.toLowerCase();
        final tracks = await db.getAllAudioTracksRaw();
        return {
          'audio_tracks': [
            for (final t in tracks)
              if (q == null || t.name.toLowerCase().contains(q)) _trackJson(t),
          ],
        };
      },
    ),
    McpTool(
      name: 'import_audio_track',
      title: 'Import reference audio',
      description:
          'Copy a local audio/video file (or download a URL) into the '
          'reference-audio library. Video files and trimmed ranges are '
          'converted to mono WAV with ffmpeg. For cloning, aim for 5–15 s of '
          'clean single-speaker speech and pass the exact transcript as '
          'ref_text.',
      inputSchema: _obj({
        'file_path': _str('Absolute path of a local audio or video file.'),
        'url': _str('HTTP(S) URL to download instead of file_path.'),
        'name': _str('Library name (defaults to the file name).'),
        'ref_text': _str('Exact transcript of the clip.'),
        'ref_lang': _str('Language code of the clip, e.g. zh, en, ja.'),
        'description': _str('Notes, e.g. source / speaker.'),
        'start_sec': _num('Trim start in seconds.'),
        'end_sec': _num('Trim end in seconds.'),
      }),
      openWorld: true,
      handler: (args) async => _trackJson(await _importTrack(args)),
    ),
    McpTool(
      name: 'delete_audio_track',
      title: 'Delete reference audio',
      description:
          'Remove a clip from the library. Characters keep working because '
          'they store their own path, unless delete_file is true.',
      inputSchema: _obj(
        {
          'track_id': _str('Audio track id.'),
          'delete_file': _bool('Also delete the file on disk (default false).'),
        },
        required: ['track_id'],
      ),
      destructive: true,
      handler: (args) async {
        final id = _req(args, 'track_id');
        final track = (await db.getAllAudioTracksRaw())
            .where((t) => t.id == id)
            .firstOrNull;
        if (track == null) throw McpToolError('Audio track "$id" not found');
        await db.deleteAudioTrack(id);
        if (_bool0(args, 'delete_file') == true) {
          final f = File(track.audioPath);
          if (await f.exists()) await f.delete();
        }
        return {'deleted': id};
      },
    ),

    // ── Voice characters ──
    McpTool(
      name: 'list_voice_characters',
      title: 'List voice characters',
      description:
          'Voice characters (a provider + model + voice / reference audio '
          'recipe). Filter by bank or provider.',
      inputSchema: _obj({
        'bank_id': _str('Only characters in this bank (id or name).'),
        'provider_id': _str('Only characters of this provider (id or name).'),
      }),
      readOnly: true,
      handler: (args) async {
        var assets = await db.getAllVoiceAssets();
        final bankRef = _opt(args, 'bank_id');
        if (bankRef != null) {
          final bank = await _bank(bankRef);
          final ids = (await db.getBankMembers(
            bank.id,
          )).map((m) => m.voiceAssetId).toSet();
          assets = assets.where((a) => ids.contains(a.id)).toList();
        }
        final providerRef = _opt(args, 'provider_id');
        if (providerRef != null) {
          final provider = await _provider(providerRef);
          assets = assets.where((a) => a.providerId == provider.id).toList();
        }
        final providers = {
          for (final pr in await db.getAllProviders()) pr.id: pr,
        };
        return {
          'characters': [
            for (final a in assets) _characterJson(a, providers[a.providerId]),
          ],
        };
      },
    ),
    McpTool(
      name: 'create_voice_character',
      title: 'Create voice character',
      description:
          'Create a voice character. Read list_adapter_types first: the '
          'meaning of model / voice / instruction depends on the engine. '
          'Reference audio comes from audio_track_id (preferred) or '
          'ref_audio_path (imported into the library automatically). For '
          'ElevenLabs / MiniMax, giving reference audio without a voice '
          'clones it on the provider account and stores the new voice id. '
          'task_mode is inferred when omitted.',
      inputSchema: _obj(
        {
          'name': _str('Character name, e.g. "Detective Conan".'),
          'provider_id': _str('Provider id or exact name.'),
          'description': _str('Optional notes.'),
          'model': _str('Engine-specific model / mode (see adapter guide).'),
          'voice': _str('Preset voice / speaker / voice id.'),
          'task_mode': _str(
            'presetVoice | cloneWithPrompt | voiceDesign.',
            enumValues: [for (final m in TaskMode.values) m.name],
          ),
          'audio_track_id': _str('Reference audio from the library.'),
          'ref_audio_path': _str('Absolute path of a reference audio file.'),
          'prompt_text': _str('Transcript of the reference audio.'),
          'prompt_lang': _str('Language of the reference audio.'),
          'instruction': _str('Style / emotion / voice-design text.'),
          'speed': _num('Speech speed multiplier (default 1.0).'),
          'loudness_offset_db': _num(
            'Loudness offset in dB on top of the bank target (-12..12), e.g. '
            '-3 for a narrator that should sit under the cast.',
          ),
          'bank_ids': _arr(_str('Banks to add the character to.')),
          'clone_on_provider': _bool(
            'ElevenLabs / MiniMax only: clone the reference audio into a '
            'reusable account voice (default true when no voice is given).',
          ),
        },
        required: ['name', 'provider_id'],
      ),
      openWorld: true,
      handler: _createCharacter,
    ),
    McpTool(
      name: 'update_voice_character',
      title: 'Update voice character',
      description:
          'Change fields of a character. Omitted fields are left unchanged; '
          'pass "" to clear a text field.',
      inputSchema: _obj(
        {
          'character_id': _str('Character id or exact name.'),
          'name': _str('New name.'),
          'description': _str('New description.'),
          'model': _str('New model / mode.'),
          'voice': _str('New preset voice.'),
          'audio_track_id': _str('New reference audio from the library.'),
          'prompt_text': _str('New reference transcript.'),
          'prompt_lang': _str('New reference language.'),
          'instruction': _str('New style / emotion / design text.'),
          'speed': _num('New speed.'),
          'loudness_offset_db': _num('New loudness offset in dB (-12..12).'),
          'enabled': _bool('Enable / disable.'),
        },
        required: ['character_id'],
      ),
      handler: _updateCharacter,
    ),
    McpTool(
      name: 'delete_voice_character',
      title: 'Delete voice character',
      description:
          'Delete a character. Cues / lines that used it become unassigned.',
      inputSchema: _obj(
        {'character_id': _str('Character id or exact name.')},
        required: ['character_id'],
      ),
      destructive: true,
      handler: (args) async {
        final a = await _character(_req(args, 'character_id'));
        await db.deleteVoiceAsset(a.id);
        return {'deleted': a.id};
      },
    ),

    // ── Synthesis ──
    McpTool(
      name: 'synthesize_speech',
      title: 'Synthesize speech',
      description:
          'Generate speech for text with a character and save it to disk. '
          'Use it to audition a character before a full dub. Returns the '
          'file path and duration; the clip also appears in the app\'s '
          'Quick TTS history.',
      inputSchema: _obj(
        {
          'character_id': _str('Character id or exact name.'),
          'text': _str('Text to speak.'),
          'output_path': _str(
            'Optional absolute output path; default is the character\'s '
            'folder in the audio library.',
          ),
          'speed': _num('Override the character speed.'),
          'instruction': _str('Override the style / emotion text.'),
          'return_audio': _bool(
            'Also return the audio inline as base64 (default false).',
          ),
          'apply_chain': _bool(
            'Run the character\'s processing chain (translate / rewrite / '
            'voice conversion) around the TTS (default true).',
          ),
        },
        required: ['character_id', 'text'],
      ),
      openWorld: true,
      handler: _synthesizeSpeech,
    ),
  ];
}
