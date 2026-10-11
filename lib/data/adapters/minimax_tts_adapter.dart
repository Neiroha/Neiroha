import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import 'tts_adapter.dart';

/// Adapter for the MiniMax speech (T2A v2) API.
///
/// Endpoints (base `https://api.minimax.io`, mainland China accounts use
/// `https://api.minimaxi.com`; header `Authorization: Bearer <key>`):
///   POST /v1/t2a_v2           → synthesis, hex-encoded audio in `data.audio`
///   POST /v1/get_voice        → system / cloned / designed voices
///   POST /v1/files/upload     → upload a clone sample (purpose=voice_clone)
///   POST /v1/voice_clone      → register the sample under a custom voice_id
///
/// Every JSON response carries `base_resp.status_code` (0 = success); HTTP
/// 200 alone does not mean the call worked.
///
/// Note: MiniMax deletes cloned voices that are not used for synthesis
/// within 7 days.
class MiniMaxTtsAdapter extends TtsAdapter implements VoiceCloneCapable {
  final String baseUrl;
  final String apiKey;
  final String modelName;
  late final Dio _dio;

  static const String defaultBaseUrl = 'https://api.minimax.io';
  static const String defaultModel = 'speech-2.8-hd';

  static const List<ModelInfo> kModels = [
    ModelInfo(id: 'speech-2.8-hd', name: 'Speech 2.8 HD'),
    ModelInfo(id: 'speech-2.8-turbo', name: 'Speech 2.8 Turbo'),
    ModelInfo(id: 'speech-2.6-hd', name: 'Speech 2.6 HD'),
    ModelInfo(id: 'speech-2.6-turbo', name: 'Speech 2.6 Turbo'),
    ModelInfo(id: 'speech-02-hd', name: 'Speech 02 HD'),
    ModelInfo(id: 'speech-02-turbo', name: 'Speech 02 Turbo'),
  ];

  /// Values accepted by `voice_setting.emotion`. A character instruction that
  /// names one of these is forwarded as the emotion.
  static const List<String> kEmotions = [
    'happy',
    'sad',
    'angry',
    'fearful',
    'disgusted',
    'surprised',
    'calm',
    'fluent',
    'whisper',
  ];

  MiniMaxTtsAdapter({
    required this.baseUrl,
    required this.apiKey,
    this.modelName = defaultModel,
  }) {
    var raw = baseUrl.trim().isEmpty ? defaultBaseUrl : baseUrl.trim();
    // Accept a base URL that already ends in /v1.
    raw = raw.replaceFirst(RegExp(r'/v1/?$'), '');
    _dio = Dio(
      BaseOptions(
        baseUrl: raw.endsWith('/') ? raw : '$raw/',
        headers: {if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 5),
        responseType: ResponseType.json,
      ),
    );
  }

  String get _model => modelName.trim().isEmpty || modelName == 'default'
      ? defaultModel
      : modelName.trim();

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    final rawVoice = (request.presetVoiceName?.trim().isNotEmpty ?? false)
        ? request.presetVoiceName!
        : request.voice;
    final voiceId = voiceIdFromLabel(rawVoice);
    if (voiceId.isEmpty) {
      throw Exception('MiniMax needs a voice_id (pick a voice first).');
    }
    final emotion = request.voiceInstruction?.trim().toLowerCase() ?? '';

    final body = {
      'model': _model,
      'text': request.text,
      'stream': false,
      'output_format': 'hex',
      'language_boost': 'auto',
      'voice_setting': {
        'voice_id': voiceId,
        'speed': request.speed.clamp(0.5, 2.0),
        'vol': 1,
        'pitch': 0,
        if (kEmotions.contains(emotion)) 'emotion': emotion,
      },
      'audio_setting': {
        'sample_rate': 32000,
        'bitrate': 128000,
        'format': 'mp3',
        'channel': 1,
      },
    };

