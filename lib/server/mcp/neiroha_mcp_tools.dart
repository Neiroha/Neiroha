import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/data/services/video_dub_mix.dart';
import 'package:neiroha/data/storage/export_prefs.dart';
import 'package:neiroha/data/storage/ffmpeg_service.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/data/storage/storage_service.dart';
import 'package:neiroha/data/storage/subtitle_parser.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/enums/task_mode.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';
import 'package:neiroha/presentation/widgets/video_dub/tracks.dart';
import 'package:neiroha/server/mcp/mcp_server.dart';

/// The Neiroha tool surface for AI agents: providers, voice banks, the
/// reference-audio library, voice characters, speech synthesis and
/// end-to-end video dubbing. Everything goes through the same database and
/// [TtsQueueService] as the desktop UI, so changes appear live in the app
/// and provider rate limits are respected.
class NeirohaMcpTools {
  NeirohaMcpTools(this.db)
    : _ffmpeg = FFmpegService(db),
      _storage = StorageService(db),
      _exportPrefs = ExportPrefsService(db);

  final AppDatabase db;
  final FFmpegService _ffmpeg;
  final StorageService _storage;
  final ExportPrefsService _exportPrefs;
  static const _uuid = Uuid();

  static const String serverInstructions =
      'Neiroha is a local dubbing workstation. Typical flow: '
      'get_overview → list_providers / create_provider → import_audio_track '
      '(reference clips) → create_voice_character → create_voice_bank / '
      'add_characters_to_bank → synthesize_speech to audition → '
      'create_video_dub_project → import_subtitles → update_subtitle_cues '
      '(assign characters) → generate_video_dub_audio → export_video_dub. '
      'All paths are absolute paths on the machine running Neiroha. Call '
      'list_adapter_types to learn how each engine expects model / voice / '
      'reference audio to be configured.';

