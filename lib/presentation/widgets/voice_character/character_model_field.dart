import 'package:flutter/material.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/data/services/capabilities/model_retirement.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/presentation/widgets/ai/model_retirement_widgets.dart';
import 'package:neiroha/data/services/synthesis/browser_speech_support.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/actions/browser_speech_message.dart';

class CharacterModelField extends StatelessWidget {
  const CharacterModelField({
    super.key,
    required this.controller,
    required this.provider,
    required this.isWeb,
    required this.onChanged,
  });

  final TextEditingController controller;
  final TtsProvider? provider;
  final bool isWeb;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final adapter = provider?.adapterType;
    final block = isWeb && adapter != null
        ? browserSpeechModelBlock(
            adapter,
            browserSpeechModel(provider!, controller.text) ??
                provider!.defaultModelName,
            baseUrl: provider!.baseUrl,
          )
        : null;
    final choices = isWeb && provider != null
        ? browserSpeechModels(provider!, const [])
        : const <String>[];
    // Vendor shutdown: say when, and offer the replacement where it runs.
    final typed = controller.text.trim();
    final retiring = provider == null
        ? null
        : retiringDescriptor(
            connectionForProvider(provider!),
            typed.isEmpty ? provider!.defaultModelName : typed,
          );
    final move = retiring == null
        ? null
        : replacementFor(
            provider!,
            retiring,
            platform: isWeb ? AiPlatform.web : AiPlatform.desktop,
          );
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: l10n.uiModelName,
        hintText: choices.isNotEmpty
            ? browserSpeechModel(provider!, null)
            : switch (adapter) {
                'openaiTts' => 'e.g. gpt-realtime-2.1-mini',
                'geminiTts' => 'e.g. gemini-3.8-flash-tts',
                'elevenLabs' => 'e.g. eleven_v4',
                'minimaxTts' => 'e.g. speech-2.8-hd',
                _ => 'e.g. tts-1',
              },
        errorText: block != null
            ? browserSpeechMessage(l10n, block)
            : retiring != null
            ? retirementAdvice(l10n, retiring, move)
            : null,
        errorMaxLines: 6,
        suffixIcon: choices.isNotEmpty
            ? PopupMenuButton<String>(
                tooltip: l10n.uiSelectModel,
                itemBuilder: (_) => choices
                    .map(
                      (model) =>
                          PopupMenuItem(value: model, child: Text(model)),
                    )
                    .toList(),
                onSelected: (model) {
                  controller.text = model;
                  onChanged();
                },
              )
            : move != null
            ? IconButton(
                tooltip: l10n.retireSwitchTo(move.model),
                icon: const Icon(Icons.swap_horiz_rounded),
                onPressed: () {
                  controller.text = move.model;
                  onChanged();
                },
              )
            : null,
      ),
    );
  }
}
