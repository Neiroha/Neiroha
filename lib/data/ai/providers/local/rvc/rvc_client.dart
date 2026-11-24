import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/ai/protocols/http/streaming_post.dart';
import 'package:neiroha/data/ai/protocols/openai/openai_dio.dart';
import 'package:neiroha/domain/ai/ai_exception.dart';
import 'package:neiroha/domain/ai/media/audio_input.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

/// One loadable RVC checkpoint (`/api/rvc/catalog` → `models`).
class RvcModel {
  const RvcModel({required this.id, this.name = '', this.available = true});
  final String id;
  final String name;
  final bool available;
}

/// One speaker of a checkpoint (`/api/rvc/catalog` → `voices`).
class RvcVoice {
  const RvcVoice({
    required this.id,
    required this.model,
    this.name = '',
    this.hasIndex = false,
  });
  final String id;
  final String model;
  final String name;
  final bool hasIndex;
}

class RvcCatalog {
  const RvcCatalog(this.models, this.voices);
  final List<RvcModel> models;
  final List<RvcVoice> voices;

  List<RvcVoice> voicesFor(String? model) => [
    for (final v in voices)
      if (model == null || v.model == model) v,
  ];

  RvcVoice? voice(String id) => voices.where((v) => v.id == id).firstOrNull;

  factory RvcCatalog.fromJson(Object? json) {
    final map = json is Map ? json : const {};
    List<Map> list(String key) =>
        map[key] is List ? (map[key] as List).whereType<Map>().toList() : [];
    return RvcCatalog(
      [
        for (final m in list('models'))
          if (m['id'] case final String id when id.isNotEmpty)
            RvcModel(
              id: id,
              name: m['name']?.toString() ?? '',
              available: m['available'] != false,
            ),
      ],
      [
        for (final v in list('voices'))
          if ((v['id'], v['model']) case (
            final String id,
            final String model,
          ) when id.isNotEmpty)
            RvcVoice(
              id: id,
              model: model,
              name: v['name']?.toString() ?? '',
              hasIndex: v['has_index'] == true,
            ),
      ],
    );
  }
}

/// Neiroha-RVC voice-conversion server (`neiroha-rvc` backend).
///
///   GET  /health                → {backend: neiroha-rvc, status: ok}
///   GET  /api/rvc/catalog       → {models: [...], voices: [...]}
///   POST /api/rvc/convert       → multipart audio → whole WAV
///   POST /api/rvc/convert-stream→ multipart audio → raw PCM16, layout in
///                                 `x-neiroha-sample-rate` / `-channels`
class RvcClient {
  RvcClient({required String baseUrl, this.apiKey = ''})
    : dio = Dio(
        BaseOptions(
          baseUrl: rootUrl(baseUrl),
          followRedirects: false,
          connectTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 5),
          headers: {if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
        ),
      );

  static const defaultBaseUrl = 'http://127.0.0.1:19001';
  final String apiKey;
  final Dio dio;

  /// The server root: trailing slashes and an OpenAI-style `/v1` removed.
  static String rootUrl(String baseUrl) {
    final trimmed = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final root = trimmed.isEmpty
        ? defaultBaseUrl
        : trimmed.replaceFirst(RegExp(r'/v1$', caseSensitive: false), '');
    return '$root/';
  }

  Future<bool> health() async {
    try {
      final response = await dio.get<Map<String, dynamic>>('health');
      return response.data?['backend'] == 'neiroha-rvc' &&
          response.data?['status'] == 'ok';
    } on DioException {
      return false;
    }
  }

  Future<RvcCatalog> catalog({TtsCancelToken? cancellation}) =>
      withCancel(cancellation, apiKey, (token) async {
        final response = await dio.get<Object>(
          'api/rvc/catalog',
          cancelToken: token,
        );
        return RvcCatalog.fromJson(response.data);
      });

