// Neiroha-RVC voice conversion. Offline cases replay the recorded server
// contract on loopback; live cases run when RVC_URL answers `/health`:
//
//   set -a; source .env; set +a   # RVC_URL=http://hedt:19001
//   TTS_TEST_OUT_DIR=/tmp/rvc flutter test scripts/tests/rvc_voice_converter_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/protocols/audio/wav_utils.dart';
import 'package:neiroha/data/ai/providers/local/rvc/rvc_client.dart';
import 'package:neiroha/data/ai/providers/local/rvc/rvc_plugin.dart';
import 'package:neiroha/data/ai/providers/local/rvc/tts/rvc_adapter.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/synthesis/voice_chain_runner.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/synthesis/voice_chain.dart';
import 'package:path/path.dart' as p;

// Recorded `/api/rvc/catalog` (trimmed).
const _catalog = {
  'models': [
    {'id': 'kiki-v1', 'name': 'kikiV1', 'available': true},
    {'id': 'zhanzhan-v2', 'name': 'zhanzhanv2-xi', 'available': true},
    {'id': 'broken', 'name': 'broken', 'available': false},
  ],
  'voices': [
    {'id': 'kikiV1', 'name': 'kikiV1', 'model': 'kiki-v1', 'has_index': false},
    {
      'id': 'zhanzhanv2-xi',
      'name': 'zhanzhanv2-xi',
      'model': 'zhanzhan-v2',
      'has_index': true,
    },
  ],
};

Uint8List _pcm(int samples) {
  final out = Int16List(samples);
  for (var i = 0; i < samples; i++) {
    out[i] = (i * 37 % 2000) - 1000;
  }
  return out.buffer.asUint8List();
}

Uint8List _source() => wrapPcmAsWav(_pcm(72000), sampleRate: 48000);

/// Multipart text fields of a request body (binary-safe).
Map<String, String> _fields(String body) => {
  for (final m in RegExp(
    r'name="([^"]+)"\r\n\r\n([^\r]*)\r\n',
  ).allMatches(body))
    m.group(1)!: m.group(2)!,
};

class _Fake {
  final calls = <(String, Map<String, String>)>[];
  late HttpServer server;
  String get url => 'http://${server.address.address}:${server.port}/rvc';

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final raw = await request.fold<BytesBuilder>(
        BytesBuilder(),
        (b, c) => b..add(c),
      );
      final body = latin1.decode(raw.takeBytes());
      final r = request.response;
      final fields = _fields(body);
      calls.add((request.uri.path, fields));
      switch (request.uri.path) {
        case '/rvc/health':
          r.headers.contentType = ContentType.json;
          r.write(jsonEncode({'status': 'ok', 'backend': 'neiroha-rvc'}));
        case '/rvc/api/rvc/catalog':
          r.headers.contentType = ContentType.json;
          r.write(jsonEncode(_catalog));
        case '/rvc/api/rvc/convert':
          r.headers.contentType = ContentType('audio', 'wav');
          r.add(wrapPcmAsWav(_pcm(4000), sampleRate: 40000));
        case '/rvc/api/rvc/convert-stream':
          if (fields['voice'] == 'missing') {
            r.statusCode = 404;
            r.headers.contentType = ContentType.json;
            r.write(jsonEncode({'detail': 'Unknown voice'}));
            break;
          }
          r.headers
            ..contentType = ContentType('application', 'octet-stream')
            ..set('x-neiroha-sample-rate', '40000')
            ..set('x-neiroha-channels', '1')
            ..set('x-neiroha-output-format', 'pcm_s16le');
          // Odd-sized writes: frames must still come out whole.
          final pcm = _pcm(4000);
          for (var i = 0; i < pcm.length; i += 1001) {
            r.add(pcm.sublist(i, (i + 1001).clamp(0, pcm.length)));
            await r.flush();
          }
        default:
          r.statusCode = 404;
      }
      await r.close();
    });
  }
}

db.TtsProvider _row(String baseUrl) => db.TtsProvider(
  id: 'rvc-1',
  name: 'RVC',
  adapterType: AdapterType.rvc.name,
  baseUrl: baseUrl,
  apiKey: '',
  defaultModelName: 'auto',
  enabled: true,
  position: 0,
  maxConcurrency: 1,
);

