part of 'neiroha_mcp_tools.dart';

/// Media helpers and lookups by id or name.
extension _Internals on NeirohaMcpTools {
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
      return wavDurationSeconds(bytes ?? await File(path).readAsBytes());
    } catch (_) {
      return null;
    }
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
}
