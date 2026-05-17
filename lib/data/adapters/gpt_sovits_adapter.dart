import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'tts_adapter.dart';

/// Adapter for the Neiroha GPT-SoVITS launcher.
///
/// Endpoints used:
///   POST /v1/audio/speech      - trained/profile voices
///   POST /gpt-sovits/clone     - reference-audio clone mode
///   GET  /gpt-sovits/models    - native model catalog
///   GET  /gpt-sovits/voices    - trained/profile voices
class GptSovitsAdapter extends TtsAdapter {
  final String baseUrl;
  final String apiKey;
  final String modelName;
  late final Dio _dio;

  GptSovitsAdapter({
    required this.baseUrl,
    required this.apiKey,
    this.modelName = 'gpt-sovits',
  }) {
    final rootBaseUrl = _normalizeRootBaseUrl(baseUrl);
    _dio = Dio(
      BaseOptions(
        baseUrl: rootBaseUrl.endsWith('/') ? rootBaseUrl : '$rootBaseUrl/',
        headers: {if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
        responseType: ResponseType.bytes,
      ),
    );
  }

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    final hasRefAudio =
        request.refAudioPath != null && request.refAudioPath!.trim().isNotEmpty;
    return hasRefAudio
        ? _synthesizeClone(request)
        : _synthesizeTrainedVoice(request);
  }

  Future<TtsResult> _synthesizeTrainedVoice(TtsRequest request) async {
    final body = <String, dynamic>{
      'model': _openAiModelName,
      'input': request.text,
      'voice': _voiceName(request),
      if (request.speed != 1.0) 'speed': request.speed,
      if (request.responseFormat != null)
        'response_format': request.responseFormat,
      if (_textLang(request) != null) 'text_lang': _textLang(request),
    };

    final response = await _dio.post(
      'v1/audio/speech',
      data: body,
      options: Options(responseType: ResponseType.bytes),
    );

    return TtsResult(
      audioBytes: Uint8List.fromList(response.data as List<int>),
      contentType: response.headers.value('content-type') ?? 'audio/wav',
    );
  }

  Future<TtsResult> _synthesizeClone(TtsRequest request) async {
    final body = <String, dynamic>{
      'model': _openAiModelName,
      'input': request.text,
      'speaker': _cloneSpeakerName(request),
      'text_lang': _textLang(request) ?? 'zh',
      'ref_audio_path': request.refAudioPath,
      'response_format': request.responseFormat ?? 'wav',
      'speed': request.speed,
      'text_split_method': 'cut5',
      'batch_size': 1,
    };

    if (request.promptText != null && request.promptText!.isNotEmpty) {
      body['prompt_text'] = request.promptText;
    }
    if (request.promptLang != null && request.promptLang!.isNotEmpty) {
      body['prompt_lang'] = request.promptLang;
    }

    final response = await _dio.post(
      'gpt-sovits/clone',
      data: body,
      options: Options(responseType: ResponseType.bytes),
    );

    return TtsResult(
      audioBytes: Uint8List.fromList(response.data as List<int>),
      contentType: response.headers.value('content-type') ?? 'audio/wav',
    );
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get(
        'health',
        options: Options(
          responseType: ResponseType.json,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> getSpeakers() async {
    for (final endpoint in const [
      'gpt-sovits/voices',
      'v1/audio/voices',
      'speakers',
    ]) {
      try {
        final response = await _dio.get(
          endpoint,
          options: Options(responseType: ResponseType.json),
        );
        if (response.statusCode == 200) {
          final voices = _parseVoiceList(response.data);
          if (voices.isNotEmpty) return voices;
        }
      } catch (_) {}
    }
    return [];
  }

  @override
  Future<List<ModelInfo>> getModels() async {
    try {
      final response = await _dio.get(
        'gpt-sovits/models',
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final list = data['data'];
        if (list is List) {
          return list
              .map((e) {
                if (e is! Map) return ModelInfo(id: e.toString());
                final id = (e['id'] ?? '').toString();
                if (id.isEmpty) return null;
                return ModelInfo(id: id, name: (e['name'] ?? id).toString());
              })
              .whereType<ModelInfo>()
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  String get _openAiModelName {
    final model = modelName.trim();
    if (model == 'gpt-sovits' || model == 'tts-1' || model == 'tts-1-hd') {
      return model;
    }
    return 'gpt-sovits';
  }

  String? _textLang(TtsRequest request) {
    final direct = request.textLang?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final model = modelName.trim().toLowerCase();
    if (const {'zh', 'en', 'ja', 'ko', 'yue', 'auto'}.contains(model)) {
      return model;
    }
    return null;
  }

  String _voiceName(TtsRequest request) {
    final preset = request.presetVoiceName?.trim();
    if (preset != null && preset.isNotEmpty) return preset;
    final voice = request.voice.trim();
    return voice.isNotEmpty ? voice : 'default';
  }

  String _cloneSpeakerName(TtsRequest request) {
    final preset = request.presetVoiceName?.trim();
    final raw = preset != null && preset.isNotEmpty ? preset : 'clone';
    return _safeAsciiToken(raw, fallback: 'clone');
  }

  String _safeAsciiToken(String value, {required String fallback}) {
    final safe = value
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');
    return safe.isEmpty ? fallback : safe;
  }

  List<String> _parseVoiceList(dynamic data) {
    List? list;
    if (data is Map) {
      list = (data['voices'] ?? data['data']) as List?;
    } else if (data is List) {
      list = data;
    }
    if (list == null) return const [];
    return list
        .map((e) {
          if (e is! Map) return e.toString();
          return (e['id'] ?? e['voice_id'] ?? e['name'] ?? '').toString();
        })
        .where((v) => v.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  static String _normalizeRootBaseUrl(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.toLowerCase().endsWith('/v1')) {
      return trimmed.substring(0, trimmed.length - 3);
    }
    return trimmed;
  }
}
