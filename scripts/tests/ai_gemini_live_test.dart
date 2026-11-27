// Live check of every Gemini capability. Skipped unless GEMINI_API_KEY or
// GEMINI_KEY (from .env) is set:
//   set -a; source .env; set +a
//   flutter test scripts/tests/ai_gemini_live_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/catalog/llm_discovery.dart';
import 'package:neiroha/data/ai/catalog/llm_traits_catalog.dart';
import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/protocols/audio/pcm_resample.dart';
import 'package:neiroha/data/ai/protocols/audio/wav_utils.dart';
import 'package:neiroha/data/ai/providers/gemini/gemini_connection.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/synthesis/tts_request.dart';

const _timeout = Timeout(Duration(minutes: 3));
const _sentence = 'Good morning everyone. The meeting starts at nine.';

/// (pcm16 mono, sample rate) from WAV or raw PCM bytes.
(Uint8List, int) _pcm(Uint8List bytes, int fallbackRate) {
  if (!isRiffWav(bytes)) return (bytes, fallbackRate);
  final data = ByteData.sublistView(bytes);
  var rate = fallbackRate;
  for (var i = 12; i + 8 <= bytes.length;) {
    final id = ascii.decode(bytes.sublist(i, i + 4));
    final size = data.getUint32(i + 4, Endian.little);
    if (id == 'fmt ') rate = data.getUint32(i + 12, Endian.little);
    if (id == 'data') {
      return (Uint8List.sublistView(bytes, i + 8, i + 8 + size), rate);
    }
    i += 8 + size + (size.isOdd ? 1 : 0);
  }
  throw const FormatException('No data chunk.');
}

