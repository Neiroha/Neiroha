import 'dart:convert';

import 'package:neiroha/data/adapters/llm_chat_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/capabilities/capability_repository.dart';
import 'package:neiroha/data/services/capabilities/role_ai_model.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'package:neiroha/domain/capabilities/task_profile.dart';
import 'package:neiroha/data/services/capabilities/task_profile_repository.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/dubbing_intent.dart';
import 'package:neiroha/domain/novel/role_scene_state.dart';
import 'package:neiroha/domain/text/novel_semantic_segmenter.dart';

import 'annotation_repository.dart';
import 'character_repository.dart';
import 'novel_text_revision.dart';
import 'role_analysis_checkpoint.dart';
import 'role_analysis_protocol.dart';
import 'role_skill_repository.dart';
import 'role_skill_profiles_repository.dart';
import 'role_analysis_context.dart';
import 'role_doubt_detector.dart';

/// Inference is opt-in; constructing this service never sends story content.
class RoleAnalysisService {
  RoleAnalysisService(
    this.database,
    this.characters,
    this.annotations,
    this.queue, {
    this.capabilities,
    RoleSkillLoader? loadSkill,
  }) : _loadSkill =
           loadSkill ?? RoleSkillProfilesRepository(database).loadSkill;
  final db.AppDatabase database;
  final CharacterRepository characters;
  final AnnotationRepository annotations;
  final TtsQueueService queue;
  final CapabilityRepository? capabilities;
  final RoleSkillLoader _loadSkill;
  final Map<String, TtsCancelToken> _active = {};
  RoleAnalysisCheckpointStore get checkpoints =>
      RoleAnalysisCheckpointStore(database);
  bool isRunning(String projectId) => _active.containsKey(projectId);
  void pause(String projectId) => _active[projectId]?.cancel();
  void dispose() {
    for (final token in _active.values) {
      token.cancel();
    }
  }

