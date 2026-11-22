import 'package:flutter/material.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/conversation/character_live_settings.dart';
import 'package:neiroha/data/services/conversation/conversation_engine.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

/// OpenAI Realtime voices; the model may offer more over time.
const realtimeVoices = [
  'marin',
  'cedar',
  'alloy',
  'ash',
  'ballad',
  'coral',
  'echo',
  'sage',
  'shimmer',
  'verse',
];

Future<CharacterLiveSettings?> showLiveSettingsDialog({
  required BuildContext context,
  required db.VoiceAsset character,
  required CharacterLiveSettings settings,
  required CapabilityRouter router,
  required DialogMode mode,
}) => showDialog<CharacterLiveSettings>(
  context: context,
  builder: (_) => _LiveSettingsDialog(character, settings, router, mode),
);

class _LiveSettingsDialog extends StatefulWidget {
  const _LiveSettingsDialog(
    this.character,
    this.settings,
    this.router,
    this.mode,
  );
  final db.VoiceAsset character;
  final CharacterLiveSettings settings;
  final CapabilityRouter router;
  final DialogMode mode;

  @override
  State<_LiveSettingsDialog> createState() => _LiveSettingsDialogState();
}

class _LiveSettingsDialogState extends State<_LiveSettingsDialog> {
  late final _persona = TextEditingController(text: widget.settings.persona);
  late final _vcVoice = TextEditingController(
    text: widget.settings.vcVoice ?? '',
  );
  late String? _voice = widget.settings.realtimeVoice;
  late String? _vcConnection = widget.settings.vcConnectionId;
  late bool _interrupt = widget.settings.allowInterruptions;

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
    final realtime = widget.mode == DialogMode.realtime;
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
              if (realtime) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _voice,
                  decoration: InputDecoration(labelText: l.liveRealtimeVoice),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l.liveDefault)),
                    for (final v in realtimeVoices)
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
                TextField(
                  controller: _vcVoice,
                  decoration: InputDecoration(
                    labelText: l.liveVcVoice,
                    helperText: l.liveVcVoiceHint,
                  ),
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
              realtimeVoice: _voice,
              vcConnectionId: vcValue,
              vcVoice: vcValue == null ? null : _vcVoice.text.trim(),
              allowInterruptions: _interrupt,
            ),
          ),
          child: Text(l.uiSave),
        ),
      ],
    );
  }
}
