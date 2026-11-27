import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/providers/azure_speech/tts/azure_tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/data/services/synthesis/browser_speech_support.dart';
import 'package:neiroha/data/services/synthesis/quick_tts_service.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/quick_tts_panel.dart';
import 'package:neiroha/presentation/widgets/voice_character/character_model_field.dart';
import 'package:neiroha/presentation/widgets/voice_character/quick_tts_playback_setting.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/providers/quick_tts_preferences.dart';

const _web = PlatformCapabilities(NeirohaPlatform.web);
const _desktop = PlatformCapabilities(NeirohaPlatform.windows);
const _provider = TtsProvider(
  id: 'openai',
  name: 'OpenAI',
  adapterType: 'openaiTts',
  baseUrl: '',
  apiKey: '',
  defaultModelName: 'gpt-realtime-2.1-mini',
  enabled: true,
  position: 0,
  maxConcurrency: 1,
);
const _voice = VoiceAsset(
  id: 'role',
  name: 'Narrator',
  providerId: 'openai',
  taskMode: 'presetVoice',
  presetVoiceName: 'Nova [nova]',
  speed: 1,
  enabled: true,
  loudnessOffsetDb: 0,
);
const _realtime = ['gpt-realtime-2.1', 'gpt-realtime-2.1-mini'];

