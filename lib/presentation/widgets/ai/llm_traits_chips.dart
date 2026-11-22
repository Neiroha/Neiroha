import 'package:flutter/material.dart';
import 'package:neiroha/domain/ai/llm_traits.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

String modalityLabel(AppLocalizations l, Modality m) => switch (m) {
  Modality.text => l.modalityText,
  Modality.image => l.modalityImage,
  Modality.audio => l.modalityAudio,
  Modality.video => l.modalityVideo,
  Modality.pdf => l.modalityPdf,
};

String _tokens(int n) => n >= 1000000
    ? '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M'
    : '${n ~/ 1000}K';

/// Compact badges: thinking levels, tool calling, inputs, schema, context.
/// Unknown facts show as "?" instead of being guessed.
class LlmTraitsChips extends StatelessWidget {
  const LlmTraitsChips(this.traits, {super.key});
  final LlmTraits traits;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget chip(IconData icon, String text, {bool? good, String? tooltip}) {
      final color = switch (good) {
        true => Colors.greenAccent,
        false => scheme.error,
        null => scheme.onSurface.withAlpha(150),
      };
      final body = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: color.withAlpha(110)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      );
      return tooltip == null ? body : Tooltip(message: tooltip, child: body);
    }

    final r = traits.reasoning;
    final levels = r?.thinkingLevels ?? const [];
    final thinking = switch (r) {
      null => chip(Icons.psychology_outlined, l.llmThinkUnknown),
      ReasoningSpec(supported: false) => chip(
        Icons.psychology_outlined,
        l.llmThinkNone,
      ),
      _ when levels.isEmpty => chip(
        Icons.psychology_rounded,
        l.llmThinkLevelsUnknown,
        good: true,
      ),
      _ => chip(
        Icons.psychology_rounded,
        l.llmThinkLevels(levels.length, levels.first.name, levels.last.name) +
            (r.canDisable ? l.llmThinkCanDisable : ''),
        good: true,
        tooltip: [
          r.levels.map((e) => e.name).join(' · '),
          if (r.defaultLevel != null) l.llmThinkDefault(r.defaultLevel!.name),
          if (r.modes.isNotEmpty) l.llmThinkModes(r.modes.join(' / ')),
        ].join('\n'),
      ),
    };
    final inputs = traits.inputs;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        thinking,
        chip(
          Icons.build_rounded,
          switch (traits.tools) {
            true => l.llmTools,
            false => l.llmToolsNo,
            null => l.llmToolsUnknown,
          },
          good: traits.tools,
          tooltip: traits.parallelTools == true ? l.llmToolsParallel : null,
        ),
        chip(
          Icons.input_rounded,
          inputs == null
              ? l.llmInputsUnknown
              : [
                  for (final m in Modality.values)
                    if (inputs.contains(m)) modalityLabel(l, m),
                ].join(' · '),
        ),
        if (traits.structuredOutput == true)
          chip(Icons.data_object_rounded, l.llmSchema, good: true),
        if (traits.contextWindow != null)
          chip(
            Icons.notes_rounded,
            l.llmContext(_tokens(traits.contextWindow!)),
          ),
      ],
    );
  }
}
