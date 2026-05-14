import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'tts_adapter.dart';

/// Adapter for TTS providers that use the Chat Completions API format.
/// The text to synthesize goes in the `assistant` role message.
/// Audio is returned as base64 in `choices[0].message.audio.data`.
///
/// Compatible providers: MiMo TTS (https://api.xiaomimimo.com/v1)
class ChatCompletionsTtsAdapter extends TtsAdapter {
  final String baseUrl;
  final String apiKey;
  final String modelName;
  final String apiKeyHeader; // MiMo uses 'api-key', others use 'Authorization'
  late final Dio _dio;

  ChatCompletionsTtsAdapter({
    required this.baseUrl,
    required this.apiKey,
    required this.modelName,
    this.apiKeyHeader = 'api-key', // MiMo-style
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
        headers: {
          apiKeyHeader: apiKeyHeader == 'Authorization'
              ? 'Bearer $apiKey'
              : apiKey,
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    final modelKey = modelName.toLowerCase();
    final isVoiceDesign = modelKey.contains('voicedesign');
    final isVoiceClone = modelKey.contains('voiceclone');

    final assistantText =
        (request.audioTagPrefix != null && request.audioTagPrefix!.isNotEmpty)
        ? '${request.audioTagPrefix}${request.text}'
        : request.text;
    final userContent = _userMessageContent(request, isVoiceDesign);

    final messages = <Map<String, dynamic>>[
      if (userContent != null) {'role': 'user', 'content': userContent},
      {'role': 'assistant', 'content': assistantText},
    ];

    final audioField = <String, dynamic>{
      'format': request.responseFormat ?? 'wav',
    };
    if (isVoiceClone) {
      audioField['voice'] = await _resolveVoiceCloneDataUrl(request);
    } else if (!isVoiceDesign) {
      audioField['voice'] = request.presetVoiceName ?? 'mimo_default';
    }

    final audioData = await _requestAudioData({
      'model': modelName,
      'messages': messages,
      'audio': audioField,
    });
    late final List<int> audioBytes;
    try {
      audioBytes = base64Decode(audioData);
    } on FormatException catch (_) {
      throw const FormatException(
        'Chat Completions TTS response contained invalid base64 audio data.',
      );
    }

    return TtsResult(
      audioBytes: Uint8List.fromList(audioBytes),
      contentType: 'audio/wav',
    );
  }

  Future<String> _requestAudioData(Map<String, dynamic> payload) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _dio.post('chat/completions', data: payload);
        return _extractAudioData(response.data);
      } on DioException catch (e) {
        if (attempt == 1 || !_isRetryableDioError(e)) {
          throw Exception(
            'Chat Completions TTS request failed - ${_decodeDioError(e)}',
          );
        }
        lastError = e;
      } on FormatException catch (e) {
        if (attempt == 1 || !_isRetryableResponseShape(e)) rethrow;
        lastError = e;
      }
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    throw StateError('Chat Completions TTS retry failed: $lastError');
  }

  String _extractAudioData(dynamic raw) {
    if (raw is! Map) {
      throw FormatException(
        'Chat Completions TTS response was not a JSON object: '
        '${_compactResponse(raw)}',
      );
    }

    final error = raw['error'];
    if (error != null) {
      throw FormatException(
        'Chat Completions TTS API returned an error: '
        '${_compactResponse(error)}',
      );
    }

    final choices = raw['choices'];
    if (choices is! List || choices.isEmpty) {
      throw FormatException(
        'Chat Completions TTS response missing choices[0]: '
        '${_compactResponse(raw)}',
      );
    }

    final first = choices.first;
    if (first is! Map) {
      throw FormatException(
        'Chat Completions TTS response choices[0] was not an object: '
        '${_compactResponse(first)}',
      );
    }

    final message = first['message'];
    if (message is! Map) {
      throw FormatException(
        'Chat Completions TTS response missing choices[0].message: '
        '${_compactResponse(first)}',
      );
    }

    final audio = message['audio'];
    if (audio is! Map) {
      throw FormatException(
        'Chat Completions TTS response missing choices[0].message.audio: '
        '${_compactResponse(message)}',
      );
    }

    final data = audio['data'];
    if (data is! String || data.trim().isEmpty) {
      throw FormatException(
        'Chat Completions TTS response missing audio.data: '
        '${_compactResponse(audio)}',
      );
    }
    return data;
  }

  String? _userMessageContent(TtsRequest request, bool isVoiceDesign) {
    final instruction = request.voiceInstruction?.trim();
    if (instruction != null && instruction.isNotEmpty) return instruction;
    if (isVoiceDesign) return 'Generate a natural voice.';
    return null;
  }

