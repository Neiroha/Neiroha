import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'tts_adapter.dart';

/// Adapter for the VoxCPM2 native launcher API.
///
/// Endpoints used:
///   GET  /health                   — health check
///   GET  /v1/models                — list available model IDs
///   GET  /api/voxcpm/voices        — list registered voice profiles
///   POST /api/voxcpm/tts           — JSON-body synthesis
///   POST /api/voxcpm/tts/upload    — multipart synthesis with uploaded audio
///
/// Older launchers exposed the same native surface under `/voxcpm/*`. The
/// adapter prefers the Neiroha contract paths and falls back to the legacy
/// paths when a server returns 404.
///
/// The three native modes are:
///   • design          — text only (natural-language voice description in
///                       parentheses at the start of `text`)
///   • clone           — `reference_audio` file OR registered `voice_id`
///   • ultimate_clone  — `prompt_text` plus prompt/reference audio
///
/// The mode is stored in [modelName] on the provider side (same pattern as
/// the CosyVoice adapter). When [modelName] is not a recognised mode the
/// adapter falls back to field-based inference.
class VoxCpm2NativeAdapter extends TtsAdapter {
  final String baseUrl;
  final String apiKey;
  final String modelName;
  late final Dio _dio;

  static const _knownModes = {'design', 'clone', 'ultimate_clone'};
  static const _modelIdFallback = 'default';
  static const _speechEndpoint = 'api/voxcpm/tts';
  static const _legacySpeechEndpoint = 'voxcpm/speech';
  static const _uploadEndpoint = 'api/voxcpm/tts/upload';
  static const _legacyUploadEndpoint = 'voxcpm/speech/upload';
  static const _voicesEndpoint = 'api/voxcpm/voices';
  static const _legacyVoicesEndpoint = 'voxcpm/voices';

  VoxCpm2NativeAdapter({
    required this.baseUrl,
    required this.apiKey,
    this.modelName = '',
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
        headers: {if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
        responseType: ResponseType.bytes,
      ),
    );
  }

  // ─────────────────────────── synthesize ────────────────────────────────────

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    final mode = _knownModes.contains(modelName)
        ? modelName
        : _inferMode(request);

    final hasLocalRef =
        request.refAudioPath != null &&
        request.refAudioPath!.isNotEmpty &&
        File(request.refAudioPath!).existsSync();

