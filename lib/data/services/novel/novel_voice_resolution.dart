import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/voice_resolver.dart';

import 'novel_text_revision.dart';

ResolvedNovelVoice resolveNovelSegmentVoice({
  required db.NovelProject project,
  required db.NovelSegment segment,
  required NovelRoleSnapshot roles,
  required Iterable<String> availableVoiceIds,
}) => NovelVoiceResolver.resolve(
  segmentId: segment.id,
  chapterId: segment.chapterId,
  kind: segment.segmentType == 'dialogue'
      ? NovelSegmentKind.dialogue
      : NovelSegmentKind.narrator,
  roles: roles,
  availableVoiceIds: availableVoiceIds.toSet(),
  textRevision: novelTextRevision(segment.segmentText),
  narratorVoiceId: project.narratorVoiceAssetId,
  dialogueVoiceId: project.dialogueVoiceAssetId,
);
