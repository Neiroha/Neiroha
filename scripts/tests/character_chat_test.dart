// Character chat: tool calls over both OpenAI APIs, the character's tool
// loop and structured reply, the companion and Realtime engines using
// tools, and the saved chats.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/protocols/openai/openai_tool_chat.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/conversation/character_brain.dart';
import 'package:neiroha/data/services/conversation/character_tools.dart';
import 'package:neiroha/data/services/conversation/companion_conversation.dart';
import 'package:neiroha/data/services/conversation/conversation_engine.dart';
import 'package:neiroha/data/services/conversation/realtime_conversation.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/llm/tool_chat.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

import 'support/fake_conversation_audio.dart';

const _d = ModelDescriptor(
  id: 'fake',
  capability: AiCapability.llm,
  protocol: AiProtocol.native,
);

/// Answers from a script of turns and records what it was sent.
class _ToolLlm implements ToolCallingLanguageModel {
  _ToolLlm(this.turns, {this.reject = false});
  final List<ToolChatTurn> turns;
  final bool reject;
  final sent = <List<ToolChatMessage>>[];
  final offered = <List<String>>[];
  int streamed = 0;

  @override
  ModelDescriptor get descriptor => _d;

  @override
  Future<ToolChatTurn> chatWithTools(
    List<ToolChatMessage> messages, {
    List<LlmTool> tools = const [],
    String? schemaName,
    Map<String, Object?>? replySchema,
    TtsCancelToken? cancellation,
    int maxOutputTokens = 1024,
  }) async {
    if (reject) {
      throw const LlmChatException('tools unsupported', statusCode: 400);
    }
    sent.add([...messages]);
    offered.add([for (final t in tools) t.name]);
    return turns.removeAt(0);
  }