void main() {
  for (final model in _realtime) {
    test('Web blocks explicit $model while desktop can still stream it', () {
      final voice = _voice.copyWith(modelName: Value(model));
      expect(browserSpeechModel(_provider, model), model);
      expect(
        browserSpeechBlockForVoice(_provider, voice),
        BrowserSpeechBlock.realtime,
      );
      expect(supportsQuickTtsStreaming(_provider, voice, _web), isFalse);
      expect(supportsQuickTtsStreaming(_provider, voice, _desktop), isTrue);
    });
  }

  test('Web routes inherited OpenAI defaults to Speech and hides Realtime', () {
    const speech = browserDefaultOpenAiSpeechModel;
    expect(defaultSpeechModelForPlatform(AdapterType.openaiTts, _web), speech);
    expect(
      defaultSpeechModelForPlatform(AdapterType.openaiTts, _desktop),
      _realtime.last,
    );
    for (final inherited in [null, '', 'default']) {
      expect(browserSpeechModel(_provider, inherited), speech);
    }
    expect(
      browserSpeechModels(_provider, [
        ..._realtime,
        'default',
        'tts-1',
        'tts-1',
      ]),
      [speech, 'tts-1'],
    );
    final fallback = browserSpeechModels(_provider, _realtime);
    expect(fallback, contains(speech));
    expect(fallback.where(_realtime.contains), isEmpty);
    expect(
      browserSpeechModel(
        _provider.copyWith(defaultModelName: 'tts-1-hd'),
        null,
      ),
      'tts-1-hd',
    );
  });

  test('Web streams Speech snapshots and preserves custom voices', () {
    const snapshot = 'gpt-4o-mini-tts-2025-12-15';
    final voice = _voice.copyWith(modelName: const Value(snapshot));
    expect(browserSpeechModel(_provider, snapshot), snapshot);
    expect(browserSpeechBlockForVoice(_provider, voice), isNull);
    expect(supportsQuickTtsStreaming(_provider, voice, _web), isTrue);
    expect(browserOpenAiVoiceId(voice.presetVoiceName, voice.name), 'nova');
    expect(browserOpenAiVoiceId('', 'voice_custom'), 'voice_custom');
    final options = browserOpenAiVoiceOptions('tts-1', [
      'Marin [marin]',
      'Custom [voice_123]',
    ]);
    expect(options, contains('Custom [voice_123]'));
    expect(options, isNot(contains('Marin [marin]')));
  });

  test('reports provider, local file and preset problems independently', () {
    BrowserSpeechBlock? block({
      TtsProvider provider = _provider,
      String? localFile,
      String? preset = 'nova',
      String? model,
    }) => browserSpeechBlock(
      provider: provider,
      refAudioPath: localFile,
      presetVoice: preset,
      modelName: model,
      legacyName: _voice.name,
    );
    expect(
      block(provider: _provider.copyWith(enabled: false)),
      BrowserSpeechBlock.providerDisabled,
    );
    expect(
      block(provider: _provider.copyWith(adapterType: 'indexTts')),
      BrowserSpeechBlock.adapterUnavailable,
    );
    expect(
      block(provider: _provider.copyWith(baseUrl: 'ws://localhost')),
      BrowserSpeechBlock.invalidEndpoint,
    );
    expect(block(localFile: 'ref.wav'), BrowserSpeechBlock.localReference);
    expect(block(preset: null), BrowserSpeechBlock.missingVoice);
    expect(
      block(preset: 'marin', model: 'tts-1'),
      BrowserSpeechBlock.incompatibleVoice,
    );
  });

  test('model names only block the protocols that need them', () {
    final compatible = _provider.copyWith(adapterType: 'openaiCompatible');
    final mimo = _provider.copyWith(
      adapterType: 'chatCompletionsTts',
      defaultModelName: 'mimo-v2.5-tts-voiceclone',
    );
    expect(
      browserSpeechBlock(provider: compatible, modelName: _realtime.first),
      isNull,
    );
    expect(
      browserSpeechBlock(provider: mimo, modelName: ''),
      BrowserSpeechBlock.localReference,
    );
  });

  test(
    'Gemini Live is excluded from the TTS picker and rejected by the adapter',
    () async {
      const live = 'gemini-3.8-live';
      final provider = _provider.copyWith(
        adapterType: 'geminiTts',
        defaultModelName: 'gemini-3.8-flash-tts',
      );
      expect(
        browserSpeechBlock(provider: provider, modelName: live),
        BrowserSpeechBlock.geminiLive,
      );
      expect(
        browserSpeechModels(provider, [live]),
        contains('gemini-3.8-flash-tts'),
      );
      expect(browserSpeechModels(provider, [live]), isNot(contains(live)));
      await expectLater(
        createAdapter(
          provider,
          modelName: live,
        ).synthesize(const TtsRequest(text: 'Offline', voice: 'Kore')),
        throwsUnsupportedError,
      );
      expect(
        ttsAdapterSupportsStreaming(provider, 'gemini-2.5-flash-preview-tts'),
        isFalse,
      );
      expect(
        ttsAdapterSupportsStreaming(provider, 'gemini-3.8-flash-lite-tts'),
        isTrue,
      );
    },
  );

  test(
    'Azure validation accepts the same region and endpoint as the adapter',
    () {
      final provider = _provider.copyWith(
        adapterType: 'azureTts',
        baseUrl: 'eastus',
      );
      expect(browserSpeechBlockForVoice(provider, _voice), isNull);
      expect(supportsQuickTtsStreaming(provider, _voice, _web), isTrue);
      expect(
        browserSpeechBlock(provider: provider.copyWith(baseUrl: '')),
        BrowserSpeechBlock.invalidEndpoint,
      );
      expect(
        AzureTtsAdapter.normalizeTtsUrl('eastus'),
        'https://eastus.tts.speech.microsoft.com',
      );
      expect(
        AzureTtsAdapter.normalizeTtsUrl(
          'https://eastus.tts.speech.microsoft.com/cognitiveservices/v1',
        ),
        'https://eastus.tts.speech.microsoft.com',
      );
    },
  );

  test(
    'official MiMo inherits the current default and flags explicit retired models',
    () {
      final provider = _provider.copyWith(
        adapterType: 'chatCompletionsTts',
        baseUrl: 'https://api.xiaomimimo.com/v1',
        defaultModelName: 'mimo-v2-tts',
      );
      expect(browserSpeechModel(provider, null), 'mimo-v2.5-tts');
      expect(ttsAdapterModel(provider, null), 'mimo-v2.5-tts');
      expect(browserSpeechModels(provider, ['mimo-v2-tts']), ['mimo-v2.5-tts']);
      expect(
        browserSpeechBlock(provider: provider, modelName: 'mimo-v2-tts'),
        BrowserSpeechBlock.retiredMiMo,
      );
      expect(ttsAdapterSupportsStreaming(provider, null), isTrue);
      expect(
        ttsAdapterSupportsStreaming(provider, 'mimo-v2.5-tts-voicedesign'),
        isFalse,
      );
      expect(
        ttsAdapterSupportsStreaming(provider, 'mimo-v2.5-tts-voiceclone'),
        isFalse,
      );
      final custom = provider.copyWith(
        baseUrl: 'https://speech.example.com/v1',
      );
      expect(ttsAdapterModel(custom, null), 'mimo-v2-tts');
    },
  );

  test(
    'Realtime at the official endpoint cannot use the generic HTTP adapter',
    () async {
      final provider = _provider.copyWith(
        adapterType: 'openaiCompatible',
        baseUrl: 'https://api.openai.com/v1',
      );
      for (final model in _realtime) {
        expect(
          browserSpeechBlock(provider: provider, modelName: model),
          BrowserSpeechBlock.openAiRealtimeWrongAdapter,
        );
        await expectLater(
          createAdapter(
            provider,
            modelName: model,
          ).synthesize(const TtsRequest(text: 'Offline', voice: 'nova')),
          throwsUnsupportedError,
        );
      }
    },
  );

  testWidgets('narrow model picker lets an existing Web role select Speech', (
    tester,
  ) async {
    final controller = TextEditingController(text: _realtime.first);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            return CharacterModelField(
              controller: controller,
              provider: _provider,
              isWeb: true,
              onChanged: () => setState(() {}),
            );
          },
        ),
      ),
    );
    expect(find.textContaining('Realtime is unavailable'), findsOneWidget);
    expect(tester.getSize(find.byType(CharacterModelField)).width, 320);
    await tester.tap(find.byTooltip('Select Model'));
    await tester.pumpAndSettle();
    expect(find.text(_realtime.last), findsNothing);
    await tester.tap(
      find.widgetWithText(
        PopupMenuItem<String>,
        browserDefaultOpenAiSpeechModel,
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.text, browserDefaultOpenAiSpeechModel);
    expect(find.textContaining('Realtime is unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview shows a compact status and blocks unsupported roles', (
    tester,
  ) async {
    final selected = ValueNotifier(
      _voice.copyWith(modelName: Value(_realtime.first)),
    );
    addTearDown(selected.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformCapabilitiesProvider.overrideWithValue(_web),
          ttsProvidersStreamProvider.overrideWith(
            (ref) => Stream.value([_provider]),
          ),
          quickTtsHistoryStreamProvider.overrideWith((ref) => Stream.value([])),
          quickTtsStreamingProvider.overrideWith(
            (ref, id) => Stream.value(id == _voice.id),
          ),
          playbackNotifierProvider.overrideWith(_SilentPlayback.new),
        ],
        child: _app(
          ValueListenableBuilder(
            valueListenable: selected,
            builder: (_, role, _) =>
                SizedBox(height: 360, child: QuickTtsPanel(asset: role)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Preview');
    await tester.pump();
    final generate = find.widgetWithIcon(
      IconButton,
      Icons.auto_awesome_rounded,
    );
    expect(find.textContaining('Realtime is unavailable'), findsOneWidget);
    expect(tester.widget<IconButton>(generate).onPressed, isNull);
    expect(find.byType(SwitchListTile), findsNothing);
    selected.value = _voice;
    await tester.pumpAndSettle();
    expect(find.text('Prefer streaming'), findsOneWidget);
    expect(tester.widget<IconButton>(generate).onPressed, isNotNull);
    selected.value = _voice.copyWith(id: 'other');
    await tester.pumpAndSettle();
    expect(find.text('Generate full clip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('per-character playback menu fits a narrow settings pane', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quickTtsStreamingProvider.overrideWith(
            (ref, id) => Stream.value(true),
          ),
        ],
        child: _app(const QuickTtsPlaybackSetting(voiceId: 'role')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(PopupMenuButton<bool>)).height,
      lessThan(48),
    );
    await tester.tap(find.byTooltip('Preview playback'));
    await tester.pumpAndSettle();
    expect(find.text('Generate full clip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 320, child: child),
    ),
  ),
);

class _SilentPlayback extends PlaybackNotifier {
  @override
  PlaybackState build() => const PlaybackState();
}
