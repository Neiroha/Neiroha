import 'package:flutter/material.dart';
import 'package:neiroha/data/services/conversation/character_tools.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

/// What the character remembers in this chat; each fact can be removed.
Future<void> showChatMemoryDialog(BuildContext context, ChatMemory memory) =>
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return StatefulBuilder(
          builder: (ctx, refresh) => AlertDialog(
            title: Text(l.chatMemory),
            content: SizedBox(
              width: 420,
              child: memory.facts.isEmpty
                  ? Text(l.chatMemoryEmpty)
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final f in memory.facts)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(f),
                            trailing: IconButton(
                              tooltip: l.uiDelete,
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => refresh(() => memory.remove(f)),
                            ),
                          ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.uiConfirm),
              ),
            ],
          ),
        );
      },
    );
