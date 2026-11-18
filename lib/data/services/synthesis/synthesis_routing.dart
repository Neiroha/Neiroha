import 'package:neiroha/data/adapters/openai_tts_adapter.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'package:neiroha/domain/capabilities/task_profile.dart';

TtsAdapter synthesisAdapter(
  db.TtsProvider provider,
  String? model,
  TaskProfile? profile,
) {
  if (profile == null || profile.route == ServiceRoute.native) {
    return createAdapter(provider, modelName: profile?.model ?? model);
  }
  profile.validate();
  if (profile.providerId != provider.id) {
    throw ArgumentError('Wrong task connection.');
  }
  return OpenAiTtsAdapter(
    baseUrl: provider.baseUrl,
    apiKey: provider.apiKey,
    modelName: profile.model,
    explicitRoute: profile.route,
    endpointPath: profile.endpointPath,
    apiKeyHeader: profile.apiKeyHeader,
  );
}
