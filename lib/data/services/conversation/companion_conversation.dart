import 'dart:async';
import 'dart:typed_data';

import 'package:neiroha/data/ai/protocols/audio/pcm_resample.dart';
import 'package:neiroha/data/services/synthesis/sentence_speech_pipeline.dart';
import 'package:neiroha/data/services/transcription/audio_file_transcriber.dart';
import 'package:neiroha/data/services/transcription/media_pcm_decoder.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/synthesis/sentence_chunker.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

import 'conversation_engine.dart';
import 'reply_player.dart';

/// Synthesises the character's line with its own voice (any TTS provider).
typedef SpeakText =
    Stream<TtsEvent> Function(String text, TtsCancelToken cancellation);

/// Cascaded companion: local VAD finds the end of what the user said, STT
/// transcribes it, the LLM answers in character, and the character's own TTS
/// voice (optionally followed by VC) speaks the reply. Half duplex: the
/// microphone is ignored while the character thinks or speaks.
///
/// The reply is streamed end to end: each sentence the LLM finishes goes to
/// TTS (and VC) at once and starts playing while the LLM is still writing
/// the next one.
class CompanionConversation implements ConversationEngine {
  CompanionConversation({
    required this.vad,
    required this.transcriber,
    required this.llm,
    required this.speak,
    required this.io,
    required this.systemPrompt,
    this.conversion,
    this.decode,
    this.languages = const [],
    this.maxHistory = 20,
  }) : _perSentenceVc =
           conversion == null || canConvertPerSentence([conversion], decode),
       _player = ReplyPlayer(
         io,
         // A converter that only returns encoded files (and no decoder):
         // collect the whole reply and convert it once, as before.
         conversion:
             conversion == null || canConvertPerSentence([conversion], decode)
             ? null
             : conversion,
       );

  static const sttRate = 16000;
  static const _style =
      'Reply as spoken dialogue: one to three short sentences, no markdown, '
      'no lists, no stage directions, in the language the user speaks.';

  final VoiceActivityDetector vad;
  final Transcriber transcriber;
  final LanguageModel llm;
  final SpeakText speak;
  final ConversationAudioIo io;
  final String systemPrompt;
  final VoiceConversionStage? conversion;

  /// Lets sentence streaming read engines that only return encoded audio.
  final AudioDecoder? decode;
  final List<String> languages;
  final int maxHistory;
  final ReplyPlayer _player;
  final bool _perSentenceVc;

  final _events = StreamController<ConversationEvent>.broadcast();
  final _history = <LlmChatMessage>[];
  StreamSubscription<Uint8List>? _micSub;
  late VadStream _vad = vad.open(sampleRate: sttRate);
  final _heard = BytesBuilder(copy: false);
  TtsCancelToken _turn = TtsCancelToken();
  bool _busy = false;
  bool _stopped = false;

  List<LlmChatMessage> get history => List.unmodifiable(_history);

  @override
  Stream<ConversationEvent> get events => _events.stream;

  void _emit(ConversationEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  void _state(ConversationState s) => _emit(ConversationStateChanged(s));

  @override
  Future<void> start() async {
    _state(ConversationState.connecting);
    try {
      final mic = await io.startMicrophone();
      _micSub = mic.listen(
        (pcm) => _onAudio(resamplePcm16(pcm, io.microphoneRate, sttRate)),
      );
    } catch (error) {
      _emit(ConversationFailed(error));
    }
    _state(ConversationState.listening);
  }

  /// Exposed for tests: feeds 16 kHz PCM16 mono as if from the microphone.
  void onAudioForTest(Uint8List pcm16k) => _onAudio(pcm16k);

  void _onAudio(Uint8List pcm) {
    if (_busy || _stopped) return;
    _heard.add(pcm);
    final ended = _vad.feed(pcm);
    if (ended.isEmpty) return;
    final audio = slicePcm(
      _heard.toBytes(),
      sttRate,
      ended.first.start,
      ended.first.end,
    );
    unawaited(_hear(audio));
  }

  Future<void> _hear(Uint8List audio) => _runTurn(() async {
    final transcript = await transcriber.transcribe(
      wavInput(audio, sttRate, name: 'turn'),
      options: TranscribeOptions(languages: languages),
      cancellation: _turn,
    );
    return transcript.text.trim();
  });

  @override
  Future<void> sendText(String text) =>
      _busy ? Future.value() : _runTurn(() async => text.trim());

  Future<void> _runTurn(Future<String> Function() userText) async {
    _busy = true;
    _turn = TtsCancelToken();
    _state(ConversationState.thinking);
    try {
      final said = await userText();
      if (said.isEmpty || _stopped) return;
      _emit(UserTurn(said));
      _history.add(LlmChatMessage(role: 'user', content: said));
      final reply = StringBuffer();
      final deltas =
          streamCompletion(llm, [
            LlmChatMessage(role: 'system', content: '$systemPrompt\n\n$_style'),
            ..._history,
          ], cancellation: _turn).map((delta) {
            reply.write(delta);
            _emit(CharacterTurn(delta));
            return delta;
          });
      final pipeline = SentenceSpeechPipeline(
        speak: speak,
        conversions: [if (_perSentenceVc) ?conversion],
        decode: decode,
      );
      try {
        await for (final e in pipeline.run(
          chunkSentences(deltas),
          cancellation: _turn,
        )) {
          if (_stopped) break;
          if (e is TtsAudioStarted) {
            _state(ConversationState.speaking);
            await _player.begin(e.format);
          }
          if (e is TtsAudioChunk) await _player.add(e.bytes);
        }
        await _player.end();
      } on FormatException {
        // An empty answer has nothing to speak; anything else is an error.
        if (reply.toString().trim().isNotEmpty) rethrow;
      } finally {
        final text = reply.toString().trim();
        if (text.isNotEmpty) {
          _history.add(LlmChatMessage(role: 'assistant', content: text));
          if (_history.length > maxHistory) {
            _history.removeRange(0, _history.length - maxHistory);
          }
        }
        _emit(CharacterTurn(text, done: true));
      }
    } on TtsCancelledException {
      // Stopped mid-turn.
    } catch (error) {
      _emit(ConversationFailed(error));
    } finally {
      _busy = false;
      _vad = vad.open(sampleRate: sttRate);
      _heard.clear();
      if (!_stopped) _state(ConversationState.listening);
    }
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    _turn.cancel();
    await _micSub?.cancel();
    await io.stopMicrophone();
    await _player.stop();
    _state(ConversationState.idle);
    await _events.close();
  }
}
