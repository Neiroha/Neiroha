import 'dart:convert';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/novel/role_models.dart';

StoryCharacter storyCharacterFromRow(
  db.NovelCharacter row, {
  CharacterIdentityKind identityKind = CharacterIdentityKind.named,
}) => StoryCharacter(
  id: row.id,
  projectId: row.projectId,
  name: row.name,
  aliases: (jsonDecode(row.aliasesJson) as List).cast<String>(),
  description: row.description,
  color: row.color,
  identityKind: identityKind,
);

SegmentAnnotation annotationFromRow(db.NovelAnnotation row) =>
    SegmentAnnotation(
      segmentId: row.segmentId,
      projectId: row.projectId,
      textRevision: row.textRevision,
      characterId: row.characterId,
      kind: NovelSegmentKind.values.byName(row.kind),
      voiceAssetId: row.voiceAssetId,
      instruction: row.instruction,
      locked: row.locked,
      reviewState: NovelReviewState.values.byName(row.reviewState),
      reason: row.reason,
      changeId: row.changeId,
    );

CharacterVoiceBinding bindingFromRow(db.NovelVoiceBinding row) =>
    CharacterVoiceBinding(
      characterId: row.characterId,
      voiceAssetId: row.voiceAssetId,
      chapterId: row.chapterId,
      instruction: row.instruction,
    );
