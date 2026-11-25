// Contract test for self-hosted GPT-SoVITS (OpenAI-compatible wrapper) and
// Irodori servers, driven through the app's provider factory.
//
// Offline (default): every case runs against a loopback fake that replays the
// JSON shapes and error bodies recorded from the real servers, so CI and
// machines without the Tailnet still verify the contract.
//
// Live (opt-in): set the base URLs and the same cases also run against the
// real servers. An unreachable server is skipped rather than failed:
//
//   set -a; source .env; set +a   # GPT_SOVITS_URL, IRODORI_URL
//   TTS_TEST_OUT_DIR=/tmp/tts flutter test scripts/tests/self_hosted_tts_contract_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/providers/local/irodori/tts/irodori_adapter.dart';
import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:path/path.dart' as p;

const _text = '指挥官、今日もお疲れさまでした。';
const _sovitsModel = 'azurlane-voices-v5dev';
const _sovitsNagato = 'al-ship-30505-ja-v5dev';
const _irodoriNagato = 'al-ship-30505-ja';

// ── Recorded server shapes (trimmed) ─────────────────────────────────────────

const _sovitsHealth = {
  'status': 'ok',
  'backend': 'gpt-sovits',
  'model': _sovitsModel,
  'voice_count': 2,
};
const _sovitsModels = {
  'object': 'list',
  'data': [
    {
      'id': _sovitsModel,
      'object': 'model',
      'owned_by': 'neiroha',
      'name': 'Azur Lane V5 Dev',
      'voice_count': 2,
    },
  ],
};
const _sovitsVoices = {
  'object': 'list',
  'data': [
    {
      'id': _sovitsNagato,
      'voice_id': _sovitsNagato,
      'model': _sovitsModel,
      'name': '长门',
    },
    {
      'id': 'al-ship-970506-ja-v5dev',
      'voice_id': 'al-ship-970506-ja-v5dev',
      'model': _sovitsModel,
      'name': '长门·META',
    },
  ],
};
const _irodoriHealth = {
  'backend': 'irodori',
  'version': '0.2.0',
  'status': 'ok',
  'loaded_model_preset': 'azurlane-lora',
};
const _irodoriModels = {
  'object': 'list',
  'data': [
    {'id': 'azurlane', 'name': 'Azur Lane · Moear Irodori LoRA'},
    {'id': 'default', 'name': 'Irodori v4.1 Small'},
    {'id': 'meanflow', 'name': 'Irodori MeanFlow'},
  ],
};
const _irodoriVoices = {
  'object': 'list',
  'data': [
    {
      'id': _irodoriNagato,
      'voice_id': _irodoriNagato,
      'name': '长门',
      'model': 'azurlane',
      'model_preset': 'azurlane-lora',
      'language': 'ja',
    },
    {
      'id': 'default',
      'voice_id': 'default',
      'name': 'Irodori RF',
      'model': 'default',
      'model_preset': 'default',
    },
    {
      'id': 'meanflow',
      'voice_id': 'meanflow',
      'name': 'Irodori MeanFlow',
      'model': 'meanflow',
      'model_preset': 'meanflow',
    },
  ],
};

/// One second of 48 kHz mono silence, like the real servers' WAV output.
Uint8List _wav({int sampleRate = 48000, int samples = 48000}) {
  final data = samples * 2;
  final b = ByteData(44 + data);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + data, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, data, Endian.little);
  return b.buffer.asUint8List();
}

