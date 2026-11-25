import 'dart:async';
import 'dart:typed_data';

import 'package:neiroha/data/ai/protocols/audio/pcm_resample.dart';
import 'package:neiroha/data/services/synthesis/sentence_speech_pipeline.dart'
    show AudioDecoder;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

import 'character_tools.dart';
import 'conversation_engine.dart';
import 'reply_player.dart';

/// Full-duplex voice chat with a Realtime model (GPT Realtime / Live style).
/// The server detects turns and replies on its own; when the user speaks
/// over the character, playback stops (barge-in).
///
/// Without echo cancellation the character would hear itself through the
/// speakers, so [allowInterruptions] = false (the default) mutes the
/// microphone while a reply plays. Turn it on with headphones.
class RealtimeConversation implements ConversationEngine {
  RealtimeConversation({
    required this.model,
    required this.io,
    required this.instructions,
    this.voice,
    this.conversion,
    this.decode,
    this.allowInterruptions = false,
    this.tools = const [],
  }) : _player = ReplyPlayer(io, conversion: conversion, decode: decode);

  /// Functions the character may call, when the session supports them.
  final List<CharacterTool> tools;

  final RealtimeModel model;
  final ConversationAudioIo io;
  final String instructions;
  final String? voice;
  final VoiceConversionStage? conversion;

  /// Lets phrase-by-phrase VC read converters that return encoded files.
  final AudioDecoder? decode;
  final bool allowInterruptions;
  final ReplyPlayer _player;

  final _events = StreamController<ConversationEvent>.broadcast();
  RealtimeSession? _session;
  StreamSubscription<AiSessionEvent>? _sessionSub;
  StreamSubscription<Uint8List>? _micSub;

  /// A reply is playing (it may already be fully received).
  bool _replying = false;

  /// The server is still generating a reply, so it can be cancelled.
  bool _generating = false;

  /// [stop] ran, or the session ended: a start still in flight gives up.
  bool _stopped = false;

  /// The reply being played, to truncate it at what was heard.
  String? _replyItem;
  DateTime? _replyStarted;
  int _replyReceivedMs = 0;
  Future<void> _playback = Future.value();
  Future<void> _queue = Future.value();

  @override
  Stream<ConversationEvent> get events => _events.stream;

