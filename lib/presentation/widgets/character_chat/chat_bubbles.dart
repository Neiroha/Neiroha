import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:neiroha/data/ai/protocols/openai/openai_tool_chat.dart'
    show toolArguments;
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

Map<String, Object?> chatMeta(db.ChatMessage m) {
  if (m.metaJson == null) return const {};
  try {
    final o = jsonDecode(m.metaJson!);
    return o is Map<String, dynamic> ? o : const {};
  } on FormatException {
    return const {};
  }
}

/// One line of a chat: the user's on the right, the character's on the left
/// with its emotion and delivery, a tool use as a quiet note in between.
class ChatBubble extends StatelessWidget {
  const ChatBubble.message(
    db.ChatMessage this.message, {
    super.key,
    required this.characterName,
  }) : pendingText = null;

  /// The character's reply while it is still being written.
  const ChatBubble.pending(
    String this.pendingText, {
    super.key,
    required this.characterName,
  }) : message = null;

  final db.ChatMessage? message;
  final String? pendingText;
  final String characterName;

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m == null) return _bubble(context, false, pendingText!, const {});
    final meta = chatMeta(m);
    return switch (m.role) {
      'tool' => _toolNote(context, meta, m.content),
      'user' => _bubble(context, true, m.content, meta),
      _ => _bubble(context, false, m.content, meta),
    };
  }

  Widget _toolNote(
    BuildContext context,
    Map<String, Object?> meta,
    String result,
  ) {
    final l = AppLocalizations.of(context);
    final name = '${meta['name'] ?? ''}';
    final fact = '${toolArguments('${meta['arguments'] ?? ''}')['fact'] ?? ''}';
    final label = switch (name) {
      'get_current_time' => l.chatToolTime,
      'remember_fact' => l.chatToolRemember(fact),
      'forget_fact' => l.chatToolForget(fact),
      _ => l.chatToolOther(name),
    };
    final muted = Colors.white.withValues(alpha: 0.45);
    return Center(
      child: Tooltip(
        message: result,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.build_circle_outlined, size: 14, color: muted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bubble(
    BuildContext context,
    bool user,
    String text,
    Map<String, Object?> meta,
  ) {
    final l = AppLocalizations.of(context);
    final emotion = meta['emotion'] as String?;
    final style = '${meta['style'] ?? ''}'.trim();
    final muted = Colors.white.withValues(alpha: 0.45);
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: user
              ? AppTheme.accentColor.withValues(alpha: 0.24)
              : AppTheme.surfaceBright,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(user ? 14 : 4),
            bottomRight: Radius.circular(user ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!user)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    characterName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (emotion != null && emotion != 'neutral') ...[
                    const SizedBox(width: 6),
                    Text(
                      l.chatEmotion(emotion),
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ],
              ),
            SelectableText(text, style: const TextStyle(height: 1.4)),
            if (style.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  style,
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: muted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
