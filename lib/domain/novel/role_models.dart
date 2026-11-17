enum NovelSegmentKind { narrator, dialogue, thought, system }

enum NovelReviewState { pending, inferred, conflict, confirmed }

enum CharacterIdentityKind { named, anonymous, group }

class StoryCharacter {
  const StoryCharacter({
    required this.id,
    required this.projectId,
    required this.name,
    this.aliases = const [],
    this.description = '',
    this.color = 0xFF7E9CD8,
    this.identityKind = CharacterIdentityKind.named,
  });
  final String id;
  final String projectId;
  final String name;
  final List<String> aliases;
  final String description;
  final int color;
  final CharacterIdentityKind identityKind;
}

class SegmentAnnotation {
  const SegmentAnnotation({
    required this.segmentId,
    required this.projectId,
    required this.textRevision,
    this.characterId,
    this.kind = NovelSegmentKind.narrator,
    this.voiceAssetId,
    this.instruction,
    this.locked = false,
    this.reviewState = NovelReviewState.pending,
    this.reason = '',
    this.changeId = '',
  });
  final String segmentId;
  final String projectId;
  final String textRevision;
  final String? characterId;
  final NovelSegmentKind kind;
  final String? voiceAssetId;
  final String? instruction;
  final bool locked;
  final NovelReviewState reviewState;
  final String reason;
  final String changeId;
}

class CharacterVoiceBinding {
  const CharacterVoiceBinding({
    required this.characterId,
    required this.voiceAssetId,
    this.chapterId = '',
    this.instruction,
    this.kind,
  });
  final String characterId;
  final String voiceAssetId;
  final String chapterId;
  final String? instruction;
  final NovelSegmentKind? kind;
}

class NovelRoleSnapshot {
  const NovelRoleSnapshot({
    this.characters = const [],
    this.annotations = const {},
    this.bindings = const [],
  });
  final List<StoryCharacter> characters;
  final Map<String, SegmentAnnotation> annotations;
  final List<CharacterVoiceBinding> bindings;
}
