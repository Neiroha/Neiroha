import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:neiroha/data/ai/protocols/realtime/json_socket_session.dart';
import 'package:neiroha/domain/ai/ai.dart';

import 'gemini_live_setup.dart';

export 'gemini_live_setup.dart';

/// Gemini Live API (`BidiGenerateContent`) session. Input is 16 kHz PCM16,
/// output audio 24 kHz PCM16. Server messages carry `setupComplete`,
/// `serverContent`, `voiceActivity`, `usageMetadata`, `goAway`…
///
/// * conversation — model audio (or text) + transcripts; with server VAD
///   the service detects turns and sends `interrupted` on barge-in,
///   otherwise turns are bracketed by `activityStart` / `activityEnd`.
/// * transcription — cumulative `interimInputTranscription`, then one
///   final `inputTranscription` and `generationComplete` (no turnComplete).
/// * translation — a continuous stream without turns: translated speech
///   (paced in real time) plus incremental source (`inputTranscription`)
///   and target (`outputTranscription`) text.
class GeminiLiveSession extends JsonSocketSession implements RealtimeSession {
  GeminiLiveSession._(super.socket, this.mode, {required this.manualTurns});

  static const inputRate = 16000;
  static const outputRate = 24000;
  static const _pcmMime = 'audio/pcm;rate=16000';

  final GeminiLiveMode mode;

  /// No server VAD: the client marks each turn with activityStart/End.
  final bool manualTurns;
  bool _activityOpen = false;
  final _input = StringBuffer();
  final _output = StringBuffer();
  bool _inputReported = false;
  String _lastReply = '';
  String _interim = '';
  DateTime _lastEvent = DateTime.now();

