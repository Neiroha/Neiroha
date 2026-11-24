import 'dart:async';
import 'dart:typed_data';

import 'package:neiroha/data/ai/protocols/audio/pcm_resample.dart';
import 'package:neiroha/data/services/synthesis/sentence_speech_pipeline.dart';
import 'package:neiroha/data/services/transcription/audio_file_transcriber.dart';
import 'package:neiroha/data/services/transcription/media_pcm_decoder.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/llm/tool_chat.dart';
import 'package:neiroha/domain/synthesis/sentence_chunker.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

import 'character_brain.dart';
import 'character_tools.dart';
import 'conversation_engine.dart';
import 'reply_player.dart';

/// Synthesises the character's line with its own voice (any TTS provider).
typedef SpeakText =
    Stream<TtsEvent> Function(String text, TtsCancelToken cancellation);

/// The character's voice for a reply delivered in [style] (empty = as
/// usual), e.g. passed to the TTS as its delivery instruction.
typedef StyledSpeech = SpeakText Function(String style);

/// AI companion: the user types, or speaks (local VAD finds the end of a
/// turn and STT transcribes it); the LLM answers in character and the
/// character's own TTS voice (optionally followed by VC) speaks the reply.
/// Half duplex: the microphone is ignored while the character thinks or
/// speaks. Without [vad] and [transcriber] the chat is typed only.
///
/// A model that calls functions ([ToolCallingLanguageModel]) answers through
/// [CharacterBrain]: it may use [tools], then replies as JSON with the line,
/// its delivery style and emotion; the style reaches the voice through
/// [speakWith]. Other models stream: each sentence the LLM finishes goes to
/// TTS (and VC) at once and plays while the next one is written.
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
    this.tools = const [],
    this.speakWith,
    this.instructions,
    List<LlmChatMessage> history = const [],
  }) : _history = [...history],
       _perSentenceVc =
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

  final VoiceActivityDetector? vad;
  final Transcriber? transcriber;
  final LanguageModel llm;
  final List<CharacterTool> tools;
  final StyledSpeech? speakWith;

  /// Extra instructions read at each turn (e.g. remembered facts).
  final String Function()? instructions;
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
  final List<LlmChatMessage> _history;
  StreamSubscription<Uint8List>? _micSub;
  late VadStream? _vad = vad?.open(sampleRate: sttRate);
  final _heard = BytesBuilder(copy: false);
  TtsCancelToken _turn = TtsCancelToken();
  bool _busy = false;
  bool _stopped = false;

  /// The model rejected tool calls; stream plain replies instead.
  bool _plainOnly = false;

  List<LlmChatMessage> get history => List.unmodifiable(_history);

  @override
  Stream<ConversationEvent> get events => _events.stream;

  void _emit(ConversationEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  void _state(ConversationState s) => _emit(ConversationStateChanged(s));

  /// Whether spoken turns are possible (VAD and STT are available).
  bool get listens => vad != null && transcriber != null;

  @override
  Future<void> start() async {
    _state(ConversationState.connecting);
    if (!listens) {
      _state(ConversationState.listening);
      return;
    }
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
    final vad = _vad;
    if (_busy || _stopped || vad == null) return;
    _heard.add(pcm);
    final ended = vad.feed(pcm);
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
    final transcript = await transcriber!.transcribe(
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
      if (llm case final ToolCallingLanguageModel model when !_plainOnly) {
        try {
          await _answerWithTools(model);
          return;
        } on LlmChatException catch (e) {
          // An OpenAI-compatible server without tools or JSON Schema
          // output: answer by plain streaming from now on.
          if (!const {400, 404, 422}.contains(e.statusCode)) rethrow;
          _plainOnly = true;
        }
      }
      final reply = StringBuffer();
      final deltas =
          streamCompletion(llm, [
            LlmChatMessage(role: 'system', content: '$_system\n\n$_style'),
            ..._history,
          ], cancellation: _turn).map((delta) {
            reply.write(delta);
            _emit(CharacterTurn(delta));
            return delta;
          });
      try {
        await _speak(chunkSentences(deltas), speak);
      } on FormatException {
        // An empty answer has nothing to speak; anything else is an error.
        if (reply.toString().trim().isNotEmpty) rethrow;
      } finally {
        final text = reply.toString().trim();
        _remember(text);
        _emit(CharacterTurn(text, done: true));
      }
    } on TtsCancelledException {
      // Stopped mid-turn.
    } catch (error) {
      _emit(ConversationFailed(error));
    } finally {
      _busy = false;
      _vad = vad?.open(sampleRate: sttRate);
      _heard.clear();
      if (!_stopped) _state(ConversationState.listening);
    }
  }

  String get _system {
    final extra = instructions?.call().trim() ?? '';
    return extra.isEmpty ? systemPrompt : '$systemPrompt\n\n$extra';
  }

  void _remember(String text) {
    if (text.isEmpty) return;
    _history.add(LlmChatMessage(role: 'assistant', content: text));
    if (_history.length > maxHistory) {
      _history.removeRange(0, _history.length - maxHistory);
    }
  }

  /// Plays the voice for [sentences] as each one is synthesised.
  Future<void> _speak(Stream<String> sentences, SpeakText voice) async {
    final pipeline = SentenceSpeechPipeline(
      speak: voice,
      conversions: [if (_perSentenceVc) ?conversion],
      decode: decode,
    );
    await for (final e in pipeline.run(sentences, cancellation: _turn)) {
      if (_stopped) break;
      if (e is TtsAudioStarted) {
        _state(ConversationState.speaking);
        await _player.begin(e.format);
      }
      if (e is TtsAudioChunk) await _player.add(e.bytes);
    }
    await _player.end();
  }

  Future<void> _answerWithTools(ToolCallingLanguageModel model) async {
    final reply = await CharacterBrain(model, tools: tools).answer(
      [
        ToolChatMessage.system('$_system\n\n${CharacterBrain.replyRules}'),
        for (final m in _history)
          m.role == 'assistant'
              ? ToolChatMessage.assistant(m.content)
              : ToolChatMessage.user(m.content),
      ],
      cancellation: _turn,
      onTool: (use) => _emit(ToolUsed(use.name, use.arguments, use.result)),
    );
    _remember(reply.say);
    _emit(
      CharacterTurn(
        reply.say,
        done: true,
        emotion: reply.emotion,
        style: reply.style,
      ),
    );
    final voice = speakWith?.call(reply.style) ?? speak;
    await _speak(chunkSentences(Stream.value(reply.say)), voice);
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
