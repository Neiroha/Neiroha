import 'dart:async';
import 'dart:typed_data';

import 'package:neiroha/data/ai/protocols/realtime/json_socket_session.dart';
import 'package:neiroha/data/ai/protocols/realtime/realtime_audio.dart';
import 'package:neiroha/domain/ai/ai_exception.dart';
import 'package:neiroha/domain/ai/events/session_events.dart';
import 'package:neiroha/domain/ai/media/transcript.dart';

/// `wss://…/realtime?intent=transcription`: the model goes in the session,
/// not the URL (a model in the URL opens a conversation instead).
class OpenAiTranscriptionSession extends JsonSocketSession {
  OpenAiTranscriptionSession._(super.socket);

  static Future<OpenAiTranscriptionSession> connect({
    required String baseUrl,
    required String apiKey,
    required String model,
    TranscribeOptions options = const TranscribeOptions(),
  }) async {
    final socket = await JsonSocketSession.connectSocket(
      websocketUri(baseUrl, 'realtime', {'intent': 'transcription'}),
      apiKey,
    );
    final session = OpenAiTranscriptionSession._(socket);
    session.send({
      'type': 'session.update',
      'session': {
        'type': 'transcription',
        'audio': {
          'input': {
            'format': openAiRealtimePcmFormat,
            'transcription': {
              'model': model,
              if (options.languages.isNotEmpty) 'languages': options.languages,
              if (options.prompt?.isNotEmpty == true) 'prompt': options.prompt,
              if (options.keywords.isNotEmpty) 'keywords': options.keywords,
            },
            'turn_detection': null,
          },
        },
      },
    });
    return session;
  }

  @override
  int get inputSampleRate => openAiRealtimeRate;

  @override
  void sendPcm(Uint8List pcm16) =>
      appendAudio('input_audio_buffer.append', pcm16);

  @override
  Iterable<AiSessionEvent> decode(Map<String, dynamic> event) sync* {
    final item = event['item_id'] as String?;
    switch (event['type']) {
      case 'input_audio_buffer.committed':
        _committed = item;
      case 'conversation.item.input_audio_transcription.delta':
        yield TranscriptDelta('${event['delta'] ?? ''}', itemId: item);
      case 'conversation.item.input_audio_transcription.completed':
        yield TranscriptFinal(
          '${event['transcript'] ?? ''}'.trim(),
          itemId: item,
          languages: realtimeLanguages(event['languages']),
        );
      case 'conversation.item.input_audio_transcription.failed':
        throw AiProviderException('Transcription failed: ${event['error']}');
      case 'input_audio_buffer.speech_started':
        yield const SpeechStarted();
      case 'input_audio_buffer.speech_stopped':
        yield const SpeechStopped();
    }
  }

  String? _committed;

  /// Commits the buffered turn and waits for its final transcript. The
  /// predicate reads [_committed], which [decode] sets before waiters run, so
  /// a transcript arriving in the same read as the commit ack is not missed.
  @override
  Future<void> finish({Duration timeout = const Duration(minutes: 2)}) async {
    _committed = null;
    final done = waitFor(
      (e) =>
          e['type'] ==
              'conversation.item.input_audio_transcription.completed' &&
          _committed != null &&
          e['item_id'] == _committed,
      timeout: timeout,
    );
    send({'type': 'input_audio_buffer.commit'});
    await done;
    await close();
  }
}
