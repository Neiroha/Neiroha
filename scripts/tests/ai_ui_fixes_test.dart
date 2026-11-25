import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/providers/azure_speech/tts/azure_tts_adapter.dart';
import 'package:neiroha/data/ai/providers/common/adapter_backed_connection.dart';
import 'package:neiroha/data/ai/providers/mimo/mimo_plugin.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/ai/registry/model_badges.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/conversation/character_live_settings.dart';
import 'package:neiroha/data/services/conversation/conversation_factory.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/synthesis/tts_request.dart';

db.TtsProvider _row(String id, AdapterType type, String url) => db.TtsProvider(
  id: id,
  name: id,
  adapterType: type.name,
  baseUrl: url,
  apiKey: 'k',
  defaultModelName: type.defaultModel,
  enabled: true,
  position: 0,
  maxConcurrency: 1,
);

void main() {
  test('model badges: catalog first, then the id', () {
    final gemini = connectionForProvider(_row('g', AdapterType.geminiTts, ''));
    expect(modelBadges('gemini-3.5-transcribe', gemini), ['ASR']);
    expect(modelBadges('gemini-3.8-live', gemini), ['Realtime']);
    expect(modelBadges('lyria-3.5', gemini), ['Music']);
    expect(modelBadges('gemini-3.8-flash', gemini), ['LLM']);
    expect(modelBadges('mimo-v2.5-asr'), ['ASR']);
    expect(modelBadges('whisper-1'), ['ASR']);
    expect(modelBadges('gemini-embedding-002'), ['Embedding']);
    expect(modelBadges('mimo-v2.5'), ['LLM', 'ASR']);
    expect(modelBadges('mimo-v2.6-pro'), ['LLM']);
  });

  test('Azure streams PCM it labels audio/basic', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    String? ssml;
    server.listen((req) async {
      ssml = await req
          .cast<List<int>>()
          .transform(const SystemEncoding().decoder)
          .join();
      req.response.headers.set('content-type', 'audio/basic');
      req.response.add(Uint8List(4800));
      await req.response.close();
    });
    final adapter = AzureTtsAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKey: 'k',
    );
    final events = await adapter
        .synthesizeStream(
          const TtsRequest(
            text: '你好',
            voice: 'zh-CN-XiaoxiaoNeural',
            responseFormat: 'pcm',
          ),
          cancellation: TtsCancelToken(),
        )
        .toList();
    expect(events.whereType<TtsAudioChunk>(), isNotEmpty);
    expect(events.last, isA<TtsSynthesisCompleted>());
    expect(ssml, contains('xml:lang="zh-CN"'));
    expect(ssml, contains('name="zh-CN-XiaoxiaoNeural"'));
  });

  test('realtime model per character, with fallback to the default', () {
    final router = CapabilityRouter([
      connectionForProvider(_row('oa', AdapterType.openaiTts, '')),
      connectionForProvider(_row('gm', AdapterType.geminiTts, '')),
    ]);
    final factory = ConversationFactory(router);
    final gemini = factory.realtimeFor(
      const CharacterLiveSettings(
        realtimeConnectionId: 'gm',
        realtimeModelId: 'gemini-3.8-live',
      ),
    )!;
    expect(gemini.connection.id, 'gm');
    expect(gemini.model.voices, contains('Kore'));
    expect(gemini.model.voices, isNot(contains('marin')));
    final gone = factory.realtimeFor(
      const CharacterLiveSettings(realtimeConnectionId: 'deleted'),
    )!;
    expect(gone.connection.id, 'oa');
    final json = const CharacterLiveSettings(
      realtimeConnectionId: 'gm',
      realtimeModelId: 'gemini-3.8-live',
      realtimeVoice: 'Kore',
    ).toJson();
    final back = CharacterLiveSettings.fromJson(json);
    expect(
      (back.realtimeConnectionId, back.realtimeModelId, back.realtimeVoice),
      ('gm', 'gemini-3.8-live', 'Kore'),
    );
  });

  test('MiMo ASR: chat input_audio with api-key, one GET for health', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final seen = <(String, String, String?, Map<String, dynamic>)>[];
    server.listen((req) async {
      final raw = await utf8.decoder.bind(req).join();
      seen.add((
        req.method,
        req.uri.path,
        req.headers.value('api-key'),
        raw.isEmpty ? {} : jsonDecode(raw) as Map<String, dynamic>,
      ));
      req.response.headers.contentType = ContentType.json;
      req.response.write(
        jsonEncode(
          req.method == 'GET'
              ? {
                  'data': [
                    {'id': 'mimo-v2.5-asr'},
                    {'id': 'mimo-v2.6-pro'},
                  ],
                }
              : {
                  'choices': [
                    {
                      'message': {'role': 'assistant', 'content': ' 早上好。 '},
                    },
                  ],
                },
        ),
      );
      await req.response.close();
    });
    final c = const MiMoPlugin().connect(
      connectionForProvider(
        _row(
          'm',
          AdapterType.chatCompletionsTts,
          'http://127.0.0.1:${server.port}/v1',
        ),
      ).config,
    );
    expect(c.capabilities, contains(AiCapability.stt));
    expect(modelBadges('mimo-v2.5-asr', c), ['ASR']);
    final t = await c.transcriber()!.transcribe(
      AudioInput(Uint8List.fromList([1, 2, 3]), contentType: 'audio/mpeg'),
      options: const TranscribeOptions(languages: ['zh'], keywords: ['长门']),
    );
    expect(t.text, '早上好。');
    final (method, path, key, body) = seen.single;
    expect((method, path, key), ('POST', '/v1/chat/completions', 'k'));
    expect(body['model'], 'mimo-v2.5-asr');
    final parts = body['messages'][0]['content'] as List;
    expect(parts.first, {
      'type': 'text',
      'text': 'Language: zh. Vocabulary: 长门.',
    });
    expect(parts.last['input_audio'], {'data': 'AQID', 'format': 'mp3'});

    seen.clear();
    final health = await (c as AdapterBackedConnection).checkListed({
      AiCapability.llm,
      AiCapability.stt,
    });
    expect(seen.single.$2, '/v1/models');
    expect(health[AiCapability.stt]!.models, ['mimo-v2.5-asr']);
    expect(health[AiCapability.llm]!.models, ['mimo-v2.6-pro']);
  });
}
