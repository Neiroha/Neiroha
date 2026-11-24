import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:neiroha/data/services/synthesis/voice_chain_runner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/conversation/character_live_settings.dart';
import 'package:neiroha/data/services/conversation/conversation_engine.dart';
import 'package:neiroha/data/services/conversation/conversation_factory.dart';
import 'package:neiroha/data/services/conversation/platform_conversation_audio.dart';
import 'package:neiroha/data/services/transcription/media_pcm_decoder.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'live_settings_dialog.dart';

class _Turn {
  _Turn(this.user, this.text, {this.done = true});
  final bool user;
  String text;
  bool done;
}

/// Live voice chat with one character of the bank, in Realtime (full
/// duplex) or companion (ASR → LLM → character TTS) mode.
class LiveConversationPanel extends ConsumerStatefulWidget {
  const LiveConversationPanel({
    super.key,
    required this.mode,
    required this.bankAssets,
    this.initialVoiceId,
  });

  final DialogMode mode;
  final List<db.VoiceAsset> bankAssets;
  final String? initialVoiceId;

  @override
  ConsumerState<LiveConversationPanel> createState() =>
      _LiveConversationPanelState();
}

class _LiveConversationPanelState extends ConsumerState<LiveConversationPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <_Turn>[];
  String? _characterId;
  CharacterLiveSettings _settings = const CharacterLiveSettings();
  ConversationEngine? _engine;
  PlatformConversationAudio? _io;
  StreamSubscription<ConversationEvent>? _sub;
  ConversationState _state = ConversationState.idle;
  String? _error;

  db.VoiceAsset? get _character =>
      widget.bankAssets.where((a) => a.id == _characterId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _characterId = widget.bankAssets.any((a) => a.id == widget.initialVoiceId)
        ? widget.initialVoiceId
        : widget.bankAssets.firstOrNull?.id;
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    final id = _characterId;
    if (id == null) return;
    final settings = await CharacterLiveSettings.load(
      ref.read(databaseProvider),
      id,
    );
    if (mounted && id == _characterId) setState(() => _settings = settings);
  }

  @override
  void dispose() {
    unawaited(_stop());
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final character = _character;
    final router = ref.read(aiCapabilityRouterProvider).value;
    if (character == null || router == null) return;
    setState(() {
      _error = null;
      _state = ConversationState.connecting;
    });
    try {
      final providers = await ref.read(databaseProvider).getAllProviders();
      final io = _io ??= PlatformConversationAudio();
      final ffmpeg = kIsWeb
          ? null
          : MediaPcmDecoder(ref.read(ffmpegServiceProvider));
      final engine =
          ConversationFactory(
            router,
            decode: ffmpeg == null
                ? null
                : (bytes, format) =>
                      decodeSpeechBytes(ffmpeg, bytes, format.extension),
          ).create(
            mode: widget.mode,
            character: character,
            characterProvider: providers
                .where((p) => p.id == character.providerId)
                .firstOrNull,
            settings: _settings,
            io: io,
            chain: await VoiceChainHook.load(
              ref.read(databaseProvider),
              character.id,
            ),
          );
      _engine = engine;
      _sub = engine.events.listen(_onEvent);
      await engine.start();
    } catch (error) {
      await _stop();
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _stop() async {
    final engine = _engine;
    _engine = null;
    await engine?.stop();
    await _sub?.cancel();
    _sub = null;
    if (mounted) setState(() => _state = ConversationState.idle);
  }

  void _onEvent(ConversationEvent event) {
    if (!mounted) return;
    setState(() {
      switch (event) {
        case ConversationStateChanged(:final state):
          _state = state;
        case UserTurn(:final text):
          _turns.add(_Turn(true, text));
        case CharacterTurn(:final text, :final done):
          final last = _turns.lastOrNull;
          if (last != null && !last.user && !last.done) {
            if (done) {
              if (text.isNotEmpty) last.text = text;
              last.done = true;
            } else {
              last.text += text;
            }
          } else if (text.isNotEmpty) {
            _turns.add(_Turn(false, text, done: done));
          }
        case ConversationFailed(:final error):
          _error = '$error';
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _engine == null) return;
    _input.clear();
    await _engine!.sendText(text);
  }

  Future<void> _editSettings() async {
    final character = _character;
    final router = ref.read(aiCapabilityRouterProvider).value;
    if (character == null || router == null) return;
    final updated = await showLiveSettingsDialog(
      context: context,
      character: character,
      settings: _settings,
      router: router,
      mode: widget.mode,
    );
    if (updated == null || !mounted) return;
    await updated.save(ref.read(databaseProvider), character.id);
    setState(() => _settings = updated);
  }

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
    final running = _engine != null;
    final character = _character;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _characterId,
                  hint: Text(l.liveNoCharacter),
                  items: [
                    for (final a in widget.bankAssets)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: running
                      ? null
                      : (id) {
                          setState(() => _characterId = id);
                          unawaited(_loadSettings());
                        },
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                avatar: Icon(switch (_state) {
                  ConversationState.listening => Icons.mic_rounded,
                  ConversationState.speaking => Icons.volume_up_rounded,
                  ConversationState.thinking => Icons.more_horiz_rounded,
                  _ => Icons.circle_outlined,
                }, size: 16),
                label: Text(_stateLabel(l)),
              ),
              if (_settings.usesVoiceConversion) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: l.liveVcActive,
                  child: const Icon(Icons.auto_fix_high_rounded, size: 18),
                ),
              ],
              IconButton(
                tooltip: l.liveSettings,
                onPressed: running || character == null ? null : _editSettings,
                icon: const Icon(Icons.tune_rounded),
              ),
              const SizedBox(width: 4),
              running
                  ? FilledButton.tonalIcon(
                      onPressed: _stop,
                      icon: const Icon(Icons.stop_rounded),
                      label: Text(l.liveStop),
                    )
                  : FilledButton.icon(
                      onPressed: character == null ? null : _start,
                      icon: const Icon(Icons.mic_rounded),
                      label: Text(l.liveStart),
                    ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: _turns.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      widget.mode == DialogMode.realtime
                          ? l.liveEmptyRealtime
                          : l.liveEmptyCompanion,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withAlpha(120)),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _turns.length,
                  itemBuilder: (_, i) => _bubble(_turns[i], character),
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: running,
                  decoration: InputDecoration(
                    hintText: l.liveTypeHint,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(
                onPressed: running ? _send : null,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bubble(_Turn turn, db.VoiceAsset? character) => Align(
    alignment: turn.user ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 520),
      decoration: BoxDecoration(
        color: turn.user
            ? AppTheme.accentColor.withAlpha(60)
            : AppTheme.surfaceBright,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!turn.user && character != null)
            Text(
              character.name,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          SelectableText(turn.text),
        ],
      ),
    ),
  );
}
