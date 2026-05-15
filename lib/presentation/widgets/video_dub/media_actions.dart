part of 'editor.dart';

extension _VideoDubEditorMediaActions on _VideoDubEditorState {
  // ───────────────── Actions ─────────────────

  Future<double?> _probeMediaDuration(String path) async {
    final ffmpeg = ref.read(ffmpegServiceProvider);
    final viaFfmpeg = await ffmpeg.probeDurationSeconds(path);
    if (viaFfmpeg != null && viaFfmpeg > 0) return viaFfmpeg;

    final probe = Player();
    try {
      await probe.open(Media(path), play: false);
      final duration = await probe.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 2), onTimeout: () => Duration.zero);
      return duration > Duration.zero ? duration.inMilliseconds / 1000.0 : null;
    } catch (_) {
      return null;
    } finally {
      await probe.dispose();
    }
  }

  /// Import video, image, or audio onto the multi-track timeline.
  /// Files are copied into `{voiceAssetRoot}/video_dub/{slug}/assets/`
  /// and registered as TimelineClips under `projectType='videodub'`.
  /// Start time = end of the last clip on the same lane (stacked append).
  /// Duration is probed via ffprobe first, then media_kit as a local fallback;
  /// image clips default to 3 s so they have something visible until stretched.
  /// Premiere-style import: references the source file in place (no
  /// copy into the project folder). The DB row stores the absolute path;
  /// a missing source later lights up as a red "missing" clip.
  ///
  /// A `video` import inserts **two** linked rows — V1 (video) + A1
  /// (video-audio) — sharing a `linkGroupId` so subsequent drag/trim
  /// work can move them in lock-step.
  Future<void> _importMedia(
    db.VideoDubProject project,
    DubImportKind kind,
    List<db.TimelineClip> existing,
  ) async {
    // Single-video constraint: refuse a second V1 import. The toolbar
    // disables the button too, but guard here in case it's invoked
    // programmatically.
    if (kind == DubImportKind.video &&
        existing.any((c) => c.laneIndex == DubLanes.v1)) {
      _snack('Delete the V1 clip first — only one source video is allowed');
      return;
    }

    final typeForPicker = switch (kind) {
      DubImportKind.video => FileType.video,
      DubImportKind.audio => FileType.audio,
    };
    final picked = await FilePicker.platform.pickFiles(
      type: typeForPicker,
      allowMultiple: false,
    );
    final src = picked?.files.single.path;
    if (src == null) return;
    if (!await File(src).exists()) return;

    final base = p.basenameWithoutExtension(src);
    double? duration;
    switch (kind) {
      case DubImportKind.video:
        duration = await _probeMediaDuration(src);
        break;
      case DubImportKind.audio:
        duration = await _probeMediaDuration(src);
        break;
    }

    final assignment = laneAndSourceForImport(kind);

    // Stack append on the target lane: start at the end of the last clip
    // already on it, so successive imports don't stack on top of each other.
    var startMs = 0;
    for (final c in existing) {
      if (c.laneIndex != assignment.lane) continue;
      final end = c.startTimeMs + ((c.durationSec ?? 0) * 1000).round();
      if (end > startMs) startMs = end;
    }

    final database = ref.read(databaseProvider);
    final uuid = const Uuid();
    _markDirty();

    if (kind == DubImportKind.video) {
      final linkId = uuid.v4();
      await database.insertTimelineClip(
        makeDubClipCompanion(
          id: uuid.v4(),
          projectId: project.id,
          lane: DubLanes.v1,
          startTimeMs: startMs,
          sourceType: 'video',
          audioPath: src,
          label: base,
          durationSec: duration,
          linkGroupId: linkId,
        ),
      );
      await database.insertTimelineClip(
        makeDubClipCompanion(
          id: uuid.v4(),
          projectId: project.id,
          lane: DubLanes.a1,
          startTimeMs: startMs,
          sourceType: 'video-audio',
          audioPath: src,
          label: base,
          durationSec: duration,
          linkGroupId: linkId,
        ),
      );
      // Promote the imported clip to the active video for the central
      // surface. Without this the clip lands on V1 but the player has
      // nothing to render, so the timeline appears wired up to nothing.
      await database.updateVideoDubProject(
        project.copyWith(videoPath: Value(src), updatedAt: DateTime.now()),
      );
    } else {
      await database.insertTimelineClip(
        makeDubClipCompanion(
          id: uuid.v4(),
          projectId: project.id,
          lane: assignment.lane,
          startTimeMs: startMs,
          sourceType: assignment.sourceType,
          audioPath: src,
          label: base,
          durationSec: duration,
        ),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).uiImported(base))),
      );
    }
  }

  Future<void> _exportVideo(db.VideoDubProject project) async {
    final cues =
        ref.read(subtitleCuesStreamProvider(widget.projectId)).valueOrNull ??
        const <db.SubtitleCue>[];
    final clips =
        ref
            .read(timelineClipsStreamProvider('videodub:${widget.projectId}'))
            .valueOrNull ??
        const <db.TimelineClip>[];
    _updateState(() => _exporting = true);
    try {
      await exportVideoDubVideo(
        context: context,
        ref: ref,
        project: project,
        cues: cues,
        clips: clips,
        muteVideoAudio: _muteVideoAudio,
        playerDuration: _duration,
      );
    } finally {
      if (mounted) _updateState(() => _exporting = false);
    }
  }

  Future<void> _exportAudio(db.VideoDubProject project) async {
    final cues =
        ref.read(subtitleCuesStreamProvider(widget.projectId)).valueOrNull ??
        const <db.SubtitleCue>[];
    final clips =
        ref
            .read(timelineClipsStreamProvider('videodub:${widget.projectId}'))
            .valueOrNull ??
        const <db.TimelineClip>[];
    _updateState(() => _exporting = true);
    try {
      await exportVideoDubAudio(
        context: context,
        ref: ref,
        project: project,
        cues: cues,
        clips: clips,
        muteVideoAudio: _muteVideoAudio,
        playerDuration: _duration,
      );
    } finally {
      if (mounted) _updateState(() => _exporting = false);
    }
  }

  Future<void> _exportSubtitlesAndTts(
    db.VideoDubProject project,
    List<db.SubtitleCue> cues,
  ) async {
    _updateState(() => _exportingSubtitles = true);
    try {
      await exportVideoDubSubtitlesAndTts(
        context: context,
        project: project,
        cues: cues,
      );
    } finally {
      if (mounted) _updateState(() => _exportingSubtitles = false);
    }
  }

  /// Re-fit each cue's `endMs` so the on-screen subtitle length matches
  /// its generated TTS audio length. Skips cues that haven't been
  /// generated yet (no `audioPath` / `audioDuration`). Preserves
  /// `startMs` — only the end edge moves. The user can fix overlap with
  /// a follow-up drag if needed.
  Future<void> _syncCueLengthsToAudio(List<db.SubtitleCue> cues) async {
    _updateState(() => _syncingCueLengths = true);
    final db_ = ref.read(databaseProvider);
    var adjusted = 0;
    var skipped = 0;
    try {
      for (final cue in cues) {
        final dur = cue.audioDuration;
        if (dur == null || dur <= 0) {
          skipped++;
          continue;
        }
        final newEnd = cue.startMs + (dur * 1000).round();
        if (newEnd == cue.endMs) continue;
        await db_.updateSubtitleCue(cue.copyWith(endMs: newEnd));
        adjusted++;
      }
      if (adjusted > 0) _markDirty();
      if (mounted) {
        _snack(
          'Synced $adjusted cue(s) to audio length'
          '${skipped > 0 ? ' ($skipped without audio skipped)' : ''}',
        );
      }
    } finally {
      if (mounted) _updateState(() => _syncingCueLengths = false);
    }
  }

  /// Persist a cue-block drag from the timeline. Duration is preserved;
  /// only the start (and matching end) shift.
  Future<void> _moveCueTo(db.SubtitleCue cue, int newStartMs) async {
    final clamped = newStartMs < 0 ? 0 : newStartMs;
    final dur = cue.endMs - cue.startMs;
    await ref
        .read(databaseProvider)
        .updateSubtitleCue(
          cue.copyWith(startMs: clamped, endMs: clamped + dur),
        );
    _markDirty();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
