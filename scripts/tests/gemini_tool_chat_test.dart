// Gemini text models calling the character's tools over generateContent:
// declarations, a call with its thought signature sent back, results named
// after their call, and a model that refuses tools falling back to plain
// streaming.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/providers/gemini/gemini_endpoint.dart';
import 'package:neiroha/data/ai/providers/gemini/llm/gemini_language_model.dart';
import 'package:neiroha/data/ai/providers/gemini/llm/gemini_tool_chat.dart';
import 'package:neiroha/data/services/conversation/character_brain.dart';
import 'package:neiroha/data/services/conversation/character_tools.dart';
import 'package:neiroha/data/services/conversation/companion_conversation.dart';
import 'package:neiroha/data/services/conversation/conversation_engine.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/llm/tool_chat.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

import 'support/fake_conversation_audio.dart';

Map<String, Object?> _answer(List<Map<String, Object?>> parts) => {
  'candidates': [
    {
      'content': {'role': 'model', 'parts': parts},
      'finishReason': 'STOP',
    },
  ],
};

Stream<TtsEvent> _speech(String text, TtsCancelToken _) async* {
  yield const TtsAudioStarted(
    TtsAudioFormat(AudioEncoding.pcmS16le, sampleRate: 24000, channels: 1),
  );
  yield TtsAudioChunk(Uint8List(480));
  yield const TtsSynthesisCompleted();
}

void main() {
  late HttpServer server;
  final bodies = <Map<String, dynamic>>[];
  var refuseTools = false;

  setUp(() async {
    bodies.clear();
    refuseTools = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final body =
          jsonDecode(await utf8.decodeStream(req)) as Map<String, dynamic>;
      bodies.add(body);
      final res = req.response..headers.contentType = ContentType.json;
      if (req.uri.path.endsWith(':streamGenerateContent')) {
        res.headers.contentType = ContentType('text', 'event-stream');
        res.write(
          'data: ${jsonEncode(_answer([
            {'text': 'Plain hello.'},
          ]))}\n\n',
        );
      } else if (refuseTools && body['tools'] != null) {
        res
          ..statusCode = 400
          ..write(
            jsonEncode({
              'error': {'message': 'Function calling is not enabled.'},
            }),
          );
      } else {
        final contents = body['contents'] as List;
        final last = (contents.last as Map)['parts'] as List;
        final answered = (last.first as Map).containsKey('functionResponse');
        res.write(
          jsonEncode(
            answered
                ? _answer([
                    {
                      'text':
                          '{"say":"I will remember.","style":"warm","emotion":"happy"}',
                    },
                  ])
                : _answer([
                    {
                      'functionCall': {
                        'name': 'remember_fact',
                        'args': {'fact': 'Likes tea.'},
                      },
                      'thoughtSignature': 'sig-1',
                    },
                  ]),
          ),
        );
      }
      await res.close();
    });
  });
  tearDown(() => server.close(force: true));

  GeminiLanguageModel model() => GeminiLanguageModel(
    const ModelDescriptor(
      id: 'gemini-3-flash',
      capability: AiCapability.llm,
      protocol: AiProtocol.native,
    ),
    GeminiEndpoint('http://127.0.0.1:${server.port}', 'k'),
  );

  test('a call runs, its signature goes back and the reply follows', () async {
    final memory = ChatMemory();
    final uses = <ToolUse>[];
    final reply = await CharacterBrain(model(), tools: characterTools(memory))
        .answer(
          const [
            ToolChatMessage.system('You are Nagato.'),
            ToolChatMessage.user('I like tea.'),
          ],
          cancellation: TtsCancelToken(),
          onTool: uses.add,
        );
    expect(reply.say, 'I will remember.');
    expect(reply.emotion, 'happy');
    expect(memory.facts, ['Likes tea.']);
    expect(uses.single.name, 'remember_fact');

    final first = bodies.first;
    final declared =
        ((first['tools'] as List).single as Map)['functionDeclarations']
            as List;
    expect(declared.map((d) => (d as Map)['name']), contains('remember_fact'));
    expect((declared.first as Map)['parametersJsonSchema'], isA<Map>());
    // JSON mode and tools do not mix on every model: the schema is asked
    // for in the instructions instead.
    final config = first['generationConfig'] as Map;
    expect(config.containsKey('responseMimeType'), isFalse);
    final system = jsonEncode(first['systemInstruction']);
    expect(system, contains('JSON Schema'));
    expect(system, contains('You are Nagato.'));

    final second = bodies[1]['contents'] as List;
    final modelTurn = second[1] as Map;
    expect(modelTurn['role'], 'model');
    final callPart = (modelTurn['parts'] as List).single as Map;
    expect(callPart['thoughtSignature'], 'sig-1');
    // Gemini gave no id, so none is sent back.
    expect((callPart['functionCall'] as Map).containsKey('id'), isFalse);
    final resultTurn = second[2] as Map;
    expect(resultTurn['role'], 'user');
    expect(((resultTurn['parts'] as List).single as Map)['functionResponse'], {
      'name': 'remember_fact',
      'response': {'result': 'Remembered.'},
    });
  });

  test('without tools the reply schema is enforced as JSON output', () {
    final body = GeminiToolChat.body(
      const [ToolChatMessage.user('hi')],
      tools: const [],
      maxOutputTokens: 100,
      replySchema: CharacterReply.schema,
    );
    final config = body['generationConfig'] as Map;
    expect(config['responseMimeType'], 'application/json');
    expect(config['responseJsonSchema'], CharacterReply.schema);
    expect(body.containsKey('tools'), isFalse);
  });

  test('results of parallel calls share one message, in order', () {
    final body = GeminiToolChat.body(
      const [
        ToolChatMessage.user('time and remember'),
        ToolChatMessage.assistant(
          '',
          toolCalls: [
            LlmToolCall(id: 'a', name: 'get_current_time', arguments: ''),
            LlmToolCall(
              id: 'b',
              name: 'remember_fact',
              arguments: '{"fact":"x"}',
            ),
          ],
        ),
        ToolChatMessage.toolResult('a', 'noon'),
        ToolChatMessage.toolResult('b', 'Remembered.'),
      ],
      tools: const [],
      maxOutputTokens: 100,
    );
    final contents = body['contents'] as List;
    expect(contents, hasLength(3));
    final calls = (contents[1] as Map)['parts'] as List;
    expect(((calls[1] as Map)['functionCall'] as Map)['args'], {'fact': 'x'});
    final results = (contents[2] as Map)['parts'] as List;
    expect(results.map((p) => ((p as Map)['functionResponse'] as Map)['id']), [
      'a',
      'b',
    ]);
  });

  test('a model that refuses tools answers by plain streaming', () async {
    refuseTools = true;
    final engine = CompanionConversation(
      vad: null,
      transcriber: null,
      llm: model(),
      speak: _speech,
      io: FakeConversationAudio(),
      systemPrompt: 'x',
      tools: characterTools(ChatMemory()),
    );
    final events = <ConversationEvent>[];
    engine.events.listen(events.add);
    await engine.start();
    await engine.sendText('hi');
    await pumpEventQueue();
    expect(
      events.whereType<ConversationFailed>().map((e) => e.error.toString()),
      isEmpty,
    );
    expect(
      events.whereType<CharacterTurn>().where((t) => t.done).last.text,
      'Plain hello.',
    );
    await engine.stop();
  });
}
