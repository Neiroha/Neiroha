import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/server/api_server.dart';
import 'package:neiroha/server/mcp/mcp_server.dart';
import 'package:neiroha/server/mcp/neiroha_mcp_tools.dart';
import 'package:shelf/shelf.dart';

void main() {
  late db.AppDatabase database;
  late McpServer mcp;
  var nextId = 0;

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    mcp = McpServer(
      tools: NeirohaMcpTools(database).build(),
      serverVersion: 'test',
      instructions: NeirohaMcpTools.serverInstructions,
    );
  });
  tearDown(() => database.close());

  Future<Response> post(Object body, {Map<String, String>? headers}) {
    return mcp.handle(
      Request(
        'POST',
        Uri.parse('http://127.0.0.1/mcp'),
        body: jsonEncode(body),
        headers: {'content-type': 'application/json', ...?headers},
      ),
    );
  }

  Future<Map<String, dynamic>> rpc(String method, [Object? params]) async {
    final res = await post({
      'jsonrpc': '2.0',
      'id': ++nextId,
      'method': method,
      'params': ?params,
    });
    expect(res.statusCode, 200);
    return jsonDecode(await res.readAsString()) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> call(
    String tool,
    Map<String, dynamic> args,
  ) async {
    final res = await rpc('tools/call', {'name': tool, 'arguments': args});
    final result = res['result'] as Map<String, dynamic>;
    if (result['isError'] == true) {
      fail('$tool failed: ${result['content']}');
    }
    return result['structuredContent'] as Map<String, dynamic>;
  }

  test('initialize echoes protocol version and advertises tools', () async {
    final res = await rpc('initialize', {
      'protocolVersion': '2025-11-25',
      'capabilities': {},
      'clientInfo': {'name': 'test', 'version': '1'},
    });
    final result = res['result'] as Map<String, dynamic>;
    expect(result['protocolVersion'], '2025-11-25');
    expect(result['serverInfo']['name'], 'neiroha');
    expect(result['capabilities']['tools'], isNotNull);

    final notify = await post({
      'jsonrpc': '2.0',
      'method': 'notifications/initialized',
    });
    expect(notify.statusCode, 202);
  });

  test('tools/list exposes the dubbing workflow with schemas', () async {
    final res = await rpc('tools/list');
    final tools = (res['result']['tools'] as List).cast<Map<String, dynamic>>();
    final names = tools.map((t) => t['name']).toSet();
    expect(
      names,
      containsAll([
        'create_provider',
        'delete_provider',
        'create_voice_bank',
        'import_audio_track',
        'create_voice_character',
        'synthesize_speech',
        'import_subtitles',
        'generate_video_dub_audio',
        'export_video_dub',
      ]),
    );
    for (final t in tools) {
      expect(t['inputSchema']['type'], 'object', reason: '${t['name']}');
    }
  });

  Future<int> freePort() async {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = s.port;
    await s.close();
    return port;
  }

  Future<(int, String)> httpPost(int port, Object body, {String? key}) async {
    final client = HttpClient();
    try {
      final req = await client.post('127.0.0.1', port, '/mcp');
      req.headers.contentType = ContentType.json;
      if (key != null) req.headers.set('authorization', 'Bearer $key');
      req.write(jsonEncode(body));
      final res = await req.close();
      return (res.statusCode, await utf8.decodeStream(res));
    } finally {
      client.close(force: true);
    }
  }

  test('ApiServer routes /mcp through its auth middleware', () async {
    final port = await freePort();
    final server = ApiServer(db: database);
    await server.start(
      config: ApiServerConfig(port: port, apiKey: 'k', rateLimitPerMin: 0),
    );
    addTearDown(server.stop);
    final ping = {'jsonrpc': '2.0', 'id': 1, 'method': 'ping'};

    final (denied, _) = await httpPost(port, ping);
    expect(denied, 401);
    final (ok, body) = await httpPost(port, ping, key: 'k');
    expect(ok, 200);
    expect(jsonDecode(body)['result'], isEmpty);
  });

  test('API auto-start and MCP flags persist and default sensibly', () async {
    final fresh = await ApiServerConfig.load(database);
    expect(fresh.autoStart, isFalse);
    expect(fresh.mcpEnabled, isTrue);

    await ApiServerConfig.save(
      database,
      fresh.copyWith(autoStart: true, mcpEnabled: false),
    );
    final saved = await ApiServerConfig.load(database);
    expect(saved.autoStart, isTrue);
    expect(saved.mcpEnabled, isFalse);

    await ApiServerConfig.saveAutoStart(database, false);
    expect((await ApiServerConfig.load(database)).autoStart, isFalse);
  });

  test('MCP refuses an unauthenticated LAN bind', () async {
    final port = await freePort();
    final server = ApiServer(db: database);
    await server.start(
      config: ApiServerConfig(
        bindHost: '0.0.0.0',
        port: port,
        rateLimitPerMin: 0,
      ),
    );
    addTearDown(server.stop);
    final (status, _) = await httpPost(port, {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'ping',
    });
    expect(status, 403);
  });

  test('browser origins are rejected unless allow-listed', () async {
    final res = await post(
      {'jsonrpc': '2.0', 'id': 1, 'method': 'ping'},
      headers: {'origin': 'https://evil.example'},
    );
    expect(res.statusCode, 403);
  });

  test('unknown tools and bad arguments come back as errors', () async {
    final unknown = await rpc('tools/call', {'name': 'nope'});
    expect(unknown['error']['code'], -32602);

    final bad = await rpc('tools/call', {
      'name': 'create_provider',
      'arguments': {'name': 'x', 'adapter_type': 'notReal'},
    });
    expect(bad['result']['isError'], isTrue);
  });

  test('agent can build a cast, dub cues and synthesize end to end', () async {
    final tmp = await Directory.systemTemp.createTemp('neiroha_mcp');
    addTearDown(() => tmp.delete(recursive: true));
    PathService.instance.applyVoiceAssetRootOverride(tmp.path);
    addTearDown(() => PathService.instance.applyVoiceAssetRootOverride(null));
    // Fake OpenAI-compatible TTS server returning a tiny WAV.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final wav = _silentWav(800);
    server.listen((req) async {
      await req.drain<void>();
      req.response
        ..headers.contentType = ContentType('audio', 'wav')
        ..add(wav);
      await req.response.close();
    });

    final provider = await call('create_provider', {
      'name': 'Local OpenAI',
      'adapter_type': 'openaiCompatible',
      'base_url': 'http://127.0.0.1:${server.port}/v1',
      'api_key': 'secret',
    });
    expect(provider['has_api_key'], isTrue);
    expect(provider.containsKey('api_key'), isFalse);

    final bank = await call('create_voice_bank', {'name': 'Cast'});
    final hero = await call('create_voice_character', {
      'name': 'Hero',
      'provider_id': provider['id'],
      'model': 'tts-1',
      'voice': 'alloy',
      'bank_ids': [bank['id']],
    });
    expect(hero['task_mode'], 'presetVoice');
    final villain = await call('create_voice_character', {
      'name': 'Villain',
      'provider_id': 'Local OpenAI', // lookup by name works too
      'voice': 'onyx',
      'bank_ids': ['Cast'],
    });

    final banks = await call('list_voice_banks', {});
    final members =
        (banks['banks'] as List).firstWhere(
              (b) => b['id'] == bank['id'],
            )['members']
            as List;
    expect(members.map((m) => m['name']), containsAll(['Hero', 'Villain']));

    final project = await call('create_video_dub_project', {
      'name': 'Trailer',
      'bank_id': bank['id'],
    });
    final imported = await call('import_subtitles', {
      'project_id': project['id'],
      'subtitle_text':
          '1\n00:00:01,000 --> 00:00:02,000\nI will stop you.\n\n'
          '2\n00:00:03,000 --> 00:00:04,500\nYou can try.\n',
      'character_id': 'Hero',
    });
    expect(imported['imported'], 2);

    final cues =
        (await call('list_subtitle_cues', {
              'project_id': project['id'],
            }))['cues']
            as List;
    expect(cues.every((c) => c['character_name'] == 'Hero'), isTrue);

    await call('update_subtitle_cues', {
      'project_id': project['id'],
      'updates': [
        {'cue_id': cues[1]['id'], 'character_id': villain['id']},
      ],
    });

    final generated = await call('generate_video_dub_audio', {
      'project_id': project['id'],
      'sync_cue_length': true,
    });
    expect(generated['generated'], 2);
    expect(generated['failed'], 0);

    final after =
        (await call('list_subtitle_cues', {
              'project_id': project['id'],
            }))['cues']
            as List;
    expect(after[1]['character_name'], 'Villain');
    for (final c in after) {
      expect(File(c['audio_path'] as String).existsSync(), isTrue);
      // 800 samples @ 16 kHz mono 16-bit = 50 ms → end snapped to start+50.
      expect(c['end_ms'], (c['start_ms'] as int) + 50);
    }

    final speech = await call('synthesize_speech', {
      'character_id': 'Villain',
      'text': 'Hello there',
      'output_path': '${tmp.path}/line',
    });
    expect(speech['path'], endsWith('line.wav'));
    expect(speech['duration_sec'], closeTo(0.05, 0.001));

    final srt = await call('export_video_dub', {
      'project_id': project['id'],
      'kind': 'srt',
      'output_path': '${tmp.path}/out.srt',
    });
    expect(
      File(srt['path'] as String).readAsStringSync(),
      contains('You can try.'),
    );
  });
}

List<int> _silentWav(int samples) {
  const rate = 16000;
  final dataLen = samples * 2;
  final b = BytesBuilder();
  void w32(int v) =>
      b.add([v & 255, v >> 8 & 255, v >> 16 & 255, v >> 24 & 255]);
  void w16(int v) => b.add([v & 255, v >> 8 & 255]);
  b.add(ascii.encode('RIFF'));
  w32(36 + dataLen);
  b.add(ascii.encode('WAVEfmt '));
  w32(16);
  w16(1);
  w16(1);
  w32(rate);
  w32(rate * 2);
  w16(2);
  w16(16);
  b.add(ascii.encode('data'));
  w32(dataLen);
  b.add(List.filled(dataLen, 0));
  return b.toBytes();
}