  Future<void> run({
    required String projectId,
    required String chapterId,
    required db.TtsProvider provider,
    required String model,
    bool restart = false,
    bool confirmRoster = false,
    bool replan = false,
    String feedback = '',
    int maxCalls = 12,
    int batchSize = 20,
    LlmChatAdapter? client,
    TtsCancelToken? cancelToken,
    void Function(RoleAnalysisProgress)? onProgress,
  }) async {
    final binding = await TaskProfileRepository(
      database,
    ).resolve(projectId, ModelTask.analysis, provider);
    provider = binding.provider;
    model = binding.profile?.model ?? model;
    final route = binding.profile?.route ?? ServiceRoute.chatCompletions;
    if (isRunning(projectId)) {
      throw StateError('Analysis is already running for this novel.');
    }
    if (model.trim().isEmpty) {
      throw ArgumentError('Choose a text analysis model.');
    }
    if (maxCalls < 1 || maxCalls > 100 || batchSize < 1 || batchSize > 30) {
      throw ArgumentError('Invalid analysis budget.');
    }
    final skill = await _loadSkill();
    final all = await database.getNovelSegmentsForChapter(chapterId);
    if (all.isEmpty || all.any((s) => s.projectId != projectId)) {
      throw StateError('No chapter text to analyze.');
    }
    if (all.any((s) => s.segmentText.length > 12000)) {
      throw StateError('Split very long paragraphs before analysis.');
    }
    final signature = novelTextRevision(
      jsonEncode([
        for (final s in all) [s.id, s.segmentText],
        skill.identity,
        NovelSemanticSegmenter.version,
        if (binding.profile != null) binding.profile!.toJson(),
      ]),
    );
    final previous = restart
        ? null
        : await checkpoints.load(projectId, chapterId);
    if (previous != null && previous.skillDigest != skill.digest) {
      throw StateError(
        'Analysis skill changed or the saved analysis is unversioned. Start a new analysis.',
      );
    }
    if (previous != null &&
        previous.segmentationVersion != NovelSemanticSegmenter.version) {
      throw StateError('Semantic segmentation changed. Start a new analysis.');
    }
    if (previous != null && previous.signature != signature) {
      throw StateError('Chapter text changed. Start a new analysis.');
    }
    if (previous != null &&
        (previous.providerId != provider.id || previous.model != model)) {
      throw StateError(
        'Resume with the saved provider and model, or start a new analysis.',
      );
    }
    final checkpoint =
        previous ??
        RoleAnalysisCheckpoint(
          signature: signature,
          providerId: provider.id,
          model: model,
          skillName: skill.name,
          skillVersion: skill.version,
          skillDigest: skill.digest,
          segmentationVersion: NovelSemanticSegmenter.version,
          sceneSummary: await checkpoints.recentScene(projectId, chapterId),
          scene: await checkpoints.recentSceneState(projectId, chapterId),
        );
    final context = RoleAnalysisContext(all);
    if (checkpoint.stage == 'completed' &&
        !restart &&
        !replan &&
        feedback.trim().isEmpty) {
      return;
    }
    final cancellation = cancelToken ?? TtsCancelToken();
    // Recheck after asynchronous loads; only one chapter may write a roster.
    if (_active.containsKey(projectId)) {
      throw StateError('Analysis is already running.');
    }
    _active[projectId] = cancellation;
    final llm =
        client ?? TaskProfileRepository.llm(provider, model, binding.profile);
    final callLimit = checkpoint.calls + maxCalls;
    final priorStage = checkpoint.stage;
    final requestedIntent = feedback.trim();
    void progress() => onProgress?.call(
      RoleAnalysisProgress(
        stage: checkpoint.stage,
        processed: checkpoint.nextSegment,
        total: all.length,
        calls: checkpoint.calls,
      ),
    );
    Future<LlmStructuredResult> invoke(
      String prompt,
      Map<String, Object?> schema,
      Map<String, Object?> input,
    ) async {
      cancellation.throwIfCancelled();
      if (checkpoint.calls >= callLimit) throw const _BudgetReached();
      final encodedInput = jsonEncode(input);
      if (encodedInput.length > 64000) {
        throw StateError(
          'Analysis input exceeds the local 64000 UTF-16 budget. Reduce the batch or cast.',
        );
      }
      checkpoint.calls++;
      await checkpoints.save(projectId, chapterId, checkpoint);
      progress();
      try {
        final result = await queue.enqueue(
          provider: provider,
          source: 'Novel role analysis',
          label: checkpoint.stage,
          cancelToken: cancellation,
          estimatedTokens: (encodedInput.length / 2).ceil(),
          task: () => llm.structured(
            schemaName: 'novel_${checkpoint.stage}',
            schema: schema,
            cancellation: cancellation,
            messages: [
              LlmChatMessage(role: 'system', content: prompt),
              LlmChatMessage(role: 'user', content: jsonEncode(input)),
            ],
          ),
        );
        try {
          await capabilities?.markSuccess(provider, model, route, [
            'text',
            if (result.responseFormat == 'json_schema') 'structuredOutput',
          ]);
        } catch (_) {}
        return result;
      } on LlmChatException catch (error) {
        if (error.transportFailure) {
          try {
            await capabilities?.markFailure(
              provider,
              model,
              route,
              error.statusCode,
            );
          } catch (_) {}
        }
        rethrow;
      }
    }

    try {
      if (client == null) {
        await RoleAiModel(
          capabilities ?? CapabilityRepository(database),
        ).requireForTask(provider, model, binding.profile, cancellation);
      }
      checkpoint.error = null;
      if (!checkpoint.rosterReady || replan || requestedIntent.isNotEmpty) {
        final replanning = checkpoint.rosterReady;
        checkpoint.stage = replanning ? 'replanCast' : 'planCast';
        if (!replanning && requestedIntent.isNotEmpty) {
          checkpoint.feedback = requestedIntent;
        }
        final planIntent = replanning ? requestedIntent : checkpoint.feedback;
        final roles = await characters.load(projectId);
        final excerpt = all.map((s) => s.segmentText).join('\n');
        final plan = await invoke(
          skill.prompt(replanning ? 'replanner' : 'planner'),
          RoleAnalysisProtocol.rosterSchema,
          {
            'knownCharacters': _roster(roles),
            'recentScene': checkpoint.sceneSummary,
            'userFeedback': planIntent,
            'chapterExcerpt': RoleAnalysisContext.excerpt(excerpt, 18000),
            'structure': context.summary,
            'sceneState': checkpoint.scene.forRoster(roles),
          },
        );
        await database.transaction(() async {
          await _applyRoster(projectId, plan.object, roles, cancellation);
          checkpoint.scene = RoleSceneState.fromPlan(
            plan.object['scene'],
            await characters.load(projectId),
          );
        });
        checkpoint.feedback = planIntent;
        checkpoint.rosterReady = true;
        checkpoint.rosterConfirmed = false;
        if (replanning) checkpoint.nextSegment = 0;
        checkpoint.stage = 'rosterReview';
        await checkpoints.save(projectId, chapterId, checkpoint);
        progress();
        return; // Always let the user review new/replanned characters first.
      }
      checkpoint.rosterConfirmed |= confirmRoster;
      if (!checkpoint.rosterConfirmed) {
        checkpoint.stage = 'rosterReview';
        await checkpoints.save(projectId, chapterId, checkpoint);
        return;
      }
      while (checkpoint.nextSegment < all.length) {
        cancellation.throwIfCancelled();
        checkpoint.stage = 'labelChunk';
        var end = checkpoint.nextSegment;
        var charactersInBatch = 0;
        while (end < all.length && end - checkpoint.nextSegment < batchSize) {
          final length = all[end].segmentText.length;
          if (end > checkpoint.nextSegment &&
              charactersInBatch + length > 24000) {
            break;
          }
          charactersInBatch += length;
          end++;
        }
        final roles = await characters.load(projectId);
        final batch = all.sublist(checkpoint.nextSegment, end).where((s) {
          final a = roles.annotations[s.id];
          return !(a?.locked ?? false) &&
              !(a?.reviewState == NovelReviewState.confirmed &&
                  a?.textRevision == novelTextRevision(s.segmentText));
        }).toList();
        if (batch.isNotEmpty) {
          final result = await invoke(
            skill.prompt('executor'),
            RoleAnalysisProtocol.labelsSchema,
            {
              'roster': _roster(roles),
              'recentScene': checkpoint.sceneSummary,
              'userFeedback': checkpoint.feedback,
              'sceneState': checkpoint.scene.forRoster(roles),
              'segments': context.describe(batch, roles),
              'precedingContext': context.describe(
                all.sublist(
                  (checkpoint.nextSegment - 3).clamp(0, all.length),
                  checkpoint.nextSegment,
                ),
                roles,
                contextOnly: true,
              ),
              'followingContext': context.describe(
                all.sublist(end, (end + 3).clamp(0, all.length)),
                roles,
                contextOnly: true,
              ),
            },
          );
          checkpoint.stage = 'validate';
          var labels = RoleAnalysisProtocol.parseLabels(
            result.object,
            batch,
            roles,
          );
          final doubts = RoleDoubtDetector.inspect(
            labels: labels,
            roles: roles,
            context: context,
          );
          labels = RoleDoubtDetector.flag(labels, doubts);
          cancellation.throwIfCancelled();
          await annotations.apply(projectId, labels, fromAi: true);
          final doubtfulIds = doubts.map((d) => d.segmentId).toSet();
          if (doubtfulIds.isNotEmpty && checkpoint.calls < callLimit) {
            checkpoint.stage = 'review';
            final doubtful = batch
                .where((s) => doubtfulIds.contains(s.id))
                .toList();
            final review = await invoke(
              skill.prompt('reviewer'),
              RoleAnalysisProtocol.labelsSchema,
              {
                'roster': _roster(roles),
                if (checkpoint.feedback.isNotEmpty)
                  'userFeedback': checkpoint.feedback,
                'sceneState': checkpoint.scene.forRoster(roles),
                'segments': context.describe(
                  doubtful,
                  await characters.load(projectId),
                ),
                'surroundingContext': context.describe(
                  all.sublist(
                    (checkpoint.nextSegment - 3).clamp(0, all.length),
                    (end + 3).clamp(0, all.length),
                  ),
                  roles,
                  contextOnly: true,
                ),
                'doubts': doubts.map((d) => d.toJson()).toList(),
              },
            );
            var reviewed = RoleAnalysisProtocol.parseLabels(
              review.object,
              doubtful,
              roles,
            );
            reviewed = RoleDoubtDetector.flag(
              reviewed,
              RoleDoubtDetector.inspect(
                labels: reviewed,
                roles: roles,
                context: context,
                audit: false,
              ),
            );
            cancellation.throwIfCancelled();
            await annotations.apply(projectId, reviewed, fromAi: true);
            checkpoint.reviewedSegments += reviewed.length;
            checkpoint.reviewChanges += reviewed
                .where(
                  (r) => labels.any(
                    (a) =>
                        a.segmentId == r.segmentId &&
                        (a.characterId != r.characterId || a.kind != r.kind),
                  ),
                )
                .length;
          }
          final summary = result.object['sceneSummary'];
          if (summary is String) {
            checkpoint.sceneSummary = summary.substring(
              0,
              summary.length.clamp(0, 500),
            );
          }
        }
        checkpoint.nextSegment = end;
        await checkpoints.save(projectId, chapterId, checkpoint);
        progress();
      }
      checkpoint.stage = 'completed';
    } on TtsCancelledException {
      checkpoint.stage = checkpoint.stage == 'replanCast'
          ? priorStage
          : 'paused';
    } on _BudgetReached {
      checkpoint.stage = 'paused';
      checkpoint.error =
          'Call budget reached; resume explicitly to authorize another bounded run.';
    } catch (error) {
      checkpoint.stage = checkpoint.stage == 'replanCast'
          ? priorStage
          : 'failed';
      checkpoint.error = '$error';
      rethrow;
    } finally {
      if (identical(_active[projectId], cancellation)) {
        _active.remove(projectId);
      }
      await checkpoints.save(projectId, chapterId, checkpoint);
    }
  }

