import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'package:drift/drift.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:uuid/uuid.dart';

import 'model_discovery_service.dart';

/// Discovery adds inventory. A temporary API omission must not delete bindings
/// already referenced by a character or deliberately entered by the user.
class ProviderModelInventory {
  const ProviderModelInventory(this.database, this.discovery);
  final db.AppDatabase database;
  final ModelDiscoveryService discovery;

  Future<void> refresh(
    db.TtsProvider provider, {
    required bool separateVoices,
  }) async {
    final models = await discovery.modelsForProvider(provider);
    final voices = separateVoices
        ? await createAdapter(provider).getSpeakers()
        : <String>[];
    await database.transaction(() async {
      final existing = await database.getBindingsForProvider(provider.id);
      final modelIds = existing
          .where((m) => m.supportedTaskModes != 'voice')
          .map((m) => m.modelKey)
          .toSet();
      final voiceIds = existing
          .where((m) => m.supportedTaskModes == 'voice')
          .map((m) => m.modelKey)
          .toSet();
      for (final model in models) {
        if (!modelIds.add(model.id)) continue;
        await database.insertBinding(
          db.ModelBindingsCompanion(
            id: Value(const Uuid().v4()),
            providerId: Value(provider.id),
            modelKey: Value(model.id),
          ),
        );
      }
      for (final voice in voices) {
        if (!voiceIds.add(voice)) continue;
        await database.insertBinding(
          db.ModelBindingsCompanion(
            id: Value(const Uuid().v4()),
            providerId: Value(provider.id),
            modelKey: Value(voice),
            supportedTaskModes: const Value('voice'),
          ),
        );
      }
    });
  }
}
