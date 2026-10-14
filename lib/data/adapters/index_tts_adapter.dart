import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import 'tts_adapter.dart';

/// Adapter for IndexTTS 2 / 2.5 running behind its official Gradio WebUI
/// (`webui.py`).
///
/// Neiroha does not ship an IndexTTS launcher yet, so this targets the
/// WebUI that every community one-click package starts (e.g.
/// `opc-run/tts-index-tts-bundle` → `start-webui.bat`, default
/// `http://127.0.0.1:7860`). The WebUI exposes the generate button as the
/// Gradio API endpoint `/gen_single`; we drive it through the standard
/// Gradio HTTP protocol:
///
///   GET  /gradio_api/info                     → parameter schema + defaults
///   POST /gradio_api/upload                   → upload the reference audio
///   POST /gradio_api/call/gen_single          → returns `event_id`
///   GET  /gradio_api/call/gen_single/{id}     → SSE; `event: complete`
///   GET  /gradio_api/file={path}              → generated WAV
///
/// Gradio 4 servers use the same routes without the `/gradio_api` prefix;
/// the adapter probes both.
///
/// Parameters are filled by name from `/gradio_api/info`, falling back to the
/// WebUI's own defaults, so the adapter tolerates extra sampling knobs added
/// by forks. IndexTTS is zero-shot: every request needs a reference audio
/// (`refAudioPath`). `modelName` carries the target language (`ZH`, `EN`,
/// `JA`, `AR`, `ES`; empty/`auto` = detect from text). The character
/// instruction is sent as the emotion text when the WebUI exposes the
/// experimental emotion-text mode.
class IndexTtsAdapter extends TtsAdapter {
  final String baseUrl;
  final String apiKey;
  final String modelName;
  late final Dio _dio;

  static const String defaultBaseUrl = 'http://127.0.0.1:7860';
  static const String apiName = 'gen_single';
  static const List<String> kLanguages = ['ZH', 'EN', 'JA', 'AR', 'ES'];

  /// Per-server cache of the detected route prefix and endpoint schema.
  static final Map<String, _GradioSchema> _schemaCache = {};

  IndexTtsAdapter({
    required this.baseUrl,
    required this.apiKey,
    this.modelName = 'auto',
  }) {
    final raw = baseUrl.trim().isEmpty ? defaultBaseUrl : baseUrl.trim();
    _dio = Dio(
      BaseOptions(
        baseUrl: raw.endsWith('/') ? raw : '$raw/',
        headers: {if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 15),
      ),
    );
  }

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    final ref = request.refAudioPath;
    if (ref == null || ref.isEmpty) {
      throw Exception(
        'IndexTTS is zero-shot: the character needs a reference audio.',
      );
    }
    if (!await File(ref).exists()) {
      throw Exception('Reference audio not found: $ref');
    }

