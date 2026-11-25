import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/conversation/character_live_settings.dart';
import 'package:neiroha/data/services/conversation/character_tools.dart';
import 'package:neiroha/data/services/conversation/conversation_engine.dart';
import 'package:neiroha/data/services/conversation/conversation_factory.dart';
import 'package:neiroha/data/services/conversation/platform_conversation_audio.dart';
import 'package:neiroha/data/services/synthesis/voice_chain_runner.dart';
import 'package:neiroha/data/services/transcription/media_pcm_decoder.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/synthesis/voice_chain.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/quick_tts/generate_bar.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/chat_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';

import 'chat_bubbles.dart';
import 'chat_memory_dialog.dart';
import 'chat_header.dart';
import 'chat_recorder.dart';
import 'chat_settings_panel.dart';

/// One chat with a character. Every line is saved as it happens, so a chat
/// can be left and picked up again: the model gets the recent history and
/// what the character remembered.
///
/// AI companion: typing sends a turn; the microphone button opens spoken
/// turns. Live call: the call button connects the Realtime model. Replies
/// keep their audio and can be played again. The settings panel sits at the
/// right on a wide window, in a dialog otherwise.
class ChatView extends ConsumerStatefulWidget {
  const ChatView({
    super.key,
    required this.session,
    required this.character,
    this.onBack,
  });

  final db.ChatSession session;
  final db.VoiceAsset character;
  final VoidCallback? onBack;

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final ChatMemory _memory;
  CharacterLiveSettings _settings = const CharacterLiveSettings();
  ConversationEngine? _engine;
  bool _engineListens = false;
  PlatformConversationAudio? _io;
  StreamSubscription<ConversationEvent>? _sub;
  ConversationState _state = ConversationState.idle;
  bool _starting = false;
  String _pending = '';
  String? _error;
  late final ChatRecorder _recorder;
  VoiceChain _chain = VoiceChain.empty;
  bool _panelOpen = true;

  /// Settings changed while a call or the microphone runs.
  bool _changedWhileLive = false;

  ChatEngine get _kind => ChatEngine.fromName(widget.session.engine);
  db.AppDatabase get _db => ref.read(databaseProvider);

  @override
  void initState() {
    super.initState();
    _memory = ChatMemory(_decodeFacts(widget.session.memoryJson), (facts) {
      unawaited(_db.saveChatMemory(widget.session.id, facts));
      if (mounted) setState(() {});
    });
    _recorder = ChatRecorder(_db, widget.session.id);
    _input.addListener(() => setState(() {}));
    unawaited(_loadSettings());
  }

  static List<String> _decodeFacts(String raw) {
    try {
      final o = jsonDecode(raw);
      return o is List ? [for (final f in o) '$f'] : const [];
    } on FormatException {
      return const [];
    }
  }

  Future<void> _loadSettings() async {
    final s = await CharacterLiveSettings.load(_db, widget.character.id);
    final chain = await VoiceChainHook.load(_db, widget.character.id);
    if (mounted) {
      setState(() {
        _settings = s;
        _chain = chain;
      });
    }
  }

  bool get _live =>
      _engine != null && (_kind == ChatEngine.realtime || _engineListens);

  Future<void> _applySettings(CharacterLiveSettings updated) async {
    if (!mounted) return;
    setState(() => _settings = updated);
    await updated.save(_db, widget.character.id);
    if (!mounted) return;
    // A typed chat restarts on its next turn; a live one keeps going.
    if (_live) {
      setState(() => _changedWhileLive = true);
    } else {
      await _stopEngine();
    }
  }