  List<Map<String, Object?>> _roster(NovelRoleSnapshot roles) => [
    for (final c in roles.characters)
      {
        'id': c.id,
        'name': c.name,
        'aliases': c.aliases,
        'description': c.description,
        'identityKind': c.identityKind.name,
      },
  ];
  Future<void> _applyRoster(
    String projectId,
    Map<String, dynamic> object,
    NovelRoleSnapshot roles,
    TtsCancelToken cancellation,
  ) async {
    final raw = object['characters'];
    if (raw is! List || raw.length > 100) {
      throw const FormatException('Invalid character roster.');
    }
    const pronouns = {
      'I',
      '我',
      '你',
      '他',
      '她',
      '它',
      '我们',
      '你们',
      '他们',
      '她们',
      '吾',
      '大家',
      '众人',
    };
    final names = {
      for (final c in roles.characters) ...[c.name, ...c.aliases],
    };
    await database.transaction(() async {
      for (final item in raw) {
        cancellation.throwIfCancelled();
        if (item is! Map ||
            item['name'] is! String ||
            item['aliases'] is! List ||
            item['description'] is! String) {
          throw const FormatException('Malformed character.');
        }
        final name = (item['name'] as String).trim();
        final kind = CharacterIdentityKind.values.byName(
          item['identityKind'] as String? ?? 'named',
        );
        final scene = object['scene'];
        final anonymousNarrator =
            (name == '我' || name == 'I') &&
            kind == CharacterIdentityKind.anonymous &&
            scene is Map &&
            scene['firstPersonName'] == name;
        final collective =
            ['大家', '众人'].contains(name) && kind == CharacterIdentityKind.group;
        if (name.isEmpty ||
            name.length > 80 ||
            (pronouns.contains(name) && !anonymousNarrator && !collective)) {
          continue;
        }
        if (!names.add(name)) {
          continue; // Never overwrite manually edited metadata.
        }
        await characters.saveCharacter(
          projectId: projectId,
          name: name,
          aliases: (item['aliases'] as List)
              .cast<String>()
              .where((s) => !pronouns.contains(s.trim()))
              .toList(),
          description: item['description'] as String,
          identityKind: kind,
        );
      }
    });
  }
}

class _BudgetReached implements Exception {
  const _BudgetReached();
}
