import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/providers/common/adapter_backed_connection.dart';
import 'package:neiroha/data/ai/providers/common/adapter_tts_plugin.dart';
import 'package:neiroha/data/ai/providers/gemini/gemini_plugin.dart';
import 'package:neiroha/data/ai/providers/mimo/mimo_plugin.dart';
import 'package:neiroha/data/ai/providers/minimax/minimax_plugin.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';

db.TtsProvider _row(AdapterType type, String baseUrl) => db.TtsProvider(
  id: 'p-${type.name}',
  name: type.displayName,
  adapterType: type.name,
  baseUrl: baseUrl,
  apiKey: 'fixture',
  defaultModelName: type.defaultModel,
  enabled: true,
  position: 0,
  maxConcurrency: 1,
);

AdapterBackedConnection _connect(AdapterType type, String baseUrl) =>
    connectionForProvider(_row(type, baseUrl)) as AdapterBackedConnection;

void main() {
  test('Gemini, MiniMax and MiMo each get their own plugin with LLM', () {
    for (final (type, url, plugin, model) in [
      (
        AdapterType.geminiTts,
        'https://generativelanguage.googleapis.com',
        GeminiPlugin,
        'gemini-3.8-flash',
      ),
      (
        AdapterType.minimaxTts,
        'https://api.minimax.io',
        MiniMaxPlugin,
        'MiniMax-M3',
      ),
      (
        AdapterType.chatCompletionsTts,
        'https://api.xiaomimimo.com/v1',
        MiMoPlugin,
        'mimo-v2.6-pro',
      ),
    ]) {
      final c = _connect(type, url);
      expect(c.plugin.runtimeType, plugin);
      expect(c.capabilities, {AiCapability.tts, AiCapability.llm});
      expect(c.languageModel()?.descriptor.id, model);
      expect(c.languageModel()?.descriptor.protocol, AiProtocol.openAiChat);
      expect(c.speechModel(), isNotNull, reason: type.name);
    }
  });

  test('TTS-only engines stay TTS-only; custom chat-TTS hosts keep LLM', () {
    for (final type in [
      AdapterType.azureTts,
      AdapterType.gptSovits,
      AdapterType.cosyvoice,
      AdapterType.indexTts,
      AdapterType.voxcpm2Native,
    ]) {
      final c = connectionForProvider(_row(type, 'http://127.0.0.1:9'));
      expect(c.plugin.runtimeType, AdapterTtsPlugin, reason: type.name);
      expect(c.capabilities, {AiCapability.tts});
      expect(c.languageModel(), isNull);
    }
    final custom = _connect(
      AdapterType.chatCompletionsTts,
      'https://gateway.example/v1',
    );
    expect(custom.plugin, isA<ChatCompletionsTtsPlugin>());
    expect(custom.languageModel(), isNull); // no catalog default
    expect(
      custom.languageModel('qwen-max')?.descriptor.source,
      DescriptorSource.user,
    );
  });

  test('official hosts route LLM to each vendor text endpoint', () {
    final gemini = _connect(
      AdapterType.geminiTts,
      'https://generativelanguage.googleapis.com',
    ).llmEndpoint;
    expect(
      gemini.baseUrl,
      'https://generativelanguage.googleapis.com/v1beta/openai/',
    );
    expect(gemini.apiKeyHeader, 'Authorization');
    final minimax = _connect(
      AdapterType.minimaxTts,
      'https://api.minimax.io',
    ).llmEndpoint;
    expect(minimax.baseUrl, 'https://api.minimax.io/v1/');
    final mimo = _connect(
      AdapterType.chatCompletionsTts,
      'https://api.xiaomimimo.com/v1',
    ).llmEndpoint;
    expect(mimo.baseUrl, 'https://api.xiaomimimo.com/v1');
    expect(mimo.apiKeyHeader, 'api-key');
  });

  group('chat requests (fake server)', () {
    late HttpServer server;
    final seen = <(String, String?, String?, Map<String, dynamic>)>[];
    setUp(() async {
      seen.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final body = await utf8.decoder.bind(req).join();
        seen.add((
          req.uri.path,
          req.headers.value('authorization'),
          req.headers.value('api-key'),
          body.isEmpty ? {} : jsonDecode(body) as Map<String, dynamic>,
        ));
        req.response.headers.contentType = ContentType.json;
        if (req.uri.path.endsWith('/models')) {
          req.response.write(
            jsonEncode({
              'data': [
                {'id': 'models/gemini-3.8-flash'},
                {'id': 'mimo-v2.6-pro'},
              ],
            }),
          );
        } else {
          req.response.write(
            jsonEncode({
              'choices': [
                {
                  'finish_reason': 'stop',
                  'message': {'content': '{"speaker":"Alice"}'},
                },
              ],
            }),
          );
        }
        await req.response.close();
      });
    });
    tearDown(() => server.close(force: true));

    String url(String path) => 'http://127.0.0.1:${server.port}$path';

    test('Gemini sends Bearer chat completions on its OpenAI path', () async {
      final c = _connect(AdapterType.geminiTts, url('/v1beta/openai'));
      final reply = await c.languageModel()!.complete(const [
        LlmChatMessage(role: 'user', content: 'hi'),
      ]);
      expect(reply, '{"speaker":"Alice"}');
      final (path, auth, apiKey, body) = seen.single;
      expect(path, '/v1beta/openai/chat/completions');
      expect(auth, 'Bearer fixture');
      expect(apiKey, isNull);
      expect(body['model'], 'gemini-3.8-flash');
      final health = await c.checkLlm();
      expect(health.state, HealthState.ok);
      expect(health.models, ['gemini-3.8-flash']);
    });

    test('MiMo uses the api-key header for structured output', () async {
      final c = connectionForProvider(
        _row(AdapterType.chatCompletionsTts, url('/v1')),
      );
      // A local URL is not the official host, so pick MiMo explicitly.
      final mimo =
          const MiMoPlugin().connect(c.config) as AdapterBackedConnection;
      final result = await mimo.languageModel()!.structured(
        const [LlmChatMessage(role: 'user', content: 'who?')],
        schemaName: 'speaker',
        schema: const {'type': 'object'},
      );
      expect(result.object['speaker'], 'Alice');
      final (path, auth, apiKey, body) = seen.single;
      expect(path, '/v1/chat/completions');
      expect(auth, isNull);
      expect(apiKey, 'fixture');
      expect(body['model'], 'mimo-v2.6-pro');
      expect(body['response_format']['type'], 'json_schema');
    });

    test('MiniMax chat and a rejected key during health check', () async {
      final c = _connect(AdapterType.minimaxTts, url('/v1'));
      await c.languageModel('MiniMax-M3.1-Flash')!.complete(const [
        LlmChatMessage(role: 'user', content: 'hi'),
      ]);
      expect(seen.single.$1, '/v1/chat/completions');
      expect(seen.single.$4['model'], 'MiniMax-M3.1-Flash');
      await server.close(force: true);
      final down = await c.checkLlm();
      expect(down.state, HealthState.unknown);
    });
  });
}
