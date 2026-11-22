import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/services/transcription/audio_file_transcriber.dart';
import 'package:neiroha/data/services/transcription/media_pcm_decoder.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';

/// Reference-text field with a button that transcribes [audioPath] using
/// the routed speech-to-text model and fills the text (and the language,
/// when empty and the service reports one).
class ReferenceTextField extends ConsumerStatefulWidget {
  const ReferenceTextField({
    super.key,
    required this.controller,
    required this.languageController,
    required this.audioPath,
  });

  final TextEditingController controller;
  final TextEditingController languageController;
  final String audioPath;

  @override
  ConsumerState<ReferenceTextField> createState() => _ReferenceTextFieldState();
}

class _ReferenceTextFieldState extends ConsumerState<ReferenceTextField> {
  bool _busy = false;

  Future<void> _transcribe(AudioFileTranscriber transcriber) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final language = widget.languageController.text.trim();
    setState(() => _busy = true);
    try {
      final transcript = await transcriber.transcribe(
        widget.audioPath,
        options: TranscribeOptions(
          languages: language.isEmpty ? const [] : [language],
        ),
      );
      if (!mounted) return;
      widget.controller.text = transcript.text.trim();
      if (language.isEmpty && transcript.languages.isNotEmpty) {
        widget.languageController.text = transcript.languages.first;
      }
      messenger.showSnackBar(SnackBar(content: Text(l.transcribeFilled)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.transcribeFailed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final router = ref.watch(aiCapabilityRouterProvider).value;
    final transcriber = router == null
        ? null
        : AudioFileTranscriber(
            router,
            decoder: PlatformCapabilities.current().supportsFfmpegCli
                ? MediaPcmDecoder(ref.read(ffmpegServiceProvider))
                : null,
          );
    final available = transcriber?.available ?? false;
    return TextField(
      controller: widget.controller,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: l.uiReferenceText,
        helperText: l.uiTranscriptOfTheAudioUsedByVoiceCloningModelsThatNeedIt,
        suffixIcon: _busy
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.subtitles_rounded),
                tooltip: available
                    ? l.transcribeFromAudio
                    : l.transcribeNeedsStt,
                onPressed: available ? () => _transcribe(transcriber!) : null,
              ),
      ),
    );
  }
}
