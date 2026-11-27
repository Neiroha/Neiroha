import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';

import 'speech_resolver.dart';
import 'speech_stream_response.dart';
import 'tracked_http_server.dart';

/// `POST /v1/audio/speech`: OpenAI-compatible synchronous speech.
class SpeechRequestHandler {
  const SpeechRequestHandler(this.db);
  final AppDatabase db;

  Future<Response> handle(Request request) async {
    try {
      final json = jsonDecode(await request.readAsString());
      if (json is! Map<String, dynamic>) {
        return jsonError(400, 'Body must be a JSON object');
      }
      final speech = await resolveSpeech(db, json);
      if (json['stream'] == true) {
        if (speech.request.responseFormat != 'pcm') {
          return jsonError(400, 'Streaming requires response_format: pcm');
        }
        return await streamSpeechResponse(
          provider: speech.provider,
          modelName: speech.asset.modelName,
          request: speech.request,
          clientClosed:
              request.context[clientClosedContextKey] as Future<void>?,
        );
      }
      // Through the global TTS scheduler, so local API calls obey the same
      // provider limits as the desktop UI.
      final result = await TtsQueueService.instance.synthesize(
        provider: speech.provider,
        modelName: speech.asset.modelName,
        source: 'External API',
        label: '${speech.request.voice}: ${speech.request.text}',
        request: speech.request,
      );
      return Response.ok(
        result.audioBytes,
        headers: {'content-type': result.contentType},
      );
    } on SpeechApiException catch (e) {
      return jsonError(e.status, e.message);
    } on FormatException catch (e) {
      return jsonError(400, 'Invalid JSON: ${e.message}');
    } catch (e) {
      return jsonError(500, e.toString());
    }
  }
}

Response jsonError(int status, String message) => Response(
  status,
  body: jsonEncode({'error': message}),
  headers: {'content-type': 'application/json'},
);