  void _emit(ConversationEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  void _state(ConversationState s) => _emit(ConversationStateChanged(s));

  /// The catalog says the model calls functions, or says nothing about it
  /// (a model added by hand): then the tools are tried.
  bool get _modelCallsTools {
    final features = model.descriptor.features;
    return features.isEmpty || features.contains(AiFeature.toolCalls);
  }

  bool _toolsOffered = false;

  /// The session has answered, so it accepted its setup.
  bool _answered = false;

  /// Whether the character's tools are on for this call.
  bool get toolsActive => _toolsOffered;

  @override
  Future<void> start() async {
    _state(ConversationState.connecting);
    await _connect(withTools: tools.isNotEmpty && _modelCallsTools);
    if (_stopped) return;
    try {
      final mic = await io.startMicrophone();
      if (_stopped) {
        // Hung up while the microphone was opening.
        await io.stopMicrophone();
        return;
      }
      _micSub = mic.listen((pcm) {
        final session = _session;
        if (session == null || (_replying && !allowInterruptions)) return;
        try {
          session.sendPcm(
            resamplePcm16(pcm, io.microphoneRate, session.inputSampleRate),
          );
        } catch (error) {
          // The socket closed between frames: end the call.
          unawaited(_end(error));
        }
      });
    } catch (error) {
      // No microphone: typed turns still work.
      _emit(ConversationFailed(error));
    }
    _state(ConversationState.listening);
  }

  Future<void> _connect({required bool withTools}) async {
    _toolsOffered = withTools;
    final RealtimeSession session;
    try {
      session = await model.connect(
        RealtimeConfig(
          instructions: instructions,
          voice: voice,
          serverVad: true,
          transcribeInput: true,
          tools: withTools ? [for (final t in tools) t.spec] : const [],
        ),
      );
    } catch (_) {
      // A setup with tools refused outright: connect without them.
      if (!withTools || _stopped) rethrow;
      return _connect(withTools: false);
    }
    if (_stopped) {
      // Hung up during the handshake: this session is not wanted.
      await session.close().catchError((_) {});
      return;
    }
    _session = session;
    // Handle events strictly in order: audio must not overtake begin().
    _sessionSub = session.events.listen(
      (e) => _queue = _queue.then((_) => _onEvent(e)).catchError(_fail),
      onError: (Object e) => _queue = _queue.then((_) => _onSessionError(e)),
    );
  }

  /// A server that rejects the tools fails before its first answer; the
  /// call then goes on without them. Any other session error ends the call.
  Future<void> _onSessionError(Object error) async {
    final old = _session;
    if (_stopped || old == null) return;
    if (!_toolsOffered || _answered) return _end(error);
    _session = null;
    await _sessionSub?.cancel();
    await old.close().catchError((_) {});
    try {
      await _connect(withTools: false);
    } catch (e) {
      await _end(e);
    }
  }

  /// The session is gone: release the microphone, playback and socket, and
  /// tell the page the call ended so it can start a new one.
  Future<void> _end(Object error) async {
    if (_stopped) return;
    _stopped = true;
    _fail(error);
    await _release();
    _state(ConversationState.idle);
  }

  Future<void> _release() async {
    await _micSub?.cancel();
    _micSub = null;
    await io.stopMicrophone().catchError((_) {});
    await _player.stop();
    await _playback.catchError((_) {});
    _replying = false;
    _generating = false;
    await _sessionSub?.cancel();
    _sessionSub = null;
    final session = _session;
    _session = null;
    await session?.close().catchError((_) {});
  }

  void _emitRecording() {
    final heard = _player.takeRecording();
    if (heard != null) _emit(ReplyAudio(heard.format, heard.bytes));
  }

  Future<void> _onEvent(AiSessionEvent event) async {
    if (event
        case AudioDelta() ||
            TranscriptDelta() ||
            ResponseDone() ||
            FunctionCallRequested()) {
      _answered = true;
    }
    switch (event) {
      case SpeechStarted():
        if (_replying) await _interrupt();
        _state(ConversationState.listening);
      case SpeechStopped():
        _state(ConversationState.thinking);
      case TranscriptFinal(:final text) when text.isNotEmpty:
        _emit(UserTurn(text));
      case TranscriptDelta(:final text):
        _generating = true;
        _emit(CharacterTurn(text));
      case FunctionCallRequested(:final callId, :final name, :final arguments):
        _generating = true;
        final result = await runCharacterTool(tools, name, arguments);
        _emit(ToolUsed(name, arguments, result));
        if (_session case final ToolCallingRealtimeSession s) {
          s.sendToolResult(callId, result);
        }
      case AudioDelta(:final pcm, :final sampleRate, :final itemId):
        _generating = true;
        if (itemId != null && itemId != _replyItem) {
          _replyItem = itemId;
          _replyReceivedMs = 0;
          _replyStarted = null;
        }
        _replyReceivedMs += pcm.length * 1000 ~/ (sampleRate * 2);
        if (!_replying) {
          _replying = true;
          _replyStarted = DateTime.now();
          _state(ConversationState.speaking);
          await _player.begin(
            TtsAudioFormat(
              AudioEncoding.pcmS16le,
              sampleRate: sampleRate,
              channels: 1,
            ),
          );
        }
        await _player.add(pcm);
      case ResponseDone(:final text):
        _generating = false;
        _emit(CharacterTurn(text ?? '', done: true));
        if (!_replying) return;
        // Converting the whole reply takes a moment before it plays.
        if (_player.convertsWholeReply) _state(ConversationState.thinking);
        _playback = _player
            .end()
            .catchError((Object e) {
              if (e is! TtsCancelledException) _fail(e);
            })
            .whenComplete(() {
              _replying = false;
              _emitRecording();
              _state(ConversationState.listening);
            });
      default:
    }
  }

  Future<void> _interrupt() async {
    // Once the server finished the reply only local playback is left;
    // cancelling a finished response is an error on OpenAI.
    if (_generating) _session?.cancelResponse();
    _generating = false;
    // Tell the model where the user cut in, so it does not assume they
    // heard the rest of the reply.
    final item = _replyItem, started = _replyStarted;
    if (_session case final TruncatableRealtimeSession s?
        when item != null && started != null) {
      final played = DateTime.now().difference(started).inMilliseconds;
      s.truncate(item, played.clamp(0, _replyReceivedMs));
    }
    _replyItem = null;
    _replyStarted = null;
    await _player.stop();
    _replying = false;
    _emitRecording();
  }

  void _fail(Object error) => _emit(ConversationFailed(error));

  @override
  Future<void> sendText(String text) async {
    final session = _session;
    if (session == null || text.trim().isEmpty) return;
    if (_replying) await _interrupt();
    _emit(UserTurn(text.trim()));
    session.sendText(text.trim());
    _state(ConversationState.thinking);
    unawaited(session.respond().then((_) {}, onError: (_) {}));
  }

  @override
  Future<void> stop() async {
    final ended = _stopped;
    _stopped = true;
    if (!ended) await _release();
    if (!ended) _state(ConversationState.idle);
    if (!_events.isClosed) await _events.close();
  }
}
