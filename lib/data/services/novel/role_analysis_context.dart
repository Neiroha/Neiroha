import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/text/novel_semantic_segmenter.dart';

import 'novel_text_revision.dart';

/// Describes existing rows without silently changing segment IDs or human edits.
class RoleAnalysisContext {
  RoleAnalysisContext(this.segments) {
    final text = segments.map((s) => s.segmentText).join();
    final semantic = NovelSemanticSegmenter.split(text);
    var start = 0;
    var first = 0;
    for (final row in segments) {
      final end = start + row.segmentText.length;
      while (first < semantic.length && semantic[first].end <= start) {
        first++;
      }
      final parts = <NovelTextSegment>[];
      for (var i = first; i < semantic.length && semantic[i].start < end; i++) {
        parts.add(semantic[i]);
      }
      rowsById[row.id] = row;
      positions[row.id] = positions.length;
      structures[row.id] = {
        'segmentationVersion': NovelSemanticSegmenter.version,
        'start': start,
        'end': end,
        'paragraphs': parts.map((s) => s.paragraph).toSet().toList(),
        'quoteDepths': parts.map((s) => s.quoteDepth).toSet().toList(),
        'channels': parts.map((s) => s.channel).toSet().toList(),
        'senderHints': parts
            .map((s) => s.senderHint)
            .whereType<String>()
            .toSet()
            .toList(),
        'semanticUnits': parts.length,
        'voiceUnits': parts
            .where((s) => s.channel == 'speech' || s.channel == 'chat')
            .length,
      };
      start = end;
    }
  }
  final List<db.NovelSegment> segments;
  final rowsById = <String, db.NovelSegment>{};
  final positions = <String, int>{};
  final structures = <String, Map<String, Object?>>{};

  List<Map<String, Object?>> describe(
    List<db.NovelSegment> rows,
    NovelRoleSnapshot roles, {
    bool contextOnly = false,
  }) => [
    for (final row in rows)
      {
        'id': row.id,
        'text': contextOnly ? excerpt(row.segmentText, 1500) : row.segmentText,
        if (contextOnly && row.segmentText.length > 1500) 'textTruncated': true,
        'importType': row.segmentType,
        'structure': structures[row.id],
        if (roles.annotations[row.id] case final annotation?)
          'existingLabel': {
            'characterId': annotation.characterId,
            'kind': annotation.kind.name,
            'review': annotation.reviewState.name,
            'locked': annotation.locked,
            'currentText':
                annotation.textRevision == novelTextRevision(row.segmentText),
            'reason': annotation.reason,
          },
      },
  ];
  Map<String, Object?> get summary => {
    'segmentationVersion': NovelSemanticSegmenter.version,
    'senderHints': structures.values
        .expand((s) => s['senderHints'] as List)
        .toSet()
        .take(100)
        .toList(),
    'channels': structures.values
        .expand((s) => s['channels'] as List)
        .toSet()
        .toList(),
  };
  static String excerpt(String text, int limit) {
    if (text.length <= limit) return text;
    var end = limit;
    if (text.codeUnitAt(end - 1) >= 0xD800 &&
        text.codeUnitAt(end - 1) <= 0xDBFF &&
        text.codeUnitAt(end) >= 0xDC00 &&
        text.codeUnitAt(end) <= 0xDFFF) {
      end--;
    }
    return text.substring(0, end);
  }
}
