part of '../app_database.dart';

extension AppDatabaseProjectQueries on AppDatabase {
  // --- Phase TTS Projects ---

  Stream<List<PhaseTtsProject>> watchPhaseTtsProjects() => (select(
    phaseTtsProjects,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  Future<int> insertPhaseTtsProject(PhaseTtsProjectsCompanion project) =>
      into(phaseTtsProjects).insert(project);

  Future<List<PhaseTtsProject>> getAllPhaseTtsProjects() =>
      select(phaseTtsProjects).get();

  Future<PhaseTtsProject?> getPhaseTtsProjectById(String id) => (select(
    phaseTtsProjects,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<bool> updatePhaseTtsProject(PhaseTtsProject project) =>
      update(phaseTtsProjects).replace(project);

  Future<int> deletePhaseTtsProject(String id) => transaction(() async {
    await (delete(phaseTtsSegments)..where((t) => t.projectId.equals(id))).go();
    return (delete(phaseTtsProjects)..where((t) => t.id.equals(id))).go();
  });

  // --- Phase TTS Segments ---

  Stream<List<PhaseTtsSegment>> watchPhaseTtsSegments(String projectId) =>
      (select(phaseTtsSegments)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .watch();

  Future<List<PhaseTtsSegment>> getPhaseTtsSegments(String projectId) =>
      (select(phaseTtsSegments)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  Future<int> insertPhaseTtsSegment(PhaseTtsSegmentsCompanion seg) =>
      into(phaseTtsSegments).insert(seg);

  Future<bool> updatePhaseTtsSegment(PhaseTtsSegment seg) =>
      update(phaseTtsSegments).replace(seg);

  Future<int> deletePhaseTtsSegment(String id) =>
      (delete(phaseTtsSegments)..where((t) => t.id.equals(id))).go();

  Future<int> clearPhaseTtsSegments(String projectId) => (delete(
    phaseTtsSegments,
  )..where((t) => t.projectId.equals(projectId))).go();

  // --- Dialog TTS Projects ---

  Stream<List<DialogTtsProject>> watchDialogTtsProjects() => (select(
    dialogTtsProjects,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  Future<int> insertDialogTtsProject(DialogTtsProjectsCompanion project) =>
      into(dialogTtsProjects).insert(project);

  Future<List<DialogTtsProject>> getAllDialogTtsProjects() =>
      select(dialogTtsProjects).get();

  Future<DialogTtsProject?> getDialogTtsProjectById(String id) => (select(
    dialogTtsProjects,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<bool> updateDialogTtsProject(DialogTtsProject project) =>
      update(dialogTtsProjects).replace(project);

  Future<int> deleteDialogTtsProject(String id) => transaction(() async {
    await (delete(dialogTtsLines)..where((t) => t.projectId.equals(id))).go();
    return (delete(dialogTtsProjects)..where((t) => t.id.equals(id))).go();
  });

  // --- Dialog TTS Lines ---

  Stream<List<DialogTtsLine>> watchDialogTtsLines(String projectId) =>
      (select(dialogTtsLines)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .watch();

  Future<List<DialogTtsLine>> getDialogTtsLines(String projectId) =>
      (select(dialogTtsLines)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  Future<int> insertDialogTtsLine(DialogTtsLinesCompanion line) =>
      into(dialogTtsLines).insert(line);

  Future<bool> updateDialogTtsLine(DialogTtsLine line) =>
      update(dialogTtsLines).replace(line);

  Future<int> deleteDialogTtsLine(String id) =>
      (delete(dialogTtsLines)..where((t) => t.id.equals(id))).go();

  Future<int> clearDialogTtsLines(String projectId) => (delete(
    dialogTtsLines,
  )..where((t) => t.projectId.equals(projectId))).go();

  /// Reorder a dialog line within its project by rewriting all affected
  /// `orderIndex` values in a single transaction. `oldIndex` and `newIndex`
  /// are 0-based positions in the current ordered list.
  Future<void> reorderDialogLine(
    String projectId,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex) return;
    await transaction(() async {
      final lines = await getDialogTtsLines(projectId);
      if (oldIndex < 0 ||
          oldIndex >= lines.length ||
          newIndex < 0 ||
          newIndex >= lines.length) {
        return;
      }
      final moved = lines.removeAt(oldIndex);
      lines.insert(newIndex, moved);
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].orderIndex != i) {
          await (update(dialogTtsLines)..where((t) => t.id.equals(lines[i].id)))
              .write(DialogTtsLinesCompanion(orderIndex: Value(i)));
        }
      }
    });
  }

  // --- Video Dub Projects ---

  Stream<List<VideoDubProject>> watchVideoDubProjects() => (select(
    videoDubProjects,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  Future<int> insertVideoDubProject(VideoDubProjectsCompanion project) =>
      into(videoDubProjects).insert(project);

  Future<List<VideoDubProject>> getAllVideoDubProjects() =>
      select(videoDubProjects).get();

  Future<VideoDubProject?> getVideoDubProjectById(String id) => (select(
    videoDubProjects,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<bool> updateVideoDubProject(VideoDubProject project) =>
      update(videoDubProjects).replace(project);

  Future<int> deleteVideoDubProject(String id) => transaction(() async {
    await (delete(subtitleCues)..where((t) => t.projectId.equals(id))).go();
    return (delete(videoDubProjects)..where((t) => t.id.equals(id))).go();
  });

  // --- Subtitle Cues ---

  Stream<List<SubtitleCue>> watchSubtitleCues(String projectId) =>
      (select(subtitleCues)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .watch();

  Future<List<SubtitleCue>> getSubtitleCues(String projectId) =>
      (select(subtitleCues)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  Future<int> insertSubtitleCue(SubtitleCuesCompanion cue) =>
      into(subtitleCues).insert(cue);

  Future<bool> updateSubtitleCue(SubtitleCue cue) =>
      update(subtitleCues).replace(cue);

  Future<int> deleteSubtitleCue(String id) =>
      (delete(subtitleCues)..where((t) => t.id.equals(id))).go();

  Future<int> clearSubtitleCues(String projectId) =>
      (delete(subtitleCues)..where((t) => t.projectId.equals(projectId))).go();

  // --- Timeline Clips ---

  Stream<List<TimelineClip>> watchTimelineClips(
    String projectId,
    String projectType,
  ) =>
      (select(timelineClips)
            ..where(
              (t) =>
                  t.projectId.equals(projectId) &
                  t.projectType.equals(projectType),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.startTimeMs),
              (t) => OrderingTerm.asc(t.laneIndex),
            ]))
          .watch();

  Future<List<TimelineClip>> getTimelineClips(
    String projectId,
    String projectType,
  ) =>
      (select(timelineClips)
            ..where(
              (t) =>
                  t.projectId.equals(projectId) &
                  t.projectType.equals(projectType),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.startTimeMs)]))
          .get();

  Future<int> insertTimelineClip(TimelineClipsCompanion clip) =>
      into(timelineClips).insert(clip);

  Future<bool> updateTimelineClip(TimelineClip clip) =>
      update(timelineClips).replace(clip);

  Future<int> deleteTimelineClip(String id) =>
      (delete(timelineClips)..where((t) => t.id.equals(id))).go();

  /// Replace a clip's position (lane + start). Use for drag operations.
  Future<int> moveTimelineClip(
    String id, {
    required int laneIndex,
    required int startTimeMs,
  }) => (update(timelineClips)..where((t) => t.id.equals(id))).write(
    TimelineClipsCompanion(
      laneIndex: Value(laneIndex),
      startTimeMs: Value(startTimeMs),
    ),
  );

  Future<int> deleteTimelineClipsByLine(String sourceLineId) => (delete(
    timelineClips,
  )..where((t) => t.sourceLineId.equals(sourceLineId))).go();

  // --- Audio Tracks ---

  Stream<List<AudioTrack>> watchAllAudioTracks() => (select(
    audioTracks,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Future<int> insertAudioTrack(AudioTracksCompanion track) =>
      into(audioTracks).insert(track);

  Future<bool> updateAudioTrack(AudioTrack track) =>
      update(audioTracks).replace(track);

  Future<int> deleteAudioTrack(String id) =>
      (delete(audioTracks)..where((t) => t.id.equals(id))).go();
}
