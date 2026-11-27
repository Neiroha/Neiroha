import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:neiroha/data/ai/protocols/http/speech_http_io.dart'
    if (dart.library.js_interop) 'package:neiroha/data/ai/protocols/http/speech_http_web.dart';
import 'package:neiroha/data/ai/protocols/http/speech_http_response.dart';
import 'package:neiroha/domain/capabilities/service_endpoint.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

Stream<TtsEvent> openAiSpeechStream({
  required String baseUrl,
  required String apiKey,
  required Map<String, dynamic> body,
  required TtsAudioFormat format,
  required TtsCancelToken cancellation,
  String path = 'audio/speech',
  String apiKeyHeader = 'Authorization',
  Duration timeout = const Duration(minutes: 3),
}) async* {
  final relativePath = ServiceEndpoint.validatePath(path);
  ServiceEndpoint.validateHeader(apiKeyHeader);
  final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
  SpeechHttpResponse? response;
  var length = 0;
  try {
    cancellation.throwIfCancelled();
    response = await postSpeech(
      base.resolve(relativePath),
      {
        if (apiKey.isNotEmpty)
          apiKeyHeader: apiKeyHeader.toLowerCase() == 'authorization'
              ? 'Bearer $apiKey'
              : apiKey,
      },
      body,
      cancellation,
      timeout,
    );
    cancellation.throwIfCancelled();
    var actual = format;
    final mime = response
        .header(Headers.contentTypeHeader)
        ?.split(';')
        .first
        .trim();
    final encodedTypes = {
      'audio/wav',
      'audio/x-wav',
      'audio/mpeg',
      'audio/mp3',
      'audio/ogg',
      'audio/aac',
      'audio/flac',
    };
    if (format.encoding == AudioEncoding.pcmS16le) {
      if (encodedTypes.contains(mime)) {
        throw const FormatException(
          'Server returned encoded audio instead of declared PCM.',
        );
      }
      final rate =
          response.header('x-audio-sample-rate') ??
          response.header('x-sample-rate');
      final channels =
          response.header('x-audio-channels') ?? response.header('x-channels');
      actual = TtsAudioFormat(
        AudioEncoding.pcmS16le,
        sampleRate: rate == null ? format.sampleRate : int.tryParse(rate),
        channels: channels == null ? format.channels : int.tryParse(channels),
      );
      actual.validate();
    } else if (encodedTypes.contains(mime)) {
      actual = TtsAudioFormat.fromContentType(mime!);
    }
    yield TtsAudioStarted(actual);
    await for (final chunk in response.chunks) {
      cancellation.throwIfCancelled();
      length += chunk.length;
      yield TtsAudioChunk(Uint8List.fromList(chunk));
    }
    cancellation.throwIfCancelled();
    if (length == 0) {
      throw const FormatException('Speech returned empty audio.');
    }
    yield const TtsSynthesisCompleted();
  } on DioException catch (error) {
    cancellation.throwIfCancelled();
    throw StateError(
      'Speech request failed (${error.response?.statusCode ?? error.type.name})',
    );
  } catch (_) {
    cancellation.throwIfCancelled();
    rethrow;
  } finally {
    response?.close();
  }
}
