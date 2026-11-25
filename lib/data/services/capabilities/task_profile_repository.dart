import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:neiroha/data/ai/protocols/openai/llm_chat_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/capabilities/task_profile.dart';
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'role_ai_connection.dart';

class TaskProfileRepository {
  const TaskProfileRepository(this.database);
  final db.AppDatabase database;
  String _prefix(String projectId) => 'novel.taskProfiles.$projectId.';
  String _key(String projectId, ModelTask task) =>
      '${_prefix(projectId)}${task.name}';
  Future<List<TaskProfile>> load(String projectId) async => [
    for (final raw in (await database.getSettingsWithPrefix(
      _prefix(projectId),
    )).values)
      TaskProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>),
  ];
  Stream<List<TaskProfile>> watch(String projectId) =>
      (database.select(
        database.appSettings,
      )..where((t) => t.key.like('${_prefix(projectId)}%'))).watch().map(
        (rows) => [
          for (final r in rows)
            TaskProfile.fromJson(jsonDecode(r.value) as Map<String, dynamic>),
        ],
      );

  Future<void> save(String projectId, TaskProfile profile) =>
      database.transaction(() async {
        profile.validate();
        if (await database.getNovelProjectById(projectId) == null ||
            !(await database.getAllProviders()).any(
              (p) =>
                  p.id == profile.providerId &&
                  (profile.task == ModelTask.synthesis || p.supportsRoleAi),
            )) {
          throw StateError('Project or connection was deleted.');
        }
        await database.setSetting(
          _key(projectId, profile.task),
          jsonEncode(profile.toJson()),
        );
      });

  Future<void> remove(String projectId, ModelTask task) => (database.delete(
    database.appSettings,
  )..where((t) => t.key.equals(_key(projectId, task)))).go();

  Future<({db.TtsProvider provider, TaskProfile? profile})> resolve(
    String projectId,
    ModelTask task,
    db.TtsProvider fallback,
  ) async {
    final profile = (await load(
      projectId,
    )).where((p) => p.task == task).firstOrNull;
    if (profile == null) return (provider: fallback, profile: null);
    final provider = (await database.getAllProviders())
        .where((p) => p.id == profile.providerId)
        .firstOrNull;
    if (provider == null) {
      throw StateError('Task connection was deleted. Choose a new connection.');
    }
    if (task != ModelTask.synthesis && !provider.supportsRoleAi) {
      throw StateError('This task needs a text analysis connection.');
    }
    return (provider: provider, profile: profile);
  }

  static LlmChatAdapter llm(
    db.TtsProvider provider,
    String fallbackModel,
    TaskProfile? profile,
  ) => LlmChatAdapter.fromTtsProvider(
    provider,
    modelName: profile?.model ?? fallbackModel,
    route: profile?.route ?? ServiceRoute.chatCompletions,
    endpointPath: profile?.endpointPath,
    apiKeyHeader: profile?.apiKeyHeader,
  );
}
