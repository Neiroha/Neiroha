import 'role_models.dart';

class RolePrediction {
  const RolePrediction(this.start, this.end, this.kind, this.speaker);
  final int start;
  final int end;
  final NovelSegmentKind kind;
  final String? speaker;
  factory RolePrediction.fromJson(Map<String, dynamic> json) => RolePrediction(
    json['start'] as int,
    json['end'] as int,
    NovelSegmentKind.values.byName(json['kind'] as String),
    json['speaker'] as String?,
  );
}

class RoleEvaluationResult {
  const RoleEvaluationResult(
    this.evaluated,
    this.categoryCorrect,
    this.speakerTotal,
    this.speakerCorrect,
    this.ambiguousGold,
    this.failures,
  );
  final int evaluated;
  final int categoryCorrect;
  final int speakerTotal;
  final int speakerCorrect;
  final int ambiguousGold;
  final List<String> failures;
  Map<String, Object?> toJson() => {
    'evaluated': evaluated,
    'categoryCorrect': categoryCorrect,
    'speakerTotal': speakerTotal,
    'speakerCorrect': speakerCorrect,
    'ambiguousGold': ambiguousGold,
    'failures': failures,
  };
}

/// Full UTF-16 partition is mandatory: omitted or rewritten text cannot inflate
/// accuracy. Non-unique gold snippets without occurrence are excluded explicitly.
class RoleEvaluation {
  static RoleEvaluationResult evaluate({
    required String text,
    required List<Map<String, dynamic>> gold,
    required List<RolePrediction> predictions,
    List<Map<String, dynamic>> roster = const [],
  }) {
    var cursor = 0;
    for (final p in predictions) {
      if (p.start != cursor ||
          p.end <= p.start ||
          p.end > text.length ||
          !_boundary(text, p.end)) {
        throw const FormatException(
          'Predictions must partition the original UTF-16 text exactly.',
        );
      }
      cursor = p.end;
    }
    if (cursor != text.length) {
      throw const FormatException('Predictions omit original text.');
    }
    String? canonical(String? speaker) {
      if (speaker == null) return null;
      final matches = roster
          .where(
            (c) =>
                c['name'] == speaker ||
                ((c['aliases'] as List?)?.contains(speaker) ?? false),
          )
          .toList();
      return matches.length == 1 ? matches.single['name'] as String : speaker;
    }

    var evaluated = 0, kinds = 0, speakerTotal = 0, speakers = 0, ambiguous = 0;
    final failures = <String>[];
    const categories = {
      '旁白': NovelSegmentKind.narrator,
      '对话': NovelSegmentKind.dialogue,
      '心理': NovelSegmentKind.thought,
      '系统': NovelSegmentKind.system,
    };
    for (final g in gold) {
      final match = g['match'] as String;
      if (match.isEmpty) throw const FormatException('Empty gold snippet.');
      final starts = <int>[];
      for (
        var at = text.indexOf(match);
        at >= 0;
        at = text.indexOf(match, at + 1)
      ) {
        starts.add(at);
      }
      if (starts.isEmpty) throw FormatException('Gold text absent: $match');
      final occurrence = g['occurrence'] as int?;
      if (occurrence == null && starts.length != 1) {
        ambiguous++;
        continue;
      }
      if (occurrence != null &&
          (occurrence < 0 || occurrence >= starts.length)) {
        throw const FormatException('Gold occurrence is out of range.');
      }
      final start = starts[occurrence ?? 0], end = start + match.length;
      final covered = predictions
          .where((p) => p.end > start && p.start < end)
          .toList();
      final rawKinds = g['category'] is List
          ? g['category'] as List
          : [g['category']];
      final allowed = rawKinds
          .map(
            (k) => categories[k] ?? NovelSegmentKind.values.byName(k as String),
          )
          .toSet();
      final kindCorrect = covered.every((p) => allowed.contains(p.kind));
      evaluated++;
      if (kindCorrect) kinds++;
      final rawSpeaker = g['speaker'];
      final expectedSpeakers = rawSpeaker == null
          ? <String>[]
          : rawSpeaker is String
          ? [rawSpeaker]
          : rawSpeaker is List &&
                rawSpeaker.isNotEmpty &&
                rawSpeaker.every((s) => s is String)
          ? rawSpeaker.cast<String>()
          : throw const FormatException('Invalid gold speaker alternatives.');
      var speakerCorrect = true;
      if (expectedSpeakers.isNotEmpty) {
        speakerTotal++;
        final allowedSpeakers = expectedSpeakers.map(canonical).toSet();
        speakerCorrect =
            kindCorrect &&
            covered.every(
              (p) => allowedSpeakers.contains(canonical(p.speaker)),
            );
        if (speakerCorrect) speakers++;
      }
      if (!kindCorrect || !speakerCorrect) failures.add(match);
    }
    return RoleEvaluationResult(
      evaluated,
      kinds,
      speakerTotal,
      speakers,
      ambiguous,
      failures,
    );
  }

  static bool _boundary(String text, int at) =>
      at == 0 ||
      at == text.length ||
      !(text.codeUnitAt(at - 1) >= 0xD800 &&
          text.codeUnitAt(at - 1) <= 0xDBFF &&
          text.codeUnitAt(at) >= 0xDC00 &&
          text.codeUnitAt(at) <= 0xDFFF);
}
