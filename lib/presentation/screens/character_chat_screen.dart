import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/conversation/conversation_factory.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/widgets/character_chat/chat_session_list.dart';
import 'package:neiroha/presentation/widgets/character_chat/chat_view.dart';
import 'package:neiroha/presentation/widgets/character_chat/new_chat_dialog.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/chat_providers.dart';
import 'package:neiroha/presentation/theme/app_colors.dart';

/// Chats with characters: an AI companion that answers in the character's
/// own voice, or a live Realtime call. Scripted dialog dubbing stays in
/// Dialog TTS.
class CharacterChatScreen extends ConsumerStatefulWidget {
  const CharacterChatScreen({super.key});

  @override
  ConsumerState<CharacterChatScreen> createState() =>
      _CharacterChatScreenState();
}

class _CharacterChatScreenState extends ConsumerState<CharacterChatScreen> {
  static const _listWidth = 280.0;
  static const _wideBreakpoint = 720.0;

  String? _selectedId;

  db.AppDatabase get _db => ref.read(databaseProvider);

  Future<void> _create(List<db.VoiceAsset> characters) async {
    final router = await ref
        .read(aiCapabilityRouterProvider.future)
        .then<CapabilityRouter?>((r) => r, onError: (_) => null);
    if (!mounted) return;
    final picked = await showNewChatDialog(
      context: context,
      characters: characters,
      available: router == null
          ? const {}
          : ConversationFactory(router).availableEngines(),
    );
    if (picked == null) return;
    final session = await _db.createChatSession(
      voiceAssetId: picked.voiceAssetId,
      engine: picked.engine.name,
      title: picked.title,
    );
    if (mounted) setState(() => _selectedId = session.id);
  }

  Future<void> _rename(db.ChatSession s) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController(text: s.title);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.uiRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.uiCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l.uiSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title != null && title.trim().isNotEmpty) {
      await _db.renameChatSession(s.id, title.trim());
    }
  }

  Future<void> _delete(db.ChatSession s) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l.chatDeleteConfirm(s.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.uiCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.uiDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (_selectedId == s.id) setState(() => _selectedId = null);
    await _db.deleteChatSession(s.id);
    // The recorded replies go too.
    try {
      final dir = await PathService.instance.chatAudioDir(s.id);
      await dir.delete(recursive: true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Keeps the services loaded for the chats and the new-chat dialog.
    ref.watch(aiCapabilityRouterProvider);
    final sessions =
        ref.watch(chatSessionsStreamProvider).value ?? const <db.ChatSession>[];
    final assets =
        ref.watch(voiceAssetsStreamProvider).value ?? const <db.VoiceAsset>[];
    final characters = {for (final a in assets) a.id: a};
    final selected = sessions.where((s) => s.id == _selectedId).firstOrNull;
    final character = selected == null
        ? null
        : characters[selected.voiceAssetId];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        final list = ChatSessionList(
          sessions: sessions,
          characters: characters,
          selectedId: selected?.id,
          onSelect: (s) => setState(() => _selectedId = s.id),
          onCreate: () => unawaited(
            _create([
              for (final a in assets)
                if (a.enabled) a,
            ]),
          ),
          onRename: (s) => unawaited(_rename(s)),
          onDelete: (s) => unawaited(_delete(s)),
        );
        Widget chat({VoidCallback? onBack}) =>
            selected == null || character == null
            ? Center(
                child: Text(
                  l.chatPick,
                  style: TextStyle(color: context.fg.withValues(alpha: 0.45)),
                ),
              )
            : ChatView(
                key: ValueKey(selected.id),
                session: selected,
                character: character,
                onBack: onBack,
              );
        if (!wide) {
          if (selected == null) return list;
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              AppBackIntent.markChildHandled();
              setState(() => _selectedId = null);
            },
            child: chat(onBack: () => setState(() => _selectedId = null)),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: _listWidth, child: list),
            const VerticalDivider(width: 1),
            Expanded(child: chat()),
          ],
        );
      },
    );
  }
}
