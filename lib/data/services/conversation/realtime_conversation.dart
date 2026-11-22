import 'dart:async';
import 'dart:typed_data';

import 'package:neiroha/data/ai/protocols/audio/pcm_resample.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

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
    this.allowInterruptions = false,
  }) : _player = ReplyPlayer(io, conversion: conversion);

  final RealtimeModel model;
  final ConversationAudioIo io;
  final String instructions;
  final String? voice;
  final VoiceConversionStage? conversion;
  final bool allowInterruptions;
  final ReplyPlayer _player;

  final _events = StreamController<ConversationEvent>.broadcast();
  RealtimeSession? _session;
  StreamSubscription<AiSessionEvent>? _sessionSub;
  StreamSubscription<Uint8List>? _micSub;
  bool _replying = false;
  Future<void> _playback = Future.value();
  Future<void> _queue = Future.value();

  @override
  Stream<ConversationEvent> get events => _events.stream;

  void _emit(ConversationEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  void _state(ConversationState s) => _emit(ConversationStateChanged(s));

  @override
  Future<void> start() async {
    _state(ConversationState.connecting);
    final session = await model.connect(
      RealtimeConfig(
        instructions: instructions,
        voice: voice,
        serverVad: true,
        transcribeInput: true,
      ),
    );
    _session = session;
    // Handle events strictly in order: audio must not overtake begin().
    _sessionSub = session.events.listen(
      (e) => _queue = _queue.then((_) => _onEvent(e)).catchError(_fail),
      onError: _fail,
    );
    try {
      final mic = await io.startMicrophone();
      _micSub = mic.listen((pcm) {
        if (_replying && !allowInterruptions) return;
        session.sendPcm(
          resamplePcm16(pcm, io.microphoneRate, session.inputSampleRate),
        );
      });
    } catch (error) {
      // No microphone: typed turns still work.
      _emit(ConversationFailed(error));
    }
    _state(ConversationState.listening);
  }

  Future<void> _onEvent(AiSessionEvent event) async {
    switch (event) {
      case SpeechStarted():
        if (_replying) await _interrupt();
        _state(ConversationState.listening);
      case SpeechStopped():
        _state(ConversationState.thinking);
      case TranscriptFinal(:final text) when text.isNotEmpty:
        _emit(UserTurn(text));
      case TranscriptDelta(:final text):
        _emit(CharacterTurn(text));
      case AudioDelta(:final pcm, :final sampleRate):
        if (!_replying) {
          _replying = true;
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
        _emit(CharacterTurn(text ?? '', done: true));
        if (!_replying) return;
        if (conversion != null) _state(ConversationState.thinking);
        _playback = _player
            .end()
            .catchError((Object e) {
              if (e is! TtsCancelledException) _fail(e);
            })
            .whenComplete(() {
              _replying = false;
              _state(ConversationState.listening);
            });
      default:
    }
  }

  Future<void> _interrupt() async {
    _session?.cancelResponse();
    await _player.stop();
    _replying = false;
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
    await _micSub?.cancel();
    _micSub = null;
    await io.stopMicrophone();
    await _player.stop();
    await _playback.catchError((_) {});
    await _sessionSub?.cancel();
    await _session?.close();
    _session = null;
    _state(ConversationState.idle);
    await _events.close();
  }
}
