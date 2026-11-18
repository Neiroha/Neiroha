import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:uuid/uuid.dart';

import 'novel_text_revision.dart';

/// Manual semantic editing. TTS slicing never enters this service.
/// Offsets are UTF-16 boundaries; every input character is retained.
class NovelStructureEditor {
  const NovelStructureEditor(this.database);
  final db.AppDatabase database;
  String _undoKey(String projectId) => 'novel.structure.undo.$projectId';

  Future<List<db.NovelSegment>> split(
    db.NovelSegment expected,
    int start,
    int end,
  ) => database.transaction(() async {
    final chapter = await _requireCurrent([expected]);
    final text = expected.segmentText;
    if (start < 0 ||
        end < start ||
        end > text.length ||
        !_boundary(text, start) ||
        !_boundary(text, end)) {
      throw ArgumentError('Choose a valid UTF-16 character boundary.');
    }
    final cuts = {0, start, end, text.length}.toList()..sort();
    final parts = [
      for (var i = 1; i < cuts.length; i++)
        if (cuts[i] > cuts[i - 1]) text.substring(cuts[i - 1], cuts[i]),
    ];
    if (parts.length < 2) {
      throw ArgumentError('Select an internal split point or range.');
    }
    final original = await _annotation(expected.id);
    final replacements = <db.NovelSegment>[];
    final labels = <db.NovelAnnotation>[];
    for (var i = 0; i < parts.length; i++) {
      final s = _fresh(
        expected,
        i == 0 ? expected.id : const Uuid().v4(),
        parts[i],
      );
      replacements.add(s);
      if (original != null) {
        labels.add(
          original.copyWith(
            segmentId: s.id,
            textRevision: novelTextRevision(s.segmentText),
            changeId: const Uuid().v4(),
          ),
        );
      }
    }
    return _replace(
      expected.projectId,
      chapter,
      [expected],
      replacements,
      labels,
    );
  });

  Future<List<db.NovelSegment>> merge(
    List<db.NovelSegment> expected, {
    String separator = '\n',
  }) => database.transaction(() async {
    if (expected.length < 2) {
      throw ArgumentError('Select at least two segments.');
    }
    final chapter = await _requireCurrent(expected);
    final ordered = [...expected]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final indices = ordered
        .map((s) => chapter.indexWhere((c) => c.id == s.id))
        .toList();
    for (var i = 1; i < indices.length; i++) {
      if (indices[i] != indices[i - 1] + 1) {
        throw ArgumentError('Merge adjacent segments only.');
      }
    }
    final merged = _fresh(
      ordered.first,
      ordered.first.id,
      ordered.map((s) => s.segmentText).join(separator),
    );
    final labels = <db.NovelAnnotation?>[
      for (final s in ordered) await _annotation(s.id),
    ];
    final first = labels.first;
    // Mixed attribution is never silently assigned to the first speaker.
    final compatible =
        first != null &&
        labels.every(
          (a) =>
              a != null &&
              a.characterId == first.characterId &&
              a.kind == first.kind &&
              a.voiceAssetId == first.voiceAssetId &&
              a.instruction == first.instruction &&
              a.locked == first.locked &&
              a.reviewState == first.reviewState,
        );
    return _replace(
      merged.projectId,
      chapter,
      ordered,
      [merged],
      [
        if (compatible)
          first.copyWith(
            textRevision: novelTextRevision(merged.segmentText),
            changeId: const Uuid().v4(),
          ),
      ],
    );
  });

  Future<List<db.NovelSegment>> _replace(
    String projectId,
    List<db.NovelSegment> chapter,
    List<db.NovelSegment> removed,
    List<db.NovelSegment> replacements,
    List<db.NovelAnnotation> labels,
  ) async {
    final before = await _snapshot(projectId, chapter.first.chapterId);
    final ids = removed.map((s) => s.id).toSet();
    await (database.delete(
      database.novelAnnotations,
    )..where((t) => t.segmentId.isIn(ids))).go();
    await (database.delete(
      database.novelSegments,
    )..where((t) => t.id.isIn(ids))).go();
    final result = <db.NovelSegment>[];
    var inserted = false;
    for (final s in chapter) {
      if (!ids.contains(s.id)) {
        result.add(s);
        continue;
      }
      if (!inserted) {
        result.addAll(replacements);
        inserted = true;
      }
    }
    for (var i = 0; i < result.length; i++) {
      await database
          .into(database.novelSegments)
          .insertOnConflictUpdate(result[i].copyWith(orderIndex: i));
    }
    for (final a in labels) {
      await database.into(database.novelAnnotations).insertOnConflictUpdate(a);
    }
    await database.refreshNovelOrder(projectId);
    await database.setSetting(
      _undoKey(projectId),
      jsonEncode({
        'version': 1,
        'before': before,
        'after': await _signature(projectId),
      }),
    );
    final current = await database.getNovelSegments(projectId);
    return current.where((s) => replacements.any((r) => r.id == s.id)).toList();
  }

