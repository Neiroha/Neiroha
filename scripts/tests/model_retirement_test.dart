// OpenAI retires its Speech API models on 2027-01-06: characters using them
// are found, flagged and moved to the Realtime replacement where it runs.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/capabilities/model_retirement.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/ai/model_retirement_widgets.dart';
import 'package:neiroha/providers/app_providers.dart';

const _openai = db.TtsProvider(
  id: 'openai',
  name: 'OpenAI',
  adapterType: 'openaiTts',
  baseUrl: 'https://api.openai.com/v1',
  apiKey: 'fixture',
  defaultModelName: 'gpt-4o-mini-tts',
  enabled: true,
  position: 0,
  maxConcurrency: 1,
);

db.VoiceAsset _asset(String id, {String? model, String? voice}) =>
    db.VoiceAsset(
      id: id,
      name: id,
      providerId: 'openai',
      taskMode: 'presetVoice',
      modelName: model,
      presetVoiceName: voice,
      speed: 1,
      enabled: true,
      loudnessOffsetDb: 0,
    );

void main() {
  group('finding retiring models', () {
    test(
      'characters on Speech API models are found; Realtime ones are not',
      () {
        final uses = findRetiringUses(
          [_openai],
          [
            _asset('default'), // provider default gpt-4o-mini-tts
            _asset('legacy', model: 'tts-1'),
            _asset('realtime', model: 'gpt-realtime-2.1-mini'),
            _asset('orphan').copyWith(providerId: 'gone'),
          ],
        );
        expect(uses.map((u) => u.asset.id), ['default', 'legacy']);
        expect(uses.first.model.shutdownAt, '2027-01-06');
      },
    );

    test('provider rows know the shutdown date of every capability', () {
      final c = connectionForProvider(_openai);
      expect(retiringDescriptor(c, 'tts-1')!.shutdownAt, '2027-01-06');
      expect(retiringDescriptor(c, 'whisper-1')!.capability, AiCapability.stt);
      expect(retiringDescriptor(c, 'gpt-realtime-2.1-mini'), isNull);
    });

    test('days left count calendar days', () {
      expect(daysUntil('2027-01-06', DateTime(2026, 11, 24, 23, 59)), 43);
      expect(daysUntil('2027-01-06', DateTime(2027, 1, 7)), -1);
    });
  });

  group('replacement', () {
    final model = retiringDescriptor(
      connectionForProvider(_openai),
      'gpt-4o-mini-tts',
    )!;

    test('desktop moves to Realtime and keeps voices it offers', () {
      final move = replacementFor(
        _openai,
        model,
        platform: AiPlatform.desktop,
        currentVoice: 'coral',
      )!;
      expect(move.model, 'gpt-realtime-2.1-mini');
      expect(move.voice, isNull);
    });

    test('voices Realtime lacks switch to its first voice', () {
      final move = replacementFor(
        _openai,
        model,
        platform: AiPlatform.desktop,
        currentVoice: 'fable',
      )!;
      expect(move.voice, 'marin');
      // Custom voices are left alone.
      expect(
        replacementFor(
          _openai,
          model,
          platform: AiPlatform.desktop,
          currentVoice: 'voice_abc',
        )!.voice,
        isNull,
      );
    });

    test('the web has no replacement: Realtime needs a native socket', () {
      expect(replacementFor(_openai, model, platform: AiPlatform.web), isNull);
      expect(
        aiPlatformOf(const PlatformCapabilities(NeirohaPlatform.web)),
        AiPlatform.web,
      );
    });
  });

  test('migration moves characters and the provider default', () async {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.insertProvider(
      db.TtsProvidersCompanion.insert(
        id: 'openai',
        name: 'OpenAI',
        adapterType: 'openaiTts',
        baseUrl: 'https://api.openai.com/v1',
      ),
    );
    await database.updateProvider(_openai);
    for (final a in [
      _asset('a', voice: 'nova'),
      _asset('b', model: 'tts-1-hd', voice: 'alloy'),
    ]) {
      await database.insertVoiceAsset(a.toCompanion(false));
    }
    final uses = findRetiringUses(
      await database.getAllProviders(),
      await database.getAllVoiceAssets(),
    );
    expect(
      await migrateRetiring(database, uses, platform: AiPlatform.desktop),
      2,
    );
    final assets = {
      for (final a in await database.getAllVoiceAssets()) a.id: a,
    };
    expect(assets['a']!.modelName, 'gpt-realtime-2.1-mini');
    expect(assets['a']!.presetVoiceName, 'marin');
    expect(assets['b']!.presetVoiceName, 'alloy');
    expect(
      (await database.getAllProviders())
          .firstWhere((p) => p.id == 'openai')
          .defaultModelName,
      'gpt-realtime-2.1-mini',
    );
    expect(
      findRetiringUses(
        await database.getAllProviders(),
        await database.getAllVoiceAssets(),
      ),
      isEmpty,
    );
    // The web leaves everything for a manual change.
    expect(await migrateRetiring(database, uses, platform: AiPlatform.web), 0);
  });

  testWidgets('banner counts affected characters and can be dismissed', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsProvidersStreamProvider.overrideWith(
            (_) => Stream.value(const [_openai]),
          ),
          voiceAssetsStreamProvider.overrideWith(
            (_) => Stream.value([_asset('a'), _asset('b', model: 'tts-1')]),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: RetirementBanner(now: DateTime(2026, 11, 24))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        '2 characters use models that stop working on '
        '2027-01-06 (43 days left)',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Migrate'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('gpt-4o-mini-tts → gpt-realtime-2.1-mini'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Migrate'), findsNothing);
  });
}
