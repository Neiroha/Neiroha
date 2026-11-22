import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/core/connection_config.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/providers/elevenlabs/elevenlabs_plugin.dart';
import 'package:neiroha/data/ai/providers/on_device/on_device_plugin.dart';
import 'package:neiroha/data/ai/providers/openai/openai_catalog.dart';
import 'package:neiroha/data/ai/providers/openai/openai_plugin.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';

db.TtsProvider _row(AdapterType type, {bool enabled = true}) => db.TtsProvider(
  id: 'p-${type.name}',
  name: type.displayName,
  adapterType: type.name,
  baseUrl: 'http://127.0.0.1:9',
  apiKey: 'fixture',
  defaultModelName: type.defaultModel,
  enabled: enabled,
  position: 0,
  maxConcurrency: 1,
);

/// Mono PCM16: [ms] of a 440 Hz tone at [amplitude], or silence.
Uint8List _pcm(List<(int, double)> parts, {int rate = 16000}) {
  final out = BytesBuilder();
  for (final (ms, amplitude) in parts) {
    final data = ByteData(rate * ms ~/ 1000 * 2);
    for (var i = 0; i < data.lengthInBytes ~/ 2; i++) {
      final v = amplitude * 32767 * math.sin(2 * math.pi * 440 * i / rate);
      data.setInt16(i * 2, v.round(), Endian.little);
    }
    out.add(data.buffer.asUint8List());
  }
  return out.takeBytes();
}

Future<HttpServer> _serve(Future<void> Function(HttpRequest) handle) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handle);
  addTearDown(() => server.close(force: true));
  return server;
}

String _url(HttpServer s, [String path = '/v1']) =>
    'http://127.0.0.1:${s.port}$path';

