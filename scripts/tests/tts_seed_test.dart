import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/ai/providers/local/cosyvoice/tts/cosyvoice_adapter.dart';
import 'package:neiroha/data/ai/providers/local/gpt_sovits/tts/gpt_sovits_adapter.dart';
import 'package:neiroha/data/ai/providers/local/irodori/tts/irodori_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/novel_audio_fingerprint.dart';
import 'package:neiroha/data/services/synthesis/quick_tts_service.dart';
import 'package:neiroha/domain/voice_capabilities.dart';
import 'package:neiroha/presentation/widgets/voice_character/character_seed_field.dart';
import 'package:neiroha/server/speech_resolver.dart';

/// One request the fake engine received: its path and raw body.
typedef _Received = ({String path, String body});

Future<(HttpServer, List<_Received>)> _engine() async {
  final received = <_Received>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen((request) async {
    if (request.uri.path.endsWith('/voices')) {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'data': []}));
    } else {
      received.add((
        path: request.uri.path,
        body: await utf8.decoder.bind(request).join(),
      ));
      request.response.headers.contentType = ContentType('audio', 'wav');
      request.response.add([82, 73, 70, 70]);
    }
    await request.response.close();
  });
  return (server, received);
}

/// The value of [field] in a JSON or multipart body, or null when absent.
String? _field(String body, String field) {
  if (body.startsWith('{')) {
    return (jsonDecode(body) as Map<String, dynamic>)[field]?.toString();
  }
  final match = RegExp(
    'name="$field"\\r\\n\\r\\n([^\\r]*)\\r\\n',
  ).firstMatch(body);
  return match?.group(1);
}

db.VoiceAsset _asset({int? seed, String? ref}) => db.VoiceAsset(
  id: 'voice',
  name: 'Voice',
  providerId: 'provider',
  taskMode: ref == null ? 'presetVoice' : 'cloneWithPrompt',
  presetVoiceName: 'speaker',
  refAudioPath: ref,
  promptText: ref == null ? null : 'reference',
  speed: 1,
  enabled: true,
  loudnessOffsetDb: 0,
  seed: seed,
);

db.TtsProvider _provider(String adapterType, int port) => db.TtsProvider(
  id: 'provider',
  name: adapterType,
  adapterType: adapterType,
  baseUrl: 'http://127.0.0.1:$port',
  apiKey: '',
  defaultModelName: 'default',
  enabled: true,
  position: 0,
  maxConcurrency: 1,
);

void main() {
  late String reference;
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('tts_seed_test');
    reference = '${dir.path}/reference.wav';
    await File(reference).writeAsString('reference-data');
  });

  final engines = <String, TtsAdapter Function(String baseUrl)>{
    'cosyvoice': (url) =>
        CosyVoiceAdapter(baseUrl: url, apiKey: '', modelName: 'zero_shot'),
    'gptSovits': (url) => GptSovitsAdapter(baseUrl: url, apiKey: ''),
    'irodori': (url) =>
        IrodoriAdapter(baseUrl: url, apiKey: '', modelName: 'azurlane'),
  };

  for (final MapEntry(key: type, value: create) in engines.entries) {
    test(
      '$type sends the character seed with preset and clone voices',
      () async {
        final (server, received) = await _engine();
        final provider = _provider(type, server.port);
        final adapter = create(provider.baseUrl);
        expect(VoiceCapabilities.supportsSeed(type), isTrue);

        for (final ref in [null, reference]) {
          for (final seed in [null, 4294967295]) {
            final asset = _asset(seed: seed, ref: ref);
            await adapter.synthesize(quickTtsRequest(asset, provider, 'Line'));
            final body = received.last.body;
            expect(
              _field(body, 'seed'),
              seed?.toString(),
              reason: '${received.last.path} with ref=$ref',
            );
          }
        }
        expect(received, hasLength(4));
      },
    );
  }

  test('engines without a seed control do not offer one', () {
    for (final type in [
      'openaiTts',
      'azureTts',
      'geminiTts',
      'voxcpm2Native',
    ]) {
      expect(VoiceCapabilities.supportsSeed(type), isFalse, reason: type);
    }
  });

  test('seed field accepts empty or 0..4294967295 only', () {
    expect(parseCharacterSeed(''), (null, true));
    expect(parseCharacterSeed(' 42 '), (42, true));
    expect(parseCharacterSeed('4294967295'), (4294967295, true));
    for (final bad in ['-1', '4294967296', '1.5', 'abc']) {
      expect(parseCharacterSeed(bad).$2, isFalse, reason: bad);
    }
  });

  test('novel cache follows the seed once one is set', () {
    final project = db.NovelProject(
      id: 'novel',
      name: 'Novel',
      bankId: 'bank',
      readerTheme: 'comfort',
      fontSize: 20,
      lineHeight: 1.8,
      autoTurnPage: true,
      autoAdvanceChapters: true,
      autoSliceLongSegments: true,
      sliceOnlyAtPunctuation: true,
      maxSliceChars: 80,
      prefetchSegments: 3,
      playbackGapSeconds: 0,
      overwriteCacheWhilePlaying: false,
      skipPunctuationOnlySegments: true,
      autoNormalizeLoudness: false,
      cacheCurrentColor: '#2F6B54',
      cacheStaleColor: '#7A5A2A',
      cacheHighlightOpacity: 0.24,
      currentGlobalIndex: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    const segment = db.NovelSegment(
      id: 'segment',
      projectId: 'novel',
      chapterId: 'chapter',
      globalIndex: 0,
      orderIndex: 0,
      segmentText: '指挥官，欢迎回来。',
      segmentType: 'narrator',
      missing: false,
    );
    final provider = _provider('cosyvoice', 9880);
    String key(int? seed) => NovelAudioFingerprint.build(
      project: project,
      segment: segment,
      asset: _asset(seed: seed),
      provider: provider,
    );
    expect(key(null), key(null));
    expect(key(7), isNot(key(null)));
    expect(key(7), isNot(key(8)));
    expect(key(7), key(7));
  });

  test(
    'local speech API uses the character seed; body seed overrides',
    () async {
      final database = db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.insertProvider(
        const db.TtsProvidersCompanion(
          id: Value('seed-provider'),
          name: Value('CosyVoice'),
          adapterType: Value('cosyvoice'),
          baseUrl: Value('http://127.0.0.1:9880'),
        ),
      );
      await database.insertVoiceAsset(
        const db.VoiceAssetsCompanion(
          id: Value('seed-voice'),
          name: Value('Seeded voice'),
          providerId: Value('seed-provider'),
          taskMode: Value('presetVoice'),
          seed: Value(123),
        ),
      );
      Future<int?> seedFor(Map<String, dynamic> extra) async =>
          (await resolveSpeech(database, {
            'input': 'Line',
            'voice': 'Seeded voice',
            ...extra,
          })).request.seed;

      expect(await seedFor({}), 123);
      expect(await seedFor({'seed': 9}), 9);
      for (final bad in [-1, 4294967296, 1.5, '9']) {
        await expectLater(
          seedFor({'seed': bad}),
          throwsA(
            isA<SpeechApiException>().having((e) => e.status, 'status', 400),
          ),
          reason: '$bad',
        );
      }
    },
  );
}
