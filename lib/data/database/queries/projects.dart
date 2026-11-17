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
    await _deleteTimelineClipsForProject(id, 'phase');
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

  Future<int> deletePhaseTtsSegment(String id) => transaction(() async {
    await deleteTimelineClipsByLine(id, projectType: 'phase');
    return (delete(phaseTtsSegments)..where((t) => t.id.equals(id))).go();
  });

  /// Rewrite `orderIndex` as 0..n-1 following [ordered].
  Future<void> _renumberPhaseSegments(List<PhaseTtsSegment> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      if (ordered[i].orderIndex == i) continue;
      await (update(phaseTtsSegments)..where((t) => t.id.equals(ordered[i].id)))
          .write(PhaseTtsSegmentsCompanion(orderIndex: Value(i)));
    }
  }

  /// Move a segment; indexes are positions in the ordered list.
  Future<void> reorderPhaseSegment(
    String projectId,
    int oldIndex,
    int newIndex,
  ) => transaction(() async {
    final segments = await getPhaseTtsSegments(projectId);
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        oldIndex >= segments.length ||
        newIndex < 0 ||
        newIndex >= segments.length) {
      return;
    }
    segments.insert(newIndex, segments.removeAt(oldIndex));
    await _renumberPhaseSegments(segments);
  });

  /// Insert a new segment right after [afterId] (at the top when null).
  Future<void> insertPhaseSegmentAfter({
    required String projectId,
    required String? afterId,
    required String id,
    required String text,
    String? voiceAssetId,
  }) => transaction(() async {
    final segments = await getPhaseTtsSegments(projectId);
    final at = afterId == null
        ? 0
        : segments.indexWhere((s) => s.id == afterId) + 1;
    await into(phaseTtsSegments).insert(
      PhaseTtsSegmentsCompanion(
        id: Value(id),
        projectId: Value(projectId),
        orderIndex: Value(at),
        segmentText: Value(text),
        voiceAssetId: Value(voiceAssetId),
      ),
    );
    final inserted = await (select(
      phaseTtsSegments,
    )..where((t) => t.id.equals(id))).getSingle();
    segments.insert(at.clamp(0, segments.length), inserted);
    await _renumberPhaseSegments(segments);
  });

  /// Split [segment] into [head] (keeps the id) and [tail] (new row with
  /// [tailId], same voice). Both lose their generated audio.
  Future<void> splitPhaseSegment(
    PhaseTtsSegment segment,
    String head,
    String tail,
    String tailId,
  ) => transaction(() async {
    await updatePhaseTtsSegment(
      segment.copyWith(
        segmentText: head,
        audioPath: const Value(null),
        audioDuration: const Value(null),
        error: const Value(null),
        missing: false,
      ),
    );
    await insertPhaseSegmentAfter(
      projectId: segment.projectId,
      afterId: segment.id,
      id: tailId,
      text: tail,
      voiceAssetId: segment.voiceAssetId,
    );
  });

  /// Append the next segment's text to [segmentId] and drop the next row.
  /// Returns false when [segmentId] is the last segment.
  Future<bool> mergePhaseSegmentWithNext(String projectId, String segmentId) =>
      transaction(() async {
        final segments = await getPhaseTtsSegments(projectId);
        final i = segments.indexWhere((s) => s.id == segmentId);
        if (i < 0 || i + 1 >= segments.length) return false;
        final a = segments[i];
        final b = segments[i + 1];
        await updatePhaseTtsSegment(
          a.copyWith(
            segmentText: _joinSegmentText(a.segmentText, b.segmentText),
            voiceAssetId: Value(a.voiceAssetId ?? b.voiceAssetId),
            audioPath: const Value(null),
            audioDuration: const Value(null),
            error: const Value(null),
            missing: false,
          ),
        );
        await deletePhaseTtsSegment(b.id);
        segments.removeAt(i + 1);
        await _renumberPhaseSegments(segments);
        return true;
      });

  /// CJK text joins without a space; Latin text needs one.
  static String _joinSegmentText(String a, String b) {
    final left = a.trimRight();
    final right = b.trimLeft();
    if (left.isEmpty || right.isEmpty) return '$left$right';
    final latin =
        RegExp(r'[A-Za-z0-9,.;:!?]$').hasMatch(left) &&
        RegExp(r'^[A-Za-z0-9]').hasMatch(right);
    return latin ? '$left $right' : '$left$right';
  }

  Future<void> deletePhaseSegments(String projectId, Iterable<String> ids) =>
      transaction(() async {
        for (final id in ids) {
          await deletePhaseTtsSegment(id);
        }
        await _renumberPhaseSegments(await getPhaseTtsSegments(projectId));
      });

  /// Undo for deletions: put [rows] back at their old positions.
  Future<void> restorePhaseSegments(
    String projectId,
    List<PhaseTtsSegment> rows,
  ) => transaction(() async {
    final current = await getPhaseTtsSegments(projectId);
    final restored = [...rows]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    for (final row in restored) {
      await into(phaseTtsSegments).insertOnConflictUpdate(row);
      current.insert(row.orderIndex.clamp(0, current.length), row);
    }
    await _renumberPhaseSegments(current);
  });

  Future<int> clearPhaseTtsSegments(String projectId) => transaction(() async {
    await _deleteTimelineClipsForProject(projectId, 'phase');
    return (delete(
      phaseTtsSegments,
    )..where((t) => t.projectId.equals(projectId))).go();
  });

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
    await _deleteTimelineClipsForProject(id, 'dialog');
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

  Future<int> deleteDialogTtsLine(String id) => transaction(() async {
    await deleteTimelineClipsByLine(id, projectType: 'dialog');
    return (delete(dialogTtsLines)..where((t) => t.id.equals(id))).go();
  });

  Future<int> clearDialogTtsLines(String projectId) => transaction(() async {
    await _deleteTimelineClipsForProject(projectId, 'dialog');
    return (delete(
      dialogTtsLines,
    )..where((t) => t.projectId.equals(projectId))).go();
  });

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
    await _deleteTimelineClipsForProject(id, 'videodub');
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

  Future<int> deleteTimelineClip(String id) => transaction(() async {
    final clip = await (select(
      timelineClips,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (clip == null) return 0;
    final linkGroupId = clip.linkGroupId;
    if (linkGroupId != null && linkGroupId.isNotEmpty) {
      return (delete(timelineClips)..where(
            (t) =>
                t.projectId.equals(clip.projectId) &
                t.projectType.equals(clip.projectType) &
                t.linkGroupId.equals(linkGroupId),
          ))
          .go();
    }
    return (delete(timelineClips)..where((t) => t.id.equals(id))).go();
  });

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

  Future<int> deleteTimelineClipsByLine(
    String sourceLineId, {
    String? projectType,
  }) {
    return (delete(timelineClips)..where((t) {
          final byLine = t.sourceLineId.equals(sourceLineId);
          if (projectType == null) return byLine;
          return byLine & t.projectType.equals(projectType);
        }))
        .go();
  }

  Future<int> _deleteTimelineClipsForProject(
    String projectId,
    String projectType,
  ) {
    return (delete(timelineClips)..where(
          (t) =>
              t.projectId.equals(projectId) & t.projectType.equals(projectType),
        ))
        .go();
  }

  // --- Audio Tracks ---

  Stream<List<AudioTrack>> watchAllAudioTracks() => (select(
    audioTracks,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Future<int> insertAudioTrack(AudioTracksCompanion track) =>
      into(audioTracks).insert(track);

  Future<bool> updateAudioTrack(AudioTrack track) =>
      update(audioTracks).replace(track);

  Future<int> deleteAudioTrack(String id) => transaction(() async {
    final track = await (select(
      audioTracks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (track == null) return 0;
    await (update(
      voiceAssets,
    )..where((t) => t.refAudioPath.equals(track.audioPath))).write(
      const VoiceAssetsCompanion(
        refAudioPath: Value(null),
        refAudioTrimStart: Value(null),
        refAudioTrimEnd: Value(null),
      ),
    );
    await (update(quickTtsHistories)
          ..where((t) => t.audioPath.equals(track.audioPath)))
        .write(const QuickTtsHistoriesCompanion(missing: Value(true)));
    await (update(phaseTtsSegments)
          ..where((t) => t.audioPath.equals(track.audioPath)))
        .write(const PhaseTtsSegmentsCompanion(missing: Value(true)));
    await (update(dialogTtsLines)
          ..where((t) => t.audioPath.equals(track.audioPath)))
        .write(const DialogTtsLinesCompanion(missing: Value(true)));
    await (update(novelSegments)
          ..where((t) => t.audioPath.equals(track.audioPath)))
        .write(const NovelSegmentsCompanion(missing: Value(true)));
    await (update(subtitleCues)
          ..where((t) => t.audioPath.equals(track.audioPath)))
        .write(const SubtitleCuesCompanion(missing: Value(true)));
    await (update(timelineClips)
          ..where((t) => t.audioPath.equals(track.audioPath)))
        .write(const TimelineClipsCompanion(missing: Value(true)));
    return (delete(audioTracks)..where((t) => t.id.equals(id))).go();
  });
}
