import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

/// The quick test's text box and its generate / stop button.
///
/// [roomy] gives the box several lines, for when the quick test has a
/// column of its own. ⌘/Ctrl+Enter generates; Enter adds a line.
class QuickTtsGenerateBar extends StatelessWidget {
  const QuickTtsGenerateBar({
    super.key,
    required this.controller,
    required this.generating,
    required this.onGenerate,
    required this.onStop,
    this.roomy = false,
  });

  final TextEditingController controller;
  final bool generating;

  /// Null while generating is not possible.
  final VoidCallback? onGenerate;
  final VoidCallback onStop;
  final bool roomy;

  static String get _sendKeys =>
      defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.iOS
      ? '⌘ Enter'
      : 'Ctrl+Enter';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSend = !generating && controller.text.trim().isNotEmpty;
    void send() {
      if (canSend) onGenerate?.call();
    }

    final field = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): send,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): send,
      },
      child: TextField(
        controller: controller,
        minLines: roomy ? 4 : 1,
        maxLines: roomy ? 12 : 2,
        style: TextStyle(fontSize: roomy ? 14 : 13, height: 1.5),
        decoration: InputDecoration(
          hintText: l10n.uiTypeSomethingToTest,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: roomy ? 14 : 13,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: roomy ? 12 : 10,
          ),
        ),
      ),
    );
    final button = generating
        ? IconButton(
            tooltip: l10n.uiStopSynthesis,
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: onStop,
          )
        : IconButton.filled(
            tooltip: '${l10n.uiGenerate} ($_sendKeys)',
            onPressed: canSend ? onGenerate : null,
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              disabledBackgroundColor: AppTheme.accentColor.withValues(
                alpha: 0.3,
              ),
              minimumSize: const Size(32, 32),
            ),
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
          );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: roomy
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 6, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.quickTtsSendHint(_sendKeys),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      button,
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: field),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: button,
                ),
              ],
            ),
    );
  }
}
