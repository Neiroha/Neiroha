import 'dart:convert';

import 'package:neiroha/data/ai/protocols/openai/llm_chat_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/novel/role_direction.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/capabilities/task_profile.dart';
import 'package:neiroha/data/services/capabilities/task_profile_repository.dart';

import 'annotation_repository.dart';
import 'character_repository.dart';
import 'novel_text_revision.dart';
import 'role_analysis_protocol.dart';
import 'role_skill_repository.dart';
import 'role_skill_profiles_repository.dart';

/// Bounded, opt-in director stages. A model proposes; the user chooses which
/// entries to apply. Proposal signatures reject changes made during inference.
class RoleDirectionService {
  RoleDirectionService(this.database, this.queue, {RoleSkillLoader? loadSkill})
    : _loadSkill = loadSkill ?? RoleSkillProfilesRepository(database).loadSkill;
  final db.AppDatabase database;
  final TtsQueueService queue;
  final RoleSkillLoader _loadSkill;

  Future<RoleDirectionProposal> propose({
    required String projectId,
    required String chapterId,
    required RoleDirectionTask task,
    required db.TtsProvider provider,
    required String model,
    required TtsCancelToken cancellation,
    LlmChatAdapter? client,
  }) async {
    final binding = await TaskProfileRepository(database).resolve(
      projectId,
      task == RoleDirectionTask.casting ? ModelTask.casting : ModelTask.tone,
      provider,
    );
    provider = binding.provider;
    model = binding.profile?.model ?? model;
    if (model.trim().isEmpty) throw ArgumentError('Choose an analysis model.');
    final skill = await _loadSkill();
    final state = await _state(projectId, chapterId);
    final segments = await database.getNovelSegmentsForChapter(chapterId);
    final roles = await CharacterRepository(database).load(projectId);
    final project = (await database.getNovelProjectById(projectId))!;
    final bank = (await database.getBankMembers(
      project.bankId,
    )).map((m) => m.voiceAssetId).toSet();
    final voices = (await database.getAllVoiceAssets())
        .where((v) => bank.contains(v.id) && v.enabled)
        .toList();
    final targets = task == RoleDirectionTask.casting
        ? roles.characters
              .where((c) => !roles.bindings.any((b) => b.characterId == c.id))
              .map((c) => c.id)
              .toSet()
        : segments
              .where((s) {
                final a = roles.annotations[s.id];
                return a != null &&
                    !a.locked &&
                    a.reviewState != NovelReviewState.confirmed &&
                    a.textRevision == novelTextRevision(s.segmentText) &&
                    (a.instruction?.trim().isEmpty ?? true);
              })
              .take(30)
              .map((s) => s.id)
              .toSet();
    if (targets.isEmpty) {
      throw StateError(
        'No unbound characters or eligible unconfirmed segments.',
      );
    }
    if (task == RoleDirectionTask.casting && voices.isEmpty) {
      throw StateError('No enabled voices in the bank.');
    }
    final valueSchema = task == RoleDirectionTask.casting
        ? {'type': 'string', 'enum': voices.map((v) => v.id).toList()}
        : {'type': 'string', 'maxLength': 500};
    final result = await queue.enqueue(
      capability: AiCapability.llm,
      provider: provider,
      source: 'Novel director',
      label: task.name,
      cancelToken: cancellation,
      task: () =>
          (client ??
                  TaskProfileRepository.llm(provider, model, binding.profile))
              .structured(
                schemaName: 'novel_${task.name}',
                cancellation: cancellation,
                schema: RoleAnalysisProtocol.object({
                  'suggestions': {
                    'type': 'array',
                    'maxItems': targets.length,
                    'items': RoleAnalysisProtocol.object({
                      'id': {'type': 'string', 'enum': targets.toList()},
                      'value': valueSchema,
                      'reason': RoleAnalysisProtocol.string,
                    }),
                  },
                }),
                messages: [
                  LlmChatMessage(
                    role: 'system',
                    content: skill.prompt(
                      task == RoleDirectionTask.casting ? 'caster' : 'director',
                    ),
                  ),
                  LlmChatMessage(
                    role: 'user',
                    content: _boundedInput({
                      'targetIds': targets.toList(),
                      'characters': state['characters'],
                      if (task == RoleDirectionTask.casting)
                        'voices': [
                          for (final v in voices)
                            {
                              'id': v.id,
                              'name': v.name,
                              'description': v.description,
                              'style': v.voiceInstruction,
                            },
                        ],
                      if (task == RoleDirectionTask.tone)
                        'segments': [
                          for (final s in segments)
                            if (targets.contains(s.id))
                              {
                                'id': s.id,
                                'text': s.segmentText,
                                'characterId':
                                    roles.annotations[s.id]?.characterId,
                                'kind': roles.annotations[s.id]?.kind.name,
                              },
                        ],
                    }),
                  ),
                ],
              ),
    );
    cancellation.throwIfCancelled();
    final raw = result.object['suggestions'];
    if (raw is! List || raw.length > targets.length) {
      throw const FormatException('Invalid director suggestions.');
    }
    final seen = <String>{};
    final suggestions = <RoleDirectionSuggestion>[];
    for (final item in raw) {
      if (item is! Map ||
          item['id'] is! String ||
          !targets.contains(item['id']) ||
          !seen.add(item['id'] as String) ||
          item['value'] is! String ||
          item['reason'] is! String ||
          (item['reason'] as String).length > 500) {
        throw const FormatException('Unknown or duplicate director target.');
      }
      final value = (item['value'] as String).trim();
      if (value.isEmpty ||
          (task == RoleDirectionTask.tone && value.length > 500) ||
          (task == RoleDirectionTask.casting &&
              !voices.any((v) => v.id == value))) {
        throw const FormatException('Invalid voice or delivery instruction.');
      }
      suggestions.add(
        RoleDirectionSuggestion(
          id: item['id'] as String,
          value: value,
          reason: item['reason'] as String,
        ),
      );
    }
    return RoleDirectionProposal(
      projectId: projectId,
      chapterId: chapterId,
      task: task,
      signature: novelTextRevision(jsonEncode([state, skill.identity])),
      suggestions: suggestions,
    );
  }