    if (hasLocalRef && (mode == 'clone' || mode == 'ultimate_clone')) {
      return _synthesizeWithUpload(request, mode: mode);
    }
    return _synthesizeJson(request, mode: mode);
  }

  /// Infer mode from request fields when no explicit mode is stored.
  String _inferMode(TtsRequest request) {
    final hasPromptText = request.promptText?.isNotEmpty == true;
    final hasRef = request.refAudioPath?.isNotEmpty == true;
    if (hasPromptText && hasRef) return 'ultimate_clone';
    if (hasRef || (request.presetVoiceName?.isNotEmpty == true)) return 'clone';
    return 'design';
  }

  String get _modelIdForRequest =>
      _knownModes.contains(modelName) || modelName.isEmpty
      ? _modelIdFallback
      : modelName;

  // ─────────────────────────── JSON endpoint ─────────────────────────────────

  /// POST /api/voxcpm/tts — JSON body.
  ///
  /// Used for:
  ///   • design          — pure text synthesis
  ///   • clone           — with a registered `voice_id` (no local file)
  ///   • ultimate_clone  — if the ref audio is a remote URI the server can
  ///                       fetch itself (http/file/data URI)
  Future<TtsResult> _synthesizeJson(
    TtsRequest request, {
    required String mode,
  }) async {
    final body = <String, dynamic>{
      'model': _modelIdForRequest,
      'text': request.text,
      'mode': mode,
      'response_format': request.responseFormat ?? 'wav',
    };

    // Registered voice id takes the `voice_id` slot. The server treats
    // `presetVoiceName` here as a registered voice profile; if the name isn't
    // registered the server will reject the request, same as CosyVoice.
    if (request.presetVoiceName != null &&
        request.presetVoiceName!.isNotEmpty) {
      body['voice_id'] = request.presetVoiceName;
    }

    // Allow the adapter to accept already-remote references (file://, http,
    // data: URIs) as `reference_audio` without multipart upload.
    final ref = request.refAudioPath;
    if (ref != null && ref.isNotEmpty && _isRemoteReference(ref)) {
      body['reference_audio'] = ref;
    }

    if (request.promptText != null && request.promptText!.isNotEmpty) {
      body['prompt_text'] = request.promptText;
    }
    if (request.voiceInstruction != null &&
        request.voiceInstruction!.isNotEmpty) {
      body['instruction'] = request.voiceInstruction;
    }

    try {
      final response = await _postWithLegacyFallback(
        _speechEndpoint,
        _legacySpeechEndpoint,
        data: body,
      );
      return TtsResult(
        audioBytes: Uint8List.fromList(response.data as List<int>),
        contentType: response.headers.value('content-type') ?? 'audio/wav',
      );
    } on DioException catch (e) {
      throw Exception('VoxCPM2 synthesis failed — ${_decodeError(e)}');
    }
  }

  // ─────────────────────────── Upload endpoint ───────────────────────────────

  /// POST /api/voxcpm/tts/upload — multipart with a local reference file.
  ///
  /// For `clone` we send `reference_audio`. For `ultimate_clone` we send the
  /// same file under `prompt_audio` alongside the required `prompt_text`,
  /// matching the upstream field names.
  Future<TtsResult> _synthesizeWithUpload(
    TtsRequest request, {
    required String mode,
  }) async {
    Future<FormData> buildFormData() async {
      final file = File(request.refAudioPath!);
      final fileName = file.path.split(Platform.pathSeparator).last;
      final multipart = await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      );

      final fields = <String, dynamic>{
        'model': _modelIdForRequest,
        'text': request.text,
        'mode': mode,
        'response_format': request.responseFormat ?? 'wav',
      };

      if (mode == 'ultimate_clone') {
        fields['prompt_audio'] = multipart;
        if (request.promptText != null && request.promptText!.isNotEmpty) {
          fields['prompt_text'] = request.promptText;
        }
      } else {
        fields['reference_audio'] = multipart;
      }

      if (request.presetVoiceName != null &&
          request.presetVoiceName!.isNotEmpty) {
        fields['voice_id'] = request.presetVoiceName;
      }
      if (request.voiceInstruction != null &&
          request.voiceInstruction!.isNotEmpty) {
        fields['instruction'] = request.voiceInstruction;
      }

      return FormData.fromMap(fields);
    }

    try {
      final response = await _postFormWithLegacyFallback(
        _uploadEndpoint,
        _legacyUploadEndpoint,
        buildFormData,
      );
      return TtsResult(
        audioBytes: Uint8List.fromList(response.data as List<int>),
        contentType: response.headers.value('content-type') ?? 'audio/wav',
      );
    } on DioException catch (e) {
      throw Exception('VoxCPM2 upload failed — ${_decodeError(e)}');
    }
  }

  // ─────────────────────────── Helpers ───────────────────────────────────────

  bool _isRemoteReference(String ref) {
    final lower = ref.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('file://') ||
        lower.startsWith('data:');
  }

  bool _shouldFallbackToLegacy(DioException e) {
    return e.response?.statusCode == 404;
  }

  Future<Response<dynamic>> _postWithLegacyFallback(
    String endpoint,
    String legacyEndpoint, {
    Object? data,
  }) async {
    try {
      return await _dio.post(endpoint, data: data);
    } on DioException catch (e) {
      if (!_shouldFallbackToLegacy(e)) rethrow;
      return _dio.post(legacyEndpoint, data: data);
    }
  }

  Future<Response<dynamic>> _postFormWithLegacyFallback(
    String endpoint,
    String legacyEndpoint,
    Future<FormData> Function() buildFormData,
  ) async {
    try {
      return await _dio.post(endpoint, data: await buildFormData());
    } on DioException catch (e) {
      if (!_shouldFallbackToLegacy(e)) rethrow;
      return _dio.post(legacyEndpoint, data: await buildFormData());
    }
  }

  Future<Response<dynamic>> _getWithLegacyFallback(
    String endpoint,
    String legacyEndpoint, {
    Options? options,
  }) async {
    try {
      return await _dio.get(endpoint, options: options);
    } on DioException catch (e) {
      if (!_shouldFallbackToLegacy(e)) rethrow;
      return _dio.get(legacyEndpoint, options: options);
    }
  }

  String _decodeError(DioException e) {
    final raw = e.response?.data;
    if (raw != null) {
      try {
        return 'HTTP ${e.response?.statusCode}: ${utf8.decode(raw as List<int>)}';
      } catch (_) {}
    }
    return 'HTTP ${e.response?.statusCode ?? '?'}';
  }

  // ─────────────────────────── Health / discovery ────────────────────────────

  @override
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get(
        'health',
        options: Options(responseType: ResponseType.json),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<ModelInfo>> getModels() async {
    try {
      final response = await _dio.get(
        'v1/models',
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == 200 && response.data is Map) {
        final data = (response.data as Map)['data'];
        if (data is List) {
          return data
              .map((e) {
                final id = e is Map
                    ? ((e['id'] ?? e['name'] ?? '') as Object).toString()
                    : e.toString();
                return ModelInfo(id: id, name: id);
              })
              .where((m) => m.id.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {}
    return const [];
  }

  @override
  Future<List<String>> getSpeakers() async {
    final voices = await getVoices();
    return voices.map((v) => v.id).toList();
  }

  /// Fetch the list of server-side registered voice profiles via
  /// `/api/voxcpm/voices`. These are the only values that can safely be sent
  /// as `voice_id` to the synthesis endpoints.
  Future<List<VoxCpm2Voice>> getVoices() async {
    try {
      final response = await _getWithLegacyFallback(
        _voicesEndpoint,
        _legacyVoicesEndpoint,
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == 200) {
        final raw = response.data;
        List? list;
        if (raw is Map) {
          list = (raw['voices'] ?? raw['data']) as List?;
        } else if (raw is List) {
          list = raw;
        }
        if (list == null) return const [];
        return list
            .whereType<Map>()
            .map(
              (e) => VoxCpm2Voice(
                id: (e['id'] ?? e['voice_id'] ?? e['name'] ?? '').toString(),
                displayName: (e['display_name'] ?? e['name'] ?? e['id'] ?? '')
                    .toString(),
                modeHint: (e['mode_hint'] ?? e['mode'] ?? '').toString(),
              ),
            )
            .where((v) => v.id.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }
}

/// A registered voice profile returned by `/api/voxcpm/voices`.
class VoxCpm2Voice {
  final String id;
  final String displayName;
  final String modeHint;

  const VoxCpm2Voice({
    required this.id,
    required this.displayName,
    required this.modeHint,
  });
}
