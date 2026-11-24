import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/conversation/character_live_settings.dart';
import 'package:neiroha/data/services/conversation/conversation_factory.dart';
import 'package:neiroha/data/services/synthesis/voice_chain_runner.dart';
import 'package:neiroha/data/services/voice_character_copy.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/server/mcp/mcp_synthesis.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/synthesis/voice_chain.dart';

const _d = ModelDescriptor(
  id: 'fake',
  capability: AiCapability.llm,
  protocol: AiProtocol.native,
);

final _wav = Uint8List.fromList([82, 73, 70, 70, 0, 0, 0, 0, 87, 65, 86, 69]);

class _Llm implements LanguageModel {
  final prompts = <List<LlmChatMessage>>[];
  @override
  ModelDescriptor get descriptor => _d;
  @override
  Future<String> complete(
    List<LlmChatMessage> messages, {
    TtsCancelToken? cancellation,
    int maxOutputTokens = 4096,
  }) async {
    prompts.add(messages);
    return ' [${prompts.length}] ${messages.last.content} ';
  }

  @override
  Future<LlmStructuredResult> structured(
    List<LlmChatMessage> messages, {
    required String schemaName,
    required Map<String, Object?> schema,
    TtsCancelToken? cancellation,
    int maxOutputTokens = 4096,
  }) => throw UnimplementedError();
}

class _Vc implements VoiceConverter {
  final calls = <(String, String, int)>[];
  @override
  ModelDescriptor get descriptor => _d;
  @override
  Future<TtsResult> convert(
    AudioInput audio, {
    required String targetVoice,
    TtsCancelToken? cancellation,
  }) async {
    calls.add((targetVoice, audio.contentType, audio.bytes.length));
    return TtsResult(
      audioBytes: Uint8List.fromList([73, 68, 51, 4, 0, 0]),
      contentType: 'audio/mpeg',
    );
  }
}

class _Runner extends VoiceChainRunner {
  _Runner() : super(CapabilityRouter(const []));
  final llm = _Llm();
  final vc = _Vc();
  @override
  LanguageModel languageModel(VoiceChainStep step) => llm;
  @override
  VoiceConverter converter(VoiceChainStep step) => vc;
}

class _StreamingLlm extends _Llm implements StreamingLanguageModel {
  final deltas = StreamController<String>();
  @override
  Stream<String> streamText(
    List<LlmChatMessage> messages, {
    required TtsCancelToken cancellation,
    int maxOutputTokens = 4096,
  }) => deltas.stream;
}

class _StreamingRunner extends VoiceChainRunner {
  _StreamingRunner() : super(CapabilityRouter(const []));
  final llm = _StreamingLlm();
  @override
  LanguageModel languageModel(VoiceChainStep step) => llm;
}

class _Tts extends TtsAdapter {
  final requests = <TtsRequest>[];
  @override
  bool get supportsStreaming => true;
  @override
  Stream<TtsEvent> synthesizeStream(
    TtsRequest request, {
    required TtsCancelToken cancellation,
  }) async* {
    requests.add(request);
    yield const TtsAudioStarted(
      TtsAudioFormat(AudioEncoding.pcmS16le, sampleRate: 24000, channels: 1),
    );
    yield TtsAudioChunk(Uint8List(480));
    yield const TtsSynthesisCompleted();
  }

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    requests.add(request);
    return TtsResult(audioBytes: _wav, contentType: 'audio/wav');
  }

  @override
  Future<bool> healthCheck() async => true;
}

const _translate = VoiceChainStep(
  kind: VoiceChainStepKind.translate,
  targetLanguage: 'Japanese',
);
const _convert = VoiceChainStep(
  kind: VoiceChainStepKind.convert,
  connectionId: 'el',
  targetVoice: 'nagato',
);

