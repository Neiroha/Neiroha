// Schema v34: per-character settings, connection × capability limits,
// added models and capability defaults.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/conversation/character_live_settings.dart';
import 'package:neiroha/data/services/synthesis/voice_chain_runner.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/synthesis/voice_chain.dart';

db.TtsProvider _provider(String id, {int maxConcurrency = 1}) => db.TtsProvider(
  id: id,
  name: id,
  adapterType: 'openaiCompatible',
  baseUrl: 'http://localhost/v1',
  apiKey: '',
  defaultModelName: 'tts-1',
  enabled: true,
  position: 0,
  maxConcurrency: maxConcurrency,
);

/// The v33 tables from the schema history fixture.
List<String> _v33Schema() {
  final history =
      jsonDecode(
            File(
              'scripts/tests/fixtures/database_schemas/history.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final ddl = (history['ddl'] as List).cast<String>();
  return [
    for (final i in history['versions']['33']['ddl'] as List) ddl[i as int],
  ];
}

void main() {
  test('v33 → v34 moves chains and live settings out of app_settings', () async {
    final database = db.AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (sqlite) {
          _v33Schema().forEach(sqlite.execute);
          sqlite.userVersion = 33;
          sqlite.execute(
            "INSERT INTO tts_providers (id, name, adapter_type, base_url, enabled) "
            "VALUES ('p', 'p', 'openaiCompatible', 'http://localhost/v1', 1)",
          );
          sqlite.execute(
            "INSERT INTO voice_assets (id, name, provider_id, task_mode) "
            "VALUES ('v', 'v', 'p', 'presetVoice')",
          );
          for (final (k, v) in [
            ('voice.chain.v', '[{"kind":"trim"}]'),
            ('dialog.live.v', '{"persona":"长门"}'),
            ('voice.chain.gone', '[{"kind":"trim"}]'),
            ('ui.keep', 'yes'),
          ]) {
            sqlite.execute(
              'INSERT INTO app_settings (key, value) VALUES (?, ?)',
              [k, v],
            );
          }
        },
      ),
    );
    addTearDown(database.close);
    expect(
      (await VoiceChainHook.load(database, 'v')).steps.single.kind,
      VoiceChainStepKind.trim,
    );
    expect((await CharacterLiveSettings.load(database, 'v')).persona, '长门');
    // Rows of deleted characters go; other settings stay.
    expect(
      await database.select(database.voiceAssetSettings).get(),
      hasLength(1),
    );
    expect(await database.getSettingsWithPrefix('voice.chain.'), isEmpty);
    expect(await database.getSettingsWithPrefix('dialog.live.'), isEmpty);
    expect(await database.getSetting('ui.keep'), 'yes');
  });

  test('chain and live settings live in voice_asset_settings', () async {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final voice = (await database.getAllVoiceAssets()).first.id;
    await VoiceChainHook.save(
      database,
      voice,
      const VoiceChain([VoiceChainStep(kind: VoiceChainStepKind.trim)]),
    );
    await const CharacterLiveSettings(persona: 'p').save(database, voice);
    expect((await VoiceChainHook.load(database, voice)).steps, hasLength(1));
    expect((await CharacterLiveSettings.load(database, voice)).persona, 'p');
    expect(await database.getSettingsWithPrefix('voice.chain.'), isEmpty);
    // Both columns share one row; deleting the character drops it.
    expect(
      await database.select(database.voiceAssetSettings).get(),
      hasLength(1),
    );
    await database.customStatement('PRAGMA foreign_keys = ON');
    await database.customStatement(
      "DELETE FROM voice_bank_members WHERE voice_asset_id = '$voice'",
    );
    await database.customStatement(
      "DELETE FROM voice_assets WHERE id = '$voice'",
    );
    expect(await database.select(database.voiceAssetSettings).get(), isEmpty);
  });

  group('router over the v34 tables', () {
    final rows = [_provider('a'), _provider('b')];

    test('a switched-off capability is not served', () {
      final router = CapabilityRouter.fromProviders(
        rows,
        modelRows: [
          for (final c in ['a', 'b'])
            db.ProviderModel(
              id: c,
              connectionId: c,
              modelId: 'x',
              capability: 'llm',
              featuresJson: '[]',
              source: 'manual',
              enabled: true,
            ),
        ],
        capabilityRows: [
          const db.ConnectionCapability(
            connectionId: 'a',
            capability: 'llm',
            enabled: false,
          ),
        ],
      );
      final llm = router.serving(AiCapability.llm).map((c) => c.id);
      expect(llm, ['b']);
      expect(
        router.resolve<LanguageModel>(
          AiCapability.llm,
          connectionId: 'a',
          modelId: 'x',
        ),
        isNull,
      );
    });

    test('added models are listed and defaults pick by purpose', () {
      final router = CapabilityRouter.fromProviders(
        rows,
        modelRows: [
          db.ProviderModel(
            id: 'm1',
            connectionId: 'b',
            modelId: 'my-llm',
            capability: 'llm',
            displayName: 'Mine',
            featuresJson: '[]',
            source: 'manual',
            enabled: true,
            shutdownAt: DateTime.utc(2027),
          ),
        ],
        defaultRows: [
          const db.CapabilityDefault(
            capability: 'llm',
            purpose: '',
            connectionId: 'a',
            modelId: 'general',
          ),
          const db.CapabilityDefault(
            capability: 'llm',
            purpose: 'subtitle',
            connectionId: 'b',
            modelId: 'my-llm',
          ),
        ],
      );
      final b = router.connections.firstWhere((c) => c.id == 'b');
      final mine = router
          .modelsOf(b, AiCapability.llm)
          .firstWhere((m) => m.id == 'my-llm');
      expect(mine.label, 'Mine');
      expect(mine.source, DescriptorSource.user);
      expect(mine.shutdownAt, startsWith('2027-01-01'));
      expect(router.defaults[AiCapability.llm], ('a', 'general'));
      final routed = router.resolve<LanguageModel>(
        AiCapability.llm,
        purpose: 'subtitle',
      );
      expect(
        (routed?.connection.id, routed?.model.descriptor.id),
        ('b', 'my-llm'),
      );
    });

    test('load reads the tables', () async {
      final database = db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final id = (await database.getAllProviders())
          .firstWhere(
            (p) => p.adapterType == 'openaiCompatible' || p.id == 'openai',
          )
          .id;
      await database.setCapabilityDefault('llm', (id, 'pinned'));
      final router = await CapabilityRouter.load(database);
      expect(router.defaults[AiCapability.llm], (id, 'pinned'));
      await database.setCapabilityDefault('llm', null);
      expect((await CapabilityRouter.load(database)).defaults, isEmpty);
    });
  });

  group('queue lanes', () {
    final queue = TtsQueueService.instance;
    tearDown(() => queue.setCapabilityLimits(const []));

    test('LLM work does not take the TTS slot of its connection', () async {
      final p = _provider('lane-${DateTime.now().microsecondsSinceEpoch}');
      final llmGate = Completer<void>();
      final started = <String>[];
      final llm = queue.enqueue<void>(
        provider: p,
        capability: AiCapability.llm,
        task: () {
          started.add('llm');
          return llmGate.future;
        },
      );
      final tts = queue.enqueue<void>(
        provider: p,
        task: () async => started.add('tts'),
      );
      await tts;
      expect(started, ['llm', 'tts']);
      llmGate.complete();
      await llm;
    });

    test('a capability row overrides the connection limit', () async {
      final p = _provider('limit-${DateTime.now().microsecondsSinceEpoch}');
      queue.setCapabilityLimits([
        db.ConnectionCapability(
          connectionId: p.id,
          capability: 'tts',
          enabled: true,
          maxConcurrency: 2,
        ),
      ]);
      final gates = [Completer<void>(), Completer<void>()];
      var running = 0;
      final tasks = [
        for (final g in gates)
          queue.enqueue<void>(
            provider: p,
            task: () {
              running++;
              return g.future;
            },
          ),
      ];
      await pumpEventQueue();
      expect(running, 2);
      for (final g in gates) {
        g.complete();
      }
      await Future.wait(tasks);
    });
  });
}
