// Limits and routing that must hold for every caller: the capability
// switch, rate accounting of chain sentences, look-ahead bounded by the
// listener, models added to catalog-less connections, defaults of deleted
// connections, and job events read by a slow client.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/ai/protocols/audio/wav_utils.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/synthesis/sentence_speech_pipeline.dart';
import 'package:neiroha/data/services/synthesis/synthesis_service.dart';
import 'package:neiroha/data/services/synthesis/voice_chain_runner.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/synthesis/voice_chain.dart';
import 'package:neiroha/server/jobs/speech_job_store.dart';

import 'support/novel_fixture.dart';

db.TtsProvider _row(String id, AdapterType type) => db.TtsProvider(
  id: id,
  name: id,
  adapterType: type.name,
  baseUrl: 'http://127.0.0.1:9/v1',
  apiKey: 'k',
  defaultModelName: type.defaultModel,
  enabled: true,
  position: 0,
  maxConcurrency: 1,
);

const _pcm24k = TtsAudioStarted(
  TtsAudioFormat(AudioEncoding.pcmS16le, sampleRate: 24000, channels: 1),
);

/// Loud enough to survive a silence trim.
Uint8List _loud(int samples) =>
    Int16List.fromList(List.filled(samples, 8000)).buffer.asUint8List();

class _Tts extends TtsAdapter {
  final spoken = <String>[];
  @override
  bool get supportsStreaming => true;
  @override
  Stream<TtsEvent> synthesizeStream(
    TtsRequest request, {
    required TtsCancelToken cancellation,
  }) async* {
    spoken.add(request.text);
    yield _pcm24k;
    yield TtsAudioChunk(_loud(4800));
    yield const TtsSynthesisCompleted();
  }

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    spoken.add(request.text);
    return TtsResult(
      audioBytes: wrapPcmAsWav(_loud(4800), sampleRate: 24000),
      contentType: 'audio/wav',
    );
  }

  @override
  Future<bool> healthCheck() async => true;
}

/// A converter that only returns MP3 files: without a decoder the chain
/// speaks the whole line as one file.
class _FileVc implements VoiceConverter {
  @override
  ModelDescriptor get descriptor => const ModelDescriptor(
    id: 'vc',
    capability: AiCapability.vc,
    protocol: AiProtocol.native,
  );
  @override
  Future<TtsResult> convert(
    AudioInput audio, {
    required String targetVoice,
    TtsCancelToken? cancellation,
  }) async => TtsResult(
    audioBytes: Uint8List.fromList([73, 68, 51, 4, 0, 0]),
    contentType: 'audio/mpeg',
  );
}

class _VcRunner extends VoiceChainRunner {
  _VcRunner() : super(CapabilityRouter(const []));
  @override
  VoiceConverter converter(VoiceChainStep step) => _FileVc();
}