  @override
  void dispose() {
    unawaited(_stopEngine());
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ConversationFactory? _factory() {
    final router = ref.read(aiCapabilityRouterProvider).value;
    if (router == null) return null;
    final ffmpeg = kIsWeb
        ? null
        : MediaPcmDecoder(ref.read(ffmpegServiceProvider));
    return ConversationFactory(
      router,
      decode: ffmpeg == null
          ? null
          : (bytes, format) =>
                decodeSpeechBytes(ffmpeg, bytes, format.extension),
    );
  }

  Future<List<LlmChatMessage>> _history() async => [
    for (final m in await _db.getChatMessages(widget.session.id))
      if (m.role == 'user' || m.role == 'character')
        LlmChatMessage(
          role: m.role == 'user' ? 'user' : 'assistant',
          content: m.content,
        ),
  ].reversed.take(20).toList().reversed.toList();

  /// The running engine, (re)started when the microphone choice changed.
  Future<ConversationEngine?> _ensureEngine({required bool listen}) async {
    if (_engine != null &&
        (_kind == ChatEngine.realtime || _engineListens == listen)) {
      return _engine;
    }
    await _stopEngine();
    final factory = _factory();
    if (factory == null) return null;
    setState(() {
      _error = null;
      _starting = true;
    });
    try {
      final providers = await _db.getAllProviders();
      final engine = factory.create(
        engine: _kind,
        character: widget.character,
        characterProvider: providers
            .where((p) => p.id == widget.character.providerId)
            .firstOrNull,
        settings: _settings,
        io: _io ??= PlatformConversationAudio(),
        chain: _chain = await VoiceChainHook.load(_db, widget.character.id),
        memory: _memory,
        history: await _history(),
        listen: listen,
      );
      _engine = engine;
      _engineListens = listen;
      _changedWhileLive = false;
      _sub = engine.events.listen(_onEvent);
      await engine.start();
      return engine;
    } catch (error) {
      await _stopEngine();
      if (mounted) setState(() => _error = '$error');
      return null;
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stopEngine() async {
    final engine = _engine;
    _engine = null;
    _engineListens = false;
    await engine?.stop();
    await _sub?.cancel();
    _sub = null;
    _pending = '';
    if (mounted) setState(() => _state = ConversationState.idle);
  }

  void _onEvent(ConversationEvent event) {
    if (!mounted) return;
    setState(() {
      switch (event) {
        case ConversationStateChanged(:final state):
          _state = state;
        case UserTurn(:final text):
          _recorder.user(text);
        case CharacterTurn(:final text, done: false):
          _pending += text;
        case CharacterTurn(:final text, :final emotion, :final style):
          final said = text.trim().isEmpty ? _pending : text;
          _pending = '';
          _recorder.reply(said, emotion: emotion, style: style);
        case ToolUsed(:final name, :final arguments, :final result):
          _recorder.tool(name, arguments, result);
        case ReplyAudio(:final format, :final bytes):
          _recorder.audio(format, bytes);
        case ConversationFailed(:final error):
          _error = '$error';
      }
    });
    _scrollToEnd();
  }

  Future<void> _replay(String path, String text) async {
    final playback = ref.read(playbackNotifierProvider);
    final player = ref.read(playbackNotifierProvider.notifier);
    if (playback.audioPath == path && playback.isPlaying) {
      await player.stop();
    } else {
      await player.load(path, text, subtitle: widget.character.name);
    }
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    final engine = await _ensureEngine(listen: _engineListens);
    await engine?.sendText(text);
  }

  bool get _busy =>
      _starting ||
      _state == ConversationState.thinking ||
      (_kind == ChatEngine.companion && _state == ConversationState.speaking);

  Future<void> _toggleMic() async {
    if (_engineListens) {
      await _stopEngine();
    } else {
      await _ensureEngine(listen: true);
    }
  }

  Future<void> _toggleCall() async =>
      _engine == null ? _ensureEngine(listen: true) : _stopEngine();

  ChatSettingsPanel _panel(
    CapabilityRouter router, {
    VoidCallback? onClose,
    CharacterLiveSettings? settings,
    ValueChanged<CharacterLiveSettings>? onChanged,
  }) {
    final c = widget.character;
    final providers =
        ref.read(ttsProvidersStreamProvider).value ?? const <db.TtsProvider>[];
    final provider = providers.where((p) => p.id == c.providerId).firstOrNull;
    return ChatSettingsPanel(
      key: ValueKey(('panel', c.id)),
      character: c,
      settings: settings ?? _settings,
      router: router,
      engine: _kind,
      chain: _chain,
      voiceLabel: [
        ?provider?.name,
        ?c.modelName,
        ?c.presetVoiceName,
      ].where((s) => s.trim().isNotEmpty).join(' · '),
      defaultPersona: defaultPersona(
        name: c.name,
        description: c.description,
        voiceInstruction: c.voiceInstruction,
      ),
      appliesLater: _changedWhileLive && _live,
      onChanged: onChanged ?? _applySettings,
      onClose: onClose,
    );
  }

  /// A narrow window shows the panel in a dialog.
  Future<void> _settingsDialog(CapabilityRouter router) {
    final current = ValueNotifier(_settings);
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 440,
          height: 640,
          child: ValueListenableBuilder(
            valueListenable: current,
            builder: (_, settings, _) => _panel(
              router,
              settings: settings,
              onChanged: (s) {
                current.value = s;
                unawaited(_applySettings(s));
              },
              onClose: () => Navigator.pop(ctx),
            ),
          ),
        ),
      ),
    ).whenComplete(current.dispose);
  }

