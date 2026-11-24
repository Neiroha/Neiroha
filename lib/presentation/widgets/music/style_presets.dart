import 'package:flutter/material.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

/// One tag: its label and the words it puts into the style prompt
/// (English, which music models follow best).
typedef StyleTag = ({String Function(AppLocalizations) label, String words});

/// Tag groups shown above the style prompt.
final List<(String Function(AppLocalizations), List<StyleTag>)> styleGroups = [
  (
    (l) => l.musicGenre,
    [
      (label: (l) => l.musicGenPop, words: 'pop'),
      (label: (l) => l.musicGenRock, words: 'rock'),
      (label: (l) => l.musicGenElectronic, words: 'electronic'),
      (label: (l) => l.musicGenFolk, words: 'folk'),
      (label: (l) => l.musicGenChinese, words: 'Chinese traditional'),
      (label: (l) => l.musicGenJazz, words: 'jazz'),
      (label: (l) => l.musicGenHipHop, words: 'hip-hop'),
      (label: (l) => l.musicGenLofi, words: 'lo-fi'),
      (label: (l) => l.musicGenOrchestral, words: 'orchestral'),
      (label: (l) => l.musicGenAnime, words: 'anime theme'),
    ],
  ),
  (
    (l) => l.musicMood,
    [
      (label: (l) => l.musicMoodHappy, words: 'upbeat'),
      (label: (l) => l.musicMoodSad, words: 'melancholic'),
      (label: (l) => l.musicMoodEpic, words: 'epic'),
      (label: (l) => l.musicMoodCalm, words: 'calm'),
      (label: (l) => l.musicMoodDreamy, words: 'dreamy'),
      (label: (l) => l.musicMoodDark, words: 'dark'),
    ],
  ),
  (
    (l) => l.musicInstruments,
    [
      (label: (l) => l.musicInsPiano, words: 'piano'),
      (label: (l) => l.musicInsGuitar, words: 'acoustic guitar'),
      (label: (l) => l.musicInsSynth, words: 'synthesizer'),
      (label: (l) => l.musicInsStrings, words: 'strings'),
      (label: (l) => l.musicInsGuzheng, words: 'guzheng'),
      (label: (l) => l.musicInsDrums, words: 'drums'),
    ],
  ),
  (
    (l) => l.musicVoice,
    [
      (label: (l) => l.musicVoxFemale, words: 'female vocals'),
      (label: (l) => l.musicVoxMale, words: 'male vocals'),
      (label: (l) => l.musicVoxChoir, words: 'choir'),
    ],
  ),
  (
    (l) => l.musicTempo,
    [
      (label: (l) => l.musicTempoSlow, words: 'slow tempo'),
      (label: (l) => l.musicTempoMid, words: 'mid-tempo'),
      (label: (l) => l.musicTempoFast, words: 'fast tempo'),
    ],
  ),
];

List<String> _parts(String prompt) => [
  for (final part in prompt.split(RegExp(r'[,，、]')))
    if (part.trim().isNotEmpty) part.trim(),
];

/// Whether [prompt] already lists [words] as one of its comma parts.
bool promptHas(String prompt, String words) =>
    _parts(prompt).any((p) => p.toLowerCase() == words.toLowerCase());

/// [prompt] with [words] added as a comma part, or removed if present.
String togglePromptWords(String prompt, String words) {
  final parts = _parts(prompt);
  final at = parts.indexWhere((p) => p.toLowerCase() == words.toLowerCase());
  if (at >= 0) {
    parts.removeAt(at);
  } else {
    parts.add(words);
  }
  return parts.join(', ');
}

/// Tag chips that edit the style prompt in [controller].
class StylePresetPicker extends StatelessWidget {
  const StylePresetPicker({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (title, tags) in styleGroups)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 56,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(
                        title(l),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in tags)
                          FilterChip(
                            visualDensity: VisualDensity.compact,
                            showCheckmark: false,
                            selectedColor: AppTheme.accentColor.withValues(
                              alpha: 0.25,
                            ),
                            label: Text(
                              tag.label(l),
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: promptHas(value.text, tag.words),
                            onSelected: !enabled
                                ? null
                                : (_) {
                                    controller.text = togglePromptWords(
                                      controller.text,
                                      tag.words,
                                    );
                                    onChanged();
                                  },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
