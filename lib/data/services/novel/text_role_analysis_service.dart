import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:neiroha/data/adapters/llm_chat_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/novel/text_role_plan.dart';
import 'package:neiroha/domain/text/novel_semantic_segmenter.dart';
import 'annotation_repository.dart';
import 'character_repository.dart';
import 'role_analysis_service.dart';
import 'role_skill_repository.dart';

/// Runs the same novel workflow without creating a reader project on disk.
/// Story text is partitioned and classified, never generated or paraphrased.
class TextRoleAnalysisService {
  TextRoleAnalysisService(this.queue, {required this.loadSkill});
  final TtsQueueService queue;
  final RoleSkillLoader loadSkill;
  Future<TextRolePlan> analyze({
    required String text,
    required String intent,
    required db.TtsProvider provider,
    required String model,
    required TtsCancelToken cancellation,
    LlmChatAdapter? client,
  }) async {
    if (text.length > 64000 || intent.length > 2000) {
      throw ArgumentError(
        'Choose up to 64000 UTF-16 units and a short dubbing intent.',
      );
    }
    final source = NovelSemanticSegmenter.split(text);
    if (source.isEmpty || source.length > 360) {
      throw ArgumentError(
        'Choose 1–360 semantic segments, up to 64000 UTF-16 units, and a short dubbing intent.',
      );
    }
    cancellation.throwIfCancelled();
    final skill = await loadSkill();
    final database = db.AppDatabase.temporary(NativeDatabase.memory());
    final characters = CharacterRepository(database);
    final service = RoleAnalysisService(
      database,
      characters,
      AnnotationRepository(database),
      queue,
      loadSkill: () async => skill,
    );
    const projectId = 'text-role-analysis', chapterId = 'text-role-chapter';
    try {
      final now = DateTime.now();
      await database
          .into(database.ttsProviders)
          .insertOnConflictUpdate(provider);
      await database.insertBank(
        db.VoiceBanksCompanion(
          id: const Value('role-bank'),
          name: const Value('Analysis'),
          createdAt: Value(now),
        ),
      );
      await database.insertNovelProject(
        db.NovelProjectsCompanion(
          id: const Value(projectId),
          name: const Value('Text analysis'),
          bankId: const Value('role-bank'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await database.insertNovelChapter(
        const db.NovelChaptersCompanion(
          id: Value(chapterId),
          projectId: Value(projectId),
          title: Value('Text'),
          orderIndex: Value(0),
        ),
      );
      for (var i = 0; i < source.length; i++) {
        await database.insertNovelSegment(
          db.NovelSegmentsCompanion(
            id: Value('text-$i'),
            projectId: const Value(projectId),
            chapterId: const Value(chapterId),
            orderIndex: Value(i),
            globalIndex: Value(i),
            segmentText: Value(source[i].text),
            segmentType: Value(source[i].type),
          ),
        );
      }
      cancellation.throwIfCancelled();
      await service.run(
        projectId: projectId,
        chapterId: chapterId,
        provider: provider,
        model: model,
        feedback: intent,
        maxCalls: 1,
        client: client,
        cancelToken: cancellation,
      );
      cancellation.throwIfCancelled();
      await service.run(
        projectId: projectId,
        chapterId: chapterId,
        provider: provider,
        model: model,
        confirmRoster: true,
        maxCalls: 39,
        client: client,
        cancelToken: cancellation,
      );
      cancellation.throwIfCancelled();
      final checkpoint = (await service.checkpoints.load(
        projectId,
        chapterId,
      ))!;
      if (checkpoint.stage != 'completed') {
        throw StateError(
          'Analysis paused before completion; split the text into smaller parts.',
        );
      }
      final roles = await characters.load(projectId);
      final result = TextRolePlan(
        text: text,
        skillDigest: skill.digest,
        calls: checkpoint.calls,
        characters: roles.characters,
        units: [
          for (var i = 0; i < source.length; i++)
            TextRoleUnit(
              text: source[i].text,
              start: source[i].start,
              end: source[i].end,
              kind: roles.annotations['text-$i']!.kind,
              review: roles.annotations['text-$i']!.reviewState,
              reason: roles.annotations['text-$i']!.reason,
              characterId: roles.annotations['text-$i']!.characterId,
            ),
        ],
      );
      result.validate();
      return result;
    } finally {
      service.dispose();
      await database.close();
    }
  }
}
