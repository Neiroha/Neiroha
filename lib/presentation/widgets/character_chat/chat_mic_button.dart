import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/services/conversation/conversation_factory.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';

/// Opens or closes spoken turns of the AI companion; off when no speech
/// recognition and voice activity models are available.
class ChatMicButton extends ConsumerWidget {
  const ChatMicButton({
    super.key,
    required this.on,
    required this.enabled,
    required this.onPressed,
  });
  final bool on;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final router = ref.watch(aiCapabilityRouterProvider).value;
    final canListen =
        router != null && ConversationFactory(router).companionCanListen;
    return IconButton(
      tooltip: !canListen
          ? l.chatMicUnavailable
          : on
          ? l.chatMicStop
          : l.chatMicStart,
      isSelected: on,
      color: on ? AppTheme.accentColor : null,
      onPressed: !canListen || !enabled ? null : onPressed,
      icon: Icon(on ? Icons.mic_rounded : Icons.mic_none_rounded, size: 20),
    );
  }
}
