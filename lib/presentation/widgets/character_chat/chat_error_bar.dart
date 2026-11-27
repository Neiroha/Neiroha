import 'package:flutter/material.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

/// The chat's last error, selectable, with a button to dismiss it.
class ChatErrorBar extends StatelessWidget {
  const ChatErrorBar({super.key, required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.danger.withValues(alpha: 0.12),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              message,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: onClose,
          ),
        ],
      ),
    ),
  );
}
