import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/synthesis/browser_speech_support.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/actions/browser_speech_message.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/voice_chip_list.dart';

class TtsProviderModelRow extends StatefulWidget {
  final db.ModelBinding model;
  final VoidCallback onDelete;
  final BrowserSpeechBlock? webBlock;

  /// Voices this model ships with (`builtInVoicesFor`); tap to expand.
  final List<String> voices;

  const TtsProviderModelRow({
    super.key,
    required this.model,
    required this.onDelete,
    this.webBlock,
    this.voices = const [],
  });

  @override
  State<TtsProviderModelRow> createState() => _TtsProviderModelRowState();
}

class _TtsProviderModelRowState extends State<TtsProviderModelRow> {
  bool _expanded = false;

  /// Detect TTS model type label from model name.
  String get _typeLabel {
    final k = widget.model.modelKey.toLowerCase();
    if (k.contains('voiceclone') || k.contains('clone')) return 'Clone';
    if (k.contains('voicedesign') || k.contains('design')) return 'Design';
    return 'Preset';
  }

  @override
  Widget build(BuildContext context) {
    final voices = widget.voices;
    final hasBuiltIns = voices.isNotEmpty;
    final block = widget.webBlock;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceBright,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row — tap to expand if built-ins exist.
            InkWell(
              onTap: hasBuiltIns
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.mic_rounded,
                      size: 16,
                      color: Colors.purpleAccent.withValues(alpha: 0.7),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.model.modelKey,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (block != null)
                      Tooltip(
                        message: browserSpeechMessage(
                          AppLocalizations.of(context),
                          block,
                        ),
                        child: const Icon(Icons.do_not_disturb_alt, size: 16),
                      ),
                    if (hasBuiltIns) VoiceCountBadge(count: voices.length),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _typeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.purpleAccent.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    if (hasBuiltIns)
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    SizedBox(width: 4),
                    InkWell(
                      onTap: widget.onDelete,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Built-in voices, shown when expanded.
            if (hasBuiltIns && _expanded)
              Padding(
                padding: const EdgeInsets.only(
                  left: 28,
                  right: 12,
                  bottom: 8,
                  top: 2,
                ),
                child: VoiceChipList(
                  voices: [for (final v in voices) (label: v, id: null)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