    try {
      final schema = await _schema();
      final serverPath = await _upload(schema.prefix, ref);
      final data = _buildArgs(schema, request, serverPath, ref);

      final call = await _dio.post(
        '${schema.prefix}call/$apiName',
        data: {'data': data},
        options: Options(responseType: ResponseType.json),
      );
      final eventId = (call.data as Map)['event_id'] as String?;
      if (eventId == null) throw Exception('Gradio returned no event_id');

      final sse = await _dio.get<String>(
        '${schema.prefix}call/$apiName/$eventId',
        options: Options(responseType: ResponseType.plain),
      );
      final output = _parseSse(sse.data ?? '');
      final fileUrl = _outputFileUrl(schema.prefix, output);
      final audio = await _dio.get<List<int>>(
        fileUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(audio.data ?? const []);
      if (bytes.isEmpty) throw Exception('IndexTTS returned empty audio');
      return TtsResult(audioBytes: bytes, contentType: 'audio/wav');
    } on DioException catch (e) {
      // The WebUI may have been restarted with another version: re-probe
      // the parameter schema on the next request.
      _schemaCache.remove(_dio.options.baseUrl);
      throw Exception('IndexTTS failed — ${_errMsg(e)}');
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      _schemaCache.remove(_dio.options.baseUrl);
      await _schema();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<ModelInfo>> getModels() async => [
    const ModelInfo(id: 'auto', name: 'Auto-detect language'),
    for (final l in kLanguages) ModelInfo(id: l),
  ];

  // ───────────────────────── Gradio plumbing ─────────────────────────

  Future<_GradioSchema> _schema() async {
    final key = _dio.options.baseUrl;
    final cached = _schemaCache[key];
    if (cached != null) return cached;

    DioException? lastError;
    for (final prefix in const ['gradio_api/', '']) {
      try {
        final resp = await _dio.get(
          '${prefix}info',
          options: Options(responseType: ResponseType.json),
        );
        final info = resp.data is String
            ? jsonDecode(resp.data as String)
            : resp.data;
        final endpoints = (info as Map)['named_endpoints'] as Map?;
        final endpoint = endpoints?['/$apiName'] as Map?;
        if (endpoint == null) {
          throw Exception(
            'Server at $key has no /$apiName endpoint — is this the '
            'IndexTTS WebUI?',
          );
        }
        final params = (endpoint['parameters'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList();
        final schema = _GradioSchema(prefix: prefix, parameters: params);
        _schemaCache[key] = schema;
        return schema;
      } on DioException catch (e) {
        lastError = e;
        if (e.response?.statusCode != 404) break;
      }
    }
    throw lastError ?? Exception('IndexTTS WebUI not reachable');
  }

  Future<String> _upload(String prefix, String path) async {
    final resp = await _dio.post(
      '${prefix}upload',
      data: FormData.fromMap({
        'files': await MultipartFile.fromFile(path, filename: p.basename(path)),
      }),
      options: Options(responseType: ResponseType.json),
    );
    final list = resp.data is String
        ? jsonDecode(resp.data as String)
        : resp.data;
    if (list is List && list.isNotEmpty && list.first is String) {
      return list.first as String;
    }
    throw Exception('Gradio upload returned an unexpected payload');
  }

  List<dynamic> _buildArgs(
    _GradioSchema schema,
    TtsRequest request,
    String serverPath,
    String localPath,
  ) {
    final instruction = request.voiceInstruction?.trim() ?? '';
    return [
      for (final param in schema.parameters)
        _argFor(param, request, serverPath, localPath, instruction),
    ];
  }

  dynamic _argFor(
    Map<String, dynamic> param,
    TtsRequest request,
    String serverPath,
    String localPath,
    String instruction,
  ) {
    final name = (param['parameter_name'] as String?) ?? '';
    final fallback = param['parameter_has_default'] == true
        ? param['parameter_default']
        : null;
    switch (name) {
      case 'prompt':
        return {
          'path': serverPath,
          'orig_name': p.basename(localPath),
          'meta': {'_type': 'gradio.FileData'},
        };
      case 'text':
        return request.text;
      case 'lang_choice':
        return _language(request.text);
      case 'emo_control_method':
        // Choice 3 (emotion from description text) only exists when the
        // WebUI was started with the experimental emotion model loaded.
        final choices = _enumChoices(param);
        if (instruction.isNotEmpty && choices.length >= 4) return choices[3];
        return choices.isNotEmpty ? choices.first : fallback;
      case 'emo_text':
        return instruction;
      case 'emo_ref_path':
        return null;
      case 'duration_factor':
        // WebUI slider: < 1 faster, > 1 slower.
        if (request.speed <= 0) return fallback ?? 1.0;
        return (1.0 / request.speed).clamp(0.5, 2.0);
      default:
        return fallback;
    }
  }

  List<String> _enumChoices(Map<String, dynamic> param) {
    final type = param['type'];
    if (type is Map && type['enum'] is List) {
      return (type['enum'] as List).map((e) => '$e').toList();
    }
    return const [];
  }

  String _language(String text) {
    final configured = modelName.trim().toUpperCase();
    const aliases = {'ZH-CN': 'ZH', 'CN': 'ZH', 'JP': 'JA', 'EN-US': 'EN'};
    final normalized = aliases[configured] ?? configured;
    if (kLanguages.contains(normalized)) return normalized;
    if (RegExp(r'[぀-ヿ]').hasMatch(text)) return 'JA';
    if (RegExp(r'[一-鿿]').hasMatch(text)) return 'ZH';
    if (RegExp(r'[؀-ۿ]').hasMatch(text)) return 'AR';
    if (RegExp(r'[ñ¿¡áéíóú]', caseSensitive: false).hasMatch(text)) {
      return 'ES';
    }
    return 'EN';
  }

  /// Parse the Gradio SSE stream and return the `complete` payload.
  dynamic _parseSse(String body) {
    String? event;
    dynamic completed;
    for (final line in const LineSplitter().convert(body)) {
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        final raw = line.substring(5).trim();
        if (event == 'error') {
          throw Exception(
            'IndexTTS generation failed: ${raw == 'null' ? 'see WebUI console' : raw}',
          );
        }
        if (event == 'complete') {
          completed = raw.isEmpty ? null : jsonDecode(raw);
        }
      }
    }
    if (completed == null) {
      throw Exception('IndexTTS stream ended without a result');
    }
    return completed;
  }

  String _outputFileUrl(String prefix, dynamic output) {
    dynamic first = output is List && output.isNotEmpty ? output.first : output;
    if (first is Map && first['__type__'] == 'update') first = first['value'];
    if (first is Map) {
      final path = first['path'] as String?;
      if (path != null && path.isNotEmpty) {
        return '${prefix}file=${Uri.encodeFull(path)}';
      }
      final url = first['url'] as String?;
      if (url != null && url.isNotEmpty) return url;
    }
    if (first is String && first.isNotEmpty) {
      return '${prefix}file=${Uri.encodeFull(first)}';
    }
    throw Exception('IndexTTS returned no audio file: ${jsonEncode(output)}');
  }

  String _errMsg(DioException e) {
    final raw = e.response?.data;
    final status = e.response?.statusCode;
    if (status == null) {
      return 'cannot reach ${_dio.options.baseUrl} '
          '(start the IndexTTS WebUI first): ${e.message ?? e.type.name}';
    }
    if (raw is Map) return 'HTTP $status: ${jsonEncode(raw)}';
    if (raw is String && raw.isNotEmpty) return 'HTTP $status: $raw';
    return 'HTTP $status: ${e.message ?? 'unknown'}';
  }
}

class _GradioSchema {
  final String prefix;
  final List<Map<String, dynamic>> parameters;

  const _GradioSchema({required this.prefix, required this.parameters});
}
