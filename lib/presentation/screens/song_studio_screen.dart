import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' show FileType;
import 'package:flutter/material.dart';
import 'package:neiroha/presentation/widgets/layout/page_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/services/music/song_library.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/actions/file_dialogs.dart';
import 'package:neiroha/presentation/widgets/export_progress.dart';
import 'package:neiroha/presentation/widgets/music/song_list.dart';
import 'package:neiroha/presentation/widgets/music/song_now_playing.dart';
import 'package:neiroha/presentation/widgets/music/style_presets.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/presentation/theme/app_colors.dart';
import 'package:path/path.dart' as p;

/// Song Studio: style prompt + lyrics (+ reference images) → a finished
/// song from whichever enabled provider offers the music capability
/// (Gemini Lyria today), saved under `{voiceAssetRoot}/songs/`.
class SongStudioScreen extends ConsumerStatefulWidget {
  const SongStudioScreen({super.key});

  @override
  ConsumerState<SongStudioScreen> createState() => _SongStudioScreenState();
}

class _SongStudioScreenState extends ConsumerState<SongStudioScreen> {
  final _title = TextEditingController();
  final _prompt = TextEditingController();
  final _lyrics = TextEditingController();
  bool _instrumental = false, _lossless = true;
  final _images = <(Uint8List, String, String)>[]; // bytes, mime, name
  (String, String)? _model; // connection id, model id
  List<SongRecord> _songs = const [];
  SongRecord? _selected;
  TtsCancelToken? _cancel;
  Timer? _ticker;
  int _elapsed = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _ticker?.cancel();
    _title.dispose();
    _prompt.dispose();
    _lyrics.dispose();
    super.dispose();
  }

  Future<void> _reload({SongRecord? select}) async {
    final songs = await (await SongLibrary.open()).list();
    if (!mounted) return;
    setState(() {
      _songs = songs;
      _selected = select == null
          ? null
          : songs.where((s) => s.audioPath == select.audioPath).firstOrNull;
    });
  }

  List<(ProviderConnection, ModelDescriptor)> _choices(CapabilityRouter? r) => [
    for (final c in r?.serving(AiCapability.music) ?? const [])
      for (final m in r!.modelsOf(c, AiCapability.music)) (c, m),
  ];

  Future<void> _addImages() async {
    final picked = await pickFiles(type: FileType.image, allowMultiple: true);
    for (final f in picked?.files ?? const []) {
      if (f.path == null || _images.length >= 10) continue;
      final ext = p.extension(f.path!).toLowerCase().replaceFirst('.', '');
      final mime = 'image/${ext == 'jpg' ? 'jpeg' : ext}';
      final bytes = await File(f.path!).readAsBytes();
      setState(() => _images.add((bytes, mime, f.name)));
    }
  }

  Future<void> _compose(CapabilityRouter router, (String, String) pick) async {
    final l = AppLocalizations.of(context);
    final routed = router.resolve<MusicGenerator>(
      AiCapability.music,
      connectionId: pick.$1,
      modelId: pick.$2,
    );
    if (routed == null) return;
    final cancel = TtsCancelToken();
    setState(() {
      _cancel = cancel;
      _error = null;
      _elapsed = 0;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
    final request = MusicRequest(
      prompt: _prompt.text.trim(),
      lyrics: _lyrics.text.trim(),
      instrumental: _instrumental,
      lossless: _lossless,
      images: [for (final (b, m, _) in _images) (b, m)],
    );
    try {
      final song = await routed.model.compose(request, cancellation: cancel);
      final title = _title.text.trim().isNotEmpty
          ? _title.text.trim()
          : l.musicTitleHint;
      final name = routed.connection.config.name;
      final record = await (await SongLibrary.open()).save(
        song,
        title: title,
        request: request,
        model: routed.model.descriptor.id,
        provider: name.isEmpty ? routed.connection.plugin.displayName : name,
      );
      await _reload(select: record);
      await _play(record);
    } on TtsCancelledException {
      // Cancelled by the user.
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      _ticker?.cancel();
      if (mounted) setState(() => _cancel = null);
    }
  }

  Future<void> _play(SongRecord song) => ref
      .read(playbackNotifierProvider.notifier)
      .load(
        song.audioPath,
        song.title,
        subtitle: song.model,
        sourceTag: songStudioPlaybackSource,
      );

  Future<void> _act(SongRecord song, SongAction action) async {
    final l = AppLocalizations.of(context);
    switch (action) {
      case SongAction.reuse:
        setState(() {
          _title.text = song.title;
          _prompt.text = song.prompt;
          _instrumental = song.instrumental;
          if (!song.instrumental) {
            _lyrics.text = [
              for (final (i, line) in song.lyrics.indexed) ...[
                if (line.section != null &&
                    (i == 0 || song.lyrics[i - 1].section != line.section))
                  '[${line.section}]',
                line.text,
              ],
            ].join('\n');
          }
        });
      case SongAction.showInFolder:
        await revealInFileManager(song.audioPath);
      case SongAction.saveAs:
        final target = await pickSavePath(
          fileName: '${song.title}${p.extension(song.audioPath)}',
          dialogTitle: l.musicSaveAs,
        );
        if (target == null) return;
        await File(song.audioPath).copy(target);
        if (song.lrcPath != null) {
          await File(song.lrcPath!).copy(p.setExtension(target, '.lrc'));
        }
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.musicSaved(target))));
        }
      case SongAction.delete:
        await (await SongLibrary.open()).delete(song);
        await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final router = ref.watch(aiCapabilityRouterProvider).value;
    final playing = ref.watch(
      playbackNotifierProvider.select(
        (s) => s.sourceTag == songStudioPlaybackSource && s.isPlaying
            ? s.audioPath
            : null,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(icon: Icons.queue_music_rounded, title: l.navMusic),
        const Divider(height: 1),
        Expanded(
          child: ResizableSplitPane(
            initialLeftFraction: 0.36,
            compactRightIcon: Icons.queue_music_rounded,
            compactRightLabel: l.navMusic,
            left: _controls(l, router),
            rightBuilder: (_) => SongList(
              songs: _songs,
              selected: _selected,
              playingPath: playing,
              onSelect: (s) => setState(() => _selected = s),
              onPlay: _play,
              onAction: _act,
            ),
          ),
        ),
      ],
    );
  }

  Widget _controls(AppLocalizations l, CapabilityRouter? router) {
    final choices = _choices(router);
    final keys = [for (final (c, m) in choices) (c.id, m.id)];
    final pick = keys.contains(_model) ? _model : keys.firstOrNull;
    final descriptor = choices
        .where((e) => (e.$1.id, e.$2.id) == pick)
        .firstOrNull
        ?.$2;
    final features = descriptor?.features ?? const <String>{};
    final running = _cancel != null;
    final ready =
        router != null &&
        pick != null &&
        !running &&
        (_prompt.text.trim().isNotEmpty || _lyrics.text.trim().isNotEmpty);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        _Section(icon: Icons.auto_awesome_rounded, title: l.musicModel),
        if (choices.isEmpty)
          Text(l.musicNoModel, style: TextStyle(color: context.colors.warning))
        else
          DropdownButtonFormField<(String, String)>(
            initialValue: pick,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final (c, m) in choices)
                DropdownMenuItem(
                  value: (c.id, m.id),
                  child: Text(
                    '${c.config.name.isEmpty ? c.plugin.displayName : c.config.name}'
                    ' · ${m.displayName.isEmpty ? m.id : m.displayName}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: running ? null : (v) => setState(() => _model = v),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          decoration: InputDecoration(
            labelText: l.musicTitle,
            hintText: l.musicTitleHint,
          ),
        ),
        _Section(icon: Icons.palette_rounded, title: l.musicStyle),
        Text(
          l.musicStyleHint,
          style: TextStyle(
            fontSize: 11,
            color: context.fg.withValues(alpha: 0.38),
          ),
        ),
        const SizedBox(height: 8),
        StylePresetPicker(
          controller: _prompt,
          enabled: !running,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _prompt,
          minLines: 2,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l.musicPrompt,
            hintText: l.musicPromptHint,
            alignLabelWithHint: true,
          ),
        ),
        if (!_instrumental) ...[
          _Section(
            icon: Icons.lyrics_rounded,
            title: l.musicLyrics,
            trailing: _lyrics.text.isEmpty
                ? null
                : TextButton(
                    onPressed: running
                        ? null
                        : () => setState(() => _lyrics.clear()),
                    child: Text(l.uiClear),
                  ),
          ),
          TextField(
            controller: _lyrics,
            minLines: 6,
            maxLines: 16,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              helperText: l.musicLyricsHint,
              helperMaxLines: 3,
              alignLabelWithHint: true,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final tag in const [
                      '[Intro]',
                      '[Verse]',
                      '[Chorus]',
                      '[Bridge]',
                      '[Outro]',
                    ])
                      ActionChip(
                        label: Text(tag, style: const TextStyle(fontSize: 11)),
                        onPressed: () => setState(() {
                          final t = _lyrics.text;
                          _lyrics.text =
                              '${t.isEmpty || t.endsWith('\n') ? t : '$t\n'}$tag\n';
                        }),
                      ),
                  ],
                ),
              ),
              Text(
                l.musicLyricsStats(
                  '\n'.allMatches(_lyrics.text.trim()).length +
                      (_lyrics.text.trim().isEmpty ? 0 : 1),
                  _lyrics.text.replaceAll(RegExp(r'\s'), '').length,
                ),
                style: TextStyle(
                  fontSize: 11,
                  color: context.fg.withValues(alpha: 0.38),
                ),
              ),
            ],
          ),
        ],
        _Section(icon: Icons.tune_rounded, title: l.musicOptions),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _instrumental,
          title: Text(l.musicInstrumental),
          onChanged: running ? null : (v) => setState(() => _instrumental = v),
        ),
        if (features.contains(AiFeature.losslessOutput))
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _lossless,
            title: Text(l.musicLossless),
            onChanged: running ? null : (v) => setState(() => _lossless = v),
          ),
        if (features.contains(AiFeature.imagePrompt)) ...[
          Text(l.musicImages, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (i, img) in _images.indexed)
                InputChip(
                  label: Text(img.$3, overflow: TextOverflow.ellipsis),
                  onDeleted: running
                      ? null
                      : () => setState(() => _images.removeAt(i)),
                ),
              ActionChip(
                avatar: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                label: Text(l.musicAddImage),
                onPressed: running || _images.length >= 10 ? null : _addImages,
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        if (running)
          OutlinedButton.icon(
            onPressed: () => _cancel?.cancel(),
            icon: const Icon(Icons.stop_rounded),
            label: Text(l.musicGenerating(_elapsed)),
          )
        else
          FilledButton.icon(
            onPressed: ready ? () => unawaited(_compose(router, pick)) : null,
            icon: const Icon(Icons.music_note_rounded),
            label: Text(l.musicGenerate),
          ),
        if (running) const LinearProgressIndicator(),
        if (_error != null) ...[
          const SizedBox(height: 12),
          SelectableText(
            _error!,
            style: TextStyle(color: context.colors.danger, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          l.musicWatermark,
          style: TextStyle(
            fontSize: 11,
            color: context.fg.withValues(alpha: 0.38),
          ),
        ),
      ],
    );
  }
}

/// A form section title.
class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, this.trailing});
  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 16, color: context.fg.withValues(alpha: 0.54)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}
