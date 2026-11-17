import 'role_models.dart';

class ResolvedNovelVoice {
  const ResolvedNovelVoice(this.voiceAssetId, {this.instruction});
  final String? voiceAssetId;
  final String? instruction;
}

/// All consumers use the same precedence, independent of display names.
class NovelVoiceResolver {
  static ResolvedNovelVoice resolve({
    required String segmentId,
    required String chapterId,
    required NovelSegmentKind kind,
    required NovelRoleSnapshot roles,
    required Set<String> availableVoiceIds,
    String? textRevision,
    String? narratorVoiceId,
    String? dialogueVoiceId,
  }) {
    final stored = roles.annotations[segmentId];
    final annotation =
        stored != null &&
            (textRevision == null || stored.textRevision == textRevision)
        ? stored
        : null;
    final effectiveKind = annotation?.kind ?? kind;
    bool usable(String? id) => id != null && availableVoiceIds.contains(id);
    final matching =
        roles.bindings
            .where(
              (b) =>
                  b.characterId == annotation?.characterId &&
                  (b.chapterId.isEmpty || b.chapterId == chapterId) &&
                  (b.kind == null || b.kind == effectiveKind),
            )
            .toList()
          ..sort(
            (a, b) =>
                ((b.chapterId.isNotEmpty ? 2 : 0) + (b.kind != null ? 1 : 0))
                    .compareTo(
                      (a.chapterId.isNotEmpty ? 2 : 0) +
                          (a.kind != null ? 1 : 0),
                    ),
          );
    String? voice = usable(annotation?.voiceAssetId)
        ? annotation!.voiceAssetId
        : null;
    String? instruction = annotation?.instruction;
    for (final binding in matching) {
      if (voice == null && usable(binding.voiceAssetId)) {
        voice = binding.voiceAssetId;
      }
      instruction ??= binding.instruction;
    }
    final preferred =
        effectiveKind == NovelSegmentKind.dialogue ||
            effectiveKind == NovelSegmentKind.thought
        ? dialogueVoiceId
        : narratorVoiceId;
    final fallback =
        effectiveKind == NovelSegmentKind.dialogue ||
            effectiveKind == NovelSegmentKind.thought
        ? narratorVoiceId
        : dialogueVoiceId;
    return ResolvedNovelVoice(
      voice ??
          (usable(preferred)
              ? preferred
              : (usable(fallback) ? fallback : null)),
      instruction: instruction,
    );
  }
}
