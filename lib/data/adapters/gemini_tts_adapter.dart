import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'tts_adapter.dart';

/// Adapter for Google Gemini (AI Studio) native TTS.
///
/// Two request shapes are supported:
///
/// * **Interactions API** (Gemini 3.8 TTS family and newer):
///     POST {baseUrl}/v1beta/interactions
///     `generation_config.speech_config = [{"voice": "Kore"}]`
///     The text is read verbatim; delivery direction goes into the
///     `speech_metadata.style` annotation instead of being prepended.
///     Audio comes back as base64 WAV in `steps[].content[]` (type `audio`).
///
/// * **generateContent** (legacy 2.5 / 3.1 preview TTS models):
///     POST {baseUrl}/v1beta/models/{model}:generateContent
///     `speechConfig.voiceConfig.prebuiltVoiceConfig.voiceName`
///     Returns raw 24 kHz s16le PCM that we wrap in a WAV header.
///
/// Header: `x-goog-api-key: {apiKey}`.
///
/// Synthesis modes:
///   presetVoice  → 30 prebuilt voices plus the Extended Voice Library
///                  (`GET /v1beta/voices`)
///   voiceDesign  → natural-language style instruction (`voiceInstruction`)
///   cloneWithPrompt → not supported (the adapter throws)
class GeminiTtsAdapter extends TtsAdapter {
  final String baseUrl;
  final String apiKey;
  final String modelName;
  late final Dio _dio;

  static const String defaultBaseUrl =
      'https://generativelanguage.googleapis.com';
  static const String defaultModel = 'gemini-3.8-flash-tts';

  /// TTS models listed in the Gemini speech-generation docs (2026-10).
  static const List<ModelInfo> kModels = [
    ModelInfo(id: 'gemini-3.8-flash-tts', name: 'Gemini 3.8 Flash TTS'),
    ModelInfo(
      id: 'gemini-3.8-flash-lite-tts',
      name: 'Gemini 3.8 Flash-Lite TTS',
    ),
    ModelInfo(
      id: 'gemini-3.1-flash-tts-preview',
      name: 'Gemini 3.1 Flash TTS (preview)',
    ),
    ModelInfo(
      id: 'gemini-2.5-flash-preview-tts',
      name: 'Gemini 2.5 Flash TTS (preview)',
    ),
    ModelInfo(
      id: 'gemini-2.5-pro-preview-tts',
      name: 'Gemini 2.5 Pro TTS (preview)',
    ),
  ];

  /// 30 prebuilt voices, always available even when the voice-library
  /// endpoint is unreachable.
  static const List<String> kPrebuiltVoices = [
    'Zephyr',
    'Puck',
    'Charon',
    'Kore',
    'Fenrir',
    'Leda',
    'Orus',
    'Aoede',
    'Callirrhoe',
    'Autonoe',
    'Enceladus',
    'Iapetus',
    'Umbriel',
    'Algieba',
    'Despina',
    'Erinome',
    'Algenib',
    'Rasalgethi',
    'Laomedeia',
    'Achernar',
    'Alnilam',
    'Schedar',
    'Gacrux',
    'Pulcherrima',
    'Achird',
    'Zubenelgenubi',
    'Vindemiatrix',
    'Sadachbia',
    'Sadaltager',
    'Sulafat',
  ];

  GeminiTtsAdapter({
    required this.baseUrl,
    required this.apiKey,
    this.modelName = defaultModel,
  }) {
    final raw = baseUrl.trim().isEmpty ? defaultBaseUrl : baseUrl.trim();
    final normalized = raw.endsWith('/') ? raw : '$raw/';
    _dio = Dio(
      BaseOptions(
        baseUrl: normalized,
        headers: {
          if (apiKey.isNotEmpty) 'x-goog-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.json,
      ),
    );
  }

  String get _model => modelName.trim().isEmpty || modelName == 'default'
      ? defaultModel
      : modelName.trim();

  /// 2.x and 3.0/3.1 TTS models only speak generateContent.
  static bool usesLegacyGenerateContent(String model) =>
      RegExp(r'^(models/)?gemini-(2\.|3\.[01]-)').hasMatch(model);

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    if (request.refAudioPath != null && request.refAudioPath!.isNotEmpty) {
      throw Exception(
        'Gemini TTS does not support voice cloning from reference audio.',
      );
    }

    final rawVoice =
        (request.presetVoiceName != null && request.presetVoiceName!.isNotEmpty)
        ? request.presetVoiceName!
        : 'Kore';
    final voice = voiceIdFromLabel(rawVoice);
    final model = _model;

    // Speed is not natively controllable; express it as delivery style.
    final styleParts = <String>[];
    if (request.voiceInstruction != null &&
        request.voiceInstruction!.trim().isNotEmpty) {
      styleParts.add(request.voiceInstruction!.trim());
    }
    if (request.speed != 1.0) {
      styleParts.add(request.speed > 1.0 ? 'speak quickly' : 'speak slowly');
    }
    final style = styleParts.join(', ');

    try {
      if (!usesLegacyGenerateContent(model)) {
        try {
          return await _synthesizeInteractions(
            model,
            voice,
            request.text,
            style,
          );
        } on DioException catch (e) {
          // Older API surfaces (or proxies) without /interactions: fall back.
          if (e.response?.statusCode != 404) rethrow;
        }
      }
      return await _synthesizeGenerateContent(
        model,
        voice,
        request.text,
        style,
      );
    } on DioException catch (e) {
      throw Exception('Gemini TTS failed — ${_errMsg(e)}');
    }
  }

