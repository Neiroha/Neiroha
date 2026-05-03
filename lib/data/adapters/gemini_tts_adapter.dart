import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'tts_adapter.dart';

/// Adapter for Google Gemini AI Studio Native TTS.
///
/// Free tier (per AI Studio quota panel, 2026-04):
///   - `gemini-2.5-flash-preview-tts`: 3 RPM / 10K TPM / 10 RPD
///   - `gemini-3.1-flash-preview-tts`: 3 RPM / 10K TPM / 10 RPD
///
/// Endpoint:
///   POST {baseUrl}/v1beta/models/{model}:generateContent
///   Header: x-goog-api-key: {apiKey}
///
/// Returns base64 PCM (signed 16-bit, mono, 24 kHz) inside JSON. We wrap it
/// in a WAV header so the rest of the pipeline can decode it as audio/wav.
///
/// Synthesis modes:
///   presetVoice  → 30 prebuilt voices via `prebuiltVoiceConfig.voiceName`
///   voiceDesign  → optional natural-language style instruction prepended to
///                  the text content (Gemini has no separate style field)
///   cloneWithPrompt → not supported (the adapter throws)
class GeminiTtsAdapter extends TtsAdapter {
  final String baseUrl;
  final String apiKey;
  final String modelName;
  late final Dio _dio;

  static const String defaultBaseUrl =
      'https://generativelanguage.googleapis.com';
  static const String defaultModel = 'gemini-2.5-flash-preview-tts';

  /// Models AI Studio currently exposes free TTS quota for. The Pro TTS
  /// variant is intentionally excluded — per the user's quota panel it sits
  /// at 0/0 on the free tier.
  static const List<ModelInfo> kModels = [
    ModelInfo(
      id: 'gemini-2.5-flash-preview-tts',
      name: 'Gemini 2.5 Flash TTS (preview)',
    ),
    ModelInfo(
      id: 'gemini-3.1-flash-tts-preview',
      name: 'Gemini 3.1 Flash TTS (preview)',
    ),
  ];

  /// 30 prebuilt voices. AI Studio does not expose a list endpoint, so this
  /// list is hard-coded against the official docs.
  static const List<String> kPrebuiltVoices = [
    'Zephyr', 'Puck', 'Charon', 'Kore', 'Fenrir', 'Leda', 'Orus',
    'Aoede', 'Callirrhoe', 'Autonoe', 'Enceladus', 'Iapetus', 'Umbriel',
    'Algieba', 'Despina', 'Erinome', 'Algenib', 'Rasalgethi', 'Laomedeia',
    'Achernar', 'Alnilam', 'Schedar', 'Gacrux', 'Pulcherrima', 'Achird',
    'Zubenelgenubi', 'Vindemiatrix', 'Sadachbia', 'Sadaltager', 'Sulafat',
  ];

