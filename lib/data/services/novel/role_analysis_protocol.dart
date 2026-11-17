import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/novel/role_models.dart';

import 'novel_text_revision.dart';

/// Independently implemented Dart protocol following the upstream workflow:
/// local stable segments → roster → labels → deterministic checks → review.
class RoleAnalysisProtocol {
  static Map<String, Object?> object(Map<String, Object?> properties) => {
    'type': 'object',
    'additionalProperties': false,
    'properties': properties,
    'required': properties.keys.toList(),
  };
  static const string = {'type': 'string'};
  static const nullableString = {
    'type': ['string', 'null'],
  };
  static Map<String, Object?> get rosterSchema => object({
    'characters': {
      'type': 'array',
      'items': object({
        'name': string,
        'aliases': {'type': 'array', 'items': string},
        'description': string,
        'identityKind': {
          'type': 'string',
          'enum': ['named', 'anonymous', 'group'],
        },
      }),
    },
  });
  static Map<String, Object?> get labelsSchema => object({
    'labels': {
      'type': 'array',
      'items': object({
        'id': string,
        'characterName': nullableString,
        'kind': {
          'type': 'string',
          'enum': NovelSegmentKind.values.map((v) => v.name).toList(),
        },
        'review': {
          'type': 'string',
          'enum': ['pending', 'inferred', 'conflict'],
        },
        'reason': string,
      }),
    },
    'sceneSummary': string,
  });

  static List<SegmentAnnotation> parseLabels(
    Map<String, dynamic> output,
    List<db.NovelSegment> segments,
    NovelRoleSnapshot roles,
  ) {
    final raw = output['labels'];
    if (raw is! List || raw.length != segments.length) {
      throw const FormatException('Missing or extra segment labels.');
    }
    final source = {for (final s in segments) s.id: s};
    final seen = <String>{};
    final labels = <SegmentAnnotation>[];
    for (final value in raw) {
      if (value is! Map || value['id'] is! String) {
        throw const FormatException('Invalid segment label.');
      }
      final id = value['id'] as String;
      if (!source.containsKey(id) || !seen.add(id)) {
        throw const FormatException('Unknown or duplicate segment ID.');
      }
      final segment = source[id]!;
      final kind = NovelSegmentKind.values.byName(value['kind'] as String);
      final review = NovelReviewState.values.byName(value['review'] as String);
      if (review == NovelReviewState.confirmed) {
        throw const FormatException('AI cannot claim manual confirmation.');
      }
      final name = value['characterName'] as String?;
      final candidates = roles.characters
          .where((c) => c.name == name || c.aliases.contains(name))
          .toList();
      final speaking =
          kind == NovelSegmentKind.dialogue || kind == NovelSegmentKind.thought;
      final uncertain = (speaking || name != null) && candidates.length != 1;
      final quotedNarration =
          kind == NovelSegmentKind.narrator &&
          RegExp(r'^[“「『"]').hasMatch(segment.segmentText.trim());
      final reason = value['reason'];
      if (reason is! String || reason.length > 500) {
        throw const FormatException('Invalid evidence text.');
      }
      labels.add(
        SegmentAnnotation(
          segmentId: id,
          projectId: segment.projectId,
          textRevision: novelTextRevision(segment.segmentText),
          kind: kind,
          // System voices and attributed first-person narration can also have
          // character/category bindings; do not discard a resolved identity.
          characterId: candidates.length == 1 ? candidates.single.id : null,
          reviewState: uncertain || quotedNarration
              ? NovelReviewState.conflict
              : review,
          reason: reason,
        ),
      );
    }
    return labels;
  }
}
