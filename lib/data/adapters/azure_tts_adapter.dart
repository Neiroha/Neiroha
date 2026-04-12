import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'tts_adapter.dart';

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
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    _dio = Dio(BaseOptions(
      baseUrl: base,
      headers: {
        'Ocp-Apim-Subscription-Key': apiKey,
      },
      responseType: ResponseType.bytes,
    ));
  }

  /// Default voice when none specified.
  static const _defaultVoice = 'en-US-AriaNeural';

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    final voice = request.presetVoiceName ?? _defaultVoice;

    // Build SSML
    final rate = request.speed != 1.0
        ? '${((request.speed - 1.0) * 100).round()}%'
        : '0%';
    final ssml = '''
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis"
       xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="en-US">
  <voice name="$voice">
    <prosody rate="$rate">
      ${_escapeXml(request.text)}
    </prosody>
  </voice>
</speak>''';

    // Determine output format
    final format = _mapFormat(request.responseFormat);

    final response = await _dio.post(
      'cognitiveservices/v1',
      data: ssml,
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
            .map((e) => e is Map ? (e['ShortName'] ?? e.toString()) : e.toString())
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
        // Group voices by locale as "models"
        final locales = <String>{};
        for (final v in response.data as List) {
          if (v is Map && v['Locale'] != null) {
            locales.add(v['Locale'] as String);
          }
        }
        return locales
            .map((l) => ModelInfo(id: l, name: 'Azure Voice ($l)'))
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