  Future<TtsResult> _synthesizeInteractions(
    String model,
    String voice,
    String text,
    String style,
  ) async {
    final body = {
      'model': model,
      'input': [
        {
          'type': 'user_input',
          'content': [
            {
              'type': 'text',
              'text': text,
              if (style.isNotEmpty)
                'annotations': [
                  {'type': 'speech_metadata', 'style': style},
                ],
            },
          ],
        },
      ],
      'response_format': {'type': 'audio'},
      'generation_config': {
        'speech_config': [
          {'voice': voice},
        ],
      },
    };
    final resp = await _dio.post('v1beta/interactions', data: body);
    final data = resp.data as Map<String, dynamic>;
    Map? audio;
    for (final step in (data['steps'] as List? ?? const []).whereType<Map>()) {
      if (step['type'] != 'model_output') continue;
      for (final c in (step['content'] as List? ?? const []).whereType<Map>()) {
        if (c['type'] == 'audio' && c['data'] is String) audio = c;
      }
    }
    final b64 = audio?['data'] as String?;
    if (b64 == null || b64.isEmpty) {
      throw Exception(
        'Gemini returned no audio: ${_truncate(jsonEncode(data))}',
      );
    }
    final bytes = base64Decode(b64);
    final mime = (audio?['mime_type'] ?? audio?['mimeType'] ?? '') as String;
    return _asWav(bytes, mime);
  }

  Future<TtsResult> _synthesizeGenerateContent(
    String model,
    String voice,
    String text,
    String style,
  ) async {
    // generateContent has no separate style field — instructions go inline.
    final prompt = style.isEmpty ? text : '$style: $text';
    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'responseModalities': ['AUDIO'],
        'speechConfig': {
          'voiceConfig': {
            'prebuiltVoiceConfig': {'voiceName': voice},
          },
        },
      },
    };

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
    return _asWav(base64Decode(b64), mime);
  }

  /// Pass RIFF/WAV through unchanged; wrap raw PCM (L16) in a WAV header.
  static TtsResult _asWav(Uint8List bytes, String mime) {
    final isRiff =
        bytes.length > 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46;
    if (isRiff) return TtsResult(audioBytes: bytes, contentType: 'audio/wav');
    final sampleRate = _parseSampleRate(mime, fallback: 24000);
    return TtsResult(
      audioBytes: _wrapPcmAsWav(bytes, sampleRate: sampleRate),
      contentType: 'audio/wav',
    );
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

  /// Prebuilt voices first, then the Extended Voice Library (best effort).
  @override
  Future<List<String>> getSpeakers() async {
    final out = <String>[...kPrebuiltVoices];
    final seen = out.toSet();
    String? token;
    try {
      for (var page = 0; page < 10; page++) {
        final resp = await _dio.get(
          'v1beta/voices',
          queryParameters: {'page_size': 100, 'page_token': ?token},
        );
        final data = resp.data as Map<String, dynamic>;
        for (final v
            in (data['voices'] as List? ?? const []).whereType<Map>()) {
          final id = (v['id'] ?? v['name']) as String?;
          if (id == null || id.isEmpty) continue;
          final label = voiceLabel(
            (v['display_name'] ?? v['displayName'] ?? '') as String,
            id,
          );
          if (seen.add(voiceIdFromLabel(label))) out.add(label);
        }
        token = (data['next_page_token'] ?? data['nextPageToken']) as String?;
        if (token == null || token.isEmpty) break;
      }
    } catch (_) {
      // Voice library is optional; prebuilt voices still work.
    }
    return out;
  }

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

  static String _truncate(String s) =>
      s.length > 400 ? '${s.substring(0, 400)}…' : s;

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
