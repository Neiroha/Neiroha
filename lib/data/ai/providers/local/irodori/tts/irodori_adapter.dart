import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/ai/protocols/http/http_error_message.dart';
import 'package:path/path.dart' as p;

/// The Irodori backend exposes voice sets through OpenAI Speech and accepts
/// reference uploads through its native clone endpoint.
class IrodoriAdapter extends TtsAdapter {
  static const defaultBaseUrl = 'http://127.0.0.1:19000';

  final String modelName;
  final Dio _http;

  IrodoriAdapter({
    required String baseUrl,
    required String apiKey,
    this.modelName = 'default',
  }) : _http = Dio(
         BaseOptions(
           baseUrl: _rootUrl(baseUrl),
           connectTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(minutes: 5),
           headers: {if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
         ),
       );

  static String _rootUrl(String baseUrl) {
    final trimmed = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final root = trimmed.isEmpty
        ? defaultBaseUrl
        : trimmed.replaceFirst(RegExp(r'/v1$', caseSensitive: false), '');
    return '$root/';
  }

  String get _voiceSet =>
      modelName.trim().isEmpty ? 'default' : modelName.trim();

  Future<List<Map>> _catalog(String endpoint) async {
    final response = await _http.get<Map<String, dynamic>>(endpoint);
    final entries = response.data?['data'];
    return entries is List ? entries.whereType<Map>().toList() : [];
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final response = await _http.get<Map<String, dynamic>>('health');
      return response.data?['backend'] == 'irodori' &&
          response.data?['status'] == 'ok';
    } on DioException {
      return false;
    }
  }

  @override
  Future<List<ModelInfo>> getModels() async => [
    for (final entry in await _catalog('v1/models'))
      if (entry['id'] case final String id when id.isNotEmpty)
        ModelInfo(id: id, name: entry['name']?.toString() ?? id),
  ];

  @override
  Future<List<String>> getSpeakers() => _speakers();

  Future<List<String>> getSpeakersForVoiceSet(String model) => _speakers(model);

  Future<List<String>> _speakers([String? model]) async => {
    for (final entry in await _catalog('v1/audio/voices'))
      if (model == null || entry['model'] == model)
        if ((entry['id'] ?? entry['voice_id']) case final String id
            when id.isNotEmpty)
          voiceLabel(entry['name']?.toString() ?? '', id),
  }.toList();

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    final reference = request.refAudioPath?.trim();
    final preset = request.presetVoiceName?.trim();
    final voiceId = voiceIdFromLabel(
      preset != null && preset.isNotEmpty ? preset : request.voice,
    );
    final format = request.responseFormat ?? 'wav';
    try {
      final response = reference == null || reference.isEmpty
          ? await _http.post<List<int>>(
              'v1/audio/speech',
              data: {
                'model': _voiceSet,
                'voice': voiceId.isEmpty ? 'default' : voiceId,
                'input': request.text,
                'speed': request.speed,
                'response_format': format,
              },
              options: Options(responseType: ResponseType.bytes),
            )
          : await _clone(request, reference, voiceId, format);
      final data = response.data;
      if (data == null || data.isEmpty) {
        throw const FormatException(
          'Irodori returned an empty audio response.',
        );
      }
      return TtsResult(
        audioBytes: Uint8List.fromList(data),
        contentType: response.headers.value('content-type') ?? 'audio/wav',
      );
    } on DioException catch (error, stack) {
      throwWithHttpErrorReason(error, stack);
    }
  }

  Future<Response<List<int>>> _clone(
    TtsRequest request,
    String reference,
    String voiceId,
    String format,
  ) async {
    var modelPreset = _voiceSet;
    if (modelPreset == 'azurlane') {
      modelPreset = 'azurlane-lora';
    } else if (modelPreset == 'local') {
      // The saved set can contain speakers bound to different checkpoints.
      final entries = (await _catalog(
        'v1/audio/voices',
      )).where((entry) => entry['model'] == 'local');
      final voice = (voiceId.isEmpty || voiceId == 'default')
          ? entries.firstOrNull
          : entries.where((entry) => entry['id'] == voiceId).firstOrNull;
      if (voice?['model_preset'] case final String preset
          when preset.isNotEmpty) {
        modelPreset = preset;
      } else {
        throw ArgumentError(
          'Select a saved Irodori voice with a model preset.',
        );
      }
    }
    final caption = request.voiceInstruction?.trim();
    return _http.post<List<int>>(
      'api/irodori/clone',
      data: FormData.fromMap({
        'model_preset': modelPreset,
        'text': request.text,
        'reference': await MultipartFile.fromFile(
          reference,
          filename: p.basename(reference),
        ),
        'speed': request.speed,
        'response_format': format,
        if (caption != null && caption.isNotEmpty) 'caption': caption,
      }),
      options: Options(responseType: ResponseType.bytes),
    );
  }
}
