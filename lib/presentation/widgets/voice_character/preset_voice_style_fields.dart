import 'package:flutter/material.dart';
import 'package:neiroha/data/ai/providers/minimax/tts/minimax_tts_adapter.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

class PresetVoiceStyleFields extends StatelessWidget {
  const PresetVoiceStyleFields({
    super.key,
    required this.controller,
    required this.adapterType,
  });

  final TextEditingController controller;
  final String adapterType;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TextField(
        controller: controller,
        maxLines: adapterType == 'minimaxTts' ? 1 : 3,
        decoration: InputDecoration(
          labelText: l10n.uiStyleInstructionOptional,
          hintText: switch (adapterType) {
            'minimaxTts' => MiniMaxTtsAdapter.kEmotions.join(' / '),
            'elevenLabs' => 'e.g. whispers, excited (v3 / v4 audio tag)',
            'openaiTts' => 'e.g. calm, warm narrator; slightly slow',
            _ => l10n.uiEGSpeakSoftlyAndSlowlyPrependedToTheText,
          },
        ),
      ),
    );
  }
}