Future<({TtsAudioFormat format, Uint8List pcm})> _collect(
  Stream<TtsEvent> events,
) async {
  TtsAudioFormat? format;
  final bytes = BytesBuilder();
  var completed = false;
  await for (final e in events) {
    switch (e) {
      case TtsAudioStarted():
        expect(e.format.encoding, AudioEncoding.pcmS16le);
        format = e.format;
      case TtsAudioChunk():
        expect(e.bytes.length.isEven, isTrue, reason: 'whole PCM frames');
        bytes.add(e.bytes);
      case TtsSynthesisCompleted():
        completed = true;
    }
  }
  expect(completed, isTrue);
  return (format: format!, pcm: bytes.takeBytes());
}

Future<String?> _liveSkip(String? url) async {
  if (url == null || url.trim().isEmpty) return 'RVC_URL not set';
  try {
    final ok = await RvcClient(baseUrl: url).health();
    return ok ? null : 'RVC at $url is not a healthy neiroha-rvc server';
  } on DioException catch (e) {
    return 'RVC unreachable (${e.type.name})';
  }
}

Future<void> main() async {
  final liveUrl = Platform.environment['RVC_URL'];
  final liveSkip = await _liveSkip(liveUrl);
  final outDir = Platform.environment['TTS_TEST_OUT_DIR'];

  group('offline', () {
    final fake = _Fake();
    setUpAll(fake.start);
    tearDownAll(() => fake.server.close(force: true));
    setUp(fake.calls.clear);

    test('base URL drops trailing /v1 and defaults to the local port', () {
      expect(RvcClient.rootUrl('http://h:19001/v1/'), 'http://h:19001/');
      expect(RvcClient.rootUrl(''), 'http://127.0.0.1:19001/');
    });

    test('registry: VC-only plugin, never a character voice', () {
      final connection = connectionForProvider(_row(fake.url));
      expect(connection, isA<RvcConnection>());
      expect(connection.capabilities, {AiCapability.vc});
      expect(speaksText('rvc'), isFalse);
      expect(speaksText('irodori'), isTrue);
      final adapter = createAdapter(_row(fake.url));
      expect(adapter, isA<RvcAdapter>());
      expect(
        () => adapter.synthesize(const TtsRequest(text: 'x', voice: 'v')),
        throwsUnsupportedError,
      );
    });

    test('provider editor path: health, models and voices', () async {
      final adapter = createAdapter(_row(fake.url));
      expect(await adapter.healthCheck(), isTrue);
      expect((await adapter.getModels()).map((m) => m.id), [
        'kiki-v1',
        'zhanzhan-v2',
      ]);
      expect(await adapter.getSpeakers(), ['kikiV1', 'zhanzhanv2-xi']);
    });

    test('live discovery lists checkpoints and their voices', () async {
      final c = connectionForProvider(_row(fake.url));
      final models = await discoverModels(c, AiCapability.vc);
      expect(models.map((m) => m.id), ['auto', 'kiki-v1', 'zhanzhan-v2']);
      final live = c as LiveModelDiscovery;
      expect(
        (await live.listVoices(
          AiCapability.vc,
          modelId: 'zhanzhan-v2',
        )).map((v) => v.id),
        ['zhanzhanv2-xi'],
      );
      expect(
        await live.listVoices(AiCapability.vc, modelId: 'auto'),
        hasLength(2),
      );
    });

    test('router resolves the default (auto) converter', () async {
      final router = CapabilityRouter.fromProviders([_row(fake.url)]);
      final routed = router.resolve<VoiceConverter>(AiCapability.vc);
      expect(routed?.model, isA<StreamingVoiceConverter>());
      expect(routed!.model.descriptor.id, 'auto');
    });

    test('auto picks the voice checkpoint; whole-file convert', () async {
      final vc = connectionForProvider(_row(fake.url)).voiceConverter()!;
      final r = await vc.convert(
        AudioInput(_source()),
        targetVoice: 'zhanzhanv2-xi [zhanzhanv2-xi]',
      );
      final wav = parsePcmWav(r.audioBytes);
      expect(wav.sampleRate, 40000);
      final convert = fake.calls.last;
      expect(convert.$1, '/rvc/api/rvc/convert');
      expect(convert.$2['model'], 'zhanzhan-v2');
      expect(convert.$2['voice'], 'zhanzhanv2-xi');
    });

    test('explicit checkpoint skips the catalog lookup', () async {
      final vc = connectionForProvider(
        _row(fake.url),
      ).voiceConverter('kiki-v1')!;
      await vc.convert(AudioInput(_source()), targetVoice: 'kikiV1');
      expect(fake.calls.map((c) => c.$1), ['/rvc/api/rvc/convert']);
    });

    test(
      'streaming convert yields whole frames with declared layout',
      () async {
        final vc =
            connectionForProvider(_row(fake.url)).voiceConverter()!
                as StreamingVoiceConverter;
        final out = await _collect(
          vc.convertStream(
            AudioInput(_source()),
            targetVoice: 'kikiV1',
            cancellation: TtsCancelToken(),
          ),
        );
        expect(out.format.sampleRate, 40000);
        expect(out.format.channels, 1);
        expect(out.pcm, _pcm(4000));
      },
    );

    test('unknown voice fails before upload; server errors surface', () async {
      final vc = connectionForProvider(_row(fake.url)).voiceConverter()!;
      await expectLater(
        vc.convert(AudioInput(_source()), targetVoice: 'nobody'),
        throwsA(isA<AiProviderException>()),
      );
      final pinned =
          connectionForProvider(_row(fake.url)).voiceConverter('kiki-v1')!
              as StreamingVoiceConverter;
      await expectLater(
        _collect(
          pinned.convertStream(
            AudioInput(_source()),
            targetVoice: 'missing',
            cancellation: TtsCancelToken(),
          ),
        ),
        throwsA(
          isA<AiProviderException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
    });

    test('chain runner converts through RVC', () async {
      final runner = VoiceChainRunner(
        CapabilityRouter.fromProviders([_row(fake.url)]),
      );
      final out = await runner.convertAudio(
        TtsResult(audioBytes: _source(), contentType: 'audio/wav'),
        VoiceChain([
          VoiceChainStep(
            kind: VoiceChainStepKind.convert,
            connectionId: 'rvc-1',
            targetVoice: 'kikiV1',
          ),
        ]),
      );
      expect(parsePcmWav(out.audioBytes).sampleRate, 40000);
    });
  });

  group('live', () {
    RvcConnection connection() =>
        connectionForProvider(_row(liveUrl!)) as RvcConnection;

    test('catalog lists checkpoints with voices', () async {
      final models = await connection().listModels(AiCapability.vc);
      expect(models, isNotEmpty);
      final voices = await connection().listVoices(AiCapability.vc);
      expect(voices, isNotEmpty);
    });

    test('every listed voice converts (whole + stream)', () async {
      final c = connection();
      final catalog = await c.client.catalog();
      for (final voice in catalog.voices.take(3)) {
        final vc = c.voiceConverter()! as StreamingVoiceConverter;
        final whole = await vc.convert(
          AudioInput(_source()),
          targetVoice: voice.id,
        );
        expect(parsePcmWav(whole.audioBytes).pcm, isNotEmpty);
        final clock = Stopwatch()..start();
        Duration? first;
        final stream = vc
            .convertStream(
              AudioInput(_source()),
              targetVoice: voice.id,
              cancellation: TtsCancelToken(),
            )
            .map((e) {
              if (e is TtsAudioChunk) first ??= clock.elapsed;
              return e;
            });
        final out = await _collect(stream);
        expect(out.pcm, isNotEmpty);
        // ignore: avoid_print
        print(
          'RVC ${voice.model}/${voice.id}: ${out.format.sampleRate} Hz, '
          'first audio ${first?.inMilliseconds} ms',
        );
        if (outDir != null && outDir.isNotEmpty) {
          Directory(outDir).createSync(recursive: true);
          File(p.join(outDir, 'rvc-${voice.id}.wav')).writeAsBytesSync(
            wrapPcmAsWav(out.pcm, sampleRate: out.format.sampleRate!),
          );
        }
      }
    });
  }, skip: liveSkip);
}
