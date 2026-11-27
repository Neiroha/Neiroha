import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/ai/protocols/http/http_speech_stream.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

/// Adapter for Microsoft Azure Cognitive Services Speech (Text-to-Speech).
///
/// Uses the REST API:
///   POST https://{region}.tts.speech.microsoft.com/cognitiveservices/v1
///   GET  https://{region}.tts.speech.microsoft.com/cognitiveservices/voices/list
///
/// The [baseUrl] should be the region endpoint, e.g.
/// `https://eastus.tts.speech.microsoft.com`.
/// The [apiKey] is the subscription key (Ocp-Apim-Subscription-Key).
class AzureTtsAdapter extends TtsAdapter {
  final String baseUrl;
  final String apiKey;
  final String modelName; // unused for Azure, kept for interface compat
  late final Dio _dio;

  AzureTtsAdapter({
    required this.baseUrl,
    required this.apiKey,
    this.modelName = '',
  }) {
    final normalized = normalizeTtsUrl(baseUrl);
    final base = normalized.endsWith('/') ? normalized : '$normalized/';
    _dio = Dio(
      BaseOptions(
        baseUrl: base,
        headers: {'Ocp-Apim-Subscription-Key': apiKey},
        responseType: ResponseType.bytes,
      ),
    );
  }

  /// Normalizes any Azure endpoint variant to the TTS speech endpoint.
  ///
  /// Accepted forms:
  ///   - `https://eastasia.tts.speech.microsoft.com`  (already correct)
  ///   - `https://eastasia.api.cognitive.microsoft.com` (management endpoint)
  ///   - `eastasia`  (bare region name)
  static String normalizeTtsUrl(String rawUrl) {
    final url = rawUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (url.isEmpty) return url;

    // Already the correct TTS speech endpoint — use as-is.
    final uri = Uri.tryParse(url);
    if (uri?.host.toLowerCase().endsWith('.tts.speech.microsoft.com') ??
        false) {
      return url.replaceFirst(RegExp(r'/cognitiveservices/v1$'), '');
    }

    // https://{region}.api.cognitive.microsoft.com → extract region.
    final cognitiveMatch = RegExp(
      r'^([a-z0-9-]+)\.api\.cognitive\.microsoft\.com$',
      caseSensitive: false,
    ).firstMatch(uri?.host ?? '');
    if (cognitiveMatch != null && uri!.userInfo.isEmpty) {
      final region = cognitiveMatch.group(1)!.toLowerCase();
      return 'https://$region.tts.speech.microsoft.com';
    }

    // Bare region name (no dots, no slashes, no colons).
    if (RegExp(r'^[a-z][a-z0-9-]*$', caseSensitive: false).hasMatch(url)) {
      return 'https://$url.tts.speech.microsoft.com';
    }

    return url;
  }

  /// Default voice when none specified.
  static const _defaultVoice = 'en-US-AriaNeural';

  /// `zh-CN` from `zh-CN-XiaoxiaoNeural`; the SSML language must match
  /// the voice or Azure returns an empty stream.
  static String localeOf(String voice) {
    final m = RegExp(r'^([a-z]{2,3}-[A-Za-z]{2,4})-').firstMatch(voice);
    return m?.group(1) ?? 'en-US';
  }

  String _speechSsml(TtsRequest request) {
    final named = request.presetVoiceName?.trim() ?? '';
    final voice = named.isNotEmpty
        ? named
        : request.voice.trim().isNotEmpty
        ? request.voice.trim()
        : _defaultVoice;

    // Build SSML
    final rate = request.speed != 1.0
        ? '${((request.speed - 1.0) * 100).round()}%'
        : '0%';
    return '''
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis"
       xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="${localeOf(voice)}">
  <voice name="$voice">
    <prosody rate="$rate">
      ${_escapeXml(request.text)}
    </prosody>
  </voice>
</speak>''';
  }

  @override
  bool get supportsStreaming => true;

  @override
  Stream<TtsEvent> synthesizeStream(
    TtsRequest request, {
    required TtsCancelToken cancellation,
  }) {
    if (!streamsAudioFor(request)) {
      return super.synthesizeStream(request, cancellation: cancellation);
    }
    return httpSpeechStream(
      uri: Uri.parse(_dio.options.baseUrl).resolve('cognitiveservices/v1'),
      headers: {
        'Ocp-Apim-Subscription-Key': apiKey,
        'Content-Type': 'application/ssml+xml',
        'X-Microsoft-OutputFormat': 'raw-24khz-16bit-mono-pcm',
      },
      body: _speechSsml(request),
      format: const TtsAudioFormat(
        AudioEncoding.pcmS16le,
        sampleRate: 24000,
        channels: 1,
      ),
      cancellation: cancellation,
      // Azure labels raw-24khz-16bit-mono-pcm as `audio/basic` (checked
      // 2026-11-22); the body is little-endian PCM16 all the same.
      pcmMimeAliases: const {'audio/basic'},
    );
  }

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    final format = _mapFormat(request.responseFormat);
    final response = await _dio.post(
      'cognitiveservices/v1',
      data: _speechSsml(request),
      options: Options(
        headers: {
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': format,
        },
        responseType: ResponseType.bytes,
      ),
    );

    return TtsResult(
      audioBytes: Uint8List.fromList(response.data as List<int>),
      contentType: _contentTypeForFormat(format),
    );
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get(
        'cognitiveservices/voices/list',
        options: Options(responseType: ResponseType.json),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> getSpeakers() async {
    try {
      final response = await _dio.get(
        'cognitiveservices/voices/list',
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map(
              (e) => e is Map ? (e['ShortName'] ?? e.toString()) : e.toString(),
            )
            .cast<String>()
            .toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<List<ModelInfo>> getModels() async {
    try {
      final response = await _dio.get(
        'cognitiveservices/voices/list',
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .where((v) => v is Map && v['ShortName'] != null)
            .map(
              (v) => ModelInfo(
                id: v['ShortName'] as String,
                name:
                    '${v['DisplayName'] ?? v['ShortName']} (${v['Locale'] ?? ''})',
              ),
            )
            .toList();
      }
    } catch (_) {}
    return [];
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Map user-facing format to Azure output format header value.
  String _mapFormat(String? format) {
    switch (format) {
      case 'mp3':
        return 'audio-16khz-128kbitrate-mono-mp3';
      case 'opus':
        return 'ogg-48khz-16bit-mono-opus';
      case 'ogg':
        return 'ogg-48khz-16bit-mono-opus';
      case 'pcm':
        return 'raw-16khz-16bit-mono-pcm';
      case 'wav':
      default:
        return 'riff-24khz-16bit-mono-pcm';
    }
  }

  String _contentTypeForFormat(String azureFormat) {
    if (azureFormat.contains('mp3')) return 'audio/mpeg';
    if (azureFormat.contains('ogg') || azureFormat.contains('opus')) {
      return 'audio/ogg';
    }
    if (azureFormat.contains('raw') || azureFormat.contains('pcm')) {
      return 'audio/pcm';
    }
    return 'audio/wav';
  }
}
