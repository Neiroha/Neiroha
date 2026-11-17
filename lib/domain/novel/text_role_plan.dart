import 'role_models.dart';

/// Shared, exact-text output for reader, long-text and future dubbing surfaces.
class TextRoleUnit {
  const TextRoleUnit({
    required this.text,
    required this.start,
    required this.end,
    required this.kind,
    required this.review,
    required this.reason,
    this.characterId,
  });
  final String text, reason;
  final int start, end;
  final String? characterId;
  final NovelSegmentKind kind;
  final NovelReviewState review;
  String get voiceKey => characterId ?? '@${kind.name}';
}

class TextRolePlan {
  const TextRolePlan({
    required this.text,
    required this.skillDigest,
    required this.calls,
    required this.characters,
    required this.units,
  });
  final String text, skillDigest;
  final int calls;
  final List<StoryCharacter> characters;
  final List<TextRoleUnit> units;
  void validate() {
    var offset = 0;
    final ids = characters.map((c) => c.id).toSet();
    if (ids.length != characters.length ||
        characters.any((c) => c.id.isEmpty || c.name.trim().isEmpty)) {
      throw const FormatException('Duplicate identities.');
    }
    for (final unit in units) {
      if (unit.start != offset ||
          unit.end <= unit.start ||
          unit.end > text.length ||
          (unit.end < text.length &&
              unit.end > 0 &&
              text.codeUnitAt(unit.end - 1) >= 0xD800 &&
              text.codeUnitAt(unit.end - 1) <= 0xDBFF &&
              text.codeUnitAt(unit.end) >= 0xDC00 &&
              text.codeUnitAt(unit.end) <= 0xDFFF) ||
          unit.text != text.substring(unit.start, unit.end) ||
          (unit.characterId != null && !ids.contains(unit.characterId)) ||
          unit.review == NovelReviewState.confirmed) {
        throw const FormatException('Invalid exact-text role partition.');
      }
      offset = unit.end;
    }
    if (offset != text.length || units.isEmpty) {
      throw const FormatException('Incomplete role plan.');
    }
  }
}
