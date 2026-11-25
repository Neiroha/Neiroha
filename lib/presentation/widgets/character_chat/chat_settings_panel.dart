import 'dart:async';

import 'package:flutter/material.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/conversation/character_live_settings.dart';
import 'package:neiroha/data/services/conversation/conversation_engine.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/synthesis/voice_chain.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

import 'chat_session_list.dart' show chatHeaderHeight;

/// The character's chat settings beside the chat: the persona first, then
/// the model and what it can do, then where the voice comes from. Voice
/// conversion lives in the character's processing chain and is only shown.
class ChatSettingsPanel extends StatefulWidget {
  const ChatSettingsPanel({
    super.key,
    required this.character,
    required this.settings,
    required this.router,
    required this.engine,
    required this.chain,
    required this.voiceLabel,
    required this.defaultPersona,
    required this.onChanged,
    this.appliesLater = false,
    this.onClose,
  });

  final db.VoiceAsset character;
  final CharacterLiveSettings settings;
  final CapabilityRouter router;
  final ChatEngine engine;
  final VoiceChain chain;

  /// The character's TTS voice, e.g. "OpenAI · gpt-realtime-2.1-mini · marin".
  final String voiceLabel;
  final String defaultPersona;
  final ValueChanged<CharacterLiveSettings> onChanged;

  /// A call is running: model changes wait for the next one.
  final bool appliesLater;
  final VoidCallback? onClose;

  @override
  State<ChatSettingsPanel> createState() => _ChatSettingsPanelState();
}

class _ChatSettingsPanelState extends State<ChatSettingsPanel> {
  late final _persona = TextEditingController(text: widget.settings.persona);
  Timer? _typing;

  bool get _realtime => widget.engine == ChatEngine.realtime;

  @override
  void dispose() {
    // Keep what was typed when the panel closes mid-debounce.
    if (_typing?.isActive ?? false) {
      _typing!.cancel();
      final settings = widget.settings.withPersona(_persona.text.trim());
      final save = widget.onChanged;
      // Not while the tree is being torn down.
      scheduleMicrotask(() => save(settings));
    }
    _persona.dispose();
    super.dispose();
  }

  void _personaChanged(String _) {
    _typing?.cancel();
    _typing = Timer(const Duration(milliseconds: 600), () {
      widget.onChanged(widget.settings.withPersona(_persona.text.trim()));
    });
  }

  String _connectionName(ProviderConnection c) =>
      c.config.name.isEmpty ? c.plugin.displayName : c.config.name;

