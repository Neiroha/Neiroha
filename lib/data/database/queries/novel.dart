part of '../app_database.dart';

extension AppDatabaseNovelQueries on AppDatabase {
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
    await (delete(appSettings)..where(
          (t) =>
              t.key.equals('novel.roles.preferences.$id') |
              t.key.equals('novel.structure.undo.$id') |
              t.key.like('novel.taskProfiles.$id.%') |
              t.key.like('novel.roleAnalysis.$id.%'),
        ))
        .go();
    final characters = await (select(
      novelCharacters,
    )..where((t) => t.projectId.equals(id))).get();
    await (delete(
      novelVoiceBindings,
    )..where((t) => t.characterId.isIn(characters.map((c) => c.id)))).go();
    await (delete(novelAnnotations)..where((t) => t.projectId.equals(id))).go();
    await (delete(novelRoleEdits)..where((t) => t.projectId.equals(id))).go();
    await (delete(novelCharacters)..where((t) => t.projectId.equals(id))).go();
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
    final count = await (delete(
      novelChapters,
    )..where((t) => t.projectId.equals(projectId))).go();
    await _purgeNovelRoleOrphans(projectId);
    return count;
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
    await _purgeNovelRoleOrphans(projectId);
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

  /// A late synthesis result must never restore text edited during inference.
  Future<int> completeNovelAudio(
    NovelSegment expected, {
    required String path,
    required String cacheKey,
    double? duration,
  }) =>
      (update(novelSegments)..where(
            (t) =>
                t.id.equals(expected.id) &
                t.segmentText.equals(expected.segmentText),
          ))
          .write(
            NovelSegmentsCompanion(
              audioPath: Value(path),
              audioCacheKey: Value(cacheKey),
              // The duration belongs to the new file; unknown clears the
              // old file's value instead of keeping it.
              audioDuration: Value(duration),
              error: const Value(null),
              missing: const Value(false),
            ),
          );

  Future<int> recordNovelAudioError(NovelSegment expected, String error) =>
      (update(novelSegments)..where(
            (t) =>
                t.id.equals(expected.id) &
                t.segmentText.equals(expected.segmentText),
          ))
          .write(NovelSegmentsCompanion(error: Value(error)));

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

  Future<void> refreshNovelOrder(String projectId) async =>
      _touchNovelProjectAfterStructureEdit(
        projectId,
        await _reindexNovelProject(projectId),
      );

  Future<void> _touchNovelProjectAfterStructureEdit(
    String projectId,
    int totalSegments,
  ) async {
    await _purgeNovelRoleOrphans(projectId);
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

  Future<void> _purgeNovelRoleOrphans(String projectId) async {
    await customStatement(
      'DELETE FROM novel_annotations WHERE project_id = ? '
      'AND segment_id NOT IN (SELECT id FROM novel_segments WHERE project_id = ?)',
      [projectId, projectId],
    );
    await customStatement(
      'DELETE FROM novel_voice_bindings WHERE chapter_id != \'\' '
      'AND chapter_id NOT IN (SELECT id FROM novel_chapters)',
    );
    await (delete(
      novelRoleEdits,
    )..where((t) => t.projectId.equals(projectId))).go();
  }
}