    try {
      final resp = await _dio.post('v1/t2a_v2', data: body);
      final data = _checked(resp.data);
      final hexAudio = (data['data'] as Map?)?['audio'] as String?;
      if (hexAudio == null || hexAudio.isEmpty) {
        throw Exception('MiniMax response missing data.audio');
      }
      return TtsResult(
        audioBytes: _hexDecode(hexAudio),
        contentType: 'audio/mpeg',
      );
    } on DioException catch (e) {
      throw Exception('MiniMax TTS failed — ${_errMsg(e)}');
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final resp = await _dio.post(
        'v1/get_voice',
        data: {'voice_type': 'system'},
      );
      _checked(resp.data);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<ModelInfo>> getModels() async => List.of(kModels);

  @override
  Future<List<String>> getSpeakers() async {
    try {
      final resp = await _dio.post('v1/get_voice', data: {'voice_type': 'all'});
      final data = _checked(resp.data);
      final out = <String>[];
      for (final key in ['voice_cloning', 'voice_generation', 'system_voice']) {
        for (final v in (data[key] as List? ?? const []).whereType<Map>()) {
          final id = v['voice_id'] as String?;
          if (id == null || id.isEmpty) continue;
          out.add(voiceLabel((v['voice_name'] as String?) ?? '', id));
        }
      }
      return out;
    } on DioException catch (e) {
      throw Exception('MiniMax voice list failed — ${_errMsg(e)}');
    }
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
    try {
      final upload = await _dio.post(
        'v1/files/upload',
        data: FormData.fromMap({
          'purpose': 'voice_clone',
          'file': await MultipartFile.fromFile(
            audioPath,
            filename: p.basename(audioPath),
          ),
        }),
      );
      final uploaded = _checked(upload.data);
      final fileId = (uploaded['file'] as Map?)?['file_id'];
      if (fileId == null) {
        throw Exception('MiniMax upload returned no file_id');
      }

      final voiceId = makeVoiceId(name);
      final resp = await _dio.post(
        'v1/voice_clone',
        data: {
          'file_id': fileId is int ? fileId : int.tryParse('$fileId') ?? fileId,
          'voice_id': voiceId,
          'need_noise_reduction': true,
          'need_volume_normalization': true,
        },
      );
      _checked(resp.data);
      return voiceLabel(name, voiceId);
    } on DioException catch (e) {
      throw Exception('MiniMax voice clone failed — ${_errMsg(e)}');
    }
  }

  /// MiniMax voice ids: 8–256 chars, start with a letter, only
  /// `[A-Za-z0-9_-]`, must not end with `-`/`_`, unique per account.
  static String makeVoiceId(String name) {
    final ascii = name
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final base = ascii.isEmpty ? 'voice' : ascii;
    final trimmed = base.length > 40 ? base.substring(0, 40) : base;
    return 'Neiroha_${trimmed}_$stamp';
  }

  Map<String, dynamic> _checked(dynamic raw) {
    final data = raw is String ? jsonDecode(raw) : raw;
    if (data is! Map<String, dynamic>) {
      throw Exception('MiniMax returned an unexpected payload');
    }
    final base = data['base_resp'] as Map?;
    final code = base?['status_code'];
    if (code != null && code != 0) {
      throw Exception(
        'MiniMax error $code: ${base?['status_msg'] ?? 'unknown'}',
      );
    }
    return data;
  }

  static Uint8List _hexDecode(String hex) {
    final clean = hex.trim();
    final out = Uint8List(clean.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  String _errMsg(DioException e) {
    final raw = e.response?.data;
    final status = e.response?.statusCode ?? '?';
    if (raw is Map) {
      final base = raw['base_resp'];
      if (base is Map) {
        return 'HTTP $status: ${base['status_code']} ${base['status_msg'] ?? ''}'
            .trim();
      }
      return 'HTTP $status: ${jsonEncode(raw)}';
    }
    if (raw is String && raw.isNotEmpty) return 'HTTP $status: $raw';
    return 'HTTP $status: ${e.message ?? 'unknown'}';
  }
}