  Future<void> _showMemory() => showChatMemoryDialog(context, _memory);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final router = ref.watch(aiCapabilityRouterProvider).value;
    final messages =
        ref.watch(chatMessagesStreamProvider(widget.session.id)).value ??
        const <db.ChatMessage>[];
    final playback = ref.watch(playbackNotifierProvider);
    final playing = playback.isPlaying ? playback.audioPath : null;
    final name = widget.character.name;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 880;
        final chat = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChatHeader(
              session: widget.session,
              character: widget.character,
              engine: _kind,
              state: _state,
              running: _engine != null,
              starting: _starting,
              converts: _chain.audioSteps.any(
                (s) => s.kind == VoiceChainStepKind.convert,
              ),
              memoryCount: _memory.facts.length,
              settingsOpen: wide && _panelOpen,
              onMemory: _showMemory,
              onSettings: () {
                unawaited(_loadSettings());
                if (wide) {
                  setState(() => _panelOpen = !_panelOpen);
                } else if (router != null) {
                  unawaited(_settingsDialog(router));
                }
              },
              onCall: () => unawaited(_toggleCall()),
              onBack: widget.onBack,
            ),
            const Divider(height: 1),
            if (_error != null) _errorBar(),
            Expanded(
              child: messages.isEmpty && _pending.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _kind == ChatEngine.realtime
                              ? l.chatEmptyRealtime(name)
                              : l.chatEmptyCompanion(name),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.fg.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: messages.length + (_pending.isEmpty ? 0 : 1),
                      itemBuilder: (_, i) => i < messages.length
                          ? ChatBubble.message(
                              messages[i],
                              characterName: name,
                              playingPath: playing,
                              onPlay: _replay,
                            )
                          : ChatBubble.pending(_pending, characterName: name),
                    ),
            ),
            QuickTtsGenerateBar(
              controller: _input,
              generating: false,
              roomy: true,
              hintText: l.chatComposerHint(name),
              sendIcon: Icons.arrow_upward_rounded,
              sendTooltip: l.quickTtsSendHint,
              onGenerate: _busy ? null : _send,
              onStop: () {},
              leading: _kind == ChatEngine.companion ? _micButton(l) : null,
            ),
          ],
        );
        if (!wide || !_panelOpen || router == null) return chat;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: chat),
            const VerticalDivider(width: 1),
            SizedBox(width: 340, child: _panel(router)),
          ],
        );
      },
    );
  }

  Widget _errorBar() => Material(
    color: Colors.redAccent.withValues(alpha: 0.12),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              _error!,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: () => setState(() => _error = null),
          ),
        ],
      ),
    ),
  );

  Widget _micButton(AppLocalizations l) {
    final canListen = _factory()?.companionCanListen ?? false;
    final on = _engineListens && _engine != null;
    return IconButton(
      tooltip: !canListen
          ? l.chatMicUnavailable
          : on
          ? l.chatMicStop
          : l.chatMicStart,
      isSelected: on,
      color: on ? AppTheme.accentColor : null,
      onPressed: !canListen || _starting ? null : _toggleMic,
      icon: Icon(on ? Icons.mic_rounded : Icons.mic_none_rounded, size: 20),
    );
  }
}