  /// Splits `model`/`voice`: a voice alone picks its own checkpoint.
  Future<({String model, String voice})> resolve(
    String? model,
    String voice, {
    TtsCancelToken? cancellation,
  }) async {
    final v = voiceIdFromLabel(voice);
    if (v.isEmpty) throw const AiProviderException('Pick an RVC voice.');
    final m = model?.trim() ?? '';
    if (m.isNotEmpty && m != autoModel) return (model: m, voice: v);
    final owner = (await catalog(cancellation: cancellation)).voice(v);
    if (owner == null) {
      throw AiProviderException('RVC voice "$v" is not in the catalog.');
    }
    return (model: owner.model, voice: v);
  }

  /// The catalog-free model id: the checkpoint follows the chosen voice.
  static const autoModel = 'auto';

  FormData _form(AudioInput audio, String model, String voice, int pitch) =>
      FormData()
        ..files.add(
          MapEntry(
            'audio',
            MultipartFile.fromBytes(
              audio.bytes,
              filename: audio.fileName,
              contentType: DioMediaType.parse(audio.contentType),
            ),
          ),
        )
        ..fields.addAll([
          MapEntry('model', model),
          MapEntry('voice', voice),
          MapEntry('pitch', '$pitch'),
        ]);

  Future<TtsResult> convert(
    AudioInput audio, {
    required String model,
    required String voice,
    int pitch = 0,
    TtsCancelToken? cancellation,
  }) => withCancel(cancellation, apiKey, (token) async {
    final response = await dio.post<List<int>>(
      'api/rvc/convert',
      data: _form(audio, model, voice, pitch)
        ..fields.add(const MapEntry('response_format', 'wav')),
      options: Options(responseType: ResponseType.bytes),
      cancelToken: token,
    );
    final bytes = Uint8List.fromList(response.data ?? const []);
    if (bytes.isEmpty) {
      throw const AiProviderException('RVC returned no audio.');
    }
    return TtsResult(
      audioBytes: bytes,
      contentType: response.headers.value('content-type') ?? 'audio/wav',
    );
  });

  Stream<TtsEvent> convertStream(
    AudioInput audio, {
    required String model,
    required String voice,
    int pitch = 0,
    required TtsCancelToken cancellation,
  }) async* {
    TtsAudioFormat? format;
    final body = streamingPost(
      dio,
      'api/rvc/convert-stream',
      data: _form(audio, model, voice, pitch),
      cancellation: cancellation,
      apiKey: apiKey,
      onHeaders: (headers) {
        final rate = int.tryParse(headers.value('x-neiroha-sample-rate') ?? '');
        final channels =
            int.tryParse(headers.value('x-neiroha-channels') ?? '') ?? 1;
        final encoding = headers.value('x-neiroha-output-format');
        if (rate == null || (encoding != null && encoding != 'pcm_s16le')) {
          throw AiProviderException(
            'RVC stream did not declare 16-bit PCM ($encoding @ $rate Hz).',
          );
        }
        format = TtsAudioFormat(
          AudioEncoding.pcmS16le,
          sampleRate: rate,
          channels: channels,
        )..validate();
      },
    );
    var started = false;
    var total = 0;
    final carry = BytesBuilder(copy: false);
    await for (final chunk in body) {
      final layout = format!;
      if (!started) {
        started = true;
        yield TtsAudioStarted(layout);
      }
      carry.add(chunk);
      // Hand out whole sample frames only; keep the odd tail for later.
      final frame = 2 * layout.channels!;
      final usable = carry.length - carry.length % frame;
      if (usable == 0) continue;
      final all = carry.takeBytes();
      total += usable;
      yield TtsAudioChunk(Uint8List.sublistView(all, 0, usable));
      if (usable < all.length) carry.add(Uint8List.sublistView(all, usable));
    }
    if (total == 0) throw const AiProviderException('RVC returned no audio.');
    yield const TtsSynthesisCompleted();
  }
}