  @override
  Future<String> complete(
    List<LlmChatMessage> messages, {
    TtsCancelToken? cancellation,
    int maxOutputTokens = 4096,
  }) async {
    streamed++;
    return 'Plain answer.';
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

String _reply(String say, {String style = '', String emotion = 'neutral'}) =>
    jsonEncode({'say': say, 'style': style, 'emotion': emotion});

Stream<TtsEvent> _speech(String text, TtsCancelToken _) async* {
  yield const TtsAudioStarted(
    TtsAudioFormat(AudioEncoding.pcmS16le, sampleRate: 24000, channels: 1),
  );
  yield TtsAudioChunk(Uint8List(4800));
  yield const TtsSynthesisCompleted();
}

class _Session
    implements ToolCallingRealtimeSession, TruncatableRealtimeSession {
  final _events = StreamController<AiSessionEvent>();
  RealtimeConfig? config;
  final results = <(String, String)>[];
  final truncated = <(String, int)>[];
  void emit(AiSessionEvent e) => _events.add(e);
  @override
  Stream<AiSessionEvent> get events => _events.stream;
  @override
  int get inputSampleRate => 24000;
  @override
  void sendPcm(Uint8List pcm16) {}
  @override
  void sendText(String text) {}
  @override
  Future<ResponseDone> respond({Duration timeout = Duration.zero}) async =>
      const ResponseDone();
  @override
  void cancelResponse() {}
  @override
  void sendToolResult(String callId, String output) =>
      results.add((callId, output));
  @override
  void truncate(String itemId, int audioEndMs) =>
      truncated.add((itemId, audioEndMs));
  @override
  Future<void> finish({Duration timeout = Duration.zero}) async {}
  @override
  Future<void> close() => _events.close();
}

class _Realtime implements RealtimeModel {
  _Realtime(this.session);
  final _Session session;
  @override
  ModelDescriptor get descriptor => _d;
  @override
  List<String> get voices => const ['marin'];
  @override
  Future<RealtimeSession> connect(RealtimeConfig config) async {
    session.config = config;
    return session;
  }
}

void main() {
  group('OpenAI tool chat', () {
    const call = LlmToolCall(
      id: 'c1',
      name: 'remember_fact',
      arguments: '{"fact":"likes tea"}',
    );
    final messages = [
      const ToolChatMessage.system('Be Nagato.'),
      const ToolChatMessage.user('I like tea.'),
      const ToolChatMessage.assistant('', toolCalls: [call]),
      const ToolChatMessage.toolResult('c1', 'Remembered.'),
    ];
    const tool = LlmTool(name: 'get_current_time', description: 'time');

    test('chat completions: tool messages, tools and the reply schema', () {
      final body = OpenAiToolChat.chatBody(
        'gpt-x',
        messages,
        tools: [tool],
        replySchema: CharacterReply.schema,
      );
      final sent = body['messages'] as List;
      expect((sent[2] as Map)['content'], isNull);
      expect(
        ((sent[2] as Map)['tool_calls'] as List).single['function']['name'],
        'remember_fact',
      );
      expect(sent[3], {
        'role': 'tool',
        'tool_call_id': 'c1',
        'content': 'Remembered.',
      });
      expect((body['tools'] as List).single['function']['name'], tool.name);
      expect((body['response_format'] as Map)['type'], 'json_schema');
      expect(body['max_completion_tokens'], 1024);
      expect(
        OpenAiToolChat.chatBody('m', messages, official: false),
        containsPair('max_tokens', 1024),
      );

      final turn = OpenAiToolChat.parseChat({
        'choices': [
          {
            'message': {
              'content': null,
              'tool_calls': [
                {
                  'id': 'c2',
                  'type': 'function',
                  'function': {'name': 'get_current_time', 'arguments': '{}'},
                },
              ],
            },
          },
        ],
      });
      expect(turn.content, '');
      expect(turn.toolCalls.single.id, 'c2');
    });

    test('responses: function_call items and the text format', () {
      final body = OpenAiToolChat.responsesBody(
        'gpt-x',
        messages,
        tools: [tool],
        replySchema: CharacterReply.schema,
      );
      final input = body['input'] as List;
      expect(input[2], {
        'type': 'function_call',
        'call_id': 'c1',
        'name': 'remember_fact',
        'arguments': '{"fact":"likes tea"}',
      });
      expect(input[3], {
        'type': 'function_call_output',
        'call_id': 'c1',
        'output': 'Remembered.',
      });
      expect((body['tools'] as List).single['name'], tool.name);
      expect(((body['text'] as Map)['format'] as Map)['strict'], isTrue);

      final turn = OpenAiToolChat.parseResponses({
        'output': [
          {'type': 'reasoning'},
          {
            'type': 'message',
            'content': [
              {'type': 'output_text', 'text': _reply('Hi.')},
            ],
          },
        ],
      });
      expect(turn.toolCalls, isEmpty);
      expect(CharacterReply.parse(turn.content).say, 'Hi.');
    });
  });

  group('character brain', () {
    test('runs the tools, then answers with a structured reply', () async {
      final memory = ChatMemory();
      final llm = _ToolLlm([
        const ToolChatTurn(
          toolCalls: [
            LlmToolCall(
              id: 'a',
              name: 'remember_fact',
              arguments: '{"fact":"The commander likes tea."}',
            ),
            LlmToolCall(id: 'b', name: 'unknown_tool', arguments: '{}'),
          ],
        ),
        ToolChatTurn(
          content: _reply('I will remember.', style: 'softly', emotion: 'shy'),
        ),
      ]);
      final uses = <ToolUse>[];
      final reply = await CharacterBrain(llm, tools: characterTools(memory))
          .answer(
            [const ToolChatMessage.user('I like tea.')],
            cancellation: TtsCancelToken(),
            onTool: uses.add,
          );
      expect(
        (reply.say, reply.style, reply.emotion),
        ('I will remember.', 'softly', 'shy'),
      );
      expect(memory.facts, ['The commander likes tea.']);
      expect(uses.map((u) => u.result), ['Remembered.', contains('Unknown')]);
      expect(llm.sent.last.map((m) => m.role), [
        'user',
        'assistant',
        'tool',
        'tool',
      ]);
      expect(llm.offered.first, contains('get_current_time'));
    });

    test('the last round offers no tools, so the model must answer', () async {
      const loop = ToolChatTurn(
        toolCalls: [
          LlmToolCall(id: 'x', name: 'get_current_time', arguments: ''),
        ],
      );
      final llm = _ToolLlm([loop, loop, ToolChatTurn(content: 'Plain text.')]);
      final reply = await CharacterBrain(
        llm,
        tools: characterTools(ChatMemory()),
        maxRounds: 2,
      ).answer(const [], cancellation: TtsCancelToken());
      expect(llm.offered.last, isEmpty);
      // A model that ignored the schema is spoken as it wrote.
      expect(reply.say, 'Plain text.');
      expect(reply.emotion, 'neutral');
    });

    test('time tool and memory', () async {
      final memory = ChatMemory();
      final tools = characterTools(
        memory,
        now: () => DateTime(2026, 11, 24, 21, 5),
      );
      expect(
        await runCharacterTool(tools, 'get_current_time', ''),
        startsWith('2026-11-24 Tuesday 21:05'),
      );
      await runCharacterTool(tools, 'remember_fact', '{"fact":"a"}');
      expect(
        await runCharacterTool(tools, 'remember_fact', '{"fact":"a"}'),
        'Already known.',
      );
      expect(memory.prompt, contains('- a'));
      await runCharacterTool(tools, 'forget_fact', '{"fact":"a"}');
      expect(memory.facts, isEmpty);
      expect(memory.prompt, isEmpty);
    });
  });

  group('companion with tools', () {
    test('typed turns speak the reply in its style', () async {
      final io = FakeConversationAudio();
      final styles = <String>[];
      final memory = ChatMemory(['Likes tea.']);
      final llm = _ToolLlm([
        ToolChatTurn(content: _reply('Welcome back.', style: 'warmly')),
      ]);
      final engine = CompanionConversation(
        vad: null,
        transcriber: null,
        llm: llm,
        speak: _speech,
        speakWith: (style) {
          styles.add(style);
          return _speech;
        },
        io: io,
        systemPrompt: 'You are Nagato.',
        tools: characterTools(memory),
        instructions: () => memory.prompt,
        history: const [
          LlmChatMessage(role: 'user', content: 'Earlier.'),
          LlmChatMessage(role: 'assistant', content: 'Indeed.'),
        ],
      );
      final events = <ConversationEvent>[];
      engine.events.listen(events.add);
      await engine.start();
      expect(engine.listens, isFalse);
      await engine.sendText('I am back.');
      final turn = events.whereType<CharacterTurn>().single;
      expect(
        (turn.text, turn.style, turn.done),
        ('Welcome back.', 'warmly', true),
      );
      expect(styles, ['warmly']);
      expect(io.sinks.single.bytes.length, 4800);
      final prompt = llm.sent.single;
      expect(prompt.first.content, contains('Likes tea.'));
      expect(prompt.map((m) => m.role), [
        'system',
        'user',
        'assistant',
        'user',
      ]);
      await engine.stop();
    });

    test('a server without tools falls back to plain replies', () async {
      final llm = _ToolLlm(const [], reject: true);
      final engine = CompanionConversation(
        vad: null,
        transcriber: null,
        llm: llm,
        speak: _speech,
        io: FakeConversationAudio(),
        systemPrompt: 'x',
      );
      final events = <ConversationEvent>[];
      engine.events.listen(events.add);
      await engine.start();
      await engine.sendText('hi');
      await engine.sendText('again');
      expect(llm.streamed, 2);
      expect(events.whereType<ConversationFailed>(), isEmpty);
      expect(
        events.whereType<CharacterTurn>().where((t) => t.done).last.text,
        'Plain answer.',
      );
      await engine.stop();
    });
  });

  test('realtime runs tools and truncates a reply cut short', () async {
    final session = _Session();
    final io = FakeConversationAudio();
    final engine = RealtimeConversation(
      model: _Realtime(session),
      io: io,
      instructions: 'x',
      tools: characterTools(ChatMemory()),
    );
    final events = <ConversationEvent>[];
    engine.events.listen(events.add);
    await engine.start();
    expect(session.config!.tools.map((t) => t.name), contains('remember_fact'));
    session.emit(
      const FunctionCallRequested(
        callId: 'call_1',
        name: 'remember_fact',
        arguments: '{"fact":"likes tea"}',
      ),
    );
    await pumpEventQueue();
    expect(session.results.single, ('call_1', 'Remembered.'));
    expect(events.whereType<ToolUsed>().single.name, 'remember_fact');

    // One second of reply audio, then the user speaks over it.
    session.emit(
      AudioDelta(Uint8List(48000), sampleRate: 24000, itemId: 'item_9'),
    );
    await pumpEventQueue();
    session.emit(const SpeechStarted());
    await pumpEventQueue();
    final (item, ms) = session.truncated.single;
    expect(item, 'item_9');
    expect(ms, inInclusiveRange(0, 1000));
    await engine.stop();
  });

  test('chats keep their lines in order and go with their character', () async {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final character = (await database.getAllVoiceAssets()).first;
    final chat = await database.createChatSession(
      voiceAssetId: character.id,
      engine: ChatEngine.companion.name,
      title: 'Tea',
    );
    await database.addChatMessage(chat.id, role: 'user', content: 'Hi');
    await database.addChatMessage(
      chat.id,
      role: 'character',
      content: 'Hello.',
      meta: {'emotion': 'happy'},
    );
    await database.saveChatMemory(chat.id, ['Likes tea.']);
    final lines = await database.getChatMessages(chat.id);
    expect(lines.map((m) => (m.orderIndex, m.role)), [
      (0, 'user'),
      (1, 'character'),
    ]);
    expect(jsonDecode(lines.last.metaJson!), {'emotion': 'happy'});
    final saved = (await database.getChatSession(chat.id))!;
    expect(jsonDecode(saved.memoryJson), ['Likes tea.']);
    expect(ChatEngine.fromName(saved.engine), ChatEngine.companion);
    expect(ChatEngine.fromName('script'), ChatEngine.companion);

    await database.deleteVoiceAsset(character.id);
    expect(await database.getChatSession(chat.id), isNull);
    expect(await database.getChatMessages(chat.id), isEmpty);
  });
}
