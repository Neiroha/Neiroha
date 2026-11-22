import 'dart:async';
import 'dart:typed_data';

import 'package:neiroha/data/ai/protocols/realtime/json_socket_session.dart';
import 'package:neiroha/data/ai/protocols/realtime/realtime_audio.dart';
import 'package:neiroha/domain/ai/events/session_events.dart';

/// `wss://…/realtime/translations?model=…`: continuous speech translation.
/// No `response.create`; `session.close` flushes and ends with
/// `session.closed`.
class OpenAiTranslationSession extends JsonSocketSession {
  OpenAiTranslationSession._(super.socket);

  static Future<OpenAiTranslationSession> connect({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String targetLanguage,
  }) async {
    final socket = await JsonSocketSession.connectSocket(
      websocketUri(baseUrl, 'realtime/translations', {'model': model}),
      apiKey,
    );
    final session = OpenAiTranslationSession._(socket);
    session.send({
      'type': 'session.update',
      'session': {
        'audio': {
          'output': {'language': targetLanguage},
        },
      },
    });
    return session;
  }

  @override
  int get inputSampleRate => openAiRealtimeRate;

  @override
  void sendPcm(Uint8List pcm16) =>
      appendAudio('session.input_audio_buffer.append', pcm16);

  @override
  Iterable<AiSessionEvent> decode(Map<String, dynamic> event) sync* {
    final delta = event['delta'];
    switch (event['type']) {
      case 'session.output_audio.delta' when delta is String:
        yield AudioDelta(
          Uint8List.fromList(base64DecodeSafe(delta)),
          sampleRate: openAiRealtimeRate,
        );
      case 'session.output_transcript.delta':
        yield TranscriptDelta('${delta ?? ''}');
      case 'session.input_transcript.delta':
        yield TranscriptDelta('${delta ?? ''}', source: true);
      case 'session.closed':
        yield const ResponseDone();
    }
  }

  @override
  Future<void> finish({Duration timeout = const Duration(minutes: 2)}) async {
    final closed = waitFor(
      (e) => e['type'] == 'session.closed',
      timeout: timeout,
    );
    send({'type': 'session.close'});
    await closed;
    await close();
  }
}
