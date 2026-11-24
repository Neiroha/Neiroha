import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

/// The quick test's text box and its generate / stop button, like a chat
/// composer: one line to start, growing with the text up to a few lines,
/// then scrolling. Enter generates; Shift+Enter adds a line.
///
/// [roomy] lets it grow taller, for when the quick test has its own column.
class QuickTtsGenerateBar extends StatefulWidget {
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

  @override
  State<QuickTtsGenerateBar> createState() => _QuickTtsGenerateBarState();
}

class _QuickTtsGenerateBarState extends State<QuickTtsGenerateBar> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool get _canSend =>
      !widget.generating && widget.controller.text.trim().isNotEmpty;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        (event.logicalKey != LogicalKeyboardKey.enter &&
            event.logicalKey != LogicalKeyboardKey.numpadEnter)) {
      return KeyEventResult.ignored;
    }
    // Shift+Enter is a new line; Enter while an input method is composing
    // confirms the composition.
    if (HardwareKeyboard.instance.isShiftPressed ||
        widget.controller.value.composing.isValid) {
      return KeyEventResult.ignored;
    }
    if (_canSend) widget.onGenerate?.call();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fontSize = widget.roomy ? 14.0 : 13.0;
    final button = widget.generating
        ? IconButton(
            tooltip: l10n.uiStopSynthesis,
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: widget.onStop,
          )
        : IconButton.filled(
            tooltip: '${l10n.uiGenerate} · ${l10n.quickTtsSendHint}',
            onPressed: _canSend ? widget.onGenerate : null,
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
      child: Row(
        // The button stays on the last line as the box grows.
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Focus(
              onKeyEvent: _onKey,
              child: Scrollbar(
                controller: _scroll,
                child: TextField(
                  controller: widget.controller,
                  scrollController: _scroll,
                  minLines: 1,
                  maxLines: widget.roomy ? 10 : 4,
                  keyboardType: TextInputType.multiline,
                  style: TextStyle(fontSize: fontSize, height: 1.4),
                  decoration: InputDecoration(
                    hintText: l10n.uiTypeSomethingToTest,
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: fontSize,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(6), child: button),
        ],
      ),
    );
  }
}
