part of 'neiroha_mcp_tools.dart';

/// Video dubbing tools.
extension _DubTools on NeirohaMcpTools {
  List<McpTool> _dubTools() => [
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
          'auto_normalize_loudness': _bool(
            'Normalize every generated cue to the bank / character loudness '
            'target (default false).',
          ),
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
            autoNormalizeLoudness: Value(
              _bool0(args, 'auto_normalize_loudness') ?? false,
            ),
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
      name: 'normalize_video_dub_loudness',
      title: 'Unify cue loudness',
      description:
          'Bring every generated cue of the project to the same perceived '
          'loudness (EBU R128): the bank loudness target plus each '
          "character's loudness_offset_db. Static gain + limiter, files are "
          'rewritten in place and the originals kept in an _original_audio '
          'folder, so restore: true undoes it. auto_normalize toggles '
          'normalizing future cues right after generation. Needs ffmpeg.',
      inputSchema: _obj(
        {
          'project_id': _str('Video dub project id.'),
          'cue_ids': _arr(_str('Only these cues.')),
          'target_lufs': _num(
            'Base target in LUFS (-30..-10); defaults to the bank target.',
          ),
          'use_character_offsets': _bool(
            'Apply each character loudness_offset_db (default true).',
          ),
          'restore': _bool('Put the original audio back instead.'),
          'apply': _bool(
            'Process existing cues (default true). Set false to only change '
            'auto_normalize.',
          ),
          'auto_normalize': _bool(
            'Also normalize future cues right after generation.',
          ),
        },
        required: ['project_id'],
      ),
      handler: _normalizeDubLoudness,
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
}
