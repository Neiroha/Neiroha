// Character chat, second part: Gemini Live calling the character's tools,
// tools switched by what the model can do (and dropped when refused), and
// each reply's audio saved next to its line.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/protocols/gemini/gemini_live_session.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/conversation/character_tools.dart';
import 'package:neiroha/data/services/conversation/companion_conversation.dart';
import 'package:neiroha/data/services/conversation/conversation_engine.dart';
import 'package:neiroha/data/services/conversation/realtime_conversation.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/presentation/widgets/character_chat/chat_bubbles.dart';
import 'package:neiroha/presentation/widgets/character_chat/chat_recorder.dart';

import 'support/fake_conversation_audio.dart';

ModelDescriptor _realtime(Set<String> features) => ModelDescriptor(
  id: 'live',
  capability: AiCapability.realtime,
  protocol: AiProtocol.geminiLive,
  features: features,
);

/// Gemini Live on a local socket.
class _GeminiModel implements RealtimeModel {
  _GeminiModel(this.uri);
  final Uri uri;
  @override
  ModelDescriptor get descriptor => _realtime(const {AiFeature.toolCalls});
  @override
  List<String> get voices => const ['Kore'];
  @override
  Future<RealtimeSession> connect(RealtimeConfig config) =>
      GeminiLiveSession.connect(
        uri: uri,
        mode: GeminiLiveMode.conversation,
        manualTurns: false,
        setup: geminiLiveSetup(
          model: 'live',
          mode: GeminiLiveMode.conversation,
          config: config,
        ),
      );
}

/// Records each connection's config; [refuse] fails one that has tools,
/// [failFirst] errors the first session before it answers.
class _Model implements RealtimeModel {
  _Model(this.features, {this.refuse = false, this.failFirst = false});
  final Set<String> features;
  final bool refuse;
  final bool failFirst;
  final configs = <RealtimeConfig>[];
  final sessions = <_Session>[];
  @override
  ModelDescriptor get descriptor => _realtime(features);
  @override
  List<String> get voices => const [];
  @override
  Future<RealtimeSession> connect(RealtimeConfig config) async {
    configs.add(config);
    if (refuse && config.tools.isNotEmpty) {
      throw const SocketException('setup rejected');
    }
    final session = _Session();
    sessions.add(session);
    if (failFirst && sessions.length == 1) {
      scheduleMicrotask(
        () => session.controller.addError(StateError('invalid tools')),
      );
    }
    return session;
  }
}

class _Session implements RealtimeSession {
  final controller = StreamController<AiSessionEvent>();
  bool closed = false;
  @override
  Stream<AiSessionEvent> get events => controller.stream;
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
  Future<void> finish({Duration timeout = Duration.zero}) async {}
  @override
  Future<void> close() async {
    closed = true;
    await controller.close();
  }
}

Stream<TtsEvent> _speech(String text, TtsCancelToken _) async* {
  yield const TtsAudioStarted(
    TtsAudioFormat(AudioEncoding.pcmS16le, sampleRate: 24000, channels: 1),
  );
  yield TtsAudioChunk(Uint8List(4800));
  yield const TtsSynthesisCompleted();
}

class _Llm implements LanguageModel {
  @override
  ModelDescriptor get descriptor => const ModelDescriptor(
    id: 'plain',
    capability: AiCapability.llm,
    protocol: AiProtocol.native,
  );
  @override
  Future<String> complete(
    List<LlmChatMessage> messages, {
    TtsCancelToken? cancellation,
    int maxOutputTokens = 4096,
  }) async => 'Hello there.';
  @override
  Future<LlmStructuredResult> structured(
    List<LlmChatMessage> messages, {
    required String schemaName,
    required Map<String, Object?> schema,
    TtsCancelToken? cancellation,
    int maxOutputTokens = 4096,
  }) => throw UnimplementedError();
}

