import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/conversation/character_live_settings.dart';
import 'package:neiroha/data/services/conversation/character_tools.dart';
import 'package:neiroha/data/services/conversation/conversation_engine.dart';
import 'package:neiroha/data/services/conversation/conversation_factory.dart';
import 'package:neiroha/data/services/conversation/platform_conversation_audio.dart';
import 'package:neiroha/data/services/synthesis/voice_chain_runner.dart';
import 'package:neiroha/data/services/transcription/media_pcm_decoder.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/quick_tts/generate_bar.dart';
import 'package:neiroha/presentation/widgets/voice_character/components.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/chat_providers.dart';

import 'chat_bubbles.dart';
import 'chat_memory_dialog.dart';
import 'chat_session_list.dart' show chatHeaderHeight;
import 'chat_settings_dialog.dart';
import 'new_chat_dialog.dart';

/// One chat with a character. Every line is saved as it happens, so a chat
/// can be left and picked up again: the model gets the recent history and
/// what the character remembered.
///
/// AI companion: typing sends a turn; the microphone button opens spoken
/// turns. Live call: the call button connects the Realtime model.
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
  Future<void> _writes = Future.value();

  ChatEngine get _kind => ChatEngine.fromName(widget.session.engine);
  db.AppDatabase get _db => ref.read(databaseProvider);

  @override
  void initState() {
    super.initState();
    _memory = ChatMemory(_decodeFacts(widget.session.memoryJson), (facts) {
      unawaited(_db.saveChatMemory(widget.session.id, facts));
      if (mounted) setState(() {});
    });
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
    if (mounted) setState(() => _settings = s);
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
        chain: await VoiceChainHook.load(_db, widget.character.id),
        memory: _memory,
        history: await _history(),
        listen: listen,
      );
      _engine = engine;
      _engineListens = listen;
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

  void _save(String role, String content, [Map<String, Object?>? meta]) {
    if (content.trim().isEmpty) return;
    _writes = _writes.then(
      (_) => _db
          .addChatMessage(
            widget.session.id,
            role: role,
            content: content.trim(),
            meta: meta,
          )
          .catchError((_) {}),
    );
  }

  void _onEvent(ConversationEvent event) {
    if (!mounted) return;
    setState(() {
      switch (event) {
        case ConversationStateChanged(:final state):
          _state = state;
        case UserTurn(:final text):
          _save('user', text);
        case CharacterTurn(:final text, done: false):
          _pending += text;
        case CharacterTurn(:final text, :final emotion, :final style):
          final said = text.trim().isEmpty ? _pending : text;
          _pending = '';
          _save('character', said, {
            'emotion': ?emotion,
            if (style != null && style.trim().isNotEmpty) 'style': style,
          });
        case ToolUsed(:final name, :final arguments, :final result):
          _save('tool', result, {'name': name, 'arguments': arguments});
        case ConversationFailed(:final error):
          _error = '$error';
      }
    });
    _scrollToEnd();
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

  Future<void> _editSettings() async {
    final router = ref.read(aiCapabilityRouterProvider).value;
    if (router == null) return;
    final updated = await showChatSettingsDialog(
      context: context,
      character: widget.character,
      settings: _settings,
      router: router,
      engine: _kind,
    );
    if (updated == null || !mounted) return;
    await updated.save(_db, widget.character.id);
    await _stopEngine();
    setState(() => _settings = updated);
  }

  Future<void> _showMemory() => showChatMemoryDialog(context, _memory);

  String _stateLabel(AppLocalizations l) => switch (_state) {
    ConversationState.idle => l.liveStateIdle,
    ConversationState.connecting => l.liveStateConnecting,
    ConversationState.listening => l.liveStateListening,
    ConversationState.thinking => l.liveStateThinking,
    ConversationState.speaking => l.liveStateSpeaking,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.watch(aiCapabilityRouterProvider);
    final messages =
        ref.watch(chatMessagesStreamProvider(widget.session.id)).value ??
        const <db.ChatMessage>[];
    final name = widget.character.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(l),
        const Divider(height: 1),
        if (_error != null)
          Material(
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
          ),
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
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: messages.length + (_pending.isEmpty ? 0 : 1),
                  itemBuilder: (_, i) => i < messages.length
                      ? ChatBubble.message(messages[i], characterName: name)
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
  }

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
      style: IconButton.styleFrom(minimumSize: const Size(32, 32)),
      color: on ? AppTheme.accentColor : null,
      onPressed: !canListen || _starting ? null : _toggleMic,
      icon: Icon(on ? Icons.mic_rounded : Icons.mic_none_rounded, size: 20),
    );
  }

  Widget _header(AppLocalizations l) {
    final c = widget.character;
    final running = _engine != null;
    final muted = Colors.white.withValues(alpha: 0.45);
    return SizedBox(
      height: chatHeaderHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        child: Row(
          children: [
            if (widget.onBack != null)
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              ),
            const SizedBox(width: 4),
            VoiceCharacterAvatar(
              radius: 16,
              name: c.name,
              avatarPath: c.avatarPath,
              selected: running,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.session.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    running
                        ? _stateLabel(l)
                        : '${c.name} · ${chatEngineLabel(l, _kind)}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: running ? AppTheme.accentColor : muted,
                    ),
                  ),
                ],
              ),
            ),
            if (_settings.usesVoiceConversion)
              Tooltip(
                message: l.liveVcActive,
                child: Icon(
                  Icons.auto_fix_high_rounded,
                  size: 18,
                  color: muted,
                ),
              ),
            IconButton(
              tooltip: l.chatMemory,
              onPressed: _showMemory,
              icon: Badge.count(
                count: _memory.facts.length,
                isLabelVisible: _memory.facts.isNotEmpty,
                child: const Icon(Icons.psychology_alt_outlined, size: 20),
              ),
            ),
            IconButton(
              tooltip: l.liveSettings,
              onPressed: _starting ? null : _editSettings,
              icon: const Icon(Icons.tune_rounded, size: 20),
            ),
            if (_kind == ChatEngine.realtime) ...[
              const SizedBox(width: 4),
              running
                  ? FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      onPressed: _toggleCall,
                      icon: const Icon(Icons.call_end_rounded, size: 18),
                      label: Text(l.chatCallEnd),
                    )
                  : FilledButton.icon(
                      onPressed: _starting ? null : _toggleCall,
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: Text(l.chatCallStart),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}
