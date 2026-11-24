import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/conversation/conversation_engine.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

typedef NewChat = ({String voiceAssetId, ChatEngine engine, String title});

String chatEngineLabel(AppLocalizations l, ChatEngine e) => switch (e) {
  ChatEngine.companion => l.liveModeCompanion,
  ChatEngine.realtime => l.liveModeRealtime,
};

IconData chatEngineIcon(ChatEngine e) => switch (e) {
  ChatEngine.companion => Icons.chat_rounded,
  ChatEngine.realtime => Icons.call_rounded,
};

/// Picks the character and how to talk with it. [available] are the
/// engines the current services can run.
Future<NewChat?> showNewChatDialog({
  required BuildContext context,
  required List<db.VoiceAsset> characters,
  required Set<ChatEngine> available,
  String? initialCharacterId,
}) => showDialog<NewChat>(
  context: context,
  builder: (_) => _NewChatDialog(characters, available, initialCharacterId),
);

class _NewChatDialog extends StatefulWidget {
  const _NewChatDialog(this.characters, this.available, this.initial);
  final List<db.VoiceAsset> characters;
  final Set<ChatEngine> available;
  final String? initial;

  @override
  State<_NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<_NewChatDialog> {
  final _title = TextEditingController();
  late String? _character = widget.characters.any((c) => c.id == widget.initial)
      ? widget.initial
      : widget.characters.firstOrNull?.id;
  late ChatEngine _engine = widget.available.contains(ChatEngine.companion)
      ? ChatEngine.companion
      : widget.available.firstOrNull ?? ChatEngine.companion;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final character = widget.characters
        .where((c) => c.id == _character)
        .firstOrNull;
    final canCreate = character != null && widget.available.contains(_engine);
    return AlertDialog(
      title: Text(l.chatNew),
      content: SizedBox(
        width: 440,
        child: widget.characters.isEmpty
            ? Text(l.chatNoCharacters)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _character,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.chatCharacter),
                    items: [
                      for (final c in widget.characters)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _character = v),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l.chatEngine,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<ChatEngine>(
                    showSelectedIcon: false,
                    segments: [
                      for (final e in ChatEngine.values)
                        ButtonSegment(
                          value: e,
                          enabled: widget.available.contains(e),
                          icon: Icon(chatEngineIcon(e), size: 18),
                          label: Text(chatEngineLabel(l, e)),
                        ),
                    ],
                    selected: {_engine},
                    onSelectionChanged: (s) =>
                        setState(() => _engine = s.first),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.available.contains(_engine)
                        ? switch (_engine) {
                            ChatEngine.companion => l.liveModeCompanionHint,
                            ChatEngine.realtime => l.liveModeRealtimeHint,
                          }
                        : switch (_engine) {
                            ChatEngine.companion => l.liveNeedsCompanion,
                            ChatEngine.realtime => l.liveNeedsRealtime,
                          },
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _title,
                    decoration: InputDecoration(
                      labelText: l.chatTitleOptional,
                      hintText: character?.name,
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.uiCancel),
        ),
        FilledButton(
          onPressed: canCreate
              ? () => Navigator.pop(context, (
                  voiceAssetId: character.id,
                  engine: _engine,
                  title: _title.text.trim().isEmpty
                      ? character.name
                      : _title.text.trim(),
                ))
              : null,
          child: Text(l.uiCreate),
        ),
      ],
    );
  }
}
