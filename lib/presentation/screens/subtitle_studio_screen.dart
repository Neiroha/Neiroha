import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart' show FileType;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/services/subtitles/subtitle_cue.dart';
import 'package:neiroha/data/services/subtitles/subtitle_pipeline.dart';
import 'package:neiroha/data/services/subtitles/subtitle_writer.dart';
import 'package:neiroha/data/services/transcription/media_pcm_decoder.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/actions/file_dialogs.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/presentation/widgets/subtitles/subtitle_cue_list.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:path/path.dart' as p;

/// Target languages offered in the picker; any other name can be typed.
const _targets = [
  ('Chinese (Simplified)', 'zh'),
  ('English', 'en'),
  ('Japanese', 'ja'),
  ('Korean', 'ko'),
  ('French', 'fr'),
  ('German', 'de'),
  ('Spanish', 'es'),
  ('Russian', 'ru'),
];

/// Transcribe & translate: media → VAD → STT → LLM translation → SRT /
/// VTT / LRC, using whichever enabled providers offer each capability.
class SubtitleStudioScreen extends ConsumerStatefulWidget {
  const SubtitleStudioScreen({super.key});

  @override
  ConsumerState<SubtitleStudioScreen> createState() =>
      _SubtitleStudioScreenState();
}

class _SubtitleStudioScreenState extends ConsumerState<SubtitleStudioScreen> {
  final _sourceLang = TextEditingController();
  final _context = TextEditingController();
  String? _mediaPath;
  (String, String)? _target = _targets.first;
  SubtitleFormat _format = SubtitleFormat.srt;
  SubtitleTextMode _textMode = SubtitleTextMode.translation;
  List<SubtitleCue> _cues = const [];
  SubtitleProgress? _progress;
  TtsCancelToken? _cancel;
  String? _error;

  bool get _running => _cancel != null;