void main() {
  test('JSON round trip keeps text steps before audio steps', () {
    final chain = VoiceChain.fromJson(
      const VoiceChain([
        _convert,
        _translate,
        VoiceChainStep(kind: VoiceChainStepKind.rewrite, instruction: 'calm'),
      ]).normalized().toJson(),
    );
    expect(chain.steps.map((s) => s.kind), [
      VoiceChainStepKind.translate,
      VoiceChainStepKind.rewrite,
      VoiceChainStepKind.convert,
    ]);
    expect(chain.steps.last.targetVoice, 'nagato');
    expect(
      VoiceChain.fromJson([
        {'kind': 'nope'},
        'x',
      ]).steps,
      isEmpty,
    );
  });

  test('disabled or unconfigured steps do not run', () {
    const chain = VoiceChain([
      VoiceChainStep(kind: VoiceChainStepKind.translate),
      VoiceChainStep(kind: VoiceChainStepKind.convert, targetVoice: 'x'),
      VoiceChainStep(
        kind: VoiceChainStepKind.rewrite,
        instruction: 'calm',
        enabled: false,
      ),
    ]);
    expect(chain.isActive, isFalse);
  });

  test('text steps run in order before streaming TTS', () async {
    final runner = _Runner();
    final tts = _Tts();
    final chained = ChainedTtsAdapter(
      tts,
      const VoiceChain([
        _translate,
        VoiceChainStep(kind: VoiceChainStepKind.rewrite, instruction: 'calm'),
      ]),
      runner,
    );
    // The pipeline streams, but never claims the engine itself does.
    expect(chained.supportsStreaming, isTrue);
    expect(
      chained.streamsAudioFor(
        const TtsRequest(text: '', voice: 'v', responseFormat: 'pcm'),
      ),
      isFalse,
    );
    final events = await chained
        .synthesizeStream(
          const TtsRequest(
            text: 'hello',
            voice: 'v',
            responseFormat: 'pcm',
            voiceAssetId: 'a1',
          ),
          cancellation: TtsCancelToken(),
        )
        .toList();
    expect(events.whereType<TtsAudioChunk>().single.bytes.length, 480);
    expect(tts.requests.single.text, '[2] [1] hello');
    expect(tts.requests.single.voiceAssetId, 'a1');
    final first = runner.llm.prompts.first;
    expect(first.first.content, contains('into Japanese'));
    expect(runner.llm.prompts.last.first.content, startsWith('calm'));
  });

  test(
    'encoded VC output without a decoder falls back to the whole line',
    () async {
      final runner = _Runner();
      final tts = _Tts();
      final chained = ChainedTtsAdapter(
        tts,
        const VoiceChain([_convert]),
        runner,
      );
      const request = TtsRequest(text: 'hi', voice: 'v', responseFormat: 'pcm');
      expect(chained.streamsAudioFor(request), isFalse);
      final events = await chained
          .synthesizeStream(request, cancellation: TtsCancelToken())
          .toList();
      // A file-only converter without a decoder skips sentence streaming.
      expect(tts.requests.map((r) => r.responseFormat), [null]);
      expect(runner.vc.calls.last, ('nagato', 'audio/wav', _wav.length));
      expect(
        (events.first as TtsAudioStarted).format.encoding,
        AudioEncoding.mp3,
      );
      expect(events.last, isA<TtsSynthesisCompleted>());
      expect(runner.llm.prompts, isEmpty);
    },
  );

  test('with a decoder, VC streams sentence by sentence', () async {
    final runner = _Runner();
    final tts = _Tts();
    final decoded = <int>[];
    final chained = ChainedTtsAdapter(
      tts,
      const VoiceChain([_convert]),
      runner,
      decode: (bytes, format) async {
        decoded.add(bytes.length);
        return (pcm: Uint8List(960), sampleRate: 48000, channels: 1);
      },
    );
    final events = await chained
        .synthesizeStream(
          const TtsRequest(text: '第一句。第二句。', voice: 'v', responseFormat: 'pcm'),
          cancellation: TtsCancelToken(),
        )
        .toList();
    expect(tts.requests.map((r) => r.text), ['第一句。', '第二句。']);
    expect(runner.vc.calls, hasLength(2));
    expect(decoded, hasLength(2));
    final started = events.first as TtsAudioStarted;
    expect(started.format.encoding, AudioEncoding.pcmS16le);
    expect(started.format.sampleRate, 48000);
    expect(events.whereType<TtsAudioChunk>(), hasLength(2));
  });

  test('a streamed LLM answer is spoken as each sentence completes', () async {
    final runner = _StreamingRunner();
    final tts = _Tts();
    final chained = ChainedTtsAdapter(
      tts,
      const VoiceChain([_translate]),
      runner,
    );
    final events = <TtsEvent>[];
    final done = chained
        .synthesizeStream(
          const TtsRequest(text: 'hello', voice: 'v', responseFormat: 'pcm'),
          cancellation: TtsCancelToken(),
        )
        .listen(events.add)
        .asFuture<void>();
    runner.llm.deltas.add('こんにちは。');
    runner.llm.deltas.add('今日は');
    await pumpEventQueue();
    // First sentence is already audio while the LLM is still talking.
    expect(tts.requests.map((r) => r.text), ['こんにちは。']);
    expect(events.whereType<TtsAudioChunk>(), hasLength(1));
    runner.llm.deltas.add('いい天気。');
    await runner.llm.deltas.close();
    await done;
    expect(tts.requests.map((r) => r.text), ['こんにちは。', '今日はいい天気。']);
    expect(events.last, isA<TtsSynthesisCompleted>());
  });

  test('companion speech uses the character chain, not the live VC', () {
    final factory = ConversationFactory(
      CapabilityRouter(const []),
      runner: _Runner(),
    );
    const settings = CharacterLiveSettings(
      vcConnectionId: 'el',
      vcVoice: 'live-voice',
    );
    final tts = _Tts();
    // No chain: plain TTS; the live-settings VC applies (when routable).
    expect(factory.voiceThroughChain(tts, VoiceChain.empty), same(tts));
    // A chain that converts replaces the live VC.
    const converting = VoiceChain([_translate, _convert]);
    expect(factory.companionConversion(settings, converting), isNull);
    final wrapped = factory.voiceThroughChain(tts, converting);
    expect(wrapped, isA<ChainedTtsAdapter>());
    expect((wrapped as ChainedTtsAdapter).chain, same(converting));
  });

  test('MCP and API requests name the character unless the chain is off', () {
    const asset = db.VoiceAsset(
      id: 'nagato',
      name: 'Nagato',
      providerId: 'p',
      taskMode: 'presetVoice',
      speed: 1,
      enabled: true,
      loudnessOffsetDb: 0,
    );
    const provider = db.TtsProvider(
      id: 'p',
      name: 'p',
      adapterType: 'openaiTts',
      baseUrl: '',
      apiKey: '',
      defaultModelName: '',
      enabled: true,
      position: 0,
      maxConcurrency: 1,
    );
    expect(
      characterSpeechRequest(asset, provider, 'hi').voiceAssetId,
      'nagato',
    );
    expect(
      characterSpeechRequest(
        asset,
        provider,
        'hi',
        applyChain: false,
      ).voiceAssetId,
      isNull,
    );
  });

  test('duplicating a character copies its chain', () async {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.insertProvider(
      db.TtsProvidersCompanion.insert(
        id: 'p',
        name: 'p',
        adapterType: 'openaiTts',
        baseUrl: '',
      ),
    );
    await database.insertVoiceAsset(
      db.VoiceAssetsCompanion.insert(
        id: 'nagato',
        name: 'Nagato',
        providerId: 'p',
        taskMode: 'presetVoice',
      ),
    );
    await VoiceChainHook.save(
      database,
      'nagato',
      const VoiceChain([_translate]),
    );
    final copy = await duplicateVoiceCharacter(
      database,
      (await database.getVoiceAssetById('nagato'))!,
    );
    expect(copy, isNot('nagato'));
    expect((await VoiceChainHook.load(database, copy)).textSteps, hasLength(1));
  });

  test('hook wraps only characters with an active chain', () async {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await VoiceChainHook.save(
      database,
      'a1',
      const VoiceChain([_convert, _translate]),
    );
    final stored = await VoiceChainHook.load(database, 'a1');
    expect(stored.steps.first.kind, VoiceChainStepKind.translate);
    final hook = VoiceChainHook(database);
    final tts = _Tts();
    const line = TtsRequest(text: 'hi', voice: 'v');
    expect(await hook.wrap(tts, line), same(tts));
    expect(
      await hook.wrap(
        tts,
        const TtsRequest(text: 'hi', voice: 'v', voiceAssetId: 'b'),
      ),
      same(tts),
    );
    expect(
      await hook.wrap(
        tts,
        const TtsRequest(text: 'hi', voice: 'v', voiceAssetId: 'a1'),
      ),
      isA<ChainedTtsAdapter>(),
    );
  });
}
