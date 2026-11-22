// Live checks for Azure Speech, Xiaomi MiMo and Gemini Lyria. Each group is
// skipped unless its key is set (from .env):
//   set -a; source .env; set +a
//   flutter test scripts/tests/ai_vendors_live_test.dart
// VENDOR_TEST_OUT_DIR (optional) keeps the audio for listening.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/catalog/llm_discovery.dart';
import 'package:neiroha/data/ai/catalog/llm_traits_catalog.dart';
import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/registry/built_in_voices.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:path/path.dart' as p;

const _timeout = Timeout(Duration(minutes: 5));

db.TtsProvider _row(
  AdapterType type,
  String url,
  String key, {
  String? model,
}) => db.TtsProvider(
  id: type.name,
  name: type.displayName,
  adapterType: type.name,
  baseUrl: url,
  apiKey: key,
  defaultModelName: model ?? type.defaultModel,
  enabled: true,
  position: 0,
  maxConcurrency: 1,
);

void _keep(String name, List<int> bytes) {
  final dir = Platform.environment['VENDOR_TEST_OUT_DIR'];
  if (dir == null || dir.isEmpty) return;
  Directory(dir).createSync(recursive: true);
  File(p.join(dir, name)).writeAsBytesSync(bytes);
}

void main() {
  final env = Platform.environment;

  group('Azure Speech', () {
    final key = env['AZURE_KEY'] ?? '';
    final url = env['AZURE_URL'] ?? '';
    final skip = key.isEmpty || url.isEmpty
        ? 'AZURE_URL / AZURE_KEY not set'
        : null;
    final row = _row(AdapterType.azureTts, url, key);

    test(
      'health, voice list and zh-CN synthesis',
      () async {
        final adapter = createAdapter(row);
        expect(await adapter.healthCheck(), isTrue);
        final voices = await adapter.getSpeakers();
        // ignore: avoid_print
        print('Azure voices: ${voices.length}');
        expect(voices, contains('zh-CN-XiaoxiaoNeural'));
        final r = await adapter.synthesize(
          const TtsRequest(text: '指挥官，吾在此守候。', voice: 'zh-CN-XiaoxiaoNeural'),
        );
        expect(r.audioBytes.length, greaterThan(4000));
        _keep(
          'azure.${r.contentType.contains('wav') ? 'wav' : 'mp3'}',
          r.audioBytes,
        );
        // Streaming (the app's default) gets PCM labelled audio/basic.
        final pcm = await adapter
            .synthesizeStream(
              const TtsRequest(
                text: '流式试听。',
                voice: 'zh-CN-XiaoxiaoNeural',
                responseFormat: 'pcm',
              ),
              cancellation: TtsCancelToken(),
            )
            .fold<int>(
              0,
              (n, e) => e is TtsAudioChunk ? n + e.bytes.length : n,
            );
        expect(pcm, greaterThan(4800));
        final health = await connectionForProvider(row).check();
        expect(health[AiCapability.tts]!.state, HealthState.ok);
      },
      skip: skip,
      timeout: _timeout,
    );
  });

  group('Xiaomi MiMo', () {
    final key = env['MIMO_KEY'] ?? '';
    final url = env['MIMO_URL'] ?? '';
    final skip = key.isEmpty || url.isEmpty
        ? 'MIMO_URL / MIMO_KEY not set'
        : null;
    final row = _row(AdapterType.chatCompletionsTts, url, key);

    test(
      'built-in voices per TTS model and synthesis',
      () async {
        final voices = builtInVoicesFor(
          AdapterType.chatCompletionsTts,
          row.defaultModelName,
        );
        expect(voices, isNotEmpty);
        final r = await createAdapter(
          row,
        ).synthesize(TtsRequest(text: '指挥官，今天的海风很温柔。', voice: voices[1]));
        expect(r.audioBytes.length, greaterThan(4000));
        _keep('mimo.wav', r.audioBytes);
      },
      skip: skip,
      timeout: _timeout,
    );

    test(
      'LLM: health, chat and discovery',
      () async {
        final c = connectionForProvider(row);
        final health = await c.check();
        // ignore: avoid_print
        print(
          health.entries.map((e) => '${e.key.name}: ${e.value}').join('\n'),
        );
        expect(health[AiCapability.llm]!.state, HealthState.ok);
        try {
          final reply = await c.languageModel()!.complete(const [
            LlmChatMessage(
              role: 'user',
              content: 'Reply with the single word: ok',
            ),
          ], maxOutputTokens: 512);
          expect(reply.toLowerCase(), contains('ok'));
        } catch (error) {
          // An unfunded account still proves auth and routing.
          if (!'$error'.contains('insufficient_balance')) rethrow;
          // ignore: avoid_print
          print('MiMo chat skipped: account balance is empty');
        }
        final catalog = LlmTraitsCatalog.fromSnapshot(
          jsonDecode(File(LlmTraitsCatalog.asset).readAsStringSync())
              as Map<String, dynamic>,
        );
        final inventory = await LlmDiscovery(catalog).discover(c);
        // ignore: avoid_print
        print(
          inventory.models.map((m) => '${m.id} ${m.source.name}').join('\n'),
        );
        expect(inventory.state, HealthState.ok, reason: inventory.message);
      },
      skip: skip,
      timeout: _timeout,
    );
  });

  group('Xiaomi MiMo ASR', () {
    final key = env['MIMO_KEY'] ?? '';
    final url = env['MIMO_URL'] ?? '';
    final skip = key.isEmpty || url.isEmpty
        ? 'MIMO_URL / MIMO_KEY not set'
        : null;

    test(
      'TTS → mimo-v2.5-asr round trip',
      () async {
        final row = _row(AdapterType.chatCompletionsTts, url, key);
        final c = connectionForProvider(row);
        final health = await c.check();
        expect(health[AiCapability.stt]!.models, ['mimo-v2.5-asr']);
        final speech = await createAdapter(
          row,
        ).synthesize(const TtsRequest(text: '早上好，会议九点开始。', voice: '冰糖'));
        try {
          final t = await c.transcriber()!.transcribe(
            AudioInput(speech.audioBytes),
            options: const TranscribeOptions(languages: ['zh']),
          );
          // ignore: avoid_print
          print('MiMo ASR: ${t.text}');
          expect(t.text, contains('会议'));
        } on AiProviderException catch (error) {
          if (error.statusCode != 402) rethrow;
          markTestSkipped('MiMo account balance is empty');
        }
      },
      skip: skip,
      timeout: _timeout,
    );
  });

  group('Gemini Lyria', () {
    final key = env['GEMINI_API_KEY'] ?? env['GEMINI_KEY'] ?? '';
    final skip = key.isEmpty ? 'GEMINI_API_KEY / GEMINI_KEY not set' : null;
    final c = connectionForProvider(_row(AdapterType.geminiTts, '', key));

    test(
      '30 s clip with sung, timed lyrics',
      () async {
        final song = await c
            .musicGenerator('lyria-3-clip-preview')!
            .compose(
              const MusicRequest(
                prompt: 'Bright city-pop, female vocalist, singing in Chinese.',
                lyrics: '[Verse]\n晨光洒在港口\n[Chorus]\n长门守护着你',
              ),
            );
        // ignore: avoid_print
        print(song.rawLyrics);
        expect(song.mimeType, 'audio/mpeg');
        expect(song.timed, isTrue);
        expect(song.lyrics.map((l) => l.text).join(), contains('港口'));
        _keep('lyria-clip.mp3', song.audio);
      },
      skip: skip,
      timeout: _timeout,
    );
  });
}