  List<McpTool> build() => [
    // ── Overview ──
    McpTool(
      name: 'get_overview',
      title: 'Workspace overview',
      description:
          'Summary of the Neiroha workspace: counts of providers, characters, '
          'banks, audio tracks and dub projects, which providers are enabled, '
          'the audio library folder and whether ffmpeg is available. Call '
          'this first.',
      inputSchema: _obj({}),
      readOnly: true,
      handler: _overview,
    ),
    McpTool(
      name: 'list_adapter_types',
      title: 'List TTS engine types',
      description:
          'Every supported TTS engine (adapter_type) with its default base '
          'URL, default model, capabilities and a configuration guide that '
          'explains what "model", "voice", "instruction" and reference audio '
          'mean for that engine.',
      inputSchema: _obj({}),
      readOnly: true,
      handler: (_) async => {
        'adapter_types': [for (final t in _availableTypes()) _adapterJson(t)],
      },
    ),

    // ── Providers ──
    McpTool(
      name: 'list_providers',
      title: 'List providers',
      description:
          'Configured TTS providers (engine connections). API keys are never '
          'returned, only has_api_key.',
      inputSchema: _obj({}),
      readOnly: true,
      handler: (_) async {
        final providers = await db.getAllProviders();
        return {
          'providers': [for (final pr in providers) _providerJson(pr)],
        };
      },
    ),
    McpTool(
      name: 'create_provider',
      title: 'Create provider',
      description:
          'Add a TTS provider. base_url and default_model fall back to the '
          'adapter defaults from list_adapter_types. Enabled by default.',
      inputSchema: _obj(
        {
          'name': _str('Display name, e.g. "ElevenLabs".'),
          'adapter_type': _str(
            'Engine type (see list_adapter_types).',
            enumValues: [for (final t in AdapterType.values) t.name],
          ),
          'base_url': _str('Server / API base URL.'),
          'api_key': _str('API key or token (stored locally).'),
          'default_model': _str(
            'Default model used when a character sets none.',
          ),
          'enabled': _bool('Enable immediately (default true).'),
          'max_concurrency': _int('Parallel requests allowed (default 1).'),
          'requests_per_minute': _int('Optional RPM limit.'),
        },
        required: ['name', 'adapter_type'],
      ),
      handler: _createProvider,
    ),
    McpTool(
      name: 'update_provider',
      title: 'Update provider',
      description:
          'Change a provider\'s name, URL, API key, default model, enabled '
          'flag or rate limits. Omitted fields are left unchanged.',
      inputSchema: _obj(
        {
          'provider_id': _str('Provider id or exact name.'),
          'name': _str('New display name.'),
          'base_url': _str('New base URL.'),
          'api_key': _str('New API key ("" clears it).'),
          'default_model': _str('New default model.'),
          'enabled': _bool('Enable / disable the provider.'),
          'max_concurrency': _int('Parallel requests allowed.'),
          'requests_per_minute': _int('RPM limit (0 removes the limit).'),
        },
        required: ['provider_id'],
      ),
      handler: _updateProvider,
    ),
    McpTool(
      name: 'delete_provider',
      title: 'Delete provider',
      description:
          'Permanently delete a provider AND every voice character that uses '
          'it. Prefer update_provider with enabled=false to just disable it.',
      inputSchema: _obj(
        {'provider_id': _str('Provider id or exact name.')},
        required: ['provider_id'],
      ),
      destructive: true,
      handler: (args) async {
        final provider = await _provider(_req(args, 'provider_id'));
        final affected = (await db.getAllVoiceAssets())
            .where((a) => a.providerId == provider.id)
            .map((a) => a.name)
            .toList();
        await db.deleteProvider(provider.id);
        return {'deleted': provider.id, 'deleted_characters': affected};
      },
    ),
    McpTool(
      name: 'check_provider',
      title: 'Health-check provider',
      description:
          'Ping the provider\'s server/API to confirm the URL and key work.',
      inputSchema: _obj(
        {'provider_id': _str('Provider id or exact name.')},
        required: ['provider_id'],
      ),
      readOnly: true,
      openWorld: true,
      handler: (args) async {
        final provider = await _provider(_req(args, 'provider_id'));
        try {
          final ok = await createAdapter(provider).healthCheck();
          return {'provider_id': provider.id, 'healthy': ok};
        } catch (e) {
          return {'provider_id': provider.id, 'healthy': false, 'error': '$e'};
        }
      },
    ),
    McpTool(
      name: 'list_provider_models',
      title: 'List provider models',
      description:
          'Live list of models the provider offers (for IndexTTS this is the '
          'synthesis language list).',
      inputSchema: _obj(
        {'provider_id': _str('Provider id or exact name.')},
        required: ['provider_id'],
      ),
      readOnly: true,
      openWorld: true,
      handler: (args) async {
        final provider = await _provider(_req(args, 'provider_id'));
        final models = await createAdapter(provider).getModels();
        return {
          'provider_id': provider.id,
          'models': [
            for (final m in models) {'id': m.id, 'name': m.name},
          ],
        };
      },
    ),
    McpTool(
      name: 'list_provider_voices',
      title: 'List provider voices',
      description:
          'Live list of preset / account voices on the provider. Cloud voices '
          'look like "Name [voice_id]" — pass the whole string (or just the '
          'id) as the character voice.',
      inputSchema: _obj(
        {
          'provider_id': _str('Provider id or exact name.'),
          'query': _str('Case-insensitive substring filter.'),
          'limit': _int('Max voices to return (default 200).'),
        },
        required: ['provider_id'],
      ),
      readOnly: true,
      openWorld: true,
      handler: (args) async {
        final provider = await _provider(_req(args, 'provider_id'));
        final query = _opt(args, 'query')?.toLowerCase();
        final limit = _int0(args, 'limit') ?? 200;
        final voices = await createAdapter(provider).getSpeakers();
        final filtered = query == null
            ? voices
            : voices.where((v) => v.toLowerCase().contains(query)).toList();
        return {
          'provider_id': provider.id,
          'total': filtered.length,
          'voices': filtered.take(limit).toList(),
        };
      },
    ),

    // ── Voice banks ──
    McpTool(
      name: 'list_voice_banks',
      title: 'List voice banks',
      description:
          'Voice banks (named groups of characters) with their members. '
          'Projects use one bank; active banks are exposed by the local '
          'OpenAI-compatible API as models.',
      inputSchema: _obj({}),
      readOnly: true,
      handler: (_) async {
        final banks = await db.getAllBanks();
        final assets = {for (final a in await db.getAllVoiceAssets()) a.id: a};
        return {
          'banks': [
            for (final b in banks)
              {
                ..._bankJson(b),
                'members': [
                  for (final m in await db.getBankMembers(b.id))
                    if (assets[m.voiceAssetId] case final a?)
                      {'character_id': a.id, 'name': a.name},
                ],
              },
          ],
        };
      },
    ),
    McpTool(
      name: 'create_voice_bank',
      title: 'Create voice bank',
      description: 'Create a voice bank, optionally with initial characters.',
      inputSchema: _obj(
        {
          'name': _str('Bank name, e.g. "Movie X cast".'),
          'description': _str('Optional description.'),
          'active': _bool('Expose via the local API (default true).'),
          'character_ids': _arr(_str('Character id or name.')),
        },
        required: ['name'],
      ),
      handler: (args) async {
        final id = _uuid.v4();
        await db.insertBank(
          VoiceBanksCompanion(
            id: Value(id),
            name: Value(_req(args, 'name')),
            description: Value(_opt(args, 'description')),
            isActive: Value(_bool0(args, 'active') ?? true),
            createdAt: Value(DateTime.now()),
          ),
        );
        for (final ref in _strList(args, 'character_ids')) {
          final a = await _character(ref);
          await db.addMemberToBank(
            VoiceBankMembersCompanion(
              id: Value(_uuid.v4()),
              bankId: Value(id),
              voiceAssetId: Value(a.id),
            ),
          );
        }
        return _bankJson((await _bank(id)));
      },
    ),
    McpTool(
      name: 'update_voice_bank',
      title: 'Update voice bank',
      description: 'Rename a bank, change its description or active flag.',
      inputSchema: _obj(
        {
          'bank_id': _str('Bank id or exact name.'),
          'name': _str('New name.'),
          'description': _str('New description.'),
          'active': _bool('Active flag.'),
        },
        required: ['bank_id'],
      ),
      handler: (args) async {
        final bank = await _bank(_req(args, 'bank_id'));
        final updated = bank.copyWith(
          name: _opt(args, 'name') ?? bank.name,
          description: args.containsKey('description')
              ? Value(_opt(args, 'description'))
              : Value(bank.description),
          isActive: _bool0(args, 'active') ?? bank.isActive,
        );
        await db.updateBank(updated);
        return _bankJson(updated);
      },
    ),
    McpTool(
      name: 'delete_voice_bank',
      title: 'Delete voice bank',
      description:
          'Delete a bank. Fails while a project uses it. Characters that '
          'belong to no other bank are deleted too.',
      inputSchema: _obj(
        {'bank_id': _str('Bank id or exact name.')},
        required: ['bank_id'],
      ),
      destructive: true,
      handler: (args) async {
        final bank = await _bank(_req(args, 'bank_id'));
        await db.deleteBank(bank.id);
        return {'deleted': bank.id};
      },
    ),
    McpTool(
      name: 'add_characters_to_bank',
      title: 'Add characters to bank',
      description: 'Add voice characters to a bank (duplicates are ignored).',
      inputSchema: _obj(
        {
          'bank_id': _str('Bank id or exact name.'),
          'character_ids': _arr(_str('Character id or name.')),
        },
        required: ['bank_id', 'character_ids'],
      ),
      handler: (args) async {
        final bank = await _bank(_req(args, 'bank_id'));
        final added = <String>[];
        for (final ref in _strList(args, 'character_ids')) {
          final a = await _character(ref);
          await db.addMemberToBank(
            VoiceBankMembersCompanion(
              id: Value(_uuid.v4()),
              bankId: Value(bank.id),
              voiceAssetId: Value(a.id),
            ),
          );
          added.add(a.id);
        }
        return {'bank_id': bank.id, 'added': added};
      },
    ),
    McpTool(
      name: 'remove_characters_from_bank',
      title: 'Remove characters from bank',
      description:
          'Remove characters from a bank. The characters themselves are kept.',
      inputSchema: _obj(
        {
          'bank_id': _str('Bank id or exact name.'),
          'character_ids': _arr(_str('Character id or name.')),
        },
        required: ['bank_id', 'character_ids'],
      ),
      handler: (args) async {
        final bank = await _bank(_req(args, 'bank_id'));
        var removed = 0;
        for (final ref in _strList(args, 'character_ids')) {
          final a = await _character(ref);
          removed += await db.removeMemberByAssetAndBank(bank.id, a.id);
        }
        return {'bank_id': bank.id, 'removed': removed};
      },
    ),

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
        },
        required: ['character_id', 'text'],
      ),
      openWorld: true,
      handler: _synthesizeSpeech,
    ),

    // ── Video dubbing ──
    McpTool(
      name: 'list_video_dub_projects',
      title: 'List video dub projects',
      description: 'Video dubbing projects with cue / generation progress.',
      inputSchema: _obj({}),
      readOnly: true,
      handler: (_) async {
        final projects = await db.getAllVideoDubProjects();
        return {
          'projects': [
            for (final pr in projects)
              _projectJson(pr, await db.getSubtitleCues(pr.id)),
          ],
        };
      },
    ),
    McpTool(
      name: 'create_video_dub_project',
      title: 'Create video dub project',
      description:
          'Create a dubbing project bound to a voice bank (its characters '
          'are the cast), optionally attaching the source video.',
      inputSchema: _obj(
        {
          'name': _str('Project name.'),
          'bank_id': _str('Voice bank id or exact name.'),
          'video_path': _str('Absolute path of the source video.'),
        },
        required: ['name', 'bank_id'],
      ),
      handler: (args) async {
        final bank = await _bank(_req(args, 'bank_id'));
        final id = _uuid.v4();
        final now = DateTime.now();
        await db.insertVideoDubProject(
          VideoDubProjectsCompanion(
            id: Value(id),
            name: Value(_req(args, 'name')),
            bankId: Value(bank.id),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        final video = _opt(args, 'video_path');
        if (video != null) await _attachVideo(id, video, replace: false);
        final project = await _project(id);
        return _projectJson(project, const []);
      },
    ),
    McpTool(
      name: 'attach_video_to_dub_project',
      title: 'Attach source video',
      description:
          'Set the source video of a dub project (V1 + original audio A1).',
      inputSchema: _obj(
        {
          'project_id': _str('Video dub project id.'),
          'video_path': _str('Absolute path of the video.'),
          'replace': _bool('Replace an existing video (default false).'),
        },
        required: ['project_id', 'video_path'],
      ),
      handler: (args) async {
        final id = (await _project(_req(args, 'project_id'))).id;
        await _attachVideo(
          id,
          _req(args, 'video_path'),
          replace: _bool0(args, 'replace') ?? false,
        );
        final project = await _project(id);
        return _projectJson(project, await db.getSubtitleCues(id));
      },
    ),
    McpTool(
      name: 'import_subtitles',
      title: 'Import subtitles',
      description:
          'Import SRT / VTT / LRC cues from a file or inline text into a dub '
          'project. Optionally assign one character to every imported cue; '
          'use update_subtitle_cues for per-cue casting.',
      inputSchema: _obj(
        {
          'project_id': _str('Video dub project id.'),
          'file_path': _str('Absolute path of a .srt/.vtt/.lrc/.txt file.'),
          'subtitle_text': _str('Inline subtitle content instead of a file.'),
          'format': _str(
            'Format of subtitle_text (default srt).',
            enumValues: ['srt', 'vtt', 'lrc', 'txt'],
          ),
          'character_id': _str('Character for all imported cues.'),
          'replace': _bool('Replace existing cues (default false = append).'),
        },
        required: ['project_id'],
      ),
      handler: _importSubtitles,
    ),
    McpTool(
      name: 'list_subtitle_cues',
      title: 'List subtitle cues',
      description:
          'Cues of a dub project with timing, text, assigned character and '
          'generated audio status.',
      inputSchema: _obj(
        {
          'project_id': _str('Video dub project id.'),
          'offset': _int('Skip this many cues.'),
          'limit': _int('Max cues to return (default 500).'),
        },
        required: ['project_id'],
      ),
      readOnly: true,
      handler: (args) async {
        final project = await _project(_req(args, 'project_id'));
        final cues = await db.getSubtitleCues(project.id);
        final assets = {for (final a in await db.getAllVoiceAssets()) a.id: a};
        final offset = _int0(args, 'offset') ?? 0;
        final limit = _int0(args, 'limit') ?? 500;
        return {
          'project_id': project.id,
          'total': cues.length,
          'cues': [
            for (final c in cues.skip(offset).take(limit))
              _cueJson(c, assets[c.voiceAssetId]),
          ],
        };
      },
    ),
    McpTool(
      name: 'add_subtitle_cues',
      title: 'Add subtitle cues',
      description:
          'Append cues you wrote yourself (e.g. a translated or rewritten '
          'script) to a dub project.',
      inputSchema: _obj(
        {
          'project_id': _str('Video dub project id.'),
          'cues': _arr(
            _obj(
              {
                'start_ms': _int('Start time in ms.'),
                'end_ms': _int('End time in ms.'),
                'text': _str('Line to speak.'),
                'character_id': _str('Character id or name.'),
              },
              required: ['start_ms', 'end_ms', 'text'],
            ),
          ),
        },
        required: ['project_id', 'cues'],
      ),
      handler: _addCues,
    ),
    McpTool(
      name: 'update_subtitle_cues',
      title: 'Update / cast subtitle cues',
      description:
          'Batch-edit cues: assign characters (casting), fix text or timing. '
          'Changing text clears that cue\'s generated audio. '
          'assign_all_character_id casts every cue at once before the '
          'per-cue updates are applied.',
      inputSchema: _obj(
        {
          'project_id': _str('Video dub project id.'),
          'assign_all_character_id': _str('Character for every cue.'),
          'updates': _arr(
            _obj(
              {
                'cue_id': _str('Cue id.'),
                'character_id': _str('Character id or name ("" unassigns).'),
                'text': _str('New text.'),
                'start_ms': _int('New start (ms).'),
                'end_ms': _int('New end (ms).'),
              },
              required: ['cue_id'],
            ),
          ),
        },
        required: ['project_id'],
      ),
      handler: _updateCues,
    ),
    McpTool(
      name: 'delete_subtitle_cues',
      title: 'Delete subtitle cues',
      description: 'Delete specific cues, or all cues with all=true.',
      inputSchema: _obj(
        {
          'project_id': _str('Video dub project id.'),
          'cue_ids': _arr(_str('Cue id.')),
          'all': _bool('Delete every cue of the project.'),
        },
        required: ['project_id'],
      ),
      destructive: true,
      handler: (args) async {
        final project = await _project(_req(args, 'project_id'));
        if (_bool0(args, 'all') == true) {
          final n = await db.clearSubtitleCues(project.id);
          return {'deleted': n};
        }
        var n = 0;
        final own = (await db.getSubtitleCues(
          project.id,
        )).map((c) => c.id).toSet();
        for (final id in _strList(args, 'cue_ids')) {
          if (own.contains(id)) n += await db.deleteSubtitleCue(id);
        }
        return {'deleted': n};
      },
    ),
    McpTool(
      name: 'generate_video_dub_audio',
      title: 'Generate dub audio',
      description:
          'Run TTS for the project\'s cues (those with a character). By '
          'default only cues without audio are generated. Requests go '
          'through the shared queue, so provider concurrency limits apply. '
          'Can take minutes for long videos.',
      inputSchema: _obj(
        {
          'project_id': _str('Video dub project id.'),
          'cue_ids': _arr(_str('Only these cues.')),
          'regenerate': _bool('Regenerate cues that already have audio.'),
          'sync_cue_length': _bool(
            'Snap each cue end to its generated audio length.',
          ),
        },
        required: ['project_id'],
      ),
      openWorld: true,
      handler: _generateDub,
    ),
    McpTool(
      name: 'export_video_dub',
      title: 'Export dub',
      description:
          'Render the project with ffmpeg: kind=video muxes the source video '
          'with all cue audio (+ sidecar .srt), kind=audio mixes a single '
          'audio file, kind=srt writes only the subtitles.',
      inputSchema: _obj(
        {
          'project_id': _str('Video dub project id.'),
          'output_path': _str('Absolute output file path.'),
          'kind': _str(
            'What to export (default video).',
            enumValues: ['video', 'audio', 'srt'],
          ),
          'include_original_audio': _bool(
            'Mix in the source video\'s original audio (default false).',
          ),
        },
        required: ['project_id', 'output_path'],
      ),
      handler: _exportDub,
    ),
    McpTool(
      name: 'delete_video_dub_project',
      title: 'Delete video dub project',
      description:
          'Delete a dub project and its cues. Generated files stay on disk.',
      inputSchema: _obj(
        {'project_id': _str('Video dub project id.')},
        required: ['project_id'],
      ),
      destructive: true,
      handler: (args) async {
        final project = await _project(_req(args, 'project_id'));
        await db.deleteVideoDubProject(project.id);
        return {'deleted': project.id};
      },
    ),
  ];

  // ───────────────────────── Handlers ─────────────────────────

  Future<Object?> _overview(Map<String, dynamic> _) async {
    final providers = await db.getAllProviders();
    final ffmpegOk = await _ffmpeg.isAvailable();
    return {
      'app': 'Neiroha',
      'platform': PlatformCapabilities.current().platformLabel,
      'audio_library_root': PathService.instance.voiceAssetRoot.path,
      'ffmpeg_available': ffmpegOk,
      'counts': {
        'providers': providers.length,
        'enabled_providers': providers.where((p) => p.enabled).length,
        'voice_characters': (await db.getAllVoiceAssets()).length,
        'voice_banks': (await db.getAllBanks()).length,
        'audio_tracks': (await db.getAllAudioTracksRaw()).length,
        'video_dub_projects': (await db.getAllVideoDubProjects()).length,
      },
      'enabled_providers': [
        for (final pr in providers)
          if (pr.enabled)
            {'id': pr.id, 'name': pr.name, 'adapter_type': pr.adapterType},
      ],
    };
  }

  Future<Object?> _createProvider(Map<String, dynamic> args) async {
    final type = _adapterType(_req(args, 'adapter_type'));
    final providers = await db.getAllProviders();
    final id = _uuid.v4();
    final rpm = _int0(args, 'requests_per_minute');
    await db.insertProvider(
      TtsProvidersCompanion(
        id: Value(id),
        name: Value(_req(args, 'name')),
        adapterType: Value(type.name),
        baseUrl: Value(_opt(args, 'base_url') ?? _defaultBaseUrl(type)),
        apiKey: Value(_raw(args, 'api_key') ?? ''),
        defaultModelName: Value(
          _opt(args, 'default_model') ?? type.defaultModel,
        ),
        enabled: Value(_bool0(args, 'enabled') ?? true),
        position: Value(providers.length),
        maxConcurrency: Value(_int0(args, 'max_concurrency') ?? 1),
        requestsPerMinute: Value(rpm == null || rpm <= 0 ? null : rpm),
      ),
    );
    return _providerJson(await _provider(id));
  }

  Future<Object?> _updateProvider(Map<String, dynamic> args) async {
    final pr = await _provider(_req(args, 'provider_id'));
    final rpm = _int0(args, 'requests_per_minute');
    final updated = pr.copyWith(
      name: _opt(args, 'name') ?? pr.name,
      baseUrl: _raw(args, 'base_url')?.trim() ?? pr.baseUrl,
      apiKey: _raw(args, 'api_key') ?? pr.apiKey,
      defaultModelName: _opt(args, 'default_model') ?? pr.defaultModelName,
      enabled: _bool0(args, 'enabled') ?? pr.enabled,
      maxConcurrency: _int0(args, 'max_concurrency') ?? pr.maxConcurrency,
      requestsPerMinute: args.containsKey('requests_per_minute')
          ? Value(rpm == null || rpm <= 0 ? null : rpm)
          : Value(pr.requestsPerMinute),
    );
    await db.updateProvider(updated);
    return _providerJson(updated);
  }

  Future<AudioTrack> _importTrack(Map<String, dynamic> args) async {
    final filePath = _opt(args, 'file_path');
    final url = _opt(args, 'url');
    if (filePath == null && url == null) {
      throw const McpToolError('Pass file_path or url');
    }
    final dir = await PathService.instance.voiceCharacterRefDir();
    String source;
    File? tempDownload;
    if (filePath != null) {
      source = filePath;
      if (!await File(source).exists()) {
        throw McpToolError('File not found: $source');
      }
    } else {
      final uri = Uri.tryParse(url!);
      if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
        throw McpToolError('Unsupported URL: $url');
      }
      final ext = p.extension(uri.path).isEmpty
          ? '.bin'
          : p.extension(uri.path);
      final tmp = p.join(
        Directory.systemTemp.path,
        'neiroha_dl_${_uuid.v4()}$ext',
      );
      await Dio().download(url, tmp);
      tempDownload = File(tmp);
      source = tmp;
    }

    try {
      final baseName =
          _opt(args, 'name') ??
          p.basenameWithoutExtension(filePath ?? Uri.parse(url!).path);
      final stem =
          '${PathService.sanitizeSegment(baseName, fallback: 'ref')}_${PathService.formatTimestamp()}';
      final start = _num0(args, 'start_sec');
      final end = _num0(args, 'end_sec');
      final ext = p.extension(source).toLowerCase();
      final needsConvert =
          start != null || end != null || !_audioExts.contains(ext);

      String dest;
      if (needsConvert) {
        if (!await _ffmpeg.isAvailable()) {
          throw const McpToolError(
            'ffmpeg is required to trim or extract audio from video; '
            'configure it in Neiroha Settings or pass a plain audio file.',
          );
        }
        dest = PathService.dedupeFilename(dir, stem, '.wav');
        await _extractAudio(source, dest, start: start, end: end);
      } else {
        dest = PathService.dedupeFilename(dir, stem, ext);
        await File(source).copy(dest);
      }

      final id = _uuid.v4();
      await db.insertAudioTrack(
        AudioTracksCompanion(
          id: Value(id),
          name: Value(baseName),
          description: Value(_opt(args, 'description')),
          audioPath: Value(dest),
          refText: Value(_opt(args, 'ref_text')),
          refLang: Value(_opt(args, 'ref_lang')),
          durationSec: Value(await _probeDuration(dest)),
          sourceType: const Value('upload'),
          createdAt: Value(DateTime.now()),
        ),
      );
      return (await db.getAllAudioTracksRaw()).firstWhere((t) => t.id == id);
    } finally {
      if (tempDownload != null && await tempDownload.exists()) {
        await tempDownload.delete();
      }
    }
  }

  Future<Object?> _createCharacter(Map<String, dynamic> args) async {
    final provider = await _provider(_req(args, 'provider_id'));
    final type = _adapterType(provider.adapterType);
    final name = _req(args, 'name');
    var voice = _opt(args, 'voice');
    final model = _opt(args, 'model');
    final instruction = _opt(args, 'instruction');
    var promptText = _opt(args, 'prompt_text');
    var promptLang = _opt(args, 'prompt_lang');

    // Resolve reference audio (library track preferred).
    String? refAudio;
    final trackId = _opt(args, 'audio_track_id');
    if (trackId != null) {
      final track = await _track(trackId);
      refAudio = track.audioPath;
      promptText ??= track.refText;
      promptLang ??= track.refLang;
    } else if (_opt(args, 'ref_audio_path') case final rawPath?) {
      final track = await _importTrack({
        'file_path': rawPath,
        'name': name,
        'ref_text': ?promptText,
        'ref_lang': ?promptLang,
      });
      refAudio = track.audioPath;
    }

    // ElevenLabs / MiniMax: clone into a reusable account voice.
    final cloneOnProvider =
        type.supportsCloudVoiceClone &&
        refAudio != null &&
        (_bool0(args, 'clone_on_provider') ?? voice == null);
    if (cloneOnProvider) {
      final adapter = createAdapter(provider, modelName: model);
      if (adapter is! VoiceCloneCapable) {
        throw McpToolError('${type.displayName} cannot clone voices');
      }
      voice = await (adapter as VoiceCloneCapable).cloneVoice(
        name: name,
        audioPath: refAudio,
        promptText: promptText,
        description: _opt(args, 'description'),
      );
      refAudio = null;
    }

    final taskMode = _opt(args, 'task_mode') != null
        ? _taskMode(_opt(args, 'task_mode')!)
        : _inferTaskMode(type, model, voice, refAudio, instruction);

    if (type.requiresReferenceAudio && refAudio == null) {
      throw McpToolError(
        '${type.displayName} clones from reference audio on every request: '
        'pass audio_track_id or ref_audio_path.',
      );
    }
    if (taskMode == TaskMode.cloneWithPrompt &&
        refAudio == null &&
        voice == null) {
      throw const McpToolError(
        'cloneWithPrompt needs reference audio (audio_track_id or '
        'ref_audio_path) or a server-registered voice.',
      );
    }
    if (taskMode == TaskMode.presetVoice &&
        voice == null &&
        type != AdapterType.cosyvoice) {
      throw const McpToolError(
        'presetVoice needs a voice — see list_provider_voices.',
      );
    }

    final id = _uuid.v4();
    await db.insertVoiceAsset(
      VoiceAssetsCompanion(
        id: Value(id),
        name: Value(name),
        description: Value(_opt(args, 'description')),
        providerId: Value(provider.id),
        modelName: Value(model),
        taskMode: Value(taskMode.name),
        refAudioPath: Value(refAudio),
        promptText: Value(promptText),
        promptLang: Value(promptLang),
        voiceInstruction: Value(instruction),
        presetVoiceName: Value(voice),
        speed: Value(_num0(args, 'speed') ?? 1.0),
      ),
    );
    for (final bankRef in _strList(args, 'bank_ids')) {
      final bank = await _bank(bankRef);
      await db.addMemberToBank(
        VoiceBankMembersCompanion(
          id: Value(_uuid.v4()),
          bankId: Value(bank.id),
          voiceAssetId: Value(id),
        ),
      );
    }
    return {
      ..._characterJson((await db.getVoiceAssetById(id))!, provider),
      if (cloneOnProvider) 'cloned_on_provider': true,
    };
  }

  Future<Object?> _updateCharacter(Map<String, dynamic> args) async {
    final a = await _character(_req(args, 'character_id'));
    Value<String?> textField(String key, String? current) =>
        args.containsKey(key) ? Value(_opt(args, key)) : Value(current);

    var refAudio = a.refAudioPath;
    var promptText = a.promptText;
    var promptLang = a.promptLang;
    if (_opt(args, 'audio_track_id') case final trackId?) {
      final track = await _track(trackId);
      refAudio = track.audioPath;
      promptText = track.refText ?? promptText;
      promptLang = track.refLang ?? promptLang;
    }
    final updated = a.copyWith(
      name: _opt(args, 'name') ?? a.name,
      description: textField('description', a.description),
      modelName: textField('model', a.modelName),
      presetVoiceName: textField('voice', a.presetVoiceName),
      voiceInstruction: textField('instruction', a.voiceInstruction),
      refAudioPath: Value(refAudio),
      promptText: args.containsKey('prompt_text')
          ? Value(_opt(args, 'prompt_text'))
          : Value(promptText),
      promptLang: args.containsKey('prompt_lang')
          ? Value(_opt(args, 'prompt_lang'))
          : Value(promptLang),
      speed: _num0(args, 'speed') ?? a.speed,
      enabled: _bool0(args, 'enabled') ?? a.enabled,
    );
    await db.updateVoiceAsset(updated);
    final provider = (await db.getAllProviders())
        .where((pr) => pr.id == updated.providerId)
        .firstOrNull;
    return _characterJson(updated, provider);
  }

  Future<Object?> _synthesizeSpeech(Map<String, dynamic> args) async {
    final asset = await _character(_req(args, 'character_id'));
    final text = _req(args, 'text');
    String outPath;
    if (_opt(args, 'output_path') case final custom?) {
      outPath = custom;
      await File(outPath).parent.create(recursive: true);
    } else {
      final slug = await _storage.ensureVoiceAssetSlug(asset.id);
      final dir = await PathService.instance.quickTtsDir(slug);
      outPath = PathService.dedupeFilename(
        dir,
        'mcp_${PathService.formatTimestamp()}',
        '',
      );
    }
    final result = await _synthesizeToFile(
      asset,
      text,
      outPath,
      source: 'MCP',
      speed: _num0(args, 'speed'),
      instruction: _raw(args, 'instruction'),
    );
    await db.insertQuickTtsHistory(
      QuickTtsHistoriesCompanion(
        id: Value(_uuid.v4()),
        voiceAssetId: Value(asset.id),
        voiceName: Value(asset.name),
        inputText: Value(text),
        audioPath: Value(result.path),
        audioDuration: Value(result.durationSec),
        createdAt: Value(DateTime.now()),
      ),
    );
    return {
      'character_id': asset.id,
      'path': result.path,
      'content_type': result.contentType,
      'duration_sec': result.durationSec,
      if (_bool0(args, 'return_audio') == true)
        'audio_base64': base64Encode(await File(result.path).readAsBytes()),
    };
  }

  Future<Object?> _importSubtitles(Map<String, dynamic> args) async {
    final project = await _project(_req(args, 'project_id'));
    final filePath = _opt(args, 'file_path');
    final inline = _raw(args, 'subtitle_text');
    List<ParsedCue> parsed;
    if (filePath != null) {
      final f = File(filePath);
      if (!await f.exists()) throw McpToolError('File not found: $filePath');
      parsed = await SubtitleParser.parseFile(f);
    } else if (inline != null && inline.trim().isNotEmpty) {
      final format = _opt(args, 'format') ?? 'srt';
      final tmp = File(
        p.join(Directory.systemTemp.path, 'neiroha_sub_${_uuid.v4()}.$format'),
      );
      await tmp.writeAsString(inline);
      try {
        parsed = await SubtitleParser.parseFile(tmp);
      } finally {
        await tmp.delete();
      }
    } else {
      throw const McpToolError('Pass file_path or subtitle_text');
    }
    if (parsed.isEmpty) throw const McpToolError('No cues found');

    String? voiceId;
    if (_opt(args, 'character_id') case final ref?) {
      voiceId = (await _character(ref)).id;
    }
    final existing = await db.getSubtitleCues(project.id);
    var nextOrder = 0;
    if (_bool0(args, 'replace') == true) {
      await db.clearSubtitleCues(project.id);
    } else if (existing.isNotEmpty) {
      nextOrder =
          existing.map((c) => c.orderIndex).reduce((a, b) => a > b ? a : b) + 1;
    }
    for (var i = 0; i < parsed.length; i++) {
      final c = parsed[i];
      await db.insertSubtitleCue(
        SubtitleCuesCompanion(
          id: Value(_uuid.v4()),
          projectId: Value(project.id),
          orderIndex: Value(nextOrder + i),
          startMs: Value(c.startMs),
          endMs: Value(c.endMs),
          cueText: Value(c.text),
          voiceAssetId: Value(voiceId),
        ),
      );
    }
    await _touch(project);
    return {
      'project_id': project.id,
      'imported': parsed.length,
      'total_cues': (await db.getSubtitleCues(project.id)).length,
    };
  }

  Future<Object?> _addCues(Map<String, dynamic> args) async {
    final project = await _project(_req(args, 'project_id'));
    final cues = args['cues'];
    if (cues is! List || cues.isEmpty) {
      throw const McpToolError('cues must be a non-empty array');
    }
    final existing = await db.getSubtitleCues(project.id);
    var order = existing.isEmpty
        ? 0
        : existing.map((c) => c.orderIndex).reduce((a, b) => a > b ? a : b) + 1;
    final ids = <String>[];
    for (final raw in cues.whereType<Map<String, dynamic>>()) {
      final start = _int0(raw, 'start_ms');
      final end = _int0(raw, 'end_ms');
      final text = _req(raw, 'text');
      if (start == null || end == null || end <= start) {
        throw McpToolError('Invalid timing for cue "$text"');
      }
      String? voiceId;
      if (_opt(raw, 'character_id') case final ref?) {
        voiceId = (await _character(ref)).id;
      }
      final id = _uuid.v4();
      await db.insertSubtitleCue(
        SubtitleCuesCompanion(
          id: Value(id),
          projectId: Value(project.id),
          orderIndex: Value(order++),
          startMs: Value(start),
          endMs: Value(end),
          cueText: Value(text),
          voiceAssetId: Value(voiceId),
        ),
      );
      ids.add(id);
    }
    await _touch(project);
    return {'project_id': project.id, 'added_cue_ids': ids};
  }

  Future<Object?> _updateCues(Map<String, dynamic> args) async {
    final project = await _project(_req(args, 'project_id'));
    var cues = {for (final c in await db.getSubtitleCues(project.id)) c.id: c};
    var changed = 0;

    if (_opt(args, 'assign_all_character_id') case final ref?) {
      final voiceId = (await _character(ref)).id;
      for (final c in cues.values) {
        if (c.voiceAssetId == voiceId) continue;
        await db.updateSubtitleCue(
          c.copyWith(
            voiceAssetId: Value(voiceId),
            audioPath: const Value(null),
            audioDuration: const Value(null),
            error: const Value(null),
          ),
        );
        changed++;
      }
      cues = {for (final c in await db.getSubtitleCues(project.id)) c.id: c};
    }

    final updates = args['updates'];
    final missing = <String>[];
    if (updates is List) {
      for (final raw in updates.whereType<Map<String, dynamic>>()) {
        final cueId = _req(raw, 'cue_id');
        final cue = cues[cueId];
        if (cue == null) {
          missing.add(cueId);
          continue;
        }
        var next = cue;
        var invalidateAudio = false;
        if (raw.containsKey('character_id')) {
          final ref = _opt(raw, 'character_id');
          final voiceId = ref == null ? null : (await _character(ref)).id;
          if (voiceId != cue.voiceAssetId) {
            next = next.copyWith(voiceAssetId: Value(voiceId));
            invalidateAudio = true;
          }
        }
        if (_raw(raw, 'text') case final text?
            when text.trim() != cue.cueText) {
          next = next.copyWith(cueText: text.trim());
          invalidateAudio = true;
        }
        final start = _int0(raw, 'start_ms');
        final end = _int0(raw, 'end_ms');
        if (start != null) next = next.copyWith(startMs: start);
        if (end != null) next = next.copyWith(endMs: end);
        if (next.endMs <= next.startMs) {
          throw McpToolError('Cue $cueId: end_ms must be > start_ms');
        }
        if (invalidateAudio) {
          next = next.copyWith(
            audioPath: const Value(null),
            audioDuration: const Value(null),
            error: const Value(null),
          );
        }
        if (next != cue) {
          await db.updateSubtitleCue(next);
          changed++;
        }
      }
    }
    await _touch(project);
    return {
      'project_id': project.id,
      'changed': changed,
      if (missing.isNotEmpty) 'unknown_cue_ids': missing,
    };
  }

  Future<Object?> _generateDub(Map<String, dynamic> args) async {
    final project = await _project(_req(args, 'project_id'));
    final only = _strList(args, 'cue_ids').toSet();
    final regenerate = _bool0(args, 'regenerate') ?? false;
    final sync = _bool0(args, 'sync_cue_length') ?? false;
    final cues = await db.getSubtitleCues(project.id);
    final assets = {for (final a in await db.getAllVoiceAssets()) a.id: a};
    final slug = await _storage.ensureVideoDubProjectSlug(project.id);
    final outDir = await PathService.instance.videoDubDir(slug);

    final targets = [
      for (final c in cues)
        if ((only.isEmpty || only.contains(c.id)) &&
            c.voiceAssetId != null &&
            (regenerate || c.audioPath == null))
          c,
    ];
    final unassigned = cues
        .where((c) => (only.isEmpty || only.contains(c.id)))
        .where((c) => c.voiceAssetId == null)
        .length;

    final failures = <Map<String, dynamic>>[];
    var done = 0;
    await Future.wait([
      for (final cue in targets)
        () async {
          final asset = assets[cue.voiceAssetId];
          if (asset == null) {
            failures.add({'cue_id': cue.id, 'error': 'character not found'});
            return;
          }
          try {
            final base = p.join(
              outDir.path,
              'cue_${cue.orderIndex}_${PathService.formatTimestamp()}_'
              '${cue.id.substring(0, 6)}',
            );
            final r = await _synthesizeToFile(
              asset,
              cue.cueText,
              base,
              source: 'MCP Video Dub',
              label: 'Cue ${cue.orderIndex + 1}: ${cue.cueText}',
            );
            final newEnd = sync && r.durationSec != null
                ? cue.startMs + (r.durationSec! * 1000).round()
                : cue.endMs;
            await db.updateSubtitleCue(
              cue.copyWith(
                audioPath: Value(r.path),
                audioDuration: Value(r.durationSec),
                error: const Value(null),
                endMs: newEnd,
              ),
            );
            done++;
          } catch (e) {
            await db.updateSubtitleCue(cue.copyWith(error: Value('$e')));
            failures.add({'cue_id': cue.id, 'error': '$e'});
          }
        }(),
    ]);
    await _touch(project);
    return {
      'project_id': project.id,
      'generated': done,
      'failed': failures.length,
      'skipped_without_character': unassigned,
      if (failures.isNotEmpty) 'failures': failures.take(50).toList(),
    };
  }

  Future<Object?> _exportDub(Map<String, dynamic> args) async {
    final project = await _project(_req(args, 'project_id'));
    final kind = _opt(args, 'kind') ?? 'video';
    final outPath = _req(args, 'output_path');
    await File(outPath).parent.create(recursive: true);
    final cues = await db.getSubtitleCues(project.id);

    if (kind == 'srt') {
      await File(outPath).writeAsString(cuesToSrt(cues));
      return {'path': outPath, 'cues': cues.length};
    }
    if (!await _ffmpeg.isAvailable()) {
      throw const McpToolError(
        'ffmpeg is required for export; set it in Neiroha Settings.',
      );
    }
    final clips = await db.getTimelineClips(project.id, 'videodub');
    final overlays = <DubAudioOverlay>[
      for (final c in cues)
        if (c.audioPath != null && File(c.audioPath!).existsSync())
          DubAudioOverlay(path: c.audioPath!, startMs: c.startMs),
      for (final c in clips)
        if (c.laneIndex == DubLanes.a3 && File(c.audioPath).existsSync())
          DubAudioOverlay(path: c.audioPath, startMs: c.startTimeMs),
    ];
    final includeOriginal = _bool0(args, 'include_original_audio') ?? false;
    final src = project.videoPath;
    final prefs = await _exportPrefs.load();
    List<String> ffArgs;
    if (kind == 'video') {
      if (src == null || !File(src).existsSync()) {
        throw const McpToolError(
          'Project has no source video; use attach_video_to_dub_project or '
          'export kind=audio.',
        );
      }
      ffArgs = buildDubVideoExportArgs(
        videoPath: src,
        includeOriginalAudio: includeOriginal,
        overlays: overlays,
        outPath: outPath,
        videoCodec: prefs.videoFfmpegCodec,
        audioCodec: prefs.videoAudioFfmpegCodec,
      );
    } else if (kind == 'audio') {
      final withOriginal =
          includeOriginal && src != null && File(src).existsSync();
      if (overlays.isEmpty && !withOriginal) {
        throw const McpToolError(
          'Nothing to export: generate cue audio first.',
        );
      }
      ffArgs = buildDubAudioExportArgs(
        sourceVideoPath: withOriginal ? src : null,
        overlays: overlays,
        outPath: outPath,
        audioCodec: _codecForExt(p.extension(outPath).toLowerCase()),
      );
    } else {
      throw McpToolError('Unknown kind "$kind"');
    }

    final result = await Process.run(await _ffmpeg.resolvePath(), ffArgs);
    if (result.exitCode != 0) {
      final err = '${result.stderr}';
      throw McpToolError(
        'ffmpeg failed: ${err.length > 1500 ? err.substring(err.length - 1500) : err}',
      );
    }
    String? srtPath;
    if (kind == 'video') {
      srtPath = p.setExtension(outPath, '.srt');
      await File(srtPath).writeAsString(cuesToSrt(cues));
    }
    return {
      'path': outPath,
      'srt_path': ?srtPath,
      'mixed_clips': overlays.length,
      'cues_without_audio': cues.where((c) => c.audioPath == null).length,
    };
  }

  // ───────────────────────── Internals ─────────────────────────

  Future<_SynthResult> _synthesizeToFile(
    VoiceAsset asset,
    String text,
    String outPathOrBase, {
    required String source,
    String? label,
    double? speed,
    String? instruction,
  }) async {
    if (!asset.enabled) {
      throw McpToolError('Character "${asset.name}" is disabled');
    }
    final provider = (await db.getAllProviders())
        .where((pr) => pr.id == asset.providerId)
        .firstOrNull;
    if (provider == null) {
      throw McpToolError('Provider of "${asset.name}" not found');
    }
    if (!provider.enabled) {
      throw McpToolError(
        'Provider "${provider.name}" is disabled — enable it with '
        'update_provider.',
      );
    }
    final result = await TtsQueueService.instance.synthesize(
      provider: provider,
      modelName: asset.modelName,
      source: source,
      label: label ?? '${asset.name}: $text',
      request: TtsRequest(
        text: text,
        voice: asset.presetVoiceName ?? asset.name,
        speed: speed ?? asset.speed,
        textLang: provider.adapterType == 'gptSovits' ? asset.modelName : null,
        presetVoiceName: asset.presetVoiceName,
        voiceInstruction: instruction ?? asset.voiceInstruction,
        refAudioPath: asset.refAudioPath,
        promptText: asset.promptText,
        promptLang: asset.promptLang,
      ),
    );
    final ext = _extForContentType(result.contentType);
    var path = outPathOrBase;
    if (p.extension(path).isEmpty) path = '$path$ext';
    await File(path).writeAsBytes(result.audioBytes);
    return _SynthResult(
      path: path,
      contentType: result.contentType,
      durationSec: await _probeDuration(path, bytes: result.audioBytes),
    );
  }

  Future<void> _attachVideo(
    String projectId,
    String videoPath, {
    required bool replace,
  }) async {
    if (!await File(videoPath).exists()) {
      throw McpToolError('Video not found: $videoPath');
    }
    final clips = await db.getTimelineClips(projectId, 'videodub');
    final v1 = clips.where((c) => c.laneIndex == DubLanes.v1).toList();
    if (v1.isNotEmpty) {
      if (!replace) {
        throw const McpToolError(
          'Project already has a video; pass replace=true to swap it.',
        );
      }
      final groups = v1.map((c) => c.linkGroupId).whereType<String>().toSet();
      for (final c in clips) {
        if (c.laneIndex == DubLanes.v1 ||
            (c.laneIndex == DubLanes.a1 && groups.contains(c.linkGroupId))) {
          await db.deleteTimelineClip(c.id);
        }
      }
    }
    final duration = await _probeDuration(videoPath);
    final label = p.basenameWithoutExtension(videoPath);
    final linkId = _uuid.v4();
    for (final (lane, type) in [
      (DubLanes.v1, 'video'),
      (DubLanes.a1, 'video-audio'),
    ]) {
      await db.insertTimelineClip(
        makeDubClipCompanion(
          id: _uuid.v4(),
          projectId: projectId,
          lane: lane,
          startTimeMs: 0,
          sourceType: type,
          audioPath: videoPath,
          label: label,
          durationSec: duration,
          linkGroupId: linkId,
        ),
      );
    }
    final project = await _project(projectId);
    await db.updateVideoDubProject(
      project.copyWith(
        videoPath: Value(videoPath),
        videoDurationSec: Value(duration),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _extractAudio(
    String input,
    String output, {
    double? start,
    double? end,
  }) async {
    final ffArgs = <String>[
      '-y',
      '-i',
      input,
      if (start != null) ...['-ss', start.toStringAsFixed(3)],
      if (end != null) ...['-to', end.toStringAsFixed(3)],
      '-vn',
      '-ac',
      '1',
      '-c:a',
      'pcm_s16le',
      output,
    ];
    final result = await Process.run(await _ffmpeg.resolvePath(), ffArgs);
    if (result.exitCode != 0) {
      final err = '${result.stderr}';
      throw McpToolError(
        'ffmpeg could not extract audio: '
        '${err.length > 800 ? err.substring(err.length - 800) : err}',
      );
    }
  }

  Future<double?> _probeDuration(String path, {Uint8List? bytes}) async {
    final viaFfprobe = await _ffmpeg.probeDurationSeconds(path);
    if (viaFfprobe != null && viaFfprobe > 0) return viaFfprobe;
    try {
      return _wavDuration(bytes ?? await File(path).readAsBytes());
    } catch (_) {
      return null;
    }
  }

  /// Duration of a PCM RIFF/WAVE buffer, or null for other formats.
  static double? _wavDuration(Uint8List b) {
    if (b.length < 44 || String.fromCharCodes(b.sublist(0, 4)) != 'RIFF') {
      return null;
    }
    final bd = ByteData.sublistView(b);
    var offset = 12;
    int? byteRate;
    while (offset + 8 <= b.length) {
      final id = String.fromCharCodes(b.sublist(offset, offset + 4));
      final size = bd.getUint32(offset + 4, Endian.little);
      if (id == 'fmt ') byteRate = bd.getUint32(offset + 16, Endian.little);
      if (id == 'data' && byteRate != null && byteRate > 0) {
        final dataLen = size == 0xFFFFFFFF || offset + 8 + size > b.length
            ? b.length - offset - 8
            : size;
        return dataLen / byteRate;
      }
      offset += 8 + size + (size.isOdd ? 1 : 0);
    }
    return null;
  }

  Future<void> _touch(VideoDubProject project) async {
    final fresh = await db.getVideoDubProjectById(project.id) ?? project;
    await db.updateVideoDubProject(fresh.copyWith(updatedAt: DateTime.now()));
  }

  TaskMode _inferTaskMode(
    AdapterType type,
    String? model,
    String? voice,
    String? refAudio,
    String? instruction,
  ) {
    final m = (model ?? '').toLowerCase();
    if (type.requiresReferenceAudio) return TaskMode.cloneWithPrompt;
    switch (type) {
      case AdapterType.cosyvoice:
        if (m == 'instruct') return TaskMode.voiceDesign;
        if (m == 'zero_shot' || m == 'cross_lingual' || refAudio != null) {
          return TaskMode.cloneWithPrompt;
        }
        return TaskMode.presetVoice;
      case AdapterType.voxcpm2Native:
        return m == 'design' ? TaskMode.voiceDesign : TaskMode.cloneWithPrompt;
      case AdapterType.chatCompletionsTts:
        if (m.contains('clone')) return TaskMode.cloneWithPrompt;
        if (m.contains('design')) return TaskMode.voiceDesign;
        return TaskMode.presetVoice;
      default:
        if (refAudio != null) return TaskMode.cloneWithPrompt;
        if (voice == null && instruction != null) return TaskMode.voiceDesign;
        return TaskMode.presetVoice;
    }
  }

  // ── Lookups ──

  Future<TtsProvider> _provider(String ref) async {
    final all = await db.getAllProviders();
    return all.where((x) => x.id == ref).firstOrNull ??
        all
            .where((x) => x.name.toLowerCase() == ref.toLowerCase())
            .firstOrNull ??
        (throw McpToolError('Provider "$ref" not found (see list_providers)'));
  }

  Future<VoiceAsset> _character(String ref) async {
    final byId = await db.getVoiceAssetById(ref);
    if (byId != null) return byId;
    final all = await db.getAllVoiceAssets();
    return all
            .where((a) => a.name.toLowerCase() == ref.toLowerCase())
            .firstOrNull ??
        (throw McpToolError(
          'Character "$ref" not found (see list_voice_characters)',
        ));
  }

  Future<VoiceBank> _bank(String ref) async {
    final all = await db.getAllBanks();
    return all.where((b) => b.id == ref).firstOrNull ??
        all
            .where((b) => b.name.toLowerCase() == ref.toLowerCase())
            .firstOrNull ??
        (throw McpToolError('Voice bank "$ref" not found'));
  }

  Future<AudioTrack> _track(String id) async {
    final all = await db.getAllAudioTracksRaw();
    return all.where((t) => t.id == id).firstOrNull ??
        all.where((t) => t.name == id).firstOrNull ??
        (throw McpToolError('Audio track "$id" not found'));
  }

  Future<VideoDubProject> _project(String id) async {
    final byId = await db.getVideoDubProjectById(id);
    if (byId != null) return byId;
    final all = await db.getAllVideoDubProjects();
    return all.where((x) => x.name == id).firstOrNull ??
        (throw McpToolError('Video dub project "$id" not found'));
  }

  AdapterType _adapterType(String name) {
    final t = AdapterType.values.where((t) => t.name == name).firstOrNull;
    if (t == null) {
      throw McpToolError(
        'Unknown adapter_type "$name". Valid: '
        '${AdapterType.values.map((t) => t.name).join(', ')}',
      );
    }
    if (t == AdapterType.systemTts &&
        !PlatformCapabilities.current().supportsSystemTtsAdapter) {
      throw const McpToolError('systemTts is only available on Windows');
    }
    return t;
  }

  TaskMode _taskMode(String name) =>
      TaskMode.values.where((m) => m.name == name).firstOrNull ??
      (throw McpToolError('Unknown task_mode "$name"'));

  List<AdapterType> _availableTypes() => [
    for (final t in AdapterType.values)
      if (t != AdapterType.systemTts ||
          PlatformCapabilities.current().supportsSystemTtsAdapter)
        t,
  ];

  // ── JSON views ──

  Map<String, dynamic> _providerJson(TtsProvider pr) => {
    'id': pr.id,
    'name': pr.name,
    'adapter_type': pr.adapterType,
    'base_url': pr.baseUrl,
    'has_api_key': pr.apiKey.isNotEmpty,
    'default_model': pr.defaultModelName,
    'enabled': pr.enabled,
    'max_concurrency': pr.maxConcurrency,
    'requests_per_minute': pr.requestsPerMinute,
  };

  Map<String, dynamic> _characterJson(VoiceAsset a, TtsProvider? pr) => {
    'id': a.id,
    'name': a.name,
    'description': a.description,
    'provider_id': a.providerId,
    'provider_name': pr?.name,
    'adapter_type': pr?.adapterType,
    'task_mode': a.taskMode,
    'model': a.modelName,
    'voice': a.presetVoiceName,
    'ref_audio_path': a.refAudioPath,
    'prompt_text': a.promptText,
    'prompt_lang': a.promptLang,
    'instruction': a.voiceInstruction,
    'speed': a.speed,
    'enabled': a.enabled,
  };

  Map<String, dynamic> _bankJson(VoiceBank b) => {
    'id': b.id,
    'name': b.name,
    'description': b.description,
    'active': b.isActive,
  };

  Map<String, dynamic> _trackJson(AudioTrack t) => {
    'id': t.id,
    'name': t.name,
    'description': t.description,
    'path': t.audioPath,
    'ref_text': t.refText,
    'ref_lang': t.refLang,
    'duration_sec': t.durationSec,
    'missing': t.missing,
  };

  Map<String, dynamic> _projectJson(
    VideoDubProject pr,
    List<SubtitleCue> cues,
  ) => {
    'id': pr.id,
    'name': pr.name,
    'bank_id': pr.bankId,
    'video_path': pr.videoPath,
    'video_duration_sec': pr.videoDurationSec,
    'cues': cues.length,
    'cues_with_character': cues.where((c) => c.voiceAssetId != null).length,
    'cues_with_audio': cues.where((c) => c.audioPath != null).length,
    'cues_with_error': cues.where((c) => c.error != null).length,
    'updated_at': pr.updatedAt.toIso8601String(),
  };

  Map<String, dynamic> _cueJson(SubtitleCue c, VoiceAsset? a) => {
    'id': c.id,
    'index': c.orderIndex,
    'start_ms': c.startMs,
    'end_ms': c.endMs,
    'text': c.cueText,
    'character_id': c.voiceAssetId,
    'character_name': a?.name,
    'audio_path': c.audioPath,
    'audio_duration_sec': c.audioDuration,
    'error': c.error,
  };

  Map<String, dynamic> _adapterJson(AdapterType t) => {
    'adapter_type': t.name,
    'display_name': t.displayName,
    'default_base_url': _defaultBaseUrl(t),
    'default_model': t.defaultModel,
    'supports_model_list': t.supportsModelQuery,
    'supports_voice_list': t.supportsVoiceQuery,
    'supports_cloud_voice_clone': t.supportsCloudVoiceClone,
    'requires_reference_audio': t.requiresReferenceAudio,
    'guide': _adapterGuide[t],
  };

  static String _defaultBaseUrl(AdapterType t) => switch (t) {
    AdapterType.openaiCompatible => 'http://localhost:8880/v1',
    AdapterType.chatCompletionsTts => 'https://api.xiaomimimo.com/v1',
    AdapterType.gptSovits => 'http://127.0.0.1:9880',
    AdapterType.cosyvoice => 'http://127.0.0.1:9880',
    AdapterType.voxcpm2Native => 'http://127.0.0.1:8000',
    AdapterType.azureTts => 'https://eastus.tts.speech.microsoft.com',
    AdapterType.systemTts => '',
    AdapterType.geminiTts => 'https://generativelanguage.googleapis.com',
    AdapterType.elevenLabs => 'https://api.elevenlabs.io',
    AdapterType.minimaxTts => 'https://api.minimax.io',
    AdapterType.indexTts => 'http://127.0.0.1:7860',
  };

  static const Map<AdapterType, String> _adapterGuide = {
    AdapterType.openaiCompatible:
        'Any OpenAI /v1/audio/speech server (also Qwen3-TTS / Kokoro '
        'FastAPI wrappers). model = TTS model id (tts-1, gpt-4o-mini-tts…); '
        'voice = preset voice (alloy…). task_mode presetVoice.',
    AdapterType.chatCompletionsTts:
        'MiMo-style chat-completions TTS. The model decides the mode: names '
        'containing "voiceclone" need reference audio (cloneWithPrompt), '
        '"voicedesign" need an instruction (voiceDesign), others use a '
        'preset voice. instruction = style direction.',
    AdapterType.cosyvoice:
        'CosyVoice launcher. model = mode: zero_shot (reference audio + '
        'prompt_text), cross_lingual (reference audio), instruct '
        '(instruction, optional reference audio). voice = optional '
        'server profile name.',
    AdapterType.voxcpm2Native:
        'VoxCPM2 launcher. model = design (instruction required) | clone '
        '(reference audio) | ultimate_clone (reference audio + prompt_text). '
        'voice = optional server-registered voice id.',
    AdapterType.gptSovits:
        'GPT-SoVITS launcher. presetVoice: voice = trained speaker, model = '
        'text language (zh/en/ja/ko). cloneWithPrompt: reference audio + '
        'prompt_text + prompt_lang, model = text language.',
    AdapterType.azureTts:
        'Azure Speech. base_url = https://{region}.tts.speech.microsoft.com; '
        'api_key = subscription key; voice = e.g. zh-CN-XiaoxiaoNeural.',
    AdapterType.systemTts:
        'Windows SAPI voices. No URL / key. voice = installed voice name.',
    AdapterType.geminiTts:
        'Google AI Studio. model = gemini-3.8-flash-tts (default), '
        'gemini-3.8-flash-lite-tts, or legacy 2.5/3.1 preview models; voice '
        '= prebuilt voice (Kore, Puck, Charon…) or library voice; '
        'instruction = delivery style (emotion, pace). No cloning.',
    AdapterType.elevenLabs:
        'ElevenLabs. model = eleven_v4 (default), eleven_v4_turbo, '
        'eleven_v3, eleven_multilingual_v2, eleven_flash_v2_5; voice = '
        '"Name [voice_id]" or raw voice_id; instruction = v3/v4 audio tag '
        'such as "whispers". Reference audio without a voice creates an '
        'instant voice clone on the account.',
    AdapterType.minimaxTts:
        'MiniMax speech. base_url https://api.minimax.io (mainland China '
        'accounts: https://api.minimaxi.com). model = speech-2.8-hd '
        '(default) / speech-2.8-turbo / speech-2.6-*; voice = voice_id; '
        'instruction = one emotion keyword (happy, sad, angry, fearful, '
        'disgusted, surprised, calm, fluent, whisper). Reference audio '
        '(10 s–5 min) without a voice clones it; MiniMax deletes clones '
        'unused for 7 days.',
    AdapterType.indexTts:
        'IndexTTS 2.5 through its Gradio WebUI (community one-click '
        'packages, start-webui.bat, default http://127.0.0.1:7860). '
        'Zero-shot: every character needs reference audio (5–15 s clean '
        'speech). model = synthesis language auto | ZH | EN | JA | AR | ES. '
        'instruction = emotion description (only when the WebUI loads the '
        'experimental emotion model).',
  };

  // ── Schema + argument helpers ──

  static const _audioExts = {
    '.wav',
    '.mp3',
    '.flac',
    '.ogg',
    '.m4a',
    '.aac',
    '.opus',
  };

  static String _extForContentType(String ct) {
    final c = ct.toLowerCase();
    if (c.contains('wav')) return '.wav';
    if (c.contains('flac')) return '.flac';
    if (c.contains('ogg') || c.contains('opus')) return '.ogg';
    if (c.contains('aac') || c.contains('mp4')) return '.m4a';
    return '.mp3';
  }

  static String _codecForExt(String ext) => switch (ext) {
    '.mp3' => 'libmp3lame',
    '.flac' => 'flac',
    '.m4a' || '.aac' => 'aac',
    '.ogg' || '.opus' => 'libopus',
    _ => 'pcm_s16le',
  };

  static Map<String, dynamic> _obj(
    Map<String, Map<String, dynamic>> props, {
    List<String> required = const [],
  }) => {
    'type': 'object',
    'properties': props,
    if (required.isNotEmpty) 'required': required,
  };

  static Map<String, dynamic> _str(String d, {List<String>? enumValues}) => {
    'type': 'string',
    'description': d,
    'enum': ?enumValues,
  };

  static Map<String, dynamic> _int(String d) => {
    'type': 'integer',
    'description': d,
  };

  static Map<String, dynamic> _num(String d) => {
    'type': 'number',
    'description': d,
  };

  static Map<String, dynamic> _bool(String d) => {
    'type': 'boolean',
    'description': d,
  };

  static Map<String, dynamic> _arr(Map<String, dynamic> items) => {
    'type': 'array',
    'items': items,
  };

  static String _req(Map<String, dynamic> a, String k) {
    final v = a[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    throw McpToolError('Missing required argument "$k"');
  }

  /// Trimmed non-empty string, else null.
  static String? _opt(Map<String, dynamic> a, String k) {
    final v = a[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }

  /// Raw string (may be empty), else null.
  static String? _raw(Map<String, dynamic> a, String k) {
    final v = a[k];
    return v is String ? v : null;
  }

  static bool? _bool0(Map<String, dynamic> a, String k) {
    final v = a[k];
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    return null;
  }

  static int? _int0(Map<String, dynamic> a, String k) {
    final v = a[k];
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _num0(Map<String, dynamic> a, String k) {
    final v = a[k];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static List<String> _strList(Map<String, dynamic> a, String k) {
    final v = a[k];
    if (v is List) {
      return v.whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    }
    if (v is String && v.trim().isNotEmpty) return [v.trim()];
    return const [];
  }
}

class _SynthResult {
  final String path;
  final String contentType;
  final double? durationSec;
  const _SynthResult({
    required this.path,
    required this.contentType,
    required this.durationSec,
  });
}
