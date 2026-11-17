import 'package:neiroha/domain/novel/role_models.dart';
import 'role_analysis_context.dart';

class RoleDoubt {
  const RoleDoubt(
    this.segmentId,
    this.code,
    this.evidence, {
    this.auditOnly = false,
  });
  final String segmentId;
  final String code;
  final String evidence;
  final bool auditOnly;
  Map<String, Object?> toJson() => {
    'id': segmentId,
    'code': code,
    'evidence': evidence,
    'auditOnly': auditOnly,
  };
}

/// Evidence suggestions, independent of the model's confidence or self-review.
/// Rules flag ambiguity; they never assign a different speaker automatically.
class RoleDoubtDetector {
  static List<RoleDoubt> inspect({
    required List<SegmentAnnotation> labels,
    required NovelRoleSnapshot roles,
    required RoleAnalysisContext context,
    bool audit = true,
  }) {
    final doubts = <RoleDoubt>[];
    final rows = context.rowsById;
    final owners = <String, Set<String>>{};
    const pronouns = {
      '我',
      '你',
      '他',
      '她',
      '它',
      '吾',
      'i',
      'you',
      'he',
      'she',
      'they',
    };
    for (final character in roles.characters) {
      for (final name in [character.name, ...character.aliases]) {
        final normalized = name.trim().toLowerCase();
        if (normalized.isNotEmpty && !pronouns.contains(normalized)) {
          owners.putIfAbsent(normalized, () => <String>{}).add(character.id);
        }
      }
    }
    final duplicates = owners.values
        .where((ids) => ids.length > 1)
        .expand((ids) => ids)
        .toSet();
    for (final label in labels) {
      final row = rows[label.segmentId]!;
      void add(String code, String evidence, {bool auditOnly = false}) =>
          doubts.add(RoleDoubt(row.id, code, evidence, auditOnly: auditOnly));
      final structure = context.structures[row.id]!;
      final senders = (structure['senderHints'] as List).cast<String>();
      final channels = (structure['channels'] as List).cast<String>();
      if (senders.length > 1 ||
          (structure['voiceUnits'] as int) > 1 ||
          (channels.contains('speech') && channels.contains('narration'))) {
        add(
          'mixed_turn',
          'The row contains distinct turns or narration and speech; split before assigning one speaker.',
        );
      }
      final expected = roles.characters
          .where(
            (c) => senders.any((s) => s == c.name || c.aliases.contains(s)),
          )
          .toList();
      if (expected.length == 1 && expected.single.id != label.characterId) {
        add(
          'message_sender',
          'Message header names ${expected.single.name}; verify the assigned speaker.',
        );
      }
      final index = context.positions[row.id]!;
      final before = index > 0 ? context.segments[index - 1].segmentText : '';
      final after = index + 1 < context.segments.length
          ? context.segments[index + 1].segmentText
          : '';
      if (label.kind == NovelSegmentKind.dialogue) {
        final cues = _attributions(before, after, roles);
        if (cues.length == 1 && !cues.contains(label.characterId)) {
          add(
            'attribution',
            'An adjacent explicit speech verb names a different speaker; a listener reaction alone is not attribution.',
          );
        }
        final character = roles.characters
            .where((c) => c.id == label.characterId)
            .firstOrNull;
        if (character != null &&
            [character.name, ...character.aliases].any(
              (name) => RegExp(
                '^[\\s“「『"【]*${RegExp.escape(name)}[，,！!：:]',
              ).hasMatch(row.segmentText),
            )) {
          add(
            'addressee',
            'The assigned character is addressed at the start of this line; verify speaker versus listener.',
          );
        }
      }
      if (duplicates.contains(label.characterId)) {
        add(
          'duplicate_identity',
          'The assigned identity shares a name or alias with another work-level character.',
        );
      }
      if (label.reviewState == NovelReviewState.pending ||
          label.reviewState == NovelReviewState.conflict) {
        add(
          'model_uncertainty',
          'The model left this label pending or conflicting.',
        );
      } else if (audit && row.globalIndex % 17 == 16) {
        add(
          'inferred_audit',
          'Deterministic spot-check of an inferred label; confidence is not accuracy.',
          auditOnly: true,
        );
      }
    }
    return doubts;
  }

  static Set<String> _attributions(
    String before,
    String after,
    NovelRoleSnapshot roles,
  ) {
    final ids = <String>{};
    for (final c in roles.characters) {
      for (final name in [c.name, ...c.aliases]) {
        final n = RegExp.escape(name);
        const delivery = r'(?:轻声|低声|大声|笑着|冷冷|又|忽然)?';
        const verb = r'(?:说|说道|问|问道|答道|喊道|道|传音)';
        if (RegExp(
              '(?:^|[。！？\\n])\\s*$n(?:对[^。！？\\n：:]{1,12})?$delivery$verb[：:，,]\\s*\$',
            ).hasMatch(before) ||
            RegExp('^[\\s，,。]*$n$delivery$verb').hasMatch(after)) {
          ids.add(c.id);
        }
      }
    }
    return ids;
  }

  static List<SegmentAnnotation> flag(
    List<SegmentAnnotation> labels,
    List<RoleDoubt> doubts,
  ) => [
    for (final label in labels)
      if (doubts
              .where(
                (d) =>
                    d.segmentId == label.segmentId &&
                    !d.auditOnly &&
                    d.code != 'model_uncertainty',
              )
              .toList()
          case final reasons when reasons.isNotEmpty)
        SegmentAnnotation(
          segmentId: label.segmentId,
          projectId: label.projectId,
          textRevision: label.textRevision,
          characterId: label.characterId,
          kind: label.kind,
          voiceAssetId: label.voiceAssetId,
          instruction: label.instruction,
          locked: label.locked,
          reviewState: NovelReviewState.conflict,
          reason: ('${label.reason} [${reasons.map((d) => d.code).join(',')}] ${reasons.first.evidence}')
              .substring(
                0,
                ('${label.reason} [${reasons.map((d) => d.code).join(',')}] ${reasons.first.evidence}')
                    .length
                    .clamp(0, 500),
              ),
        )
      else
        label,
  ];
}