void main() {
  test('a switched-off capability refuses work bound to it', () async {
    final queue = TtsQueueService.instance;
    addTearDown(() => queue.setCapabilityLimits(const []));
    queue.setCapabilityLimits([
      const db.ConnectionCapability(
        connectionId: 'off',
        capability: 'tts',
        enabled: false,
      ),
    ]);
    var ran = false;
    await expectLater(
      queue.enqueue(
        provider: _row('off', AdapterType.openaiTts),
        task: () async => ran = true,
      ),
      throwsA(isA<AiProviderException>()),
    );
    expect(ran, isFalse);
    // Other capabilities of the connection still run.
    expect(
      await queue.enqueue(
        provider: _row('off', AdapterType.openaiTts),
        capability: AiCapability.llm,
        task: () async => 'ok',
      ),
      'ok',
    );
  });

  test('every chain request is accounted as it is sent', () async {
    final tts = _Tts();
    final accounted = <String>[];
    final chained = ChainedTtsAdapter(
      tts,
      const VoiceChain([VoiceChainStep(kind: VoiceChainStepKind.trim)]),
      VoiceChainRunner(CapabilityRouter(const [])),
      beforeRequest: (r, _) async => accounted.add(r.text),
    );
    await chained
        .synthesizeStream(
          const TtsRequest(text: '一。二。三。', voice: 'v'),
          cancellation: TtsCancelToken(),
        )
        .drain<void>();
    // Every request is accounted with the text it sends, however the
    // splitter joined the sentences.
    expect(tts.spoken.length, greaterThan(1));
    expect(accounted, tts.spoken);
  });

  test(
    'a chained task is counted per request, not again at its lease',
    () async {
      final queue = TtsQueueService.instance;
      queue.voiceChains = (adapter, request, {beforeRequest}) async =>
          ChainedTtsAdapter(
            adapter,
            const VoiceChain([VoiceChainStep(kind: VoiceChainStepKind.trim)]),
            VoiceChainRunner(CapabilityRouter(const [])),
            beforeRequest: beforeRequest,
          );
      queue.hasVoiceChain = (_) async => true;
      addTearDown(
        () => queue
          ..voiceChains = null
          ..hasVoiceChain = null,
      );
      // One request a minute: counting the lease too would make the chain's
      // only request wait for the next minute.
      final provider = _row(
        'rpm-one',
        AdapterType.openaiTts,
      ).copyWith(requestsPerMinute: const Value(1));
      final result = await SynthesisService(queue)
          .collectInMemory(
            provider: provider,
            request: const TtsRequest(
              text: '一句。',
              voice: 'v',
              voiceAssetId: 'a',
            ),
            cancellation: TtsCancelToken(),
            adapter: _Tts(),
          )
          .timeout(const Duration(seconds: 5));
      expect(result.audioBytes, isNotEmpty);
    },
  );

  test('a chain switched on while queued leaves the task as planned', () async {
    final queue = TtsQueueService.instance;
    var wrapped = 0;
    queue.voiceChains = (adapter, request, {beforeRequest}) async {
      wrapped++;
      return ChainedTtsAdapter(
        adapter,
        const VoiceChain([VoiceChainStep(kind: VoiceChainStepKind.trim)]),
        VoiceChainRunner(CapabilityRouter(const [])),
        beforeRequest: beforeRequest,
      );
    };
    // No chain when admitted; the hook would chain it by start time.
    queue.hasVoiceChain = (_) async => false;
    addTearDown(
      () => queue
        ..voiceChains = null
        ..hasVoiceChain = null,
    );
    final provider = _row(
      'rpm-planned',
      AdapterType.openaiTts,
    ).copyWith(requestsPerMinute: const Value(1));
    final tts = _Tts();
    await SynthesisService(queue)
        .collectInMemory(
          provider: provider,
          request: const TtsRequest(
            text: '一。二。',
            voice: 'v',
            voiceAssetId: 'a',
          ),
          cancellation: TtsCancelToken(),
          adapter: tts,
        )
        .timeout(const Duration(seconds: 5));
    expect(wrapped, 0);
    expect(tts.spoken, ['一。二。']);
  });

  test('a chain decision is asked only once the task is accepted', () async {
    var asked = false;
    await expectLater(
      TtsQueueService.instance.enqueue(
        provider: _row('asked', AdapterType.openaiTts),
        cancelToken: TtsCancelToken()..cancel(),
        selfAccounting: () async {
          asked = true;
          throw StateError('database closed');
        },
        task: () async {},
      ),
      throwsA(isA<TtsCancelledException>()),
    );
    expect(asked, isFalse);
  });

  test('a chain without room yet lets interactive work through', () async {
    final queue = TtsQueueService.instance;
    final provider = _row(
      'tpm-ten',
      AdapterType.openaiTts,
    ).copyWith(tokensPerMinute: const Value(10));
    await queue.enqueue(
      provider: provider,
      estimatedTokens: 8,
      task: () async {},
    );
    final order = <String>[];
    final background = queue.enqueue(
      provider: provider,
      estimatedTokens: 5,
      selfAccounting: () async => true,
      task: () async => order.add('chain'),
    );
    await pumpEventQueue();
    await queue.enqueue(
      provider: provider,
      interactive: true,
      task: () async => order.add('preview'),
    );
    expect(order, ['preview']);
    background.ignore();
  });

  test('raising a limit wakes a request waiting inside a task', () async {
    final queue = TtsQueueService.instance;
    addTearDown(() => queue.setCapabilityLimits(const []));
    final provider = _row(
      'rpm-raise',
      AdapterType.openaiTts,
    ).copyWith(requestsPerMinute: const Value(1));
    final sent = queue.enqueue(
      provider: provider,
      task: () => queue.accountContinuation(
        provider,
        const TtsRequest(text: 'next', voice: 'v'),
        TtsCancelToken(),
      ),
    );
    await pumpEventQueue();
    queue.setCapabilityLimits([
      const db.ConnectionCapability(
        connectionId: 'rpm-raise',
        capability: 'tts',
        enabled: true,
        requestsPerMinute: 5,
      ),
    ]);
    await sent.timeout(const Duration(seconds: 5));
  });

  test('the whole-line fallback is accounted too', () async {
    final tts = _Tts();
    final accounted = <String>[];
    await ChainedTtsAdapter(
          tts,
          const VoiceChain([
            VoiceChainStep(
              kind: VoiceChainStepKind.convert,
              connectionId: 'el',
              targetVoice: 'v',
            ),
          ]),
          _VcRunner(),
          beforeRequest: (r, _) async => accounted.add(r.text),
        )
        .synthesizeStream(
          const TtsRequest(text: '一句。', voice: 'v'),
          cancellation: TtsCancelToken(),
        )
        .drain<void>();
    expect(tts.spoken, ['一句。']);
    expect(accounted, ['一句。']);
  });

  test('a listener that stops reading stops new sentences', () async {
    final started = <String>[];
    final pipeline = SentenceSpeechPipeline(
      speak: (s, _) async* {
        started.add(s);
        yield _pcm24k;
        yield TtsAudioChunk(_loud(240));
        yield const TtsSynthesisCompleted();
      },
    );
    final events = pipeline.run(
      Stream.fromIterable([for (var i = 0; i < 20; i++) '$i。']),
      cancellation: TtsCancelToken(),
    );
    final first = Completer<void>();
    late StreamSubscription<TtsEvent> sub;
    sub = events.listen((e) {
      if (e is TtsAudioChunk && !first.isCompleted) {
        sub.pause();
        first.complete();
      }
    });
    await first.future;
    await pumpEventQueue();
    // The sentence being read plus one look-ahead (lookahead: 1).
    expect(started.length, lessThanOrEqualTo(2));
    await sub.cancel();
  });

  group('routing', () {
    final compatible = connectionForProvider(
      _row('compat', AdapterType.openaiCompatible),
    );
    const whisper = ModelDescriptor(
      id: 'whisper-1',
      capability: AiCapability.stt,
      protocol: AiProtocol.openAiTranscription,
    );

    test('a model added to a catalog-less connection is routed', () {
      final router = CapabilityRouter(
        [compatible],
        extraModels: {
          'compat': [whisper],
        },
      );
      final routed = router.resolve<Transcriber>(AiCapability.stt);
      expect(routed?.connection.id, 'compat');
      expect(routed?.model.descriptor.id, 'whisper-1');
    });

    test('a default left by a deleted connection falls back', () {
      final router = CapabilityRouter(
        [compatible],
        defaults: {AiCapability.stt: ('gone', 'whisper-1')},
        extraModels: {
          'compat': [whisper],
        },
      );
      expect(
        router.resolve<Transcriber>(AiCapability.stt)?.connection.id,
        'compat',
      );
      // An explicit pick of a missing connection still fails.
      expect(
        router.resolve<Transcriber>(AiCapability.stt, connectionId: 'gone'),
        isNull,
      );
    });

    test('a default on a disabled connection stays unavailable', () {
      final router = CapabilityRouter(
        [compatible],
        knownConnectionIds: {'compat', 'local-off'},
        defaults: {AiCapability.stt: ('local-off', 'whisper-1')},
        extraModels: {
          'compat': [whisper],
        },
      );
      // Turning off a local service must not move its audio elsewhere.
      expect(router.resolve<Transcriber>(AiCapability.stt), isNull);
    });

    test('deleting a connection deletes its defaults and rows', () async {
      final database = db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final provider = (await database.getAllProviders()).first;
      await database.setCapabilityDefault('stt', (provider.id, 'whisper-1'));
      await database.upsertConnectionCapability(
        db.ConnectionCapabilitiesCompanion.insert(
          connectionId: provider.id,
          capability: 'stt',
          enabled: const Value(false),
        ),
      );
      await database.deleteProvider(provider.id);
      expect(await database.getCapabilityDefaults(), isEmpty);
      expect(await database.getConnectionCapabilities(), isEmpty);
    });
  });

  test('new novel audio of unknown length clears the old duration', () async {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await seedNovelFixture(database);
    var segment = (await database.getNovelSegments('book')).first;
    await database.completeNovelAudio(
      segment,
      path: '/a.wav',
      cacheKey: 'k1',
      duration: 2.5,
    );
    segment = (await database.getNovelSegments('book')).first;
    await database.completeNovelAudio(segment, path: '/b.mp3', cacheKey: 'k2');
    segment = (await database.getNovelSegments('book')).first;
    expect(segment.audioPath, '/b.mp3');
    expect(segment.audioDuration, isNull);
  });

  test('audio half written before a quit is removed on open', () async {
    final dir = await Directory.systemTemp.createTemp('neiroha_jobs');
    addTearDown(() => dir.delete(recursive: true));
    final part = File('${dir.path}/job.audio.2.part')..writeAsBytesSync([1]);
    await SpeechJobStore(dir, run: (_, _) => throw StateError('unused')).open();
    expect(part.existsSync(), isFalse);
  });

  test('a paused job listener still receives the final state', () async {
    final dir = await Directory.systemTemp.createTemp('neiroha_jobs');
    addTearDown(() => dir.delete(recursive: true));
    final done = Completer<TtsResult>();
    final store = SpeechJobStore(dir, run: (_, _) => done.future);
    await store.open();
    final job = await store.create({'input': 'hi', 'voice': 'v'});
    final seen = <SpeechJobStatus>[];
    final sub = store.watch(job.id).listen((j) => seen.add(j.status));
    sub.pause();
    done.complete(
      TtsResult(audioBytes: Uint8List(3), contentType: 'audio/wav'),
    );
    await pumpEventQueue();
    expect(store[job.id]!.status, SpeechJobStatus.succeeded);
    sub.resume();
    await pumpEventQueue();
    expect(seen, [SpeechJobStatus.running, SpeechJobStatus.succeeded]);
    await sub.cancel();
  });
}
