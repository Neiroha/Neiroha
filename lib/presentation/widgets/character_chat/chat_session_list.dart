import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/conversation/conversation_engine.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/voice_character/components.dart';

import 'new_chat_dialog.dart';

/// Height of the list and chat headers, so their dividers line up.
const double chatHeaderHeight = 52;

/// The chats, most recent first, with a button to start a new one.
class ChatSessionList extends StatelessWidget {
  const ChatSessionList({
    super.key,
    required this.sessions,
    required this.characters,
    required this.selectedId,
    required this.onSelect,
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
  });

  final List<db.ChatSession> sessions;
  final Map<String, db.VoiceAsset> characters;
  final String? selectedId;
  final ValueChanged<db.ChatSession> onSelect;
  final VoidCallback onCreate;
  final ValueChanged<db.ChatSession> onRename;
  final ValueChanged<db.ChatSession> onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: chatHeaderHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.navCharacterChat,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: l.chatNew,
                  onPressed: onCreate,
                  icon: const Icon(Icons.edit_square, size: 18),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: sessions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l.chatListEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: sessions.length,
                  itemBuilder: (_, i) => _tile(context, sessions[i]),
                ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, db.ChatSession s) {
    final l = AppLocalizations.of(context);
    final character = characters[s.voiceAssetId];
    final engine = ChatEngine.fromName(s.engine);
    final selected = s.id == selectedId;
    final muted = Colors.white.withValues(alpha: 0.45);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? AppTheme.accentColor.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onSelect(s),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 0, 8),
            child: Row(
              children: [
                VoiceCharacterAvatar(
                  radius: 18,
                  name: character?.name ?? s.title,
                  avatarPath: character?.avatarPath,
                  selected: selected,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(chatEngineIcon(engine), size: 12, color: muted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              [
                                ?character?.name,
                                chatEngineLabel(l, engine),
                              ].join(' · '),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz_rounded, size: 18, color: muted),
                  position: PopupMenuPosition.under,
                  onSelected: (v) => v == 'rename' ? onRename(s) : onDelete(s),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'rename', child: Text(l.uiRename)),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        l.uiDelete,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
