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

  // --- Novel Reader Projects ---

  Stream<List<NovelProject>> watchNovelProjects() => (select(
    novelProjects,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  Future<int> insertNovelProject(NovelProjectsCompanion project) =>
      into(novelProjects).insert(project);

  Future<List<NovelProject>> getAllNovelProjects() =>
      select(novelProjects).get();

  Future<NovelProject?> getNovelProjectById(String id) =>
      (select(novelProjects)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<bool> updateNovelProject(NovelProject project) =>
      update(novelProjects).replace(project);

  Future<int> deleteNovelProject(String id) => transaction(() async {
    await (delete(novelSegments)..where((t) => t.projectId.equals(id))).go();
    await (delete(novelChapters)..where((t) => t.projectId.equals(id))).go();
    return (delete(novelProjects)..where((t) => t.id.equals(id))).go();
  });

  // --- Novel Reader Chapters ---

  Stream<List<NovelChapter>> watchNovelChapters(String projectId) =>
      (select(novelChapters)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .watch();

  Future<List<NovelChapter>> getNovelChapters(String projectId) =>
      (select(novelChapters)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  Future<int> insertNovelChapter(NovelChaptersCompanion chapter) =>
      into(novelChapters).insert(chapter);

  Future<void> insertNovelChapterWithSegments({
    required String projectId,
    required NovelChaptersCompanion chapter,
    required List<NovelSegmentsCompanion> segments,
  }) => transaction(() async {
    await into(novelChapters).insert(chapter);
    await batch((b) {
      if (segments.isNotEmpty) {
        b.insertAll(novelSegments, segments);
      }
    });
    final total = await _reindexNovelProject(projectId);
    await _touchNovelProjectAfterStructureEdit(projectId, total);
  });

  Future<bool> updateNovelChapter(NovelChapter chapter) =>
      update(novelChapters).replace(chapter);

  Future<int> deleteNovelChapter(String projectId, String chapterId) =>
      transaction(() async {
        await (delete(
          novelSegments,
        )..where((t) => t.chapterId.equals(chapterId))).go();
        final removed = await (delete(
          novelChapters,
        )..where((t) => t.id.equals(chapterId))).go();
        final total = await _reindexNovelProject(projectId);
        await _touchNovelProjectAfterStructureEdit(projectId, total);
        return removed;
      });

  Future<void> replaceNovelChapterText({
    required NovelChapter chapter,
    required List<NovelSegmentsCompanion> segments,
  }) => transaction(() async {
    await updateNovelChapter(chapter);
    await (delete(
      novelSegments,
    )..where((t) => t.chapterId.equals(chapter.id))).go();
    await batch((b) {
      if (segments.isNotEmpty) {
        b.insertAll(novelSegments, segments);
      }
    });
    final total = await _reindexNovelProject(chapter.projectId);
    await _touchNovelProjectAfterStructureEdit(chapter.projectId, total);
  });

  Future<int> clearNovelContent(String projectId) => transaction(() async {
    await (delete(
      novelSegments,
    )..where((t) => t.projectId.equals(projectId))).go();
    return (delete(
      novelChapters,
    )..where((t) => t.projectId.equals(projectId))).go();
  });

  Future<void> replaceNovelContent({
    required String projectId,
    required List<NovelChaptersCompanion> chapters,
    required List<NovelSegmentsCompanion> segments,
    required NovelProject project,
  }) => transaction(() async {
    await (delete(
      novelSegments,
    )..where((t) => t.projectId.equals(projectId))).go();
    await (delete(
      novelChapters,
    )..where((t) => t.projectId.equals(projectId))).go();
    await batch((b) {
      if (chapters.isNotEmpty) {
        b.insertAll(novelChapters, chapters);
      }
      if (segments.isNotEmpty) {
        b.insertAll(novelSegments, segments);
      }
    });
    await updateNovelProject(project);
  });

  // --- Novel Reader Segments ---

  Stream<List<NovelSegment>> watchNovelSegments(String projectId) =>
      (select(novelSegments)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.globalIndex)]))
          .watch();

  Stream<List<NovelSegment>> watchNovelSegmentsForChapter(String chapterId) =>
      (select(novelSegments)
            ..where((t) => t.chapterId.equals(chapterId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .watch();

  Future<List<NovelSegment>> getNovelSegments(String projectId) =>
      (select(novelSegments)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.globalIndex)]))
          .get();

  Future<List<NovelSegment>> getNovelSegmentsForChapter(String chapterId) =>
      (select(novelSegments)
            ..where((t) => t.chapterId.equals(chapterId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  Future<int> insertNovelSegment(NovelSegmentsCompanion segment) =>
      into(novelSegments).insert(segment);

  Future<bool> updateNovelSegment(NovelSegment segment) =>
      update(novelSegments).replace(segment);

  Future<int> deleteNovelSegment(String projectId, String segmentId) =>
      transaction(() async {
        final removed = await (delete(
          novelSegments,
        )..where((t) => t.id.equals(segmentId))).go();
        final total = await _reindexNovelProject(projectId);
        await _touchNovelProjectAfterStructureEdit(projectId, total);
        return removed;
      });

  Future<int> markNovelProgress(String projectId, int globalIndex) =>
      (update(novelProjects)..where((t) => t.id.equals(projectId))).write(
        NovelProjectsCompanion(
          currentGlobalIndex: Value(globalIndex),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<int> _reindexNovelProject(String projectId) async {
    final chapters = await getNovelChapters(projectId);
    var globalIndex = 0;
    for (var chapterIndex = 0; chapterIndex < chapters.length; chapterIndex++) {
      final chapter = chapters[chapterIndex];
      if (chapter.orderIndex != chapterIndex) {
        await (update(novelChapters)..where((t) => t.id.equals(chapter.id)))
            .write(NovelChaptersCompanion(orderIndex: Value(chapterIndex)));
      }

      final segments = await getNovelSegmentsForChapter(chapter.id);
      for (
        var segmentIndex = 0;
        segmentIndex < segments.length;
        segmentIndex++
      ) {
        final segment = segments[segmentIndex];
        if (segment.orderIndex != segmentIndex ||
            segment.globalIndex != globalIndex) {
          await (update(
            novelSegments,
          )..where((t) => t.id.equals(segment.id))).write(
            NovelSegmentsCompanion(
              globalIndex: Value(globalIndex),
              orderIndex: Value(segmentIndex),
            ),
          );
        }
        globalIndex++;
      }
    }
    return globalIndex;
  }

  Future<void> _touchNovelProjectAfterStructureEdit(
    String projectId,
    int totalSegments,
  ) async {
    final project = await getNovelProjectById(projectId);
    if (project == null) return;
    final current = totalSegments <= 0
        ? 0
        : project.currentGlobalIndex.clamp(0, totalSegments - 1).toInt();
    await (update(novelProjects)..where((t) => t.id.equals(projectId))).write(
      NovelProjectsCompanion(
        currentGlobalIndex: Value(current),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

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
