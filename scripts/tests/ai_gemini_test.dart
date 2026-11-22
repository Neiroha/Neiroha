import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/protocols/gemini/gemini_live_session.dart';
import 'package:neiroha/data/ai/providers/gemini/gemini_connection.dart';
import 'package:neiroha/data/ai/providers/gemini/gemini_endpoint.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';

GeminiConnection _gemini(String baseUrl) =>
    connectionForProvider(
          db.TtsProvider(
            id: 'g',
            name: 'Gemini',
            adapterType: AdapterType.geminiTts.name,
            baseUrl: baseUrl,
            apiKey: 'fixture',
            defaultModelName: AdapterType.geminiTts.defaultModel,
            enabled: true,
            position: 0,
            maxConcurrency: 1,
          ),
        )
        as GeminiConnection;

Map setupOf(List<Map<String, dynamic>> live) => live.first['setup'] as Map;

void main() {
  test('endpoint normalises AI Studio URLs and builds the Live URI', () {
    for (final raw in [
      '',
      'https://generativelanguage.googleapis.com/v1beta',
      'https://generativelanguage.googleapis.com/v1beta/openai/',
    ]) {
      expect(
        GeminiEndpoint(raw, 'k').baseUrl,
        'https://generativelanguage.googleapis.com/',
      );
    }
    final live = GeminiEndpoint('', 'k').liveUri;
    expect(live.scheme, 'wss');
    expect(live.path, endsWith('GenerativeService.BidiGenerateContent'));
    expect(live.queryParameters['key'], 'k');
  });

  test('one key mounts every Gemini capability', () {
    final g = _gemini('https://generativelanguage.googleapis.com');
    expect(g.capabilities, {
      AiCapability.tts,
      AiCapability.llm,
      AiCapability.stt,
      AiCapability.realtime,
      AiCapability.translate,
    });
    expect(g.languageModel()!.descriptor.id, 'gemini-3.8-flash');
    expect(g.transcriber()!.descriptor.id, 'gemini-3.5-transcribe');
    expect(g.streamingTranscriber('gemini-3.5-transcribe-live'), isNotNull);
    expect(g.realtimeModel()!.voices, contains('Kore'));
    expect(g.translator(), isNotNull);
    final flash = g.languageModel()!.descriptor.llm!;
    expect(flash.reasoning!.defaultLevel, ReasoningEffort.medium);
    expect(flash.reasoning!.canDisable, isFalse);
    expect(flash.accepts(Modality.video), isTrue);
    expect(
      g.describe(AiCapability.stt, 'gemini-9-transcribe-live')!.protocol,
      AiProtocol.geminiLive,
    );
  });

  group('fake AI Studio', () {
    late HttpServer server;
    final rest = <(String, String?, Map<String, dynamic>)>[];
    final live = <Map<String, dynamic>>[];
    late String liveKey;
    setUp(() async {
      rest.clear();
      live.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        if (WebSocketTransformer.isUpgradeRequest(req)) {
          liveKey = req.uri.queryParameters['key'] ?? '';
          final ws = await WebSocketTransformer.upgrade(req);
          void reply(Map<String, Object?> m) =>
              ws.add(utf8.encode(jsonEncode(m))); // binary JSON frames
          ws.listen((raw) {
            final m = jsonDecode(raw as String) as Map<String, dynamic>;
            live.add(m);
            final input = m['realtimeInput'] as Map?;
            if (m.containsKey('setup')) {
              reply({'setupComplete': {}});
            } else if (setupOf(live)['generationConfig']['translationConfig'] !=
                null) {
              if (input?['audio'] != null && live.length == 2) {
                reply({
                  'serverContent': {
                    'inputTranscription': {'text': 'Good morning.'},
                  },
                });
                reply({
                  'serverContent': {
                    'outputTranscription': {'text': '早上好。'},
                  },
                });
                reply({
                  'serverContent': {
                    'modelTurn': {
                      'parts': [
                        {
                          'inlineData': {
                            'data': base64Encode(
                              Uint8List(480)..fillRange(0, 480, 0x40),
                            ),
                          },
                        },
                      ],
                    },
                  },
                });
              }
            } else if (setupOf(
                  live,
                )['generationConfig']['responseModalities'].first ==
                'TEXT') {
              // gemini-3.5-transcribe-live: cumulative interim, one final,
              // generationComplete instead of turnComplete.
              if (input?['activityEnd'] != null) {
                for (final t in ['hello', 'hello there']) {
                  reply({
                    'serverContent': {
                      'interimInputTranscription': {'text': t},
                    },
                  });
                }
                reply({
                  'serverContent': {
                    'inputTranscription': {'text': 'Hello there.'},
                  },
                });
                reply({
                  'serverContent': {'generationComplete': true},
                });
              }
            } else if (input?['activityEnd'] != null ||
                input?['text'] != null) {
              reply({
                'serverContent': {
                  'inputTranscription': {'text': 'hello '},
                },
              });
              reply({
                'serverContent': {
                  'inputTranscription': {'text': 'there'},
                },
              });
              reply({
                'serverContent': {
                  'modelTurn': {
                    'parts': [
                      {
                        'inlineData': {
                          'mimeType': 'audio/pcm;rate=24000',
                          'data': base64Encode(Uint8List(480)),
                        },
                      },
                    ],
                  },
                  'outputTranscription': {'text': 'Hi, commander.'},
                },
              });
              reply({
                'serverContent': {'turnComplete': true},
                'usageMetadata': {'totalTokenCount': 7},
              });
            }
          });
          return;
        }
        final body = await utf8.decoder.bind(req).join();
        rest.add((
          req.uri.path,
          req.headers.value('x-goog-api-key'),
          body.isEmpty ? {} : jsonDecode(body) as Map<String, dynamic>,
        ));
        req.response.headers.contentType = ContentType.json;
        if (req.uri.path.endsWith(':generateContent')) {
          final schema =
              (rest.last.$3['generationConfig'] as Map)['responseJsonSchema'];
          req.response.write(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'role': 'model',
                    'parts': [
                      {'text': 'thinking…', 'thought': true},
                      {
                        'text': schema == null
                            ? 'Red and blue.'
                            : '{"speaker":"Alice"}',
                        'thoughtSignature': 'sig',
                      },
                    ],
                  },
                  'finishReason': 'STOP',
                },
              ],
              'usageMetadata': {'totalTokenCount': 12},
            }),
          );
        } else if (req.uri.path.endsWith('/interactions')) {
          req.response.write(
            jsonEncode({
              'status': 'completed',
              'steps': [
                {
                  'type': 'model_output',
                  'content': [
                    {
                      'type': 'text',
                      'text': 'Good morning.',
                      'annotations': [
                        {
                          'type': 'word_info',
                          'text': 'Good',
                          'speaker': 'A',
                          'start_offset': '0.100s',
                          'end_offset': '0.400s',
                        },
                      ],
                    },
                  ],
                },
              ],
            }),
          );
        } else {
          req.response.statusCode = 404;
        }
        await req.response.close();
      });
    });
    tearDown(() => server.close(force: true));

    GeminiConnection connection() => _gemini('http://127.0.0.1:${server.port}');

    test('generateContent: system, roles, thinking parts and schema', () async {
      final llm = connection().languageModel()!;
      final reply = await llm.complete(const [
        LlmChatMessage(role: 'system', content: 'Be brief.'),
        LlmChatMessage(role: 'user', content: 'Colours?'),
        LlmChatMessage(role: 'assistant', content: 'Which?'),
        LlmChatMessage(role: 'user', content: 'Two.'),
      ]);
      expect(reply, 'Red and blue.'); // thought part dropped
      final (path, key, body) = rest.single;
      expect(path, '/v1beta/models/gemini-3.8-flash:generateContent');
      expect(key, 'fixture');
      expect(body['systemInstruction']['parts'][0]['text'], 'Be brief.');
      expect((body['contents'] as List).map((c) => c['role']), [
        'user',
        'model',
        'user',
      ]);
      final result = await llm.structured(
        const [LlmChatMessage(role: 'user', content: 'who?')],
        schemaName: 'speaker',
        schema: const {'type': 'object'},
      );
      expect(result.object['speaker'], 'Alice');
      expect(result.finishReason, 'stop');
      final config = rest.last.$3['generationConfig'] as Map;
      expect(config['responseMimeType'], 'application/json');
      expect(config['responseJsonSchema'], {'type': 'object'});
    });

    test('Interactions transcription with diarized word timings', () async {
      final t = await connection().transcriber()!.transcribe(
        AudioInput(Uint8List(8)),
        options: const TranscribeOptions(
          languages: ['en'],
          diarize: true,
          wordTimestamps: true,
          keywords: ['Neiroha'],
        ),
      );
      expect(t.text, 'Good morning.');
      expect(t.words.single.speaker, 'A');
      expect(t.words.single.start, const Duration(milliseconds: 100));
      final cfg = rest.single.$3['generation_config']['transcription_config'];
      expect(cfg['language_codes'], ['en']);
      expect(cfg['mode'], {
        'type': 'verbatim',
        'diarization_mode': 'speaker',
        'timestamp_granularities': ['word'],
      });
      expect(cfg.containsKey('custom_vocabulary'), isFalse); // incompatible
    });

    test('Live conversation: manual turn → transcript, audio, reply', () async {
      final session = await connection().realtimeModel()!.connect(
        const RealtimeConfig(
          instructions: 'You are Nagato.',
          voice: 'Kore',
          transcribeInput: true,
        ),
      );
      final events = <AiSessionEvent>[];
      session.events.listen(events.add);
      expect(liveKey, 'fixture');
      final setup = live.first['setup'] as Map;
      expect(setup['model'], 'models/gemini-3.8-live');
      expect(
        setup['realtimeInputConfig']['automaticActivityDetection']['disabled'],
        isTrue,
      );
      expect(
        setup['generationConfig']['speechConfig']['voiceConfig']['prebuiltVoiceConfig']['voiceName'],
        'Kore',
      );
      session.sendPcm(Uint8List(320));
      session.sendPcm(Uint8List(320));
      await session.finish();
      await pumpEventQueue();
      final sent = live
          .skip(1)
          .map((m) => (m['realtimeInput'] as Map).keys.single);
      expect(sent, ['activityStart', 'audio', 'audio', 'activityEnd']);
      expect(events.whereType<TranscriptFinal>().single.text, 'hello there');
      expect(
        events.indexWhere((e) => e is TranscriptFinal),
        lessThan(events.indexWhere((e) => e is AudioDelta)),
      );
      expect(events.whereType<AudioDelta>().single.sampleRate, 24000);
      expect(events.whereType<ResponseDone>().single.text, 'Hi, commander.');
      session.sendText('again');
      final done = await session.respond();
      expect(done.text, 'Hi, commander.');
      await session.close();
    });

    test('Live streaming transcription returns the final text', () async {
      final session = await connection()
          .streamingTranscriber('gemini-3.5-transcribe-live')!
          .open(options: const TranscribeOptions(languages: ['en']));
      final events = <AiSessionEvent>[];
      session.events.listen(events.add);
      final setup = live.first['setup'] as Map;
      expect(setup['generationConfig']['responseModalities'], ['TEXT']);
      expect(setup['inputAudioTranscription']['languageCodes'], ['en']);
      session.sendPcm(Uint8List(320));
      await session.finish();
      await pumpEventQueue();
      expect(events.whereType<TranscriptDelta>().map((e) => e.text), [
        'hello',
        ' there',
      ]);
      expect(events.whereType<TranscriptFinal>().single.text, 'Hello there.');
      await session.close();
    });

    test('Live translation streams both transcripts and settles', () async {
      final session = await connection().translator()!.open(
        targetLanguage: 'zh-Hans',
      );
      final events = <AiSessionEvent>[];
      session.events.listen(events.add);
      final setup = setupOf(live);
      expect(setup['model'], 'models/gemini-3.5-live-translate-preview');
      expect(setup['generationConfig']['translationConfig'], {
        'targetLanguageCode': 'zh-Hans',
      });
      expect(setup.containsKey('realtimeInputConfig'), isFalse);
      session.sendPcm(Uint8List(320));
      await (session as GeminiLiveSession).finish(
        quiet: const Duration(milliseconds: 300),
        flush: const Duration(milliseconds: 200),
      );
      expect(live.last['realtimeInput'], {'audioStreamEnd': true});
      expect(
        live.where((m) => m['realtimeInput']?['audio'] != null),
        hasLength(3),
      );
      final source = events.whereType<TranscriptDelta>().where((e) => e.source);
      final target = events.whereType<TranscriptDelta>().where(
        (e) => !e.source,
      );
      expect(source.single.text, 'Good morning.');
      expect(target.single.text, '早上好。');
      expect(events.whereType<AudioDelta>(), hasLength(1));
      await session.close();
    });
  });
}
