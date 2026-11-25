part of 'components.dart';

class VoiceCharacterVoxCpm2ModeSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onChanged;

  const VoiceCharacterVoxCpm2ModeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const _modes = [
    (
      'design',
      Icons.text_fields_rounded,
      'Design',
      'Describe the voice\nin natural language',
    ),
    ('clone', Icons.mic_rounded, 'Clone', 'Clone voice from\nreference audio'),
    (
      'ultimate_clone',
      Icons.auto_awesome_rounded,
      'Ultra Clone',
      'Clone with prompt\ntranscript + audio',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _modes.map((rec) {
        final (mode, icon, label, hint) = rec;
        final isSelected = selected == mode;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: mode != 'ultimate_clone' ? 8 : 0),
            child: InkWell(
              onTap: () => onChanged(mode),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isSelected
                      ? AppTheme.accentColor.withValues(alpha: 0.15)
                      : context.colors.panel,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentColor.withValues(alpha: 0.5)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected
                          ? AppTheme.accentColor
                          : context.fg.withValues(alpha: 0.5),
                    ),
                    SizedBox(height: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? context.fg
                            : context.fg.withValues(alpha: 0.7),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      hint,
                      style: TextStyle(
                        fontSize: 10,
                        color: context.fg.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class VoiceCharacterCosyVoiceModeSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onChanged;

  const VoiceCharacterCosyVoiceModeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const _modes = [
    (
      'zero_shot',
      Icons.mic_rounded,
      'Zero Shot',
      'Clone voice from\nreference audio',
    ),
    (
      'cross_lingual',
      Icons.translate_rounded,
      'Cross Lingual',
      'Cross-language\nvoice synthesis',
    ),
    (
      'instruct',
      Icons.text_fields_rounded,
      'Instruct',
      'Control voice via\ntext instructions',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _modes.map((rec) {
        final (mode, icon, label, hint) = rec;
        final isSelected = selected == mode;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: mode != 'instruct' ? 8 : 0),
            child: InkWell(
              onTap: () => onChanged(mode),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isSelected
                      ? AppTheme.accentColor.withValues(alpha: 0.15)
                      : context.colors.panel,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentColor.withValues(alpha: 0.5)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected
                          ? AppTheme.accentColor
                          : context.fg.withValues(alpha: 0.5),
                    ),
                    SizedBox(height: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? context.fg
                            : context.fg.withValues(alpha: 0.7),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      hint,
                      style: TextStyle(
                        fontSize: 10,
                        color: context.fg.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class VoiceCharacterGptSovitsModeSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onChanged;

  const VoiceCharacterGptSovitsModeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const _modes = [
    (
      'trained',
      Icons.record_voice_over_rounded,
      'Trained',
      'Use a saved\nspeaker profile',
    ),
    ('clone', Icons.mic_rounded, 'Clone', 'Clone voice from\nreference audio'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _modes.map((rec) {
        final (mode, icon, label, hint) = rec;
        final isSelected = selected == mode;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: mode != 'clone' ? 8 : 0),
            child: InkWell(
              onTap: () => onChanged(mode),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isSelected
                      ? AppTheme.accentColor.withValues(alpha: 0.15)
                      : context.colors.panel,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentColor.withValues(alpha: 0.5)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected
                          ? AppTheme.accentColor
                          : context.fg.withValues(alpha: 0.5),
                    ),
                    SizedBox(height: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? context.fg
                            : context.fg.withValues(alpha: 0.7),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      hint,
                      style: TextStyle(
                        fontSize: 10,
                        color: context.fg.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