  @override
  void dispose() {
    _cancel?.cancel();
    _sourceLang.dispose();
    _context.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'mp4', 'mkv', 'mov', 'webm', 'avi', 'mp3', 'wav', 'm4a', 'flac', //
        'ogg', 'aac', 'opus',
      ],
    );
    final path = picked?.files.single.path;
    if (path != null) {
      setState(() {
        _mediaPath = path;
        _cues = const [];
        _error = null;
      });
    }
  }

  Future<void> _run(CapabilityRouter router) async {
    final path = _mediaPath;
    if (path == null) return;
    final cancel = TtsCancelToken();
    setState(() {
      _cancel = cancel;
      _error = null;
      _cues = const [];
    });
    try {
      final pipeline = SubtitlePipeline.fromRouter(
        router,
        MediaPcmDecoder(ref.read(ffmpegServiceProvider)),
        translate: _target != null,
      );
      final source = _sourceLang.text.trim();
      final cues = await pipeline.run(
        SubtitleJob(
          path,
          sourceLanguages: source.isEmpty ? const [] : [source],
          targetLanguage: _target?.$1,
          context: _context.text.trim(),
        ),
        cancellation: cancel,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (mounted) setState(() => _cues = cues);
    } on TtsCancelledException {
      // Cancelled by the user.
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _cancel = null);
    }
  }

  Future<void> _export() async {
    final l = AppLocalizations.of(context);
    final media = _mediaPath;
    if (media == null || _cues.isEmpty) return;
    final mode = _target == null ? SubtitleTextMode.original : _textMode;
    final suffix = mode == SubtitleTextMode.original ? '' : '.${_target!.$2}';
    final target = await pickSavePath(
      fileName:
          '${p.basenameWithoutExtension(media)}$suffix'
          '${_format.extension}',
      dialogTitle: l.subtitleExport,
    );
    if (target == null) return;
    await File(
      target,
    ).writeAsString(writeSubtitles(_cues, _format, mode: mode));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.subtitleSaved(target))));
    }
  }

  String _stage(AppLocalizations l, SubtitleProgress progress) {
    final count = progress.total > 0
        ? ' ${progress.done}/${progress.total}'
        : '';
    return switch (progress.stage) {
          SubtitleStage.decoding => l.subtitleStageDecoding,
          SubtitleStage.detecting => l.subtitleStageDetecting,
          SubtitleStage.transcribing => l.subtitleStageTranscribing,
          SubtitleStage.translating => l.subtitleStageTranslating,
          SubtitleStage.done => l.subtitleStageDone,
        } +
        count;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final router = ref.watch(aiCapabilityRouterProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text(
            l.navSubtitles,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ResizableSplitPane(
            initialLeftFraction: 0.34,
            compactRightIcon: Icons.subtitles_rounded,
            compactRightLabel: l.subtitlePreview,
            left: _controls(l, router),
            rightBuilder: (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_running && _progress != null)
                  LinearProgressIndicator(
                    value: _progress!.total == 0
                        ? null
                        : _progress!.done / _progress!.total,
                  ),
                Expanded(
                  child: SubtitleCueList(cues: _cues, empty: l.subtitleEmpty),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _controls(AppLocalizations l, CapabilityRouter? router) {
    String? using(AiCapability cap) {
      final routed = switch (cap) {
        AiCapability.stt => router?.resolve<Transcriber>(cap),
        AiCapability.llm => router?.resolve<LanguageModel>(cap),
        _ => router?.resolve<VoiceActivityDetector>(cap),
      };
      if (routed == null) return null;
      final name = routed.connection.config.name;
      return '${name.isEmpty ? routed.connection.plugin.displayName : name}'
          ' · ${routed.model.descriptor.id}';
    }

    final stt = using(AiCapability.stt);
    final llm = using(AiCapability.llm);
    final ready =
        router != null &&
        _mediaPath != null &&
        stt != null &&
        (_target == null || llm != null);
    Widget status(String label, String? value, {bool optional = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Icon(
                value != null
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                size: 16,
                color: value != null
                    ? Colors.greenAccent
                    : optional
                    ? Colors.white38
                    : Colors.orangeAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$label: ${value ?? l.subtitleMissingCapability}',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          onPressed: _running ? null : _pick,
          icon: const Icon(Icons.video_file_rounded),
          label: Text(
            _mediaPath == null ? l.subtitlePickMedia : p.basename(_mediaPath!),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _sourceLang,
          decoration: InputDecoration(
            labelText: l.subtitleSourceLanguage,
            hintText: l.subtitleSourceLanguageHint,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<(String, String)?>(
          initialValue: _target,
          decoration: InputDecoration(labelText: l.subtitleTargetLanguage),
          items: [
            DropdownMenuItem(value: null, child: Text(l.subtitleNoTranslation)),
            for (final t in _targets)
              DropdownMenuItem(value: t, child: Text(t.$1)),
          ],
          onChanged: _running ? null : (v) => setState(() => _target = v),
        ),
        if (_target != null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _context,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l.subtitleContext,
              hintText: l.subtitleContextHint,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(l.subtitleFormat, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        SegmentedButton<SubtitleFormat>(
          showSelectedIcon: false,
          segments: [
            for (final f in SubtitleFormat.values)
              ButtonSegment(value: f, label: Text(f.name.toUpperCase())),
          ],
          selected: {_format},
          onSelectionChanged: (s) => setState(() => _format = s.first),
        ),
        if (_target != null) ...[
          const SizedBox(height: 12),
          SegmentedButton<SubtitleTextMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: SubtitleTextMode.original,
                label: Text(l.subtitleModeOriginal),
              ),
              ButtonSegment(
                value: SubtitleTextMode.translation,
                label: Text(l.subtitleModeTranslation),
              ),
              ButtonSegment(
                value: SubtitleTextMode.bilingual,
                label: Text(l.subtitleModeBilingual),
              ),
            ],
            selected: {_textMode},
            onSelectionChanged: (s) => setState(() => _textMode = s.first),
          ),
        ],
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceBright,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              status('VAD', using(AiCapability.vad)),
              status('ASR', stt),
              status('LLM', llm, optional: _target == null),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_running)
          OutlinedButton.icon(
            onPressed: () => _cancel?.cancel(),
            icon: const Icon(Icons.stop_rounded),
            label: Text(_progress == null ? l.uiCancel : _stage(l, _progress!)),
          )
        else
          FilledButton.icon(
            onPressed: ready ? () => unawaited(_run(router)) : null,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(l.subtitleRun),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _cues.isEmpty || _running ? null : _export,
          icon: const Icon(Icons.save_alt_rounded),
          label: Text(l.subtitleExport),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          SelectableText(
            _error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