  GeminiTtsAdapter({
    required this.baseUrl,
    required this.apiKey,
    this.modelName = defaultModel,
  }) {
    final raw = baseUrl.trim().isEmpty ? defaultBaseUrl : baseUrl.trim();
    final normalized = raw.endsWith('/') ? raw : '$raw/';
    _dio = Dio(BaseOptions(
      baseUrl: normalized,
      headers: {
        if (apiKey.isNotEmpty) 'x-goog-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      responseType: ResponseType.json,
    ));
  }

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    if (request.refAudioPath != null && request.refAudioPath!.isNotEmpty) {
      throw Exception(
          'Gemini TTS does not support voice cloning from reference audio.');
    }

    final voice = (request.presetVoiceName != null &&
            request.presetVoiceName!.isNotEmpty)
        ? request.presetVoiceName!
        : 'Kore';
    final model = modelName.isNotEmpty ? modelName : defaultModel;

    // Compose the text. Gemini has no separate style field — instructions go
    // inline. Speed is not natively controllable; encode it as natural-
    // language hint when the user picks something other than 1.0.
    final styleParts = <String>[];
    if (request.voiceInstruction != null &&
        request.voiceInstruction!.trim().isNotEmpty) {
      styleParts.add(request.voiceInstruction!.trim());
    }
    if (request.speed != 1.0) {
      styleParts.add(request.speed > 1.0 ? 'speak quickly' : 'speak slowly');
    }
    final prompt = styleParts.isEmpty
        ? request.text
        : '${styleParts.join(', ')}: ${request.text}';

    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'responseModalities': ['AUDIO'],
        'speechConfig': {
          'voiceConfig': {
            'prebuiltVoiceConfig': {'voiceName': voice}
          }
        }
      }
    };

    try {
      final resp = await _dio.post(
        'v1beta/models/$model:generateContent',
        data: body,
      );
      final data = resp.data as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('Gemini returned no candidates: ${jsonEncode(data)}');
      }
      final content = (candidates.first as Map?)?['content'] as Map?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw Exception('Gemini returned no parts: ${jsonEncode(data)}');
      }
      final inlineData =
          (parts.first as Map<String, dynamic>)['inlineData'] as Map?;
      final b64 = inlineData?['data'] as String?;
      final mime = (inlineData?['mimeType'] as String?) ?? '';
      if (b64 == null || b64.isEmpty) {
        throw Exception('Gemini response missing inlineData.data');
      }
      final pcm = base64Decode(b64);
      final sampleRate = _parseSampleRate(mime, fallback: 24000);
      final wav = _wrapPcmAsWav(pcm, sampleRate: sampleRate);
      return TtsResult(audioBytes: wav, contentType: 'audio/wav');
    } on DioException catch (e) {
      throw Exception('Gemini TTS failed — ${_errMsg(e)}');
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final resp = await _dio.get('v1beta/models');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> getSpeakers() async => List.of(kPrebuiltVoices);

  @override
  Future<List<ModelInfo>> getModels() async => List.of(kModels);

  static int _parseSampleRate(String mime, {required int fallback}) {
    final match = RegExp(r'rate=(\d+)').firstMatch(mime);
    if (match == null) return fallback;
    return int.tryParse(match.group(1)!) ?? fallback;
  }

  /// Wrap raw signed-16-bit PCM into a minimal RIFF/WAVE container.
  static Uint8List _wrapPcmAsWav(
    Uint8List pcm, {
    int sampleRate = 24000,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataLen = pcm.length;
    final buf = BytesBuilder();
    void w32(int v) => buf.add([
          v & 0xff,
          (v >> 8) & 0xff,
          (v >> 16) & 0xff,
          (v >> 24) & 0xff,
        ]);
    void w16(int v) => buf.add([v & 0xff, (v >> 8) & 0xff]);
    buf.add(ascii.encode('RIFF'));
    w32(36 + dataLen);
    buf.add(ascii.encode('WAVE'));
    buf.add(ascii.encode('fmt '));
    w32(16);
    w16(1); // PCM
    w16(channels);
    w32(sampleRate);
    w32(byteRate);
    w16(blockAlign);
    w16(bitsPerSample);
    buf.add(ascii.encode('data'));
    w32(dataLen);
    buf.add(pcm);
    return buf.toBytes();
  }

  String _errMsg(DioException e) {
    final raw = e.response?.data;
    if (raw is Map) {
      final err = raw['error'];
      if (err is Map) {
        final code = err['code'];
        final status = err['status'];
        final message = err['message'];
        return 'HTTP ${e.response?.statusCode}: '
            '${[code, status, message].where((v) => v != null).join(' / ')}';
      }
      return 'HTTP ${e.response?.statusCode}: ${jsonEncode(raw)}';
    }
    if (raw is List<int>) {
      try {
        return 'HTTP ${e.response?.statusCode}: ${utf8.decode(raw)}';
      } catch (_) {}
    }
    return 'HTTP ${e.response?.statusCode ?? '?'}: ${e.message ?? 'unknown'}';
  }
}