  static const _maxCloneBytes = 10 * 1024 * 1024;

  Future<String> _resolveVoiceCloneDataUrl(TtsRequest request) async {
    final inlineData = request.voiceClonePromptBase64?.trim();
    if (inlineData != null && inlineData.isNotEmpty) return inlineData;

    final refPath = request.refAudioPath?.trim();
    if (refPath == null || refPath.isEmpty) {
      throw ArgumentError(
        'MiMo VoiceClone requires an mp3/wav reference audio file.',
      );
    }

    // refAudioPath can also carry a pre-encoded data URL (Web fallback,
    // or callers that pre-compute the dataURL at save time). Pass through.
    if (refPath.startsWith('data:audio/')) return refPath;

    final lower = refPath.toLowerCase();
    final mimeType = lower.endsWith('.mp3') || lower.endsWith('.mpeg')
        ? 'audio/mpeg'
        : lower.endsWith('.wav')
        ? 'audio/wav'
        : null;
    if (mimeType == null) {
      throw ArgumentError('MiMo VoiceClone only supports mp3 or wav files.');
    }

    final file = File(refPath);
    if (!await file.exists()) {
      throw ArgumentError('Reference audio file not found: $refPath');
    }

    // Check size before loading the whole file into memory.
    final length = await file.length();
    if (length > _maxCloneBytes) {
      throw ArgumentError('MiMo VoiceClone reference audio must be <= 10 MB.');
    }

    final bytes = await file.readAsBytes();
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  String _decodeDioError(DioException e) {
    final status = e.response?.statusCode;
    final prefix = status == null ? 'network error' : 'HTTP $status';
    final body = e.response?.data;
    if (body == null) return '$prefix: ${e.message ?? e.type.name}';
    return '$prefix: ${_compactResponse(body)}';
  }

  bool _isRetryableDioError(DioException e) {
    final status = e.response?.statusCode;
    return status == null || status == 429 || status >= 500;
  }

  bool _isRetryableResponseShape(FormatException e) {
    final message = e.message.toString().toLowerCase();
    return message.contains('missing choices') ||
        message.contains('not a json object') ||
        message.contains('missing audio.data');
  }

  String _compactResponse(dynamic raw) {
    String text;
    if (raw is List<int>) {
      try {
        text = utf8.decode(raw);
      } catch (_) {
        text = '<${raw.length} bytes>';
      }
    } else {
      try {
        text = raw is String ? raw : jsonEncode(raw);
      } catch (_) {
        text = raw.toString();
      }
    }
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= 500) return text;
    return '${text.substring(0, 500)}...';
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('models');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// MiMo has no /speakers endpoint; return the known preset voices.
  static const mimoV2BuiltInVoices = [
    'mimo_default',
    'default_zh',
    'default_en',
  ];

  static const mimoV25BuiltInVoices = [
    'mimo_default', // auto: CN=冰糖, EN=Mia
    '冰糖', // CN female
    '茉莉', // CN female
    '苏打', // CN male
    '白桦', // CN male
    'Mia', // EN female
    'Chloe', // EN female
    'Milo', // EN male
    'Dean', // EN male
  ];

  static List<String> builtInVoicesForMimoModel(String modelKey) {
    final k = modelKey.toLowerCase();
    if (!k.contains('mimo') || !k.contains('tts')) return const [];
    if (k.contains('voiceclone') || k.contains('voicedesign')) return const [];
    if (k.contains('v2.5')) return mimoV25BuiltInVoices;
    return mimoV2BuiltInVoices;
  }

  @override
  Future<List<String>> getSpeakers() async {
    // For MiMo TTS models, return built-in voice list
    final voices = builtInVoicesForMimoModel(modelName);
    if (voices.isNotEmpty) {
      return voices;
    }
    // For other providers, try the speakers endpoint
    try {
      final response = await _dio.get('speakers');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => e is Map ? (e['name'] ?? e.toString()) : e.toString())
            .cast<String>()
            .toList();
      }
    } catch (_) {
      // Speakers endpoint not available
    }
    return [];
  }

  @override
  Future<List<ModelInfo>> getModels() async {
    try {
      final response = await _dio.get(
        'models',
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        if (data['data'] is List) {
          return (data['data'] as List).map((e) {
            final id = e is Map ? (e['id'] ?? '') as String : e.toString();
            return ModelInfo(id: id, name: id);
          }).toList();
        }
      }
    } catch (_) {}
    return [];
  }
}