  List<(ProviderConnection, ModelDescriptor)> _models(AiCapability cap) => [
    for (final c in widget.router.serving(cap))
      for (final m in widget.router.modelsOf(c, cap)) (c, m),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = widget.settings;
    final cap = _realtime ? AiCapability.realtime : AiCapability.llm;
    final models = _models(cap);
    final chosen = _realtime
        ? (s.realtimeConnectionId, s.realtimeModelId)
        : (s.llmConnectionId, s.llmModelId);
    final picked = models.any((e) => (e.$1.id, e.$2.id) == chosen)
        ? (chosen.$1!, chosen.$2!)
        : null;
    final routed = _realtime
        ? widget.router.resolve<RealtimeModel>(
            cap,
            connectionId: picked?.$1,
            modelId: picked?.$2,
          )
        : widget.router.resolve<LanguageModel>(
            cap,
            connectionId: picked?.$1,
            modelId: picked?.$2,
          );
    final descriptor = routed?.model.descriptor;
    final tools = _toolSupport(descriptor);

    return Material(
      color: context.colors.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: chatHeaderHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.liveSettings,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.onClose != null)
                    IconButton(
                      tooltip: l.uiClose,
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (widget.appliesLater) _note(l.chatAppliesNextCall),
                _section(Icons.badge_rounded, l.chatPanelPersona),
                TextField(
                  controller: _persona,
                  minLines: 6,
                  maxLines: 16,
                  onChanged: _personaChanged,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                  decoration: InputDecoration(
                    hintText: widget.defaultPersona,
                    hintMaxLines: 6,
                    helperText: l.chatPersonaHint,
                    helperMaxLines: 3,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                _section(Icons.memory_rounded, l.chatPanelModel),
                DropdownButtonFormField<(String, String)?>(
                  key: ValueKey(('model', picked)),
                  initialValue: picked,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _realtime ? l.liveRealtimeModel : l.chatLlmModel,
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l.liveDefault)),
                    for (final (c, m) in models)
                      DropdownMenuItem(
                        value: (c.id, m.id),
                        child: Text(
                          '${_connectionName(c)} · ${m.id}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => widget.onChanged(
                    _realtime
                        ? s.withRealtime(v, s.realtimeVoice)
                        : s.withLlm(v),
                  ),
                ),
                if (_realtime)
                  _voiceField(l, s, picked, routed?.model as RealtimeModel?),
                const SizedBox(height: 10),
                _features(l, descriptor),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: s.useTools && tools != false,
                  title: Text(l.chatUseTools),
                  subtitle: Text(
                    tools == false
                        ? l.chatToolsUnsupported
                        : l.chatUseToolsHint,
                  ),
                  onChanged: tools == false
                      ? null
                      : (v) => widget.onChanged(s.withTools(v)),
                ),
                if (_realtime)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: s.allowInterruptions,
                    title: Text(l.liveAllowInterrupt),
                    subtitle: Text(l.liveAllowInterruptHint),
                    onChanged: (v) => widget.onChanged(s.withInterruptions(v)),
                  ),
                const SizedBox(height: 16),
                _section(Icons.graphic_eq_rounded, l.chatPanelVoice),
                if (!_realtime)
                  _line(Icons.record_voice_over_rounded, widget.voiceLabel),
                _line(
                  Icons.account_tree_rounded,
                  widget.chain.isActive
                      ? l.chatVoiceChain(_chainSummary(l, widget.chain))
                      : l.chatVoiceNoChain,
                ),
                const SizedBox(height: 6),
                Text(
                  _realtime ? l.chatVoiceRealtimeHint : l.chatVoiceChainHint,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: context.fg.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _voiceField(
    AppLocalizations l,
    CharacterLiveSettings s,
    (String, String)? picked,
    RealtimeModel? model,
  ) {
    final voices = model?.voices ?? const <String>[];
    final voice = voices.contains(s.realtimeVoice) ? s.realtimeVoice : null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<String?>(
        key: ValueKey(('voice', picked, voice)),
        initialValue: voice,
        isExpanded: true,
        decoration: InputDecoration(labelText: l.liveRealtimeVoice),
        items: [
          DropdownMenuItem(value: null, child: Text(l.liveDefault)),
          for (final v in voices) DropdownMenuItem(value: v, child: Text(v)),
        ],
        onChanged: (v) => widget.onChanged(s.withRealtime(picked, v)),
      ),
    );
  }

  /// True / false when the catalog knows, null when it does not.
  bool? _toolSupport(ModelDescriptor? d) {
    if (d == null) return null;
    if (_realtime) {
      return d.features.isEmpty
          ? null
          : d.features.contains(AiFeature.toolCalls);
    }
    return d.llm?.tools;
  }

  Widget _features(AppLocalizations l, ModelDescriptor? d) {
    if (d == null) return const SizedBox.shrink();
    final known = <(String, bool?)>[
      if (_realtime) ...[
        (l.chatFeatureTools, d.features.contains(AiFeature.toolCalls)),
        (
          l.chatFeatureTranscribe,
          d.features.contains(AiFeature.inputTranscription),
        ),
        (l.chatFeatureVad, d.features.contains(AiFeature.serverVad)),
      ] else ...[
        (l.chatFeatureTools, d.llm?.tools),
        (l.chatFeatureStructured, d.llm?.structuredOutput),
      ],
    ];
    final unknown = _realtime
        ? d.features.isEmpty
        : known.every((f) => f.$2 == null);
    if (unknown) {
      return Text(
        l.chatFeatureUnknown,
        style: TextStyle(
          fontSize: 12,
          color: context.fg.withValues(alpha: 0.45),
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (label, on) in known)
          if (on != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: on
                    ? AppTheme.accentColor.withValues(alpha: 0.16)
                    : context.fg.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    on ? Icons.check_rounded : Icons.close_rounded,
                    size: 12,
                    color: on
                        ? AppTheme.accentColor
                        : context.fg.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.fg.withValues(alpha: on ? 0.85 : 0.45),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  static String _chainSummary(AppLocalizations l, VoiceChain chain) => [
    for (final s in [...chain.textSteps, ...chain.audioSteps])
      switch (s.kind) {
        VoiceChainStepKind.translate => l.chainTranslate,
        VoiceChainStepKind.rewrite => l.chainRewrite,
        VoiceChainStepKind.convert => l.chainConvert,
        VoiceChainStepKind.trim => l.chainTrim,
        VoiceChainStepKind.verify => l.chainVerify,
      },
  ].join(' → ');

  Widget _section(IconData icon, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.accentColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 16, color: context.fg.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _note(String text) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppTheme.accentColor.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: AppTheme.accentColor,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}
