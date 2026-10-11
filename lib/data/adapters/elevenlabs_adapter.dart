import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import 'tts_adapter.dart';

/// Adapter for the ElevenLabs Text-to-Speech REST API.
///
/// Endpoints (base `https://api.elevenlabs.io`, header `xi-api-key`):
///   POST /v1/text-to-speech/{voice_id}?output_format=mp3_44100_128
///   GET  /v1/models                 → health check + live model list
///   GET  /v2/voices                 → paginated voice library
///   POST /v1/voices/add             → instant voice clone (multipart)
///
/// Voices are surfaced as `Name [voice_id]`; [voiceIdFromLabel] recovers the
/// id at synthesis time. Cloning registers a reusable voice on the account,
/// so characters store the returned id as a preset voice.
class ElevenLabsAdapter extends TtsAdapter implements VoiceCloneCapable {
  final String baseUrl;
  final String apiKey;
  final String modelName;
  late final Dio _dio;

  static const String defaultBaseUrl = 'https://api.elevenlabs.io';
  static const String defaultModel = 'eleven_v4';

  /// Current TTS models (ElevenLabs model docs, 2026-10). Turbo v2/v2.5 are
  /// deprecated upstream in favour of the Flash models and are omitted.
  static const List<ModelInfo> kModels = [
    ModelInfo(id: 'eleven_v4', name: 'Eleven v4'),
    ModelInfo(id: 'eleven_v4_turbo', name: 'Eleven v4 Turbo'),
    ModelInfo(id: 'eleven_v3', name: 'Eleven v3'),
    ModelInfo(id: 'eleven_multilingual_v2', name: 'Eleven Multilingual v2'),
    ModelInfo(id: 'eleven_flash_v2_5', name: 'Eleven Flash v2.5'),
    ModelInfo(id: 'eleven_flash_v2', name: 'Eleven Flash v2 (English)'),
  ];

  ElevenLabsAdapter({
    required this.baseUrl,
    required this.apiKey,
    this.modelName = defaultModel,
  }) {
    final raw = baseUrl.trim().isEmpty ? defaultBaseUrl : baseUrl.trim();
    _dio = Dio(
      BaseOptions(
        baseUrl: raw.endsWith('/') ? raw : '$raw/',
        headers: {if (apiKey.isNotEmpty) 'xi-api-key': apiKey},
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
  }

  String get _model => modelName.trim().isEmpty || modelName == 'default'
      ? defaultModel
      : modelName.trim();

  /// v3 / v4 understand inline bracketed audio tags such as `[whispers]`.
  bool get _supportsAudioTags =>
      _model.startsWith('eleven_v3') || _model.startsWith('eleven_v4');

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    final rawVoice = (request.presetVoiceName?.trim().isNotEmpty ?? false)
        ? request.presetVoiceName!
        : request.voice;
    final voiceId = voiceIdFromLabel(rawVoice);
    if (voiceId.isEmpty) {
      throw Exception('ElevenLabs needs a voice id (pick a voice first).');
    }

    var text = request.text;
    final instruction = request.voiceInstruction?.trim() ?? '';
    if (instruction.isNotEmpty && _supportsAudioTags) {
      text = instruction.startsWith('[')
          ? '$instruction $text'
          : '[$instruction] $text';
    }

    final settings = <String, dynamic>{
      if (request.speed != 1.0) 'speed': request.speed.clamp(0.7, 1.2),
    };
    final lang = request.textLang?.trim() ?? '';
    final body = <String, dynamic>{
      'text': text,
      'model_id': _model,
      if (settings.isNotEmpty) 'voice_settings': settings,
      if (lang.isNotEmpty) 'language_code': lang,
    };

    try {
      final resp = await _dio.post<List<int>>(
        'v1/text-to-speech/${Uri.encodeComponent(voiceId)}',
        queryParameters: {'output_format': 'mp3_44100_128'},
        data: body,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Content-Type': 'application/json'},
        ),
      );
      final bytes = Uint8List.fromList(resp.data ?? const []);
      if (bytes.isEmpty) throw Exception('ElevenLabs returned empty audio');
      return TtsResult(audioBytes: bytes, contentType: 'audio/mpeg');
    } on DioException catch (e) {
      throw Exception('ElevenLabs TTS failed — ${_errMsg(e)}');
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final resp = await _dio.get('v1/models');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<ModelInfo>> getModels() async {
    try {
      final resp = await _dio.get('v1/models');
      final data = resp.data;
      if (data is List) {
        final live = <ModelInfo>[
          for (final m in data.whereType<Map>())
            if (m['can_do_text_to_speech'] != false &&
                (m['model_id'] as String?)?.isNotEmpty == true)
              ModelInfo(
                id: m['model_id'] as String,
                name: (m['name'] as String?) ?? '',
              ),
        ];
        if (live.isNotEmpty) return live;
      }
    } catch (_) {}
    return List.of(kModels);
  }

  @override
  Future<List<String>> getSpeakers() async {
    final out = <String>[];
    String? token;
    try {
      for (var page = 0; page < 20; page++) {
        final resp = await _dio.get(
          'v2/voices',
          queryParameters: {'page_size': 100, 'next_page_token': ?token},
        );
        final data = resp.data as Map<String, dynamic>;
        for (final v
            in (data['voices'] as List? ?? const []).whereType<Map>()) {
          final id = v['voice_id'] as String?;
          if (id == null || id.isEmpty) continue;
          out.add(voiceLabel((v['name'] as String?) ?? '', id));
        }
        token = data['next_page_token'] as String?;
        if (data['has_more'] != true || token == null || token.isEmpty) break;
      }
    } on DioException catch (e) {
      if (out.isEmpty) {
        throw Exception('ElevenLabs voice list failed — ${_errMsg(e)}');
      }
    }
    return out;
  }

  @override
  Future<String> cloneVoice({
    required String name,
    required String audioPath,
    String? promptText,
    String? description,
  }) async {
    final file = File(audioPath);
    if (!await file.exists()) {
      throw Exception('Reference audio not found: $audioPath');
    }
    final form = FormData.fromMap({
      'name': name,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      'files': await MultipartFile.fromFile(
        audioPath,
        filename: p.basename(audioPath),
      ),
    });
    try {
      final resp = await _dio.post('v1/voices/add', data: form);
      final data = resp.data as Map<String, dynamic>;
      final id = data['voice_id'] as String?;
      if (id == null || id.isEmpty) {
        throw Exception('ElevenLabs clone returned no voice_id');
      }
      return voiceLabel(name, id);
    } on DioException catch (e) {
      throw Exception('ElevenLabs voice clone failed — ${_errMsg(e)}');
    }
  }

  String _errMsg(DioException e) {
    final status = e.response?.statusCode ?? '?';
    var raw = e.response?.data;
    if (raw is List<int>) {
      try {
        raw = jsonDecode(utf8.decode(raw));
      } catch (_) {
        return 'HTTP $status: ${utf8.decode(raw as List<int>, allowMalformed: true)}';
      }
    }
    if (raw is Map) {
      final detail = raw['detail'];
      if (detail is Map) {
        return 'HTTP $status: ${detail['status'] ?? ''} ${detail['message'] ?? ''}'
            .trim();
      }
      return 'HTTP $status: ${jsonEncode(raw)}';
    }
    if (raw is String && raw.isNotEmpty) return 'HTTP $status: $raw';
    return 'HTTP $status: ${e.message ?? 'unknown'}';
  }
}
