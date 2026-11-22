import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:neiroha/data/ai/protocols/http/speech_http_io.dart'
    if (dart.library.js_interop) 'package:neiroha/data/ai/protocols/http/speech_http_web.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

typedef SpeechEventFrame = ({Uint8List? audio, bool done});

/// Owns the HTTP response through completion, failure or cancellation.
Stream<TtsEvent> httpSpeechStream({
  required Uri uri,
  required Map<String, String> headers,
  required Object body,
  required TtsAudioFormat format,
  required TtsCancelToken cancellation,
  SpeechEventFrame Function(String data)? decodeEvent,
  Duration timeout = const Duration(minutes: 3),

  /// Vendor labels that still mean raw PCM (Azure sends `audio/basic`).
  Set<String> pcmMimeAliases = const {},
}) async* {
  cancellation.throwIfCancelled();
  try {
    final response = await postSpeech(
      uri,
      headers,
      body,
      cancellation,
      timeout,
    );
    try {
      cancellation.throwIfCancelled();
      final mime = response
          .header('content-type')
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      final Stream<Uint8List> chunks;
      if (decodeEvent != null) {
        if (mime != 'text/event-stream') {
          throw const FormatException(
            'Expected an event stream from the speech API.',
          );
        }
        chunks = _eventAudio(response.chunks, decodeEvent);
      } else {
        if (mime != null &&
            !pcmMimeAliases.contains(mime) &&
            !const {
              'application/octet-stream',
              'binary/octet-stream',
              'audio/pcm',
              'audio/l16',
              'audio/raw',
              'audio/x-pcm',
            }.contains(mime)) {
          throw FormatException(
            'Expected raw PCM from the speech API, received $mime.',
          );
        }
        chunks = response.chunks;
      }
      format.validate();
      yield TtsAudioStarted(format);
      var length = 0;
      await for (final chunk in chunks) {
        cancellation.throwIfCancelled();
        if (chunk.isEmpty) continue;
        length += chunk.length;
        yield TtsAudioChunk(chunk);
      }
      cancellation.throwIfCancelled();
      if (length == 0 || length % (2 * format.channels!) != 0) {
        throw const FormatException('Speech returned empty or incomplete PCM.');
      }
      yield const TtsSynthesisCompleted();
    } finally {
      response.close();
    }
  } on DioException catch (error) {
    cancellation.throwIfCancelled();
    throw StateError(
      'Speech request failed (${error.response?.statusCode ?? error.type.name})',
    );
  } catch (_) {
    cancellation.throwIfCancelled();
    rethrow;
  }
}

Stream<Uint8List> _eventAudio(
  Stream<Uint8List> chunks,
  SpeechEventFrame Function(String) decode,
) async* {
  final fields = <String>[];
  await for (final line
      in utf8.decoder.bind(chunks).transform(const LineSplitter())) {
    if (line.startsWith('data:')) {
      final data = line.substring(5);
      fields.add(data.startsWith(' ') ? data.substring(1) : data);
    } else if (line.isEmpty && fields.isNotEmpty) {
      final frame = decode(fields.join('\n'));
      fields.clear();
      if (frame.audio case final audio?) yield audio;
      if (frame.done) return;
    }
  }
  throw const FormatException(
    'Speech stream ended before its completion event.',
  );
}