  static Future<GeminiLiveSession> connect({
    required Uri uri,
    required Map<String, Object?> setup,
    required GeminiLiveMode mode,
    required bool manualTurns,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final socket = await WebSocket.connect(uri.toString()).timeout(timeout);
    final session = GeminiLiveSession._(socket, mode, manualTurns: manualTurns);
    session.send(setup);
    try {
      await session.waitFor(
        (e) => e.containsKey('setupComplete'),
        timeout: timeout,
      );
    } catch (_) {
      await session.close();
      rethrow;
    }
    return session;
  }

  @override
  int get inputSampleRate => inputRate;

  static Map? _content(Map<String, dynamic> e) => e['serverContent'] as Map?;

  static bool _turnComplete(Map<String, dynamic> e) =>
      _content(e)?['turnComplete'] == true;

  static bool _transcribed(Map<String, dynamic> e) =>
      _content(e)?['generationComplete'] == true || _turnComplete(e);

  static String? _text(Map content, String key) {
    final text = (content[key] as Map?)?['text'];
    return text is String && text.isNotEmpty ? text : null;
  }

  /// Whether a PCM16 chunk is audible (the translator streams silence
  /// between and after utterances).
  static bool _audible(Uint8List pcm) {
    final data = ByteData.sublistView(pcm);
    for (var i = 0; i + 1 < pcm.length; i += 2) {
      if (data.getInt16(i, Endian.little).abs() > 300) return true;
    }
    return false;
  }

  @override
  Iterable<AiSessionEvent> decode(Map<String, dynamic> event) sync* {
    final content = _content(event);
    if (mode != GeminiLiveMode.translation) _lastEvent = DateTime.now();
    if (content == null) return;
    if (mode == GeminiLiveMode.transcription) {
      yield* _decodeTranscription(event, content);
      return;
    }
    if (content['interrupted'] == true) {
      _output.clear();
      yield const SpeechStarted();
    }
    final heard = _text(content, 'inputTranscription');
    if (heard != null) {
      _input.write(heard);
      _lastEvent = DateTime.now();
      if (mode == GeminiLiveMode.translation) {
        yield TranscriptDelta(heard, source: true);
      }
    }
    final parts = (content['modelTurn'] as Map?)?['parts'];
    final said = _text(content, 'outputTranscription');
    if ((parts is List && parts.isNotEmpty) || said != null) {
      yield* _reportInput();
    }
    if (parts is List) {
      for (final p in parts.whereType<Map>()) {
        final data = (p['inlineData'] as Map?)?['data'];
        if (data is String) {
          final pcm = base64Decode(data);
          if (_audible(pcm)) _lastEvent = DateTime.now();
          yield AudioDelta(pcm, sampleRate: outputRate);
        } else if (p['text'] is String && p['thought'] != true) {
          // TEXT responses (no audio transcript in that case).
          _output.write(p['text']);
          yield TranscriptDelta(p['text'] as String);
        }
      }
    }
    if (said != null) {
      _lastEvent = DateTime.now();
      _output.write(said);
      yield TranscriptDelta(said);
    }
    if (content['turnComplete'] == true) {
      yield* _reportInput();
      final usage = event['usageMetadata'];
      yield ResponseDone(
        text: _output.toString(),
        usage: usage is Map ? Map<String, Object?>.from(usage) : const {},
      );
      _lastReply = _output.toString();
      _output.clear();
      _inputReported = false;
    }
  }

  /// Interim text is cumulative; emit only what was appended.
  Iterable<AiSessionEvent> _decodeTranscription(
    Map<String, dynamic> event,
    Map content,
  ) sync* {
    final activity = (event['voiceActivity'] as Map?)?['type'];
    if (activity == 'ACTIVITY_START') yield const SpeechStarted();
    if (activity == 'ACTIVITY_END') yield const SpeechStopped();
    final interim = _text(content, 'interimInputTranscription');
    if (interim != null) {
      final delta = interim.startsWith(_interim)
          ? interim.substring(_interim.length)
          : interim;
      _interim = interim;
      if (delta.isNotEmpty) yield TranscriptDelta(delta);
    }
    final heard = _text(content, 'inputTranscription');
    if (heard != null) _input.write(heard);
    if (_transcribed(event)) {
      final text = _input.toString().trim();
      _input.clear();
      _interim = '';
      if (text.isNotEmpty) yield TranscriptFinal(text);
    }
  }

  /// The user's turn, once per turn, before the model's reply.
  Iterable<AiSessionEvent> _reportInput() sync* {
    if (mode != GeminiLiveMode.conversation || _inputReported) return;
    _inputReported = true;
    final text = _input.toString().trim();
    _input.clear();
    if (text.isNotEmpty) yield TranscriptFinal(text);
  }

  @override
  void sendPcm(Uint8List pcm16) {
    if (manualTurns && !_activityOpen) {
      send({
        'realtimeInput': {'activityStart': <String, Object?>{}},
      });
      _activityOpen = true;
    }
    send({
      'realtimeInput': {
        'audio': {'data': base64Encode(pcm16), 'mimeType': _pcmMime},
      },
    });
  }

  /// Ends the audio turn and waits for the reply / final transcript.
  ///
  /// A translation has no turns and streams silence once done. Ending the
  /// stream right after speech drops its tail, so [finish] first pads
  /// [flush] of silence, then waits until no speech or text arrived for
  /// [quiet].
  @override
  Future<void> finish({
    Duration timeout = const Duration(minutes: 2),
    Duration quiet = const Duration(milliseconds: 2500),
    Duration flush = const Duration(milliseconds: 1500),
  }) async {
    if (mode == GeminiLiveMode.translation) {
      const step = Duration(milliseconds: 100);
      final chunk = Uint8List(inputRate * 2 * step.inMilliseconds ~/ 1000);
      for (var t = Duration.zero; t < flush; t += step) {
        sendPcm(chunk);
        await Future<void>.delayed(step);
      }
      send({
        'realtimeInput': {'audioStreamEnd': true},
      });
      return _settle(quiet, timeout);
    }
    final done = waitFor(
      mode == GeminiLiveMode.transcription ? _transcribed : _turnComplete,
      timeout: timeout,
    );
    if (manualTurns) {
      if (_activityOpen) {
        send({
          'realtimeInput': {'activityEnd': <String, Object?>{}},
        });
        _activityOpen = false;
      }
    } else {
      send({
        'realtimeInput': {'audioStreamEnd': true},
      });
    }
    await done;
  }

  Future<void> _settle(Duration quiet, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().difference(_lastEvent) < quiet) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('Translation did not settle.', timeout);
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  void sendText(String text) {
    _inputReported = true; // typed turns need no transcript event
    send({
      'realtimeInput': {'text': text},
    });
  }

  /// Gemini answers typed turns by itself; wait for the reply.
  @override
  Future<ResponseDone> respond({
    Duration timeout = const Duration(minutes: 2),
  }) async {
    await waitFor(_turnComplete, timeout: timeout);
    return ResponseDone(text: _lastReply);
  }

  /// The service interrupts on user speech; there is no cancel message.
  @override
  void cancelResponse() {}
}
