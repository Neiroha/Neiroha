// Automatic order per capability: connection priority, then each
// connection's model order.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';

db.TtsProvider _openAi(String id, int position) => db.TtsProvider(
  id: id,
  name: id,
  adapterType: AdapterType.openaiTts.name,
  baseUrl: 'http://127.0.0.1:9/v1',
  apiKey: 'fixture',
  defaultModelName: AdapterType.openaiTts.defaultModel,
  enabled: true,
  position: position,
  maxConcurrency: 1,
);

void main() {
  test('priority and model order decide the automatic choice', () async {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    for (final p in [_openAi('a', 0), _openAi('b', 1)]) {
      await database.insertProvider(p.toCompanion(true));
    }

    var router = await CapabilityRouter.load(database);
    expect(router.serving(AiCapability.tts).map((c) => c.id), ['a', 'b']);
    final models = router.modelsOf(
      router.serving(AiCapability.tts).first,
      AiCapability.tts,
    );
    expect(models.length, greaterThan(1));

    await database.reorderCapabilityConnections('tts', ['b', 'a']);
    await database.setCapabilityModelOrder('b', 'tts', [models.last.id]);
    router = await CapabilityRouter.load(database);

    expect(router.serving(AiCapability.tts).map((c) => c.id), ['b', 'a']);
    final b = router.serving(AiCapability.tts).first;
    expect(router.modelsOf(b, AiCapability.tts).first.id, models.last.id);
    // Every model is kept; only the order changes.
    expect(router.modelsOf(b, AiCapability.tts).length, models.length);
    final picked = router.resolve<SpeechSynthesizer>(AiCapability.tts);
    expect(picked?.connection.id, 'b');
    expect(picked?.model.descriptor.id, models.last.id);
    // Other capabilities keep list order.
    expect(router.serving(AiCapability.llm).map((c) => c.id), ['a', 'b']);

    // Ordering leaves the lane on and its limits inherited.
    final rows = await database.getConnectionCapabilities();
    expect(rows.every((r) => r.enabled && r.maxConcurrency == null), isTrue);
  });

  test('a switched-off connection keeps its place but is skipped', () async {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    for (final p in [_openAi('a', 0), _openAi('b', 1)]) {
      await database.insertProvider(p.toCompanion(true));
    }
    await database.reorderCapabilityConnections('tts', ['b', 'a']);
    await database.upsertConnectionCapability(
      const db.ConnectionCapabilitiesCompanion(
        connectionId: Value('b'),
        capability: Value('tts'),
        enabled: Value(false),
      ),
    );
    final router = await CapabilityRouter.load(database);
    expect(router.ordered(AiCapability.tts).map((c) => c.id), ['b', 'a']);
    expect(router.serving(AiCapability.tts).map((c) => c.id), ['a']);
  });
}
