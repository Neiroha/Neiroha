import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/conversation/conversation_engine.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/voice_character/components.dart';

import 'chat_session_list.dart' show chatHeaderHeight;
import 'new_chat_dialog.dart';

/// The chat's title bar: who and how, what the character is doing, its
/// memory, the settings panel toggle and, for a call, the call button.
class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.session,
    required this.character,
    required this.engine,
    required this.state,
    required this.running,
    required this.starting,
    required this.converts,
    required this.memoryCount,
    required this.settingsOpen,
    required this.onMemory,
    required this.onSettings,
    required this.onCall,
    this.onBack,
  });

  final db.ChatSession session;
  final db.VoiceAsset character;
  final ChatEngine engine;
  final ConversationState state;
  final bool running;
  final bool starting;

  /// Replies pass through the chain's voice conversion.
  final bool converts;
  final int memoryCount;
  final bool settingsOpen;
  final VoidCallback onMemory;
  final VoidCallback onSettings;
  final VoidCallback onCall;
  final VoidCallback? onBack;

  String _stateLabel(AppLocalizations l) => switch (state) {
    ConversationState.idle => l.liveStateIdle,
    ConversationState.connecting => l.liveStateConnecting,
    ConversationState.listening => l.liveStateListening,
    ConversationState.thinking => l.liveStateThinking,
    ConversationState.speaking => l.liveStateSpeaking,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = context.fg.withValues(alpha: 0.45);
    return SizedBox(
      height: chatHeaderHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onBack,
              ),
            const SizedBox(width: 4),
            VoiceCharacterAvatar(
              radius: 16,
              name: character.name,
              avatarPath: character.avatarPath,
              selected: running,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  Text(
                    running
                        ? _stateLabel(l)
                        : '${character.name} · ${chatEngineLabel(l, engine)}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: running ? AppTheme.accentColor : muted,
                    ),
                  ),
                ],
              ),
            ),
            if (converts)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Tooltip(
                  message: l.chatChainConverts,
                  child: Icon(Icons.transform_rounded, size: 18, color: muted),
                ),
              ),
            IconButton(
              tooltip: l.chatMemory,
              onPressed: onMemory,
              icon: Badge.count(
                count: memoryCount,
                isLabelVisible: memoryCount > 0,
                child: const Icon(Icons.psychology_alt_rounded, size: 20),
              ),
            ),
            IconButton(
              tooltip: l.liveSettings,
              isSelected: settingsOpen,
              color: settingsOpen ? AppTheme.accentColor : null,
              onPressed: onSettings,
              icon: const Icon(Icons.tune_rounded, size: 20),
            ),
            if (engine == ChatEngine.realtime) ...[
              const SizedBox(width: 4),
              running
                  ? FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        foregroundColor: context.colors.danger,
                      ),
                      onPressed: onCall,
                      icon: const Icon(Icons.call_end_rounded, size: 18),
                      label: Text(l.chatCallEnd),
                    )
                  : FilledButton.icon(
                      onPressed: starting ? null : onCall,
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
