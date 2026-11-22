import 'dart:async';
import 'dart:typed_data';

import 'package:neiroha/data/ai/protocols/realtime/json_socket_session.dart';
import 'package:neiroha/data/ai/protocols/realtime/realtime_audio.dart';
import 'package:neiroha/domain/ai/ai_exception.dart';
import 'package:neiroha/domain/ai/events/session_events.dart';
import 'package:neiroha/domain/ai/models/realtime_model.dart';

/// `wss://…/realtime?model=…`: voice conversation with manual turns.
class OpenAiConversationSession extends JsonSocketSession
    implements RealtimeSession {
  OpenAiConversationSession._(super.socket);

  static Future<OpenAiConversationSession> connect({
    required String baseUrl,
    required String apiKey,
    required String model,
    required RealtimeConfig config,
    String inputTranscriptionModel = 'gpt-transcribe',
  }) async {
    final socket = await JsonSocketSession.connectSocket(
      websocketUri(baseUrl, 'realtime', {'model': model}),
      apiKey,
    );
    final session = OpenAiConversationSession._(socket);
    session.send({
      'type': 'session.update',
      'session': {
        'type': 'realtime',
        'output_modalities': [config.audioOutput ? 'audio' : 'text'],
        if (config.instructions.isNotEmpty) 'instructions': config.instructions,
        'audio': {
          'input': {
            'format': openAiRealtimePcmFormat,
            'turn_detection': config.serverVad
                ? {
                    'type': 'server_vad',
                    'create_response': true,
                    'interrupt_response': true,
                  }
                : null,
            if (config.transcribeInput)
              'transcription': {'model': inputTranscriptionModel},
          },
          'output': {
            'format': openAiRealtimePcmFormat,
            if (config.voice?.isNotEmpty == true) 'voice': config.voice,
          },
        },
      },
    });
    return session;
  }

  final _reply = StringBuffer();

  @override
  int get inputSampleRate => openAiRealtimeRate;

  @override
  void sendPcm(Uint8List pcm16) =>
      appendAudio('input_audio_buffer.append', pcm16);

  @override
  void sendText(String text) => send({
    'type': 'conversation.item.create',
    'item': {
      'type': 'message',
      'role': 'user',
      'content': [
        {'type': 'input_text', 'text': text},
      ],
    },
  });

  @override
  Iterable<AiSessionEvent> decode(Map<String, dynamic> event) sync* {
    final delta = event['delta'];
    switch (event['type']) {
      case 'response.output_audio.delta' when delta is String:
        yield AudioDelta(
          Uint8List.fromList(base64DecodeSafe(delta)),
          sampleRate: openAiRealtimeRate,
        );
      case 'response.output_audio_transcript.delta' ||
          'response.output_text.delta':
        _reply.write(delta ?? '');
        yield TranscriptDelta('${delta ?? ''}', itemId: event['item_id']);
      case 'conversation.item.input_audio_transcription.completed':
        yield TranscriptFinal(
          '${event['transcript'] ?? ''}'.trim(),
          itemId: event['item_id'] as String?,
          languages: realtimeLanguages(event['languages']),
        );
      case 'input_audio_buffer.speech_started':
        yield const SpeechStarted();
      case 'input_audio_buffer.speech_stopped':
        yield const SpeechStopped();
      case 'response.done':
        final response = event['response'];
        final status = response is Map ? response['status'] : null;
        if (status != 'completed' && status != 'cancelled') {
          throw AiProviderException('Realtime response $status: $response');
        }
        final text = _reply.toString();
        _reply.clear();
        yield ResponseDone(
          usage: response is Map && response['usage'] is Map
              ? Map<String, Object?>.from(response['usage'] as Map)
              : const {},
          text: text.isEmpty ? null : text,
        );
    }
  }

  @override
  Future<ResponseDone> respond({
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final done = waitFor((e) => e['type'] == 'response.done', timeout: timeout);
    final text = StringBuffer();
    // The reply text is rebuilt from the done event's output items.
    send({'type': 'response.create'});
    final event = await done;
    final response = event['response'];
    if (response is Map && response['output'] is List) {
      for (final item in (response['output'] as List).whereType<Map>()) {
        for (final part in (item['content'] as List? ?? const [])) {
          if (part is Map) text.write(part['transcript'] ?? part['text'] ?? '');
        }
      }
    }
    return ResponseDone(
      usage: response is Map && response['usage'] is Map
          ? Map<String, Object?>.from(response['usage'] as Map)
          : const {},
      text: text.isEmpty ? null : text.toString(),
    );
  }

  /// Commits buffered microphone audio and waits for the reply.
  @override
  Future<void> finish({Duration timeout = const Duration(minutes: 2)}) async {
    send({'type': 'input_audio_buffer.commit'});
    await respond(timeout: timeout);
  }

  @override
  void cancelResponse() => send({'type': 'response.cancel'});
}
