import 'package:flutter/material.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/conversation/character_live_settings.dart';
import 'package:neiroha/data/services/conversation/conversation_engine.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/presentation/widgets/ai/vc_voice_field.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

/// The character's chat settings: persona, the model that answers (an LLM
/// for the companion, a Realtime model and voice for a call), tools and VC.
Future<CharacterLiveSettings?> showChatSettingsDialog({
  required BuildContext context,
  required db.VoiceAsset character,
  required CharacterLiveSettings settings,
  required CapabilityRouter router,
  required ChatEngine engine,
}) => showDialog<CharacterLiveSettings>(
  context: context,
  builder: (_) => _ChatSettingsDialog(character, settings, router, engine),
);

class _ChatSettingsDialog extends StatefulWidget {
  const _ChatSettingsDialog(
    this.character,
    this.settings,
    this.router,
    this.engine,
  );
  final db.VoiceAsset character;
  final CharacterLiveSettings settings;
  final CapabilityRouter router;
  final ChatEngine engine;

  @override
  State<_ChatSettingsDialog> createState() => _ChatSettingsDialogState();
}

class _ChatSettingsDialogState extends State<_ChatSettingsDialog> {
  late final _persona = TextEditingController(text: widget.settings.persona);
  late final _vcVoice = TextEditingController(
    text: widget.settings.vcVoice ?? '',
  );
  late String? _voice = widget.settings.realtimeVoice;
  late (String, String)? _realtime =
      widget.settings.realtimeConnectionId == null
      ? null
      : (
          widget.settings.realtimeConnectionId!,
          widget.settings.realtimeModelId ?? '',
        );
  late String? _vcConnection = widget.settings.vcConnectionId;
  late bool _interrupt = widget.settings.allowInterruptions;
  late bool _tools = widget.settings.useTools;
  late (String, String)? _llm = widget.settings.llmConnectionId == null
      ? null
      : (widget.settings.llmConnectionId!, widget.settings.llmModelId ?? '');

  String _connectionName(ProviderConnection c) =>
      c.config.name.isEmpty ? c.plugin.displayName : c.config.name;

  List<(ProviderConnection, ModelDescriptor)> _models(AiCapability cap) => [
    for (final c in widget.router.serving(cap))
      for (final m in widget.router.modelsOf(c, cap)) (c, m),
  ];

  Widget _modelField(
    String label,
    List<(ProviderConnection, ModelDescriptor)> models,
    (String, String)? value,
    ValueChanged<(String, String)?> onChanged,
  ) => DropdownButtonFormField<(String, String)?>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      DropdownMenuItem(
        value: null,
        child: Text(AppLocalizations.of(context).liveDefault),
      ),
      for (final (c, m) in models)
        DropdownMenuItem(
          value: (c.id, m.id),
          child: Text(
            '${_connectionName(c)} · ${m.id}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: onChanged,
  );

  @override
  void dispose() {
    _persona.dispose();
    _vcVoice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final vcConnections = widget.router.serving(AiCapability.vc);
    final realtime = widget.engine == ChatEngine.realtime;
    final models = _models(AiCapability.realtime);
    final llms = _models(AiCapability.llm);
    final llm = llms.any((e) => (e.$1.id, e.$2.id) == _llm) ? _llm : null;
    final picked = models.any((e) => (e.$1.id, e.$2.id) == _realtime)
        ? _realtime
        : null;
    final voices =
        widget.router
            .resolve<RealtimeModel>(
              AiCapability.realtime,
              connectionId: picked?.$1,
              modelId: picked?.$2,
            )
            ?.model
            .voices ??
        const <String>[];
    final voice = voices.contains(_voice) ? _voice : null;
    final vcValue = vcConnections.any((c) => c.config.id == _vcConnection)
        ? _vcConnection
        : null;
    return AlertDialog(
      title: Text(l.liveSettingsTitle(widget.character.name)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _persona,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: l.livePersona,
                  helperText: l.livePersonaHint,
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: 12),
              if (!realtime)
                _modelField(
                  l.chatLlmModel,
                  llms,
                  llm,
                  (v) => setState(() => _llm = v),
                ),
              if (realtime) ...[
                _modelField(
                  l.liveRealtimeModel,
                  models,
                  picked,
                  (v) => setState(() => _realtime = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: ValueKey(picked),
                  initialValue: voice,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.liveRealtimeVoice),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l.liveDefault)),
                    for (final v in voices)
                      DropdownMenuItem(value: v, child: Text(v)),
                  ],
                  onChanged: (v) => setState(() => _voice = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _interrupt,
                  title: Text(l.liveAllowInterrupt),
                  subtitle: Text(l.liveAllowInterruptHint),
                  onChanged: (v) => setState(() => _interrupt = v),
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _tools,
                title: Text(l.chatUseTools),
                subtitle: Text(l.chatUseToolsHint),
                onChanged: (v) => setState(() => _tools = v),
              ),
              const SizedBox(height: 16),
              Text(
                l.liveVcTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(l.liveVcHint, style: Theme.of(context).textTheme.bodySmall),
              DropdownButtonFormField<String?>(
                initialValue: vcValue,
                decoration: InputDecoration(labelText: l.liveVcProvider),
                items: [
                  DropdownMenuItem(value: null, child: Text(l.liveVcOff)),
                  for (final c in vcConnections)
                    DropdownMenuItem(
                      value: c.config.id,
                      child: Text(
                        c.config.name.isEmpty
                            ? c.plugin.displayName
                            : c.config.name,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _vcConnection = v;
                  final preset = widget.character.presetVoiceName;
                  if (v != null &&
                      _vcVoice.text.isEmpty &&
                      preset != null &&
                      v == widget.character.providerId) {
                    _vcVoice.text = preset;
                  }
                }),
              ),
              if (vcValue != null)
                VcVoiceField(
                  controller: _vcVoice,
                  label: l.liveVcVoice,
                  helperText: l.liveVcVoiceHint,
                  connection: vcConnections
                      .where((c) => c.config.id == vcValue)
                      .firstOrNull,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.uiCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            CharacterLiveSettings(
              persona: _persona.text.trim(),
              realtimeVoice: realtime ? voice : widget.settings.realtimeVoice,
              realtimeConnectionId: realtime
                  ? picked?.$1
                  : widget.settings.realtimeConnectionId,
              realtimeModelId: realtime
                  ? picked?.$2
                  : widget.settings.realtimeModelId,
              vcConnectionId: vcValue,
              vcVoice: vcValue == null ? null : _vcVoice.text.trim(),
              allowInterruptions: _interrupt,
              llmConnectionId: realtime
                  ? widget.settings.llmConnectionId
                  : llm?.$1,
              llmModelId: realtime ? widget.settings.llmModelId : llm?.$2,
              useTools: _tools,
            ),
          ),
          child: Text(l.uiSave),
        ),
      ],
    );
  }
}
