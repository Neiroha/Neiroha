part of 'neiroha_mcp_tools.dart';

/// Handlers for the video dubbing tools.
extension _DubHandlers on NeirohaMcpTools {
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
            final r = await synthesizeCharacterToFile(
              db,
              asset,
              cue.cueText,
              base,
              probe: _probeDuration,
              source: 'MCP Video Dub',
              label: 'Cue ${cue.orderIndex + 1}: ${cue.cueText}',
            );
            await _autoLoudness.normalizeGenerated(
              enabled: project.autoNormalizeLoudness,
              path: r.path,
              bankId: project.bankId,
              voiceAssetId: asset.id,
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

  Future<Object?> _normalizeDubLoudness(Map<String, dynamic> args) async {
    var project = await _project(_req(args, 'project_id'));
    if (_bool0(args, 'auto_normalize') case final auto?) {
      project = project.copyWith(autoNormalizeLoudness: auto);
      await db.updateVideoDubProject(project);
    }
    final only = _strList(args, 'cue_ids').toSet();
    final targets = [
      for (final c in await db.getSubtitleCues(project.id))
        if ((only.isEmpty || only.contains(c.id)) &&
            c.audioPath != null &&
            File(c.audioPath!).existsSync())
          c,
    ];
    final summary = <String, Object?>{
      'project_id': project.id,
      'auto_normalize_loudness': project.autoNormalizeLoudness,
    };
    if (_bool0(args, 'restore') ?? false) {
      var restored = 0;
      for (final c in targets) {
        if (await LoudnessNormalizer.restoreFile(c.audioPath!)) restored++;
      }
      return {...summary, 'restored': restored};
    }
    if (!(_bool0(args, 'apply') ?? true)) return summary;
    if (!await _ffmpeg.isAvailable()) {
      throw const McpToolError(
        'ffmpeg is required for loudness normalization; set it in Neiroha '
        'Settings.',
      );
    }
    final bank = await db.getBankById(project.bankId);
    final base =
        (_num0(args, 'target_lufs') ?? bank?.loudnessTargetLufs ?? -16.0)
            .clamp(-30.0, -10.0)
            .toDouble();
    final useOffsets = _bool0(args, 'use_character_offsets') ?? true;
    final assets = {for (final a in await db.getAllVoiceAssets()) a.id: a};
    final counts = {for (final k in LoudnessOutcomeKind.values) k.name: 0};
    final failures = <Map<String, String>>[];
    var next = 0;
    Future<void> worker() async {
      while (next < targets.length) {
        final cue = targets[next++];
        final offset = useOffsets
            ? assets[cue.voiceAssetId]?.loudnessOffsetDb ?? 0
            : 0.0;
        final outcome = await _loudness.normalizeFile(
          cue.audioPath!,
          LoudnessTarget(
            lufs: LoudnessNormalizer.targetFor(
              bankLufs: base,
              offsetDb: offset,
            ),
          ),
        );
        counts[outcome.kind.name] = counts[outcome.kind.name]! + 1;
        if (outcome.error case final error?) {
          failures.add({'cue_id': cue.id, 'error': error});
        }
      }
    }

    await Future.wait([for (var i = 0; i < 4; i++) worker()]);
    return {
      ...summary,
      'target_lufs': base,
      'use_character_offsets': useOffsets,
      ...counts,
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
}
