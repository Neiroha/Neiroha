import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/theme/app_theme.dart';

/// Bottom-anchored input bar for the Dialog TTS editor.
///
/// Owns its own [TextEditingController]. Plain Enter calls [onSend] with
/// the trimmed text and clears the field; Ctrl+Enter inserts a literal
/// newline. The field auto-grows up to [maxHeight] and then becomes
/// scrollable.
class InputBar extends StatefulWidget {
  final List<db.VoiceAsset> bankAssets;
  final String? voiceId;
  final ValueChanged<String?> onVoiceChanged;
  final ValueChanged<String> onSend;
  final double maxHeight;

  const InputBar({
    super.key,
    required this.bankAssets,
    required this.voiceId,
    required this.onVoiceChanged,
    required this.onSend,
    required this.maxHeight,
  });

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.voiceId == null) return;
    _controller.clear();
    widget.onSend(text);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    if (ctrl) {
      // Ctrl+Enter → insert newline at the cursor.
      final value = _controller.value;
      final selection = value.selection;
      if (!selection.isValid) return KeyEventResult.ignored;
      final newText =
          value.text.replaceRange(selection.start, selection.end, '\n');
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + 1),
      );
      return KeyEventResult.handled;
    }
    if (widget.voiceId == null) return KeyEventResult.handled;
    _submit();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 140,
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                hintText: 'Voice',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              isExpanded: true,
              initialValue:
                  widget.bankAssets.any((a) => a.id == widget.voiceId)
                      ? widget.voiceId
                      : null,
              items: widget.bankAssets
                  .map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(a.name,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: widget.onVoiceChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.maxHeight),
              child: Focus(
                onKeyEvent: _handleKey,
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText:
                        'Type dialog line… (Enter to send, Ctrl+Enter for newline)',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3)),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.surfaceDim,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: widget.voiceId == null ? null : _submit,
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              disabledBackgroundColor:
                  AppTheme.accentColor.withValues(alpha: 0.3),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