  Future<int> apply(
    RoleDirectionProposal proposal,
    Set<String> selectedIds,
  ) => database.transaction(() async {
    if (novelTextRevision(
          jsonEncode([
            await _state(proposal.projectId, proposal.chapterId),
            (await _loadSkill()).identity,
          ]),
        ) !=
        proposal.signature) {
      throw StateError(
        'Novel, voices or analysis skill changed. Request fresh suggestions.',
      );
    }
    if (!selectedIds.every(
      (id) => proposal.suggestions.any((s) => s.id == id),
    )) {
      throw ArgumentError('Unknown suggestion selected.');
    }
    final selected = proposal.suggestions
        .where((s) => selectedIds.contains(s.id))
        .toList();
    final characters = CharacterRepository(database);
    if (proposal.task == RoleDirectionTask.casting) {
      for (final s in selected) {
        await characters.bindVoice(
          projectId: proposal.projectId,
          characterId: s.id,
          voiceAssetId: s.value,
        );
      }
      return selected.length;
    }
    final roles = await characters.load(proposal.projectId);
    return AnnotationRepository(database).apply(proposal.projectId, [
      for (final s in selected)
        SegmentAnnotation(
          segmentId: s.id,
          projectId: proposal.projectId,
          textRevision: roles.annotations[s.id]!.textRevision,
          characterId: roles.annotations[s.id]!.characterId,
          kind: roles.annotations[s.id]!.kind,
          voiceAssetId: roles.annotations[s.id]!.voiceAssetId,
          instruction: s.value,
          reviewState: NovelReviewState.inferred,
          reason: s.reason,
        ),
    ], fromAi: true);
  });

  String _boundedInput(Map<String, Object?> input) {
    final json = jsonEncode(input);
    if (json.length > 64000) {
      throw StateError(
        'Director input exceeds the local budget. Split long paragraphs or narrow the voice bank.',
      );
    }
    return json;
  }

  Future<Map<String, Object?>> _state(String projectId, String chapterId) =>
      database.transaction(() async {
        final project = await database.getNovelProjectById(projectId);
        if (project == null ||
            !(await database.getNovelChapters(
              projectId,
            )).any((c) => c.id == chapterId)) {
          throw StateError('Unknown novel chapter.');
        }
        final roles = await CharacterRepository(database).load(projectId);
        final segments = await database.getNovelSegmentsForChapter(chapterId);
        final bank = (await database.getBankMembers(
          project.bankId,
        )).map((m) => m.voiceAssetId).toSet();
        return {
          'characters': [
            for (final c in roles.characters)
              {
                'id': c.id,
                'name': c.name,
                'kind': c.identityKind.name,
                'description': c.description,
              },
          ],
          'bindings': [
            for (final b in roles.bindings)
              {
                'id': b.characterId,
                'chapter': b.chapterId,
                'kind': b.kind?.name,
                'voice': b.voiceAssetId,
                'instruction': b.instruction,
              },
          ],
          'segments': [
            for (final s in segments)
              {
                'id': s.id,
                'text': s.segmentText,
                'annotation': roles.annotations[s.id]?.changeId,
              },
          ],
          'voices': [
            for (final v in await database.getAllVoiceAssets())
              if (bank.contains(v.id)) v.toJson(),
          ],
        };
      });
}
