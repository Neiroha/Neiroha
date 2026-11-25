// Live check of the dialog and subtitle features on OpenAI. Skipped unless
// OPENAI_TEST_API_KEY (or OPENAI_KEY from .env) is set:
//
//   set -a; source .env; set +a
//   flutter test scripts/tests/ai_features_live_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/core/connection_config.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/protocols/audio/pcm_resample.dart';
import 'package:neiroha/data/ai/providers/on_device/on_device_plugin.dart';
import 'package:neiroha/data/ai/providers/openai/openai_plugin.dart';
import 'package:neiroha/data/services/conversation/companion_conversation.dart';
import 'package:neiroha/data/services/conversation/conversation_engine.dart';
import 'package:neiroha/data/services/conversation/realtime_conversation.dart';
import 'package:neiroha/data/services/subtitles/subtitle_pipeline.dart';
import 'package:neiroha/data/services/subtitles/subtitle_translator.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/synthesis/tts_request.dart';

import 'support/fake_conversation_audio.dart';

const _timeout = Timeout(Duration(minutes: 3));

void main() {
  final env = Platform.environment;
  final key = env['OPENAI_TEST_API_KEY'] ?? env['OPENAI_KEY'] ?? '';
  final skip = key.isEmpty ? 'OPENAI_TEST_API_KEY / OPENAI_KEY not set' : null;
  final openai = const OpenAiPlugin().connect(
    ConnectionConfig(id: 'live', baseUrl: '', apiKey: key),
  );
  final vad = OnDevicePlugin.builtIn().vad()!;

  Stream<TtsEvent> speak(String text, TtsCancelToken cancellation) =>
      openai.speechModel()!.synthesize(
        TtsRequest(text: text, voice: 'marin', responseFormat: 'pcm'),
        cancellation: cancellation,
      );

  /// 16 kHz PCM16 of [text] with half a second of silence around it.
  Future<Uint8List> spoken(String text) async {
    final pcm = BytesBuilder(copy: false)..add(Uint8List(16000));
    final raw = BytesBuilder(copy: false);
    await for (final e in speak(text, TtsCancelToken())) {
      if (e is TtsAudioChunk) raw.add(e.bytes);
    }
    pcm
      ..add(resamplePcm16(raw.takeBytes(), 24000, 16000))
      ..add(Uint8List(16000));
    return pcm.takeBytes();
  }

  Future<List<ConversationEvent>> untilReply(
    ConversationEngine engine,
    Future<void> Function() act,
  ) async {
    final events = <ConversationEvent>[];
    final sub = engine.events.listen(events.add);
    await act();
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (!events.any((e) => e is CharacterTurn && e.done) ||
        events.whereType<ConversationStateChanged>().lastOrNull?.state !=
            ConversationState.listening) {
      if (DateTime.now().isAfter(deadline)) fail('no reply: $events');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await sub.cancel();
    return events;
  }

  test(
    'realtime conversation answers a typed turn with audio (server VAD)',
    () async {
      final io = FakeConversationAudio();
      final engine = RealtimeConversation(
        model: openai.realtimeModel()!,
        io: io,
        instructions: 'You are Nagato, a calm and polite battleship girl.',
      );
      await engine.start();
      final events = await untilReply(
        engine,
        () => engine.sendText('Greet me in one short sentence.'),
      );
      final reply = events.whereType<CharacterTurn>().last.text;
      expect(reply, isNotEmpty);
      expect(io.sinks.single.bytes.length, greaterThan(24000));
      await engine.stop();
    },
    skip: skip,
    timeout: _timeout,
  );

  test(
    'companion hears speech, answers in character and speaks',
    () async {
      final io = FakeConversationAudio();
      final engine = CompanionConversation(
        vad: vad,
        transcriber: openai.transcriber()!,
        llm: openai.languageModel()!,
        speak: speak,
        io: io,
        systemPrompt: 'You are Nagato. Answer in English.',
      );
      await engine.start();
      final audio = await spoken('What colour is the sky on a clear day?');
      final events = await untilReply(engine, () async {
        engine.onAudioForTest(audio);
      });
      expect(
        events.whereType<UserTurn>().single.text.toLowerCase(),
        contains('sky'),
      );
      expect(events.whereType<CharacterTurn>().last.text, isNotEmpty);
      expect(io.sinks.single.bytes.length, greaterThan(24000));
      await engine.stop();
    },
    skip: skip,
    timeout: _timeout,
  );

  test(
    'subtitle pipeline transcribes VAD chunks and translates them',
    () async {
      final first = await spoken('Good morning, everyone.');
      final second = await spoken('The meeting starts at nine.');
      final pipeline = SubtitlePipeline(
        decode: (_, _) async =>
            Uint8List.fromList([...first, ...Uint8List(16000), ...second]),
        vad: vad,
        transcriber: openai.transcriber()!,
        translator: SubtitleTranslator(openai.languageModel()!),
      );
      final cues = await pipeline.run(
        const SubtitleJob('memory.wav', targetLanguage: 'Chinese (Simplified)'),
      );
      expect(cues, hasLength(2));
      expect(cues.first.text.toLowerCase(), contains('morning'));
      expect(cues.last.start, greaterThan(cues.first.end));
      for (final c in cues) {
        expect(c.translation, matches(RegExp(r'[一-鿿]')));
      }
    },
    skip: skip,
    timeout: _timeout,
  );
}
