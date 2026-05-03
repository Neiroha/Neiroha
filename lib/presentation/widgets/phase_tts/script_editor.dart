import 'package:flutter/material.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

/// Left-pane multiline script editor for the Phase TTS project.
///
/// The parent owns the [TextEditingController] (so the surrounding state can
/// read its text on save / auto-split) and wires [onChanged] to a debounced
/// persist call.
class ScriptEditor extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const ScriptEditor({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('SCRIPT',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.4))),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                hintText:
                    'Paste your novel text here...\n\nEach paragraph becomes a TTS segment.',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                filled: true,
                fillColor: AppTheme.surfaceDim,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
