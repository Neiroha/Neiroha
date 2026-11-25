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
    this.hintText,
    this.sendIcon = Icons.auto_awesome_rounded,
    this.sendTooltip,
    this.leading,
  });

  final TextEditingController controller;
  final bool generating;

  /// Null while generating is not possible.
  final VoidCallback? onGenerate;
  final VoidCallback onStop;
  final bool roomy;

  /// Overrides for other composers (the character chat).
  final String? hintText;
  final IconData sendIcon;
  final String? sendTooltip;

  /// A button before the text, e.g. the microphone.
  final Widget? leading;

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
    // Every line is _line tall (text and hint alike), so one line of text
    // and the 32 px buttons, each in a _row-high slot, share a centre.
    final strut = StrutStyle(
      fontSize: fontSize,
      height: _line / fontSize,
      forceStrutHeight: true,
    );
    final button = widget.generating
        ? IconButton(
            tooltip: l10n.uiStopSynthesis,
            style: _compact,
            icon: const Icon(Icons.stop_circle_rounded),
            onPressed: widget.onStop,
          )
        : IconButton.filled(
            tooltip:
                widget.sendTooltip ??
                '${l10n.uiGenerate} · ${l10n.quickTtsSendHint}',
            onPressed: _canSend ? widget.onGenerate : null,
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              disabledBackgroundColor: AppTheme.accentColor.withValues(
                alpha: 0.3,
              ),
              minimumSize: const Size.square(32),
              fixedSize: const Size.square(32),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(widget.sendIcon, size: 16),
          );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: context.colors.raised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.fg.withValues(alpha: 0.08)),
      ),
      child: Row(
        // The button stays on the last line as the box grows.
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (widget.leading case final leading?)
            _slot(
              IconButtonTheme(
                data: IconButtonThemeData(style: _compact),
                child: leading,
              ),
            ),
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
                  style: TextStyle(fontSize: fontSize),
                  strutStyle: strut,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: widget.hintText ?? l10n.uiTypeSomethingToTest,
                    hintMaxLines: 1,
                    hintStyle: TextStyle(
                      color: context.fg.withValues(alpha: 0.3),
                      fontSize: fontSize,
                      height: _line / fontSize,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.fromLTRB(
                      widget.leading == null ? 14 : 4,
                      (_row - _line) / 2,
                      8,
                      (_row - _line) / 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _slot(button),
        ],
      ),
    );
  }

  static const _line = 20.0;
  static const _row = 44.0;

  static final _compact = IconButton.styleFrom(
    minimumSize: const Size.square(32),
    fixedSize: const Size.square(32),
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  /// A button centred on the last line of text.
  static Widget _slot(Widget child) => SizedBox(
    width: _row,
    height: _row,
    child: Center(child: child),
  );
}