void main() {
  group('Gemini Live tools', () {
    late HttpServer server;
    final received = <Map<String, dynamic>>[];
    setUp(() async {
      received.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final ws = await WebSocketTransformer.upgrade(req);
        void reply(Map<String, Object?> m) => ws.add(jsonEncode(m));
        ws.listen((raw) {
          final m = jsonDecode(raw as String) as Map<String, dynamic>;
          received.add(m);
          if (m.containsKey('setup')) {
            reply({'setupComplete': {}});
          } else if ((m['realtimeInput'] as Map?)?['text'] != null) {
            reply({
              'toolCall': {
                'functionCalls': [
                  {
                    'id': 'fc1',
                    'name': 'remember_fact',
                    'args': {'fact': 'Likes tea.'},
                  },
                ],
              },
            });
          } else if (m.containsKey('toolResponse')) {
            reply({
              'serverContent': {
                'modelTurn': {
                  'parts': [
                    {
                      'inlineData': {'data': base64Encode(Uint8List(960))},
                    },
                  ],
                },
                'outputTranscription': {'text': 'I will remember.'},
              },
            });
            reply({
              'serverContent': {'turnComplete': true},
            });
          }
        });
      });
    });
    tearDown(() => server.close(force: true));

    test('declares the tools, runs a call and hears the reply', () async {
      final memory = ChatMemory();
      final io = FakeConversationAudio();
      final engine = RealtimeConversation(
        model: _GeminiModel(Uri.parse('ws://127.0.0.1:${server.port}')),
        io: io,
        instructions: 'You are Nagato.',
        tools: characterTools(memory),
      );
      final events = <ConversationEvent>[];
      final heard = Completer<void>();
      engine.events.listen((e) {
        events.add(e);
        if (e is ReplyAudio && !heard.isCompleted) heard.complete();
      });
      await engine.start();
      expect(engine.toolsActive, isTrue);
      final setup = received.first['setup'] as Map;
      final declared =
          ((setup['tools'] as List).single as Map)['functionDeclarations']
              as List;
      expect(
        declared.map((d) => (d as Map)['name']),
        contains('remember_fact'),
      );
      // Gemini's schema subset has no additionalProperties.
      expect(jsonEncode(declared), isNot(contains('additionalProperties')));

      await engine.sendText('I like tea.');
      await heard.future.timeout(const Duration(seconds: 5));
      expect(memory.facts, ['Likes tea.']);
      final response = received.firstWhere(
        (m) => m.containsKey('toolResponse'),
      );
      expect(
        ((response['toolResponse'] as Map)['functionResponses'] as List).single,
        {
          'id': 'fc1',
          'name': 'remember_fact',
          'response': {'result': 'Remembered.'},
        },
      );
      expect(events.whereType<ToolUsed>().single.result, 'Remembered.');
      expect(
        events.whereType<CharacterTurn>().where((t) => t.done).last.text,
        'I will remember.',
      );
      expect(events.whereType<ReplyAudio>().single.bytes.length, 960);
      await engine.stop();
    });
  });

  group('realtime tools follow the model', () {
    Future<_Model> run(_Model model) async {
      final engine = RealtimeConversation(
        model: model,
        io: FakeConversationAudio(),
        instructions: 'x',
        tools: characterTools(ChatMemory()),
      );
      final failures = <ConversationFailed>[];
      engine.events.listen((e) {
        if (e is ConversationFailed) failures.add(e);
      });
      await engine.start();
      await pumpEventQueue();
      expect(failures, isEmpty);
      await engine.stop();
      return model;
    }

    test('a model without tools is not offered them', () async {
      final model = await run(_Model({AiFeature.serverVad}));
      expect(model.configs.single.tools, isEmpty);
    });

    test('unknown capabilities try the tools', () async {
      final model = await run(_Model({}));
      expect(model.configs.single.tools, isNotEmpty);
    });

    test('a setup refused with tools connects without them', () async {
      final model = await run(_Model({}, refuse: true));
      expect(model.configs.map((c) => c.tools.isEmpty), [false, true]);
    });

    test('an error before the first answer drops the tools', () async {
      final model = await run(_Model({}, failFirst: true));
      expect(model.configs.map((c) => c.tools.isEmpty), [false, true]);
      expect(model.sessions.first.closed, isTrue);
    });
  });

  test('a companion reply carries the audio that was played', () async {
    final engine = CompanionConversation(
      vad: null,
      transcriber: null,
      llm: _Llm(),
      speak: _speech,
      io: FakeConversationAudio(),
      systemPrompt: 'x',
    );
    final events = <ConversationEvent>[];
    engine.events.listen(events.add);
    await engine.start();
    await engine.sendText('hi');
    await pumpEventQueue(); // events are delivered asynchronously
    final audio = events.whereType<ReplyAudio>().single;
    expect(audio.bytes.length, 4800);
    expect(audio.format.sampleRate, 24000);
    await engine.stop();
  });

  test('reply audio is saved with its own line', () async {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final dir = await Directory.systemTemp.createTemp('chat_audio');
    addTearDown(() => dir.delete(recursive: true));
    final character = (await database.getAllVoiceAssets()).first;
    final chat = await database.createChatSession(
      voiceAssetId: character.id,
      engine: ChatEngine.realtime.name,
      title: 't',
    );
    final recorder = ChatRecorder(database, chat.id, audioDir: () async => dir);
    const pcm = TtsAudioFormat(
      AudioEncoding.pcmS16le,
      sampleRate: 24000,
      channels: 1,
    );
    // Text first, then its audio (a structured reply, a call).
    recorder.user('one');
    recorder.reply('First.', emotion: 'happy');
    recorder.audio(pcm, Uint8List(480));
    // Audio first (a streamed reply), then the text.
    recorder.user('two');
    recorder.audio(pcm, Uint8List(960));
    recorder.reply('Second.');
    // A reply whose audio never came; the next audio is not its.
    recorder.user('three');
    recorder.reply('Silent.');
    recorder.user('four');
    recorder.audio(pcm, Uint8List(100));
    await recorder.idle;

    final lines = await database.getChatMessages(chat.id);
    String? audioOf(String text) =>
        chatMeta(lines.firstWhere((m) => m.content == text))['audio']
            as String?;
    expect(File(audioOf('First.')!).lengthSync(), 480 + 44);
    expect(File(audioOf('Second.')!).lengthSync(), 960 + 44);
    expect(audioOf('Silent.'), isNull);
    expect(
      chatMeta(lines.firstWhere((m) => m.content == 'First.'))['emotion'],
      'happy',
    );
  });
}