  /// One durable structure undo. Any later text/annotation/audio change rejects
  /// restoration rather than overwriting subsequent work.
  Future<bool> undo(String projectId) => database.transaction(() async {
    final raw = await database.getSetting(_undoKey(projectId));
    if (raw == null) return false;
    final record = jsonDecode(raw) as Map<String, dynamic>;
    if (record['version'] != 1 ||
        record['after'] != await _signature(projectId)) {
      throw StateError(
        'Novel changed after the structure edit; undo would overwrite newer work.',
      );
    }
    final before = record['before'] as Map<String, dynamic>;
    final chapterId = before['chapterId'] as String;
    final current = await database.getNovelSegmentsForChapter(chapterId);
    await (database.delete(
      database.novelAnnotations,
    )..where((t) => t.segmentId.isIn(current.map((s) => s.id)))).go();
    await (database.delete(
      database.novelSegments,
    )..where((t) => t.chapterId.equals(chapterId))).go();
    for (final row in before['segments'] as List) {
      await database
          .into(database.novelSegments)
          .insert(
            db.NovelSegment.fromJson(Map<String, dynamic>.from(row as Map)),
          );
    }
    for (final row in before['annotations'] as List) {
      await database
          .into(database.novelAnnotations)
          .insert(
            db.NovelAnnotation.fromJson(Map<String, dynamic>.from(row as Map)),
          );
    }
    await database.refreshNovelOrder(projectId);
    await (database.delete(
      database.appSettings,
    )..where((t) => t.key.equals(_undoKey(projectId)))).go();
    return true;
  });

  Future<List<db.NovelSegment>> _requireCurrent(
    List<db.NovelSegment> expected,
  ) async {
    if (expected.isEmpty) throw ArgumentError('No source segments.');
    final chapter = await database.getNovelSegmentsForChapter(
      expected.first.chapterId,
    );
    for (final s in expected) {
      if (s.projectId != expected.first.projectId ||
          s.chapterId != expected.first.chapterId ||
          !chapter.any((c) => c.id == s.id && c.segmentText == s.segmentText)) {
        throw StateError('Source text changed or belongs to another chapter.');
      }
    }
    if (expected.map((s) => s.id).toSet().length != expected.length) {
      throw ArgumentError('Duplicate source segment.');
    }
    return chapter;
  }

  Future<db.NovelAnnotation?> _annotation(String id) => (database.select(
    database.novelAnnotations,
  )..where((t) => t.segmentId.equals(id))).getSingleOrNull();

  Future<Map<String, Object?>> _snapshot(
    String projectId,
    String chapterId,
  ) async => {
    'chapterId': chapterId,
    'segments': [
      for (final s in await database.getNovelSegmentsForChapter(chapterId))
        s.toJson(),
    ],
    'annotations': [
      for (final s in await database.getNovelSegmentsForChapter(chapterId))
        if (await _annotation(s.id) case final a?) a.toJson(),
    ],
  };

  Future<String> _signature(String projectId) async => novelTextRevision(
    jsonEncode({
      'segments': [
        for (final s in await database.getNovelSegments(projectId)) s.toJson(),
      ],
      'annotations': [
        for (final s in await database.getNovelSegments(projectId))
          if (await _annotation(s.id) case final a?) a.toJson(),
      ],
    }),
  );

  db.NovelSegment _fresh(db.NovelSegment s, String id, String text) =>
      s.copyWith(
        id: id,
        segmentText: text,
        audioPath: const Value(null),
        audioDuration: const Value(null),
        audioCacheKey: const Value(null),
        error: const Value(null),
        missing: false,
      );

  bool _boundary(String text, int offset) =>
      offset == 0 ||
      offset == text.length ||
      !(text.codeUnitAt(offset - 1) >= 0xD800 &&
          text.codeUnitAt(offset - 1) <= 0xDBFF &&
          text.codeUnitAt(offset) >= 0xDC00 &&
          text.codeUnitAt(offset) <= 0xDFFF);
}
