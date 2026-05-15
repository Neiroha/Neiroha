import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'tts_adapter.dart';

/// Adapter for CosyVoice native API.
///
/// Endpoints used:
///   GET  /health                  — health check
///   GET  /speakers                — list available speakers (SillyTavern compat)
///   GET  /cosyvoice/profiles      — list local profiles
///   POST /cosyvoice/speech        — JSON-body synthesis
///   POST /cosyvoice/speech/upload — multipart synthesis with uploaded audio
///
/// The CosyVoice mode ('zero_shot' | 'cross_lingual' | 'instruct') is stored
/// in [modelName] on the provider side and routed here.  When [modelName] is
/// not a recognised mode the adapter falls back to field-based inference.
class CosyVoiceAdapter extends TtsAdapter {
  final String baseUrl;
  final String apiKey;
  final String modelName;
  late final Dio _dio;

  static const _knownModes = {'zero_shot', 'cross_lingual', 'instruct'};

  CosyVoiceAdapter({
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
    // modelName holds the CosyVoice mode set by the character creator.
    // A per-call instruction must route through instruct mode, even if the
    // saved character was originally zero_shot / cross_lingual.
    final mode = request.voiceInstruction?.trim().isNotEmpty == true
        ? 'instruct'
        : _knownModes.contains(modelName)
        ? modelName
        : _inferMode(request);

    if (request.refAudioPath != null && request.refAudioPath!.isNotEmpty) {
      return _synthesizeWithUpload(request, mode: mode);
    }
    return _synthesizeJson(request, mode: mode);
  }

  /// Infer mode from request fields when no explicit mode is stored.
  String _inferMode(TtsRequest request) {
    if (request.voiceInstruction?.isNotEmpty == true) return 'instruct';
    return 'zero_shot';
  }

  // ─────────────────────────── JSON endpoint ─────────────────────────────────

  /// POST /cosyvoice/speech — JSON body.
  ///
  /// Used when there is no local reference audio to upload.
  /// Typical cases: preset-voice mode (profile only) and instruct with a preset.
  Future<TtsResult> _synthesizeJson(
    TtsRequest request, {
    required String mode,
  }) async {
    final body = <String, dynamic>{
      'text': request.text,
      'mode': mode,
      'speed': request.speed,
      'response_format': request.responseFormat ?? 'wav',
    };

    if (request.presetVoiceName != null &&
        request.presetVoiceName!.isNotEmpty) {
      body['profile'] = request.presetVoiceName;
    }
    if (request.voiceInstruction != null &&
        request.voiceInstruction!.isNotEmpty) {
      body['instruct_text'] = request.voiceInstruction;
    }
    if (request.promptText != null && request.promptText!.isNotEmpty) {
      body['prompt_text'] = request.promptText;
    }
    if (request.promptLang != null && request.promptLang!.isNotEmpty) {
      body['prompt_lang'] = request.promptLang;
    }

    try {
      final response = await _dio.post('cosyvoice/speech', data: body);
      return TtsResult(
        audioBytes: Uint8List.fromList(response.data as List<int>),
        contentType: response.headers.value('content-type') ?? 'audio/wav',
      );
    } on DioException catch (e) {
      throw Exception('CosyVoice synthesis failed — ${_decodeError(e)}');
    }
  }

  // ─────────────────────────── Upload endpoint ───────────────────────────────

  /// POST /cosyvoice/speech/upload — multipart with prompt_audio.
  ///
  /// Used for all modes that supply a local reference audio file:
  ///   • zero_shot    — clone voice from audio; prompt_text recommended
  ///   • cross_lingual — clone voice, synthesise in a different language
  ///   • instruct     — audio defines the voice; instruct_text controls style
  ///
  /// NOTE: we intentionally DO NOT send `profile` here. The server-side
  /// `build_runtime_char_config` treats `profile` as a lookup key against its
  /// local character config and raises 400 "未找到角色" if the name isn't
  /// registered. When the user uploads their own prompt audio we have
  /// everything the server needs (prompt_audio + mode-specific text fields),
  /// so sending a speculative profile name would only introduce failures.
  Future<TtsResult> _synthesizeWithUpload(
    TtsRequest request, {
    required String mode,
  }) async {
    final file = File(request.refAudioPath!);
    final fileName = file.path.split(Platform.pathSeparator).last;

    final formData = FormData.fromMap({
      'text': request.text,
      'mode': mode,
      'speed': request.speed,
      'response_format': request.responseFormat ?? 'wav',
      'prompt_audio': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
      if (request.promptText != null && request.promptText!.isNotEmpty)
        'prompt_text': request.promptText,
      if (request.promptLang != null && request.promptLang!.isNotEmpty)
        'prompt_lang': request.promptLang,
      if (request.voiceInstruction != null &&
          request.voiceInstruction!.isNotEmpty)
        'instruct_text': request.voiceInstruction,
    });

    try {
      final response = await _dio.post(
        'cosyvoice/speech/upload',
        data: formData,
      );
      return TtsResult(
        audioBytes: Uint8List.fromList(response.data as List<int>),
        contentType: response.headers.value('content-type') ?? 'audio/wav',
      );
    } on DioException catch (e) {
      throw Exception('CosyVoice upload failed — ${_decodeError(e)}');
    }
  }

  // ─────────────────────────── Helpers ───────────────────────────────────────

  String _decodeError(DioException e) {
    final raw = e.response?.data;
    if (raw != null) {
      try {
        return 'HTTP ${e.response?.statusCode}: ${utf8.decode(raw as List<int>)}';
      } catch (_) {}
    }
    return 'HTTP ${e.response?.statusCode ?? '?'}';
  }

  // ─────────────────────────── Health / speakers ─────────────────────────────

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
  Future<List<String>> getSpeakers() async {
    try {
      final response = await _dio.get(
        'speakers',
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => e is Map ? (e['name'] ?? e.toString()) : e.toString())
            .cast<String>()
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Fetch the list of server-side profiles via `/cosyvoice/profiles`.
  ///
  /// Unlike [getSpeakers] which goes through the SillyTavern-compatible
  /// endpoint, this hits the native profile registry used by
  /// `build_runtime_char_config`. The returned names are the only values
  /// that can safely be sent as `profile` to the synth endpoints.
  Future<List<CosyVoiceProfile>> getProfiles() async {
    try {
      final response = await _dio.get(
        'cosyvoice/profiles',
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == 200 && response.data is Map) {
        final data = (response.data as Map)['data'];
        if (data is List) {
          return data
              .whereType<Map>()
              .map(
                (e) => CosyVoiceProfile(
                  id: (e['id'] ?? e['name'] ?? '').toString(),
                  name: (e['name'] ?? e['id'] ?? '').toString(),
                  mode: (e['mode'] ?? '').toString(),
                  modeLabel: (e['mode_label'] ?? '').toString(),
                ),
              )
              .where((p) => p.id.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {}
    return const [];
  }
}

/// A local profile registered on the CosyVoice server (returned by
/// `/cosyvoice/profiles`).
class CosyVoiceProfile {
  final String id;
  final String name;
  final String mode;
  final String modeLabel;

  const CosyVoiceProfile({
    required this.id,
    required this.name,
    required this.mode,
    required this.modeLabel,
  });
}