/// Serves `/sovits/...` and `/irodori/...` the way the real servers do.
Future<HttpServer> _fakeServers() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  void json(HttpResponse r, Object body, [int status = 200]) {
    r.statusCode = status;
    r.headers.contentType = ContentType.json;
    r.write(jsonEncode(body));
  }

  void audio(HttpResponse r) {
    r.headers.contentType = ContentType('audio', 'wav');
    r.add(_wav());
  }

  Set<String> ids(Map<String, Object> catalog, [String? model]) => {
    for (final v in (catalog['data']! as List).cast<Map>())
      if (model == null || v['model'] == model) v['id'] as String,
  };

  server.listen((request) async {
    final r = request.response;
    // Multipart uploads carry binary audio: keep bytes, decode JSON on demand.
    final bytes = await request.fold<BytesBuilder>(
      BytesBuilder(copy: false),
      (b, chunk) => b..add(chunk),
    );
    final raw = bytes.takeBytes();
    final body = request.headers.contentType?.mimeType == 'application/json'
        ? utf8.decode(raw)
        : latin1.decode(raw);
    switch (request.uri.path) {
      case '/sovits/health':
        json(r, _sovitsHealth);
      case '/sovits/v1/models':
        json(r, _sovitsModels);
      case '/sovits/v1/audio/voices':
        json(r, _sovitsVoices);
      case '/sovits/v1/audio/speech':
        final req = jsonDecode(body) as Map<String, dynamic>;
        if (!ids(_sovitsVoices).contains(req['voice'])) {
          json(r, {'detail': 'Choose an ID from /v1/audio/voices.'}, 404);
        } else {
          audio(r);
        }
      case '/irodori/health':
        json(r, _irodoriHealth);
      case '/irodori/v1/models':
        json(r, _irodoriModels);
      case '/irodori/v1/audio/voices':
        json(r, _irodoriVoices);
      case '/irodori/v1/audio/speech':
        final req = jsonDecode(body) as Map<String, dynamic>;
        final set = req['model'] as String? ?? 'default';
        if (!ids(_irodoriVoices, set).contains(req['voice'])) {
          json(r, {
            'error': {
              'code': 'voice_not_found',
              'message': "Voice '${req['voice']}' is unavailable in '$set'.",
              'details': {},
            },
          }, 404);
        } else {
          audio(r);
        }
      case '/irodori/api/irodori/clone':
        final multipart =
            request.headers.contentType?.mimeType == 'multipart/form-data';
        if (multipart &&
            body.contains('name="reference"') &&
            body.contains('name="text"')) {
          audio(r);
        } else {
          json(r, {'detail': 'reference and text are required'}, 422);
        }
      default:
        r.statusCode = HttpStatus.notFound;
    }
    await r.close();
  });
  return server;
}

// ── Shared cases ─────────────────────────────────────────────────────────────

db.TtsProvider _provider(String adapterType, String baseUrl, String model) =>
    db.TtsProvider(
      id: 'contract-$adapterType',
      name: adapterType,
      adapterType: adapterType,
      baseUrl: baseUrl,
      apiKey: '',
      defaultModelName: model,
      enabled: true,
      position: 0,
      maxConcurrency: 1,
    );

void _expectWav(TtsResult result) {
  expect(result.contentType, contains('wav'));
  final bytes = result.audioBytes;
  expect(bytes.length, greaterThan(16000));
  expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
  expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
  final rate = ByteData.sublistView(bytes, 24, 28).getUint32(0, Endian.little);
  expect(rate, greaterThanOrEqualTo(16000));
}

/// A server is live-testable only when its URL is set and `/health` answers.
Future<String?> _liveSkip(String name, String? url) async {
  if (url == null || url.trim().isEmpty) return '$name URL not set';
  final root = url.trim().replaceFirst(RegExp(r'/v1/?$'), '');
  try {
    final res = await Dio(
      BaseOptions(connectTimeout: const Duration(seconds: 3)),
    ).get<Object>('$root/health');
    return res.statusCode == 200
        ? null
        : '$name health returned ${res.statusCode}';
  } on DioException catch (e) {
    return '$name unreachable at $root (${e.type.name})';
  }
}

void _sovitsCases(
  String Function() url,
  void Function(String, TtsResult) keep,
) {
  TtsAdapter adapter() =>
      createAdapter(_provider('gptSovits', url(), _sovitsModel));

  test('health and model discovery', () async {
    expect(await adapter().healthCheck(), isTrue);
    expect(
      (await adapter().getModels()).map((m) => m.id),
      contains(_sovitsModel),
    );
  });

  test('speaker discovery includes Nagato', () async {
    final speakers = await adapter().getSpeakers();
    expect(speakers.map(voiceIdFromLabel), contains(_sovitsNagato));
  });

  test('preset voice synthesis', () async {
    final r = await adapter().synthesize(
      const TtsRequest(
        text: _text,
        voice: _sovitsNagato,
        textLang: 'ja',
        responseFormat: 'wav',
      ),
    );
    _expectWav(r);
    keep('sovits-nagato.wav', r);
  });

  test('unknown voice surfaces the server reason', () async {
    await expectLater(
      adapter().synthesize(const TtsRequest(text: _text, voice: 'nope')),
      throwsA(predicate((e) => '$e'.contains('/v1/audio/voices'))),
    );
  });
}

