import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:neiroha/data/ai/protocols/openai/llm_chat_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/data/services/capabilities/capability_repository.dart';
import 'package:neiroha/data/services/capabilities/role_ai_model.dart';
import 'package:neiroha/data/services/capabilities/task_profile_repository.dart';
import 'package:neiroha/domain/capabilities/task_profile.dart';
import 'package:neiroha/domain/novel/role_review.dart';
import 'role_review_repository.dart';
import 'role_review_snapshot.dart';
import 'role_review_protocol.dart';
import 'role_review_tools.dart';
import 'role_skill_repository.dart';
import 'role_skill_profiles_repository.dart';

class RoleReviewService {
  RoleReviewService(this.database, this.queue, {RoleSkillLoader? loadSkill})
    : _loadSkill = loadSkill ?? RoleSkillProfilesRepository(database).loadSkill;
  final db.AppDatabase database;
  final TtsQueueService queue;
  final RoleSkillLoader _loadSkill;
  final _active = <String, TtsCancelToken>{};
  RoleReviewRepository get repository =>
      RoleReviewRepository(database, loadSkill: _loadSkill);
  bool isRunning(String projectId) => _active.containsKey(projectId);
  void pause(String projectId) => _active[projectId]?.cancel();
  void dispose() {
    for (final token in _active.values) {
      token.cancel();
    }
  }

