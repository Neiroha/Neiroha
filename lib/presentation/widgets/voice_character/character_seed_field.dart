import 'dart:math';

import 'package:flutter/material.dart';
import 'package:neiroha/domain/synthesis/tts_request.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

/// Parses the seed field: null for empty, or a whole number in range.
/// Returns false as the second value when the text is not a valid seed.
(int?, bool) parseCharacterSeed(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return (null, true);
  final seed = int.tryParse(trimmed);
  if (seed == null || seed < 0 || seed > TtsRequest.maxSeed) {
    return (null, false);
  }
  return (seed, true);
}

/// Optional fixed sampling seed of a character (CosyVoice, GPT-SoVITS,
/// Irodori). Empty lets the engine pick a new seed every request.
class CharacterSeedField extends StatelessWidget {
  const CharacterSeedField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: l10n.voiceSeed,
          helperText: l10n.voiceSeedHelper,
          helperMaxLines: 3,
          errorText: parseCharacterSeed(value.text).$2
              ? null
              : l10n.voiceSeedInvalid,
          errorMaxLines: 2,
          suffixIcon: IconButton(
            tooltip: l10n.voiceSeedRandomize,
            icon: const Icon(Icons.casino_outlined, size: 18),
            onPressed: () => controller.text = '${Random().nextInt(1 << 31)}',
          ),
        ),
      ),
    );
  }
}