void _irodoriCases(
  String Function() url,
  void Function(String, TtsResult) keep,
) {
  TtsAdapter adapter([String model = 'azurlane']) =>
      createAdapter(_provider('irodori', url(), model));

  test('factory builds IrodoriAdapter and health passes', () async {
    expect(adapter(), isA<IrodoriAdapter>());
    expect(await adapter().healthCheck(), isTrue);
  });

  test('voice-set and speaker discovery', () async {
    final models = (await adapter().getModels()).map((m) => m.id);
    expect(models, containsAll(['default', 'azurlane']));
    final irodori = adapter() as IrodoriAdapter;
    final azurlane = await irodori.getSpeakersForVoiceSet('azurlane');
    expect(azurlane.map(voiceIdFromLabel), contains(_irodoriNagato));
    expect(await irodori.getSpeakersForVoiceSet('default'), isNotEmpty);
  });

  test('azurlane preset voice from a picker label', () async {
    final irodori = adapter() as IrodoriAdapter;
    final label = (await irodori.getSpeakersForVoiceSet(
      'azurlane',
    )).firstWhere((l) => voiceIdFromLabel(l) == _irodoriNagato);
    final r = await adapter().synthesize(
      TtsRequest(text: _text, voice: label, responseFormat: 'wav'),
    );
    _expectWav(r);
    keep('irodori-azurlane-nagato.wav', r);
  });

  test('default voice set', () async {
    final r = await adapter(
      'default',
    ).synthesize(const TtsRequest(text: _text, voice: 'default'));
    _expectWav(r);
    keep('irodori-default.wav', r);
  });

  test('reference clone through the native endpoint', () async {
    final dir = await Directory.systemTemp.createTemp('irodori_ref');
    addTearDown(() => dir.delete(recursive: true));
    final seed = await adapter().synthesize(
      const TtsRequest(text: _text, voice: _irodoriNagato),
    );
    final ref = File(p.join(dir.path, 'nagato_ref.wav'))
      ..writeAsBytesSync(seed.audioBytes);
    final r = await adapter().synthesize(
      TtsRequest(
        text: '吾は長門、よろしく頼む。',
        voice: 'clone',
        refAudioPath: ref.path,
        voiceInstruction: '落ち着いた声',
      ),
    );
    _expectWav(r);
    keep('irodori-clone.wav', r);
  });

  test('unknown voice surfaces the server reason', () async {
    await expectLater(
      adapter().synthesize(const TtsRequest(text: _text, voice: 'nope')),
      throwsA(predicate((e) => '$e'.contains('unavailable'))),
    );
  });
}

Future<void> main() async {
  final env = Platform.environment;
  final outDir = env['TTS_TEST_OUT_DIR'];
  final sovitsLive = await _liveSkip('GPT_SOVITS', env['GPT_SOVITS_URL']);
  final irodoriLive = await _liveSkip('IRODORI', env['IRODORI_URL']);

  void keep(String name, TtsResult r) {
    if (outDir == null || outDir.isEmpty) return;
    Directory(outDir).createSync(recursive: true);
    File(p.join(outDir, name)).writeAsBytesSync(r.audioBytes);
  }

  void discard(String _, TtsResult _) {}

  group('offline contract', () {
    late HttpServer server;
    setUpAll(() async => server = await _fakeServers());
    tearDownAll(() => server.close(force: true));
    String root(String prefix) =>
        'http://${server.address.address}:${server.port}/$prefix/v1';

    group('GPT-SoVITS', () => _sovitsCases(() => root('sovits'), discard));
    group('Irodori', () => _irodoriCases(() => root('irodori'), discard));
  });

  group('live', () {
    group(
      'GPT-SoVITS',
      () => _sovitsCases(() => env['GPT_SOVITS_URL']!, keep),
      skip: sovitsLive,
    );
    group(
      'Irodori',
      () => _irodoriCases(() => env['IRODORI_URL']!, keep),
      skip: irodoriLive,
    );
  });
}