void main() {
  group('registry', () {
    test('every adapter type maps to one plugin with TTS', () {
      for (final type in AdapterType.values) {
        if (type == AdapterType.systemTts) continue; // on-device, see below
        final connection = connectionForProvider(_row(type));
        expect(connection.capabilities, contains(AiCapability.tts));
        expect(connection.defaultModel(AiCapability.tts), isNotNull);
        expect(connection.speechModel(), isNotNull, reason: type.name);
      }
    });

    test('on-device capabilities follow the platform', () {
      final windows = OnDevicePlugin(
        platform: const PlatformCapabilities(NeirohaPlatform.windows),
      );
      final web = OnDevicePlugin(
        platform: const PlatformCapabilities(NeirohaPlatform.web),
      );
      expect(windows.capabilities, {AiCapability.vad, AiCapability.tts});
      expect(web.capabilities, {AiCapability.vad});
      expect(
        connectionForProvider(_row(AdapterType.systemTts)).plugin,
        isA<OnDevicePlugin>(),
      );
      final router = CapabilityRouter.fromProviders([
        _row(AdapterType.systemTts),
      ]);
      expect(router.connections.whereType<ProviderConnection>(), hasLength(1));
      expect(
        router.resolve<VoiceActivityDetector>(AiCapability.vad),
        isNotNull,
      );
    });

    test('one OpenAI connection exposes every OpenAI capability', () {
      final openai = connectionForProvider(_row(AdapterType.openaiTts));
      expect(openai.plugin, isA<OpenAiPlugin>());
      expect(openai.capabilities, {
        AiCapability.llm,
        AiCapability.tts,
        AiCapability.stt,
        AiCapability.realtime,
        AiCapability.translate,
      });
      expect(openai.languageModel()?.descriptor.id, 'gpt-6-luna');
      expect(openai.speechModel()?.descriptor.id, 'gpt-realtime-2.1-mini');
      expect(openai.transcriber()?.descriptor.id, 'gpt-transcribe');
      expect(openai.streamingTranscriber('gpt-live-transcribe'), isNotNull);
      expect(openai.transcriber('gpt-live-transcribe'), isNull);
      expect(openai.realtimeModel()?.descriptor.id, 'gpt-realtime-2.1');
      expect(openai.translator()?.descriptor.id, 'gpt-realtime-translate');
      expect(openai.voiceConverter(), isNull);
      expect(openai.vad(), isNull);
    });

    test('catalog labels deprecations and platforms', () {
      final tts1 = openAiCatalog.firstWhere((m) => m.id == 'tts-1');
      expect(tts1.lifecycle, ModelLifecycle.deprecated);
      expect(tts1.shutDownBy(DateTime(2027, 1, 6)), isTrue);
      expect(tts1.shutDownBy(DateTime(2027, 1, 5)), isFalse);
      expect(tts1.replacement, 'gpt-realtime-2.1-mini');
      final whisper = openAiCatalog.firstWhere((m) => m.id == 'whisper-1');
      expect(whisper.shutdownAt, '2027-02-26');
      final translate = openAiCatalog.firstWhere(
        (m) => m.capability == AiCapability.translate,
      );
      expect(translate.platforms, isNot(contains(AiPlatform.web)));
    });

    test('manual model ids get a user-sourced descriptor', () {
      final openai = connectionForProvider(_row(AdapterType.openaiTts));
      final custom = openai.describe(AiCapability.tts, 'gpt-realtime-9');
      expect(custom?.source, DescriptorSource.user);
      expect(custom?.protocol, AiProtocol.openAiRealtime);
      expect(openai.describe(AiCapability.vc, 'x'), isNull);
    });

    test('router resolves defaults, explicit picks and on-device VAD', () {
      final router = CapabilityRouter.fromProviders([
        _row(AdapterType.gptSovits),
        _row(AdapterType.elevenLabs, enabled: false),
        _row(AdapterType.openaiTts),
      ]);
      expect(
        router.resolve<SpeechSynthesizer>(AiCapability.tts)?.connection.id,
        'p-gptSovits',
      );
      expect(
        router.resolve<Transcriber>(AiCapability.stt)?.model.descriptor.id,
        'gpt-transcribe',
      );
      expect(
        router.resolve<VoiceActivityDetector>(AiCapability.vad)?.connection.id,
        OnDevicePlugin.connectionId,
      );
      expect(router.resolve<VoiceConverter>(AiCapability.vc), isNull);
      final picked = router.resolve<SpeechSynthesizer>(
        AiCapability.tts,
        connectionId: 'p-openaiTts',
        modelId: 'gpt-4o-mini-tts',
      );
      expect(picked?.model.descriptor.protocol, AiProtocol.openAiSpeech);
    });
  });

  test('energy VAD finds two utterances and merges padded gaps', () {
    final vad = OnDevicePlugin.builtIn().vad()!;
    final pcm = _pcm([(500, 0), (1000, 0.3), (600, 0), (500, 0.3), (400, 0)]);
    final segments = vad.segments(pcm, sampleRate: 16000);
    expect(segments, hasLength(2));
    expect(segments[0].start.inMilliseconds, closeTo(400, 40));
    expect(segments[0].end.inMilliseconds, closeTo(1600, 40));
    expect(segments[1].start.inMilliseconds, closeTo(2000, 40));
    final merged = vad.segments(
      _pcm([(300, 0.3), (150, 0), (300, 0.3)]),
      sampleRate: 16000,
    );
    expect(merged, hasLength(1));
  });

  test('OpenAI file transcription sends gpt-transcribe multipart', () async {
    late String body;
    final server = await _serve((req) async {
      expect(req.uri.path, '/v1/audio/transcriptions');
      expect(req.headers.value('authorization'), 'Bearer fixture');
      body = await utf8.decoder.bind(req).join();
      req.response.headers.contentType = ContentType.json;
      req.response.write(
        jsonEncode({
          'text': ' bonjour ',
          'languages': [
            {'code': 'fr'},
          ],
        }),
      );
      await req.response.close();
    });
    final openai = const OpenAiPlugin().connect(
      ConnectionConfig(id: 'o', baseUrl: _url(server), apiKey: 'fixture'),
    );
    final result = await openai.transcriber()!.transcribe(
      AudioInput(Uint8List.fromList([1, 2, 3])),
      options: const TranscribeOptions(
        languages: ['fr'],
        keywords: ['Neiroha'],
      ),
    );
    expect(result.text, 'bonjour');
    expect(result.languages, ['fr']);
    expect(body, contains('name="model"\r\n\r\ngpt-transcribe'));
    expect(body, contains('name="languages[]"\r\n\r\nfr'));
    expect(body, contains('name="keywords[]"\r\n\r\nNeiroha'));
    expect(body, isNot(contains('name="language"')));
  });

  test('HTTP errors keep the reason and hide the key', () async {
    final server = await _serve((req) async {
      req.response.statusCode = 401;
      req.response.write('{"error":{"message":"bad key fixture"}}');
      await req.response.close();
    });
    final openai = const OpenAiPlugin().connect(
      ConnectionConfig(id: 'o', baseUrl: _url(server), apiKey: 'fixture'),
    );
    final health = await openai.check();
    expect(health[AiCapability.stt]!.state, HealthState.failed);
    expect(health[AiCapability.stt]!.message, contains('bad key [key]'));
  });

  group('realtime sessions (fake WebSocket)', () {
    Future<(HttpServer, List<Map<String, dynamic>>)> socketServer(
      FutureOr<void> Function(WebSocket ws, Map<String, dynamic> event)
      onEvent, {
      void Function(Uri uri)? onConnect,
    }) async {
      final received = <Map<String, dynamic>>[];
      final server = await _serve((req) async {
        onConnect?.call(req.uri);
        final ws = await WebSocketTransformer.upgrade(req);
        ws.listen((m) async {
          final event = jsonDecode(m as String) as Map<String, dynamic>;
          received.add(event);
          await onEvent(ws, event);
        });
      });
      return (server, received);
    }

    test(
      'streaming transcription commits and returns the final text',
      () async {
        Uri? uri;
        final (server, received) = await socketServer((ws, e) {
          if (e['type'] == 'input_audio_buffer.commit') {
            ws.add(
              jsonEncode({
                'type': 'input_audio_buffer.committed',
                'item_id': 'i1',
              }),
            );
            ws.add(
              jsonEncode({
                'type': 'conversation.item.input_audio_transcription.delta',
                'item_id': 'i1',
                'delta': 'hel',
              }),
            );
            ws.add(
              jsonEncode({
                'type': 'conversation.item.input_audio_transcription.completed',
                'item_id': 'i1',
                'transcript': 'hello',
              }),
            );
          }
        }, onConnect: (u) => uri = u);
        final openai = const OpenAiPlugin().connect(
          ConnectionConfig(id: 'o', baseUrl: _url(server), apiKey: 'fixture'),
        );
        final session = await openai
            .streamingTranscriber('gpt-live-transcribe')!
            .open();
        final events = <AiSessionEvent>[];
        final sub = session.events.listen(events.add);
        session.sendPcm(Uint8List(4800));
        await session.finish(timeout: const Duration(seconds: 5));
        await sub.cancel();
        expect(uri?.path, '/v1/realtime');
        expect(uri?.queryParameters, {'intent': 'transcription'});
        final update = received.first['session'] as Map;
        expect(update['type'], 'transcription');
        expect(
          (update['audio'] as Map)['input']['transcription']['model'],
          'gpt-live-transcribe',
        );
        expect(received[1]['type'], 'input_audio_buffer.append');
        expect(events.whereType<TranscriptDelta>().single.text, 'hel');
        expect(events.whereType<TranscriptFinal>().single.text, 'hello');
      },
    );

    test('translation streams audio and closes with session.closed', () async {
      Uri? uri;
      final (server, received) = await socketServer((ws, e) {
        if (e['type'] == 'session.input_audio_buffer.append') {
          ws.add(
            jsonEncode({
              'type': 'session.input_transcript.delta',
              'delta': 'hi',
            }),
          );
          ws.add(
            jsonEncode({
              'type': 'session.output_transcript.delta',
              'delta': 'hola',
            }),
          );
          ws.add(
            jsonEncode({
              'type': 'session.output_audio.delta',
              'delta': base64Encode([1, 0, 2, 0]),
            }),
          );
        }
        if (e['type'] == 'session.close') {
          ws.add(jsonEncode({'type': 'session.closed'}));
        }
      }, onConnect: (u) => uri = u);
      final openai = const OpenAiPlugin().connect(
        ConnectionConfig(id: 'o', baseUrl: _url(server), apiKey: 'fixture'),
      );
      final session = await openai.translator()!.open(targetLanguage: 'es');
      final events = <AiSessionEvent>[];
      final sub = session.events.listen(events.add);
      session.sendPcm(Uint8List(4800));
      await session.finish(timeout: const Duration(seconds: 5));
      await sub.cancel();
      expect(uri?.path, '/v1/realtime/translations');
      expect(uri?.queryParameters['model'], 'gpt-realtime-translate');
      expect(received.first['session']['audio']['output']['language'], 'es');
      final text = events.whereType<TranscriptDelta>().toList();
      expect(text.map((e) => (e.text, e.source)), [
        ('hi', true),
        ('hola', false),
      ]);
      expect(events.whereType<AudioDelta>().single.pcm, [1, 0, 2, 0]);
      expect(events.last, isA<ResponseDone>());
    });

    test('server error events fail the pending wait', () async {
      final (server, _) = await socketServer((ws, e) {
        if (e['type'] == 'input_audio_buffer.commit') {
          ws.add(
            jsonEncode({
              'type': 'error',
              'error': {
                'code': 'input_audio_buffer_commit_empty',
                'message': 'empty',
              },
            }),
          );
        }
      });
      final openai = const OpenAiPlugin().connect(
        ConnectionConfig(id: 'o', baseUrl: _url(server), apiKey: 'fixture'),
      );
      final session = await openai.realtimeModel()!.connect(
        const RealtimeConfig(),
      );
      unawaited(session.events.drain<void>().catchError((_) {}));
      await expectLater(
        session.finish(timeout: const Duration(seconds: 5)),
        throwsA(
          isA<AiProviderException>().having(
            (e) => e.message,
            'message',
            contains('commit_empty'),
          ),
        ),
      );
    });
  });

  test('ElevenLabs Scribe and speech-to-speech use xi-api-key', () async {
    final paths = <String>[];
    final server = await _serve((req) async {
      paths.add('${req.method} ${req.uri.path}?${req.uri.query}');
      expect(req.headers.value('xi-api-key'), 'fixture');
      final body = await utf8.decoder.bind(req).join();
      if (req.uri.path == '/v1/speech-to-text') {
        expect(body, contains('name="model_id"\r\n\r\nscribe_v2'));
        req.response.headers.contentType = ContentType.json;
        req.response.write(
          jsonEncode({
            'text': 'hi there',
            'language_code': 'en',
            'words': [
              {
                'text': 'hi',
                'start': 0.1,
                'end': 0.3,
                'type': 'word',
                'speaker_id': 's0',
              },
              {'text': ' ', 'start': 0.3, 'end': 0.35, 'type': 'spacing'},
              {'text': 'there', 'start': 0.35, 'end': 0.7, 'type': 'word'},
            ],
          }),
        );
      } else {
        expect(
          body,
          contains('name="model_id"\r\n\r\neleven_multilingual_sts_v2'),
        );
        req.response.headers.contentType = ContentType('audio', 'mpeg');
        req.response.add([73, 68, 51, 1]);
      }
      await req.response.close();
    });
    final eleven = const ElevenLabsPlugin().connect(
      ConnectionConfig(id: 'e', baseUrl: _url(server, ''), apiKey: 'fixture'),
    );
    final transcript = await eleven.transcriber()!.transcribe(
      AudioInput(Uint8List(8)),
      options: const TranscribeOptions(wordTimestamps: true),
    );
    expect(transcript.text, 'hi there');
    expect(transcript.words.map((w) => w.text), ['hi', 'there']);
    expect(transcript.words.first.speaker, 's0');
    expect(transcript.words.last.end, const Duration(milliseconds: 700));
    final converted = await eleven.voiceConverter()!.convert(
      AudioInput(Uint8List(8)),
      targetVoice: 'voice 1',
    );
    expect(converted.contentType, 'audio/mpeg');
    expect(
      paths.last,
      'POST /v1/speech-to-speech/voice%201?output_format=mp3_44100_128',
    );
  });
}