  Future<RoleReviewSession> run({
    required String projectId,
    required String chapterId,
    required db.TtsProvider provider,
    required String model,
    List<String>? targetIds,
    bool resume = false,
    RoleReviewBudget budget = const RoleReviewBudget(),
    LlmChatAdapter? client,
  }) async {
    budget.validate();
    if (isRunning(projectId)) {
      throw StateError('A local review is already running for this novel.');
    }
    final binding = await TaskProfileRepository(
      database,
    ).resolve(projectId, ModelTask.analysis, provider);
    provider = binding.provider;
    model = binding.profile?.model ?? model;
    if (model.trim().isEmpty) throw ArgumentError('Choose a review model.');
    final skill = await _loadSkill();
    final state = await RoleReviewSnapshot.load(
      database,
      projectId,
      chapterId,
      skill,
    );
    final previous = resume
        ? await repository.load(projectId, chapterId)
        : null;
    if (resume && (previous == null || !previous.canResume)) {
      throw StateError('No resumable review budget remains.');
    }
    if (previous != null &&
        (previous.signature != state.signature ||
            previous.skillDigest != skill.digest ||
            previous.providerId != provider.id ||
            previous.model != model)) {
      throw StateError(
        'Resume needs the same novel state, skill, provider and model.',
      );
    }
    var session =
        previous ??
        RoleReviewSession(
          id: const Uuid().v4(),
          projectId: projectId,
          chapterId: chapterId,
          signature: state.signature,
          skillDigest: skill.digest,
          providerId: provider.id,
          model: model,
          targets: state.selectTargets(targetIds),
          budget: budget,
        );
    for (final id in session.targets) {
      session.excerpts[id] = [state.requireSegment(id).segmentText];
    }
    final cancellation = TtsCancelToken();
    if (_active.containsKey(projectId)) {
      throw StateError('A local review is already running.');
    }
    _active[projectId] = cancellation;
    session.owner = const Uuid().v4();
    session.status = 'running';
    session.error = null;
    Timer? heartbeat;
    var claimed = false;
    final watch = Stopwatch()..start();
    try {
      await repository.claim(session);
      claimed = true;
      heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
        unawaited(
          repository
              .renew(projectId, chapterId, session.id, session.owner!)
              .catchError((Object _) => cancellation.cancel()),
        );
      });
      final llm =
          client ?? TaskProfileRepository.llm(provider, model, binding.profile);
      if (client == null) {
        await RoleAiModel(
          CapabilityRepository(database),
        ).requireForTask(provider, model, binding.profile, cancellation);
      }
      while (session.status == 'running') {
        cancellation.throwIfCancelled();
        if (session.calls >= session.budget.maxCalls) {
          session.status = 'budgetExhausted';
          break;
        }
        final messages = [
          LlmChatMessage(
            role: 'system',
            content: skill.prompt('tool_reviewer'),
          ),
          LlmChatMessage(
            role: 'user',
            content: jsonEncode({
              'protocol': RoleReviewProtocol.version,
              'targets': [
                for (final id in session.targets)
                  state.segment(state.requireSegment(id)),
              ],
              'characters': state.castFor(session.targets),
              'totalCharacterCount': state.roles.characters.length,
              'proposals': session.proposals
                  .map(
                    (p) =>
                        {'key': p.key, 'action': p.action, ...p.data}
                          ..remove('evidence'),
                  )
                  .toList(),
              'lastToolResults': session.journal
                  .where((j) => j.containsKey('cacheKey'))
                  .toList(),
              'remainingCalls': session.budget.maxCalls - session.calls,
              'remainingReads': session.budget.maxReads - session.reads,
              'remainingProposals':
                  session.budget.maxProposals - session.proposals.length,
            }),
          ),
        ];
        final inputBytes = utf8
            .encode(jsonEncode(messages.map((m) => m.toJson()).toList()))
            .length;
        final reserve =
            inputBytes +
            utf8.encode(jsonEncode(RoleReviewProtocol.schema)).length +
            session.budget.outputTokens +
            512;
        if (inputBytes > session.budget.inputBytes ||
            session.chargedTokens + reserve > session.budget.maxTokens) {
          session.status = 'budgetExhausted';
          session.error =
              'Input or conservative token reservation exceeds the remaining local budget.';
          break;
        }
        // Reserve before sending. Crashes/errors retain the unknown charge; resume never refunds it blindly.
        session.calls++;
        session.chargedTokens += reserve;
        await repository.save(session);
        final result = await queue.enqueue(
          capability: AiCapability.llm,
          provider: provider,
          source: 'Novel local review',
          label: 'turn ${session.calls}',
          cancelToken: cancellation,
          estimatedTokens: reserve,
          task: () => llm.structured(
            messages: messages,
            schemaName: 'novel_local_review',
            schema: RoleReviewProtocol.schema,
            cancellation: cancellation,
            maxOutputTokens: session.budget.outputTokens,
            allowFormatFallback: false,
            timeout: const Duration(seconds: 60),
          ),
        );
        final usage = result.usage['total_tokens'];
        if (usage is int && usage > 0) {
          session.reportedTokens += usage;
          session.chargedTokens += usage - reserve;
        }
        // A cancellation after a valid response still records its returned usage.
        await repository.save(session);
        cancellation.throwIfCancelled();
        if (session.chargedTokens > session.budget.maxTokens) {
          session.status = 'budgetExhausted';
          session.error =
              'Reported usage exceeded the conservative reservation; no further call is allowed.';
          break;
        }
        session = RoleReviewTools(
          state,
        ).dispatch(session, RoleReviewProtocol.parse(result.object));
        session.elapsedMs += watch.elapsedMilliseconds;
        watch.reset();
        await repository.save(session);
      }
      final current = await RoleReviewSnapshot.load(
        database,
        projectId,
        chapterId,
        skill,
      );
      if (current.signature != session.signature) {
        throw StateError(
          'Novel state changed during local review. Proposals are stale.',
        );
      }
    } on TtsCancelledException {
      session.status = 'paused';
    } catch (error) {
      session.status = 'failed';
      session.error = '$error'.replaceAll(
        provider.apiKey,
        provider.apiKey.isEmpty ? '' : '[REDACTED]',
      );
      if (provider.apiKey.isNotEmpty && '$error'.contains(provider.apiKey)) {
        throw StateError(session.error!);
      }
      rethrow;
    } finally {
      heartbeat?.cancel();
      session.elapsedMs += watch.elapsedMilliseconds;
      if (identical(_active[projectId], cancellation)) {
        _active.remove(projectId);
      }
      if (claimed) await repository.save(session);
    }
    return session;
  }
}