void main() {
  final env = Platform.environment;
  final key = env['GEMINI_API_KEY'] ?? env['GEMINI_KEY'] ?? '';
  final skip = key.isEmpty ? 'GEMINI_API_KEY / GEMINI_KEY not set' : null;
  final gemini =
      connectionForProvider(
            db.TtsProvider(
              id: 'live',
              name: 'Gemini',
              adapterType: AdapterType.geminiTts.name,
              baseUrl: 'https://generativelanguage.googleapis.com',
              apiKey: key,
              defaultModelName: AdapterType.geminiTts.defaultModel,
              enabled: true,
              position: 0,
              maxConcurrency: 1,
            ),
          )
          as GeminiConnection;
  Uint8List? speech16k;

  Future<Uint8List> speech() async {
    if (speech16k != null) return speech16k!;
    final bytes = BytesBuilder(copy: false);
    TtsAudioFormat? format;
    await for (final e in gemini.speechModel()!.synthesize(
      const TtsRequest(text: _sentence, voice: 'Kore'),
      cancellation: TtsCancelToken(),
    )) {
      if (e is TtsAudioStarted) format = e.format;
      if (e is TtsAudioChunk) bytes.add(e.bytes);
    }
    final (pcm, rate) = _pcm(bytes.takeBytes(), format?.sampleRate ?? 24000);
    return speech16k = resamplePcm16(pcm, rate, 16000);
  }

  test(
    'health: every capability sees its catalog models',
    () async {
      final health = await gemini.check();
      // ignore: avoid_print
      print(health.entries.map((e) => '${e.key.name}: ${e.value}').join('\n'));
      for (final cap in gemini.capabilities) {
        expect(health[cap]!.state, HealthState.ok, reason: cap.name);
      }
    },
    skip: skip,
    timeout: _timeout,
  );

  test(
    'LLM discovery lists chat models with traits',
    () async {
      final catalog = LlmTraitsCatalog.fromSnapshot(
        jsonDecode(File(LlmTraitsCatalog.asset).readAsStringSync())
            as Map<String, dynamic>,
      );
      final inventory = await LlmDiscovery(catalog).discover(gemini);
      // ignore: avoid_print
      print(
        '${inventory.state} ${inventory.message ?? ''}\n'
        '${inventory.models.map((m) => '${m.id} ${m.source.name} '
            'think=${m.llm?.reasoning?.levels.map((e) => e.name).join('/')}'
            ' tools=${m.llm?.tools}').join('\n')}',
      );
      expect(inventory.state, HealthState.ok, reason: inventory.message);
      final ids = inventory.models.map((m) => m.id).toSet();
      expect(ids, containsAll(['gemini-3.8-flash', 'gemini-4-hydrogen']));
      expect(ids.where((id) => id.contains('tts')), isEmpty);
      expect(ids.where((id) => id.contains('embedding')), isEmpty);
    },
    skip: skip,
    timeout: _timeout,
  );

  test(
    'native generateContent: text and JSON schema',
    () async {
      final llm = gemini.languageModel()!;
      final text = await llm.complete(const [
        LlmChatMessage(role: 'system', content: 'Answer in one word.'),
        LlmChatMessage(role: 'user', content: 'What colour is a ripe banana?'),
      ]);
      expect(text.toLowerCase(), contains('yellow'));
      final result = await llm.structured(
        const [
          LlmChatMessage(
            role: 'user',
            content: 'Who speaks: "Hi," said Alice.',
          ),
        ],
        schemaName: 'speaker',
        schema: const {
          'type': 'object',
          'properties': {
            'speaker': {'type': 'string'},
          },
          'required': ['speaker'],
        },
      );
      expect(result.object['speaker'], 'Alice');
    },
    skip: skip,
    timeout: _timeout,
  );

  test(
    'TTS → file transcription (Interactions)',
    () async {
      final pcm = await speech();
      final t = await gemini.transcriber()!.transcribe(
        AudioInput(wrapPcmAsWav(pcm, sampleRate: 16000)),
        options: const TranscribeOptions(languages: ['en']),
      );
      // ignore: avoid_print
      print('transcript: ${t.text}');
      expect(t.text.toLowerCase(), contains('meeting'));
    },
    skip: skip,
    timeout: _timeout,
  );

  test(
    'Live streaming transcription',
    () async {
      final pcm = await speech();
      final session = await gemini
          .streamingTranscriber('gemini-3.5-transcribe-live')!
          .open(options: const TranscribeOptions(languages: ['en']));
      final events = <AiSessionEvent>[];
      session.events.listen(events.add, onError: (_) {});
      for (var i = 0; i < pcm.length; i += 3200) {
        session.sendPcm(
          Uint8List.sublistView(pcm, i, (i + 3200).clamp(0, pcm.length)),
        );
      }
      await session.finish(timeout: const Duration(seconds: 60));
      await session.close();
      final text = events.whereType<TranscriptFinal>().last.text;
      // ignore: avoid_print
      print('live transcript: $text');
      expect(text.toLowerCase(), contains('meeting'));
    },
    skip: skip,
    timeout: _timeout,
  );

  for (final serverVad in [false, true]) {
    test(
      'Live conversation (serverVad: $serverVad): typed and spoken turns',
      () async {
        final session = await gemini.realtimeModel()!.connect(
          RealtimeConfig(
            instructions:
                'You are Nagato. Reply in one short English sentence.',
            voice: 'Kore',
            transcribeInput: true,
            serverVad: serverVad,
          ),
        );
        final events = <AiSessionEvent>[];
        session.events.listen(events.add, onError: (_) {});
        session.sendText('Say good morning to me.');
        final typed = await session.respond(
          timeout: const Duration(seconds: 60),
        );
        expect(events.whereType<AudioDelta>(), isNotEmpty);
        // ignore: avoid_print
        print('typed reply: ${typed.text}');
        expect(typed.text, isNotEmpty);

        events.clear();
        final pcm = await speech();
        for (var i = 0; i < pcm.length; i += 3200) {
          session.sendPcm(
            Uint8List.sublistView(pcm, i, (i + 3200).clamp(0, pcm.length)),
          );
        }
        if (serverVad) {
          // Trailing silence lets the server detect the end of the turn.
          for (var i = 0; i < 15; i++) {
            session.sendPcm(Uint8List(3200));
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        }
        await session.finish(timeout: const Duration(seconds: 60));
        final heard = events.whereType<TranscriptFinal>();
        // ignore: avoid_print
        print(
          'heard: ${heard.map((e) => e.text)} → '
          '${events.whereType<ResponseDone>().map((e) => e.text)}',
        );
        expect(heard.single.text.toLowerCase(), contains('meeting'));
        expect(events.whereType<AudioDelta>(), isNotEmpty);
        await session.close();
      },
      skip: skip,
      timeout: _timeout,
    );
  }

  test(
    'Live speech translation to Chinese',
    () async {
      final pcm = await speech();
      final session = await gemini.translator()!.open(
        targetLanguage: 'zh-Hans',
      );
      final events = <AiSessionEvent>[];
      session.events.listen(events.add, onError: (_) {});
      for (var i = 0; i < pcm.length; i += 3200) {
        session.sendPcm(
          Uint8List.sublistView(pcm, i, (i + 3200).clamp(0, pcm.length)),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      try {
        await session.finish(timeout: const Duration(seconds: 45));
      } finally {
        await session.close();
      }
      final source = events.whereType<TranscriptDelta>().where((e) => e.source);
      final target = events.whereType<TranscriptDelta>().where(
        (e) => !e.source,
      );
      // ignore: avoid_print
      print(
        'source: ${source.map((e) => e.text).join()}\n'
        'target: ${target.map((e) => e.text).join()}',
      );
      expect(events.whereType<AudioDelta>(), isNotEmpty);
      expect(target.map((e) => e.text).join(), matches(RegExp(r'[一-鿿]')));
    },
    skip: skip,
    timeout: _timeout,
  );
}
