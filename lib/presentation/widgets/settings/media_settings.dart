import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/data/storage/export_prefs.dart';
import 'package:neiroha/data/storage/ffmpeg_service.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'settings_shared.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

// ───────────────────────────── FFmpeg card ─────────────────────────────

class FfmpegSettingsCard extends ConsumerStatefulWidget {
  const FfmpegSettingsCard({super.key});

  @override
  ConsumerState<FfmpegSettingsCard> createState() => _FfmpegSettingsCardState();
}

class _FfmpegSettingsCardState extends ConsumerState<FfmpegSettingsCard> {
  final _pathCtrl = TextEditingController();
  String? _loadedOverride;
  bool _hydrated = false;

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  Future<void> _hydrate(FFmpegService svc) async {
    final stored = await svc.getOverride();
    if (!mounted) return;
    setState(() {
      _loadedOverride = stored;
      _pathCtrl.text = stored ?? '';
      _hydrated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(platformCapabilitiesProvider);
    final svc = ref.watch(ffmpegServiceProvider);
    final availability = ref.watch(ffmpegAvailabilityProvider);

    if (!capabilities.supportsFfmpegCli) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SettingsRow(
            icon: Icons.block_rounded,
            title: 'FFmpeg',
            subtitle: AppLocalizations.of(
              context,
            ).uiFFmpegUnavailableOnPlatform(capabilities.platformLabel),
            trailing: const SizedBox.shrink(),
          ),
        ),
      );
    }

    if (!_hydrated) {
      // Lazy one-shot load of the persisted override.
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate(svc));
    }

    final isAvailable = availability.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );
    final loading = availability.isLoading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SettingsRow(
              icon: isAvailable
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              title: 'FFmpeg',
              subtitle: loading
                  ? AppLocalizations.of(context).uiProbing
                  : (isAvailable
                        ? AppLocalizations.of(
                            context,
                          ).uiDetectedUsedForWaveformExtractionAndImportedMediaAnalysis
                        : AppLocalizations.of(
                            context,
                          ).uiNotFoundInstallFfmpegOrSetAPathBelowTheAppWorks),
              trailing: loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: () {
                        ref.read(ffmpegServiceProvider).invalidate();
                        ref.invalidate(ffmpegAvailabilityProvider);
                      },
                      child: Text(AppLocalizations.of(context).uiReCheck),
                    ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsRow(
                    icon: Icons.terminal_rounded,
                    title: AppLocalizations.of(context).uiExecutablePath,
                    subtitle:
                        _loadedOverride == null || _loadedOverride!.isEmpty
                        ? AppLocalizations.of(context).uiAutoDetectFromPATH
                        : AppLocalizations.of(context).uiUsingOverride,
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _save,
                          child: Text(AppLocalizations.of(context).uiSave),
                        ),
                        if (_loadedOverride != null &&
                            _loadedOverride!.isNotEmpty)
                          TextButton(
                            onPressed: _clear,
                            child: Text(AppLocalizations.of(context).uiReset),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: _pathCtrl,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: AppLocalizations.of(
                        context,
                      ).uiLeaveBlankToAutoDetectEGCFfmpegBinFfmpegExe,
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 12,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.folder_open_rounded, size: 18),
                        tooltip: AppLocalizations.of(context).uiBrowse,
                        onPressed: _browse,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _browse() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['exe', ''],
      allowMultiple: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    setState(() => _pathCtrl.text = path);
  }

  Future<void> _save() async {
    final path = _pathCtrl.text.trim();
    await ref
        .read(ffmpegServiceProvider)
        .setOverride(path.isEmpty ? null : path);
    ref.invalidate(ffmpegAvailabilityProvider);
    setState(() => _loadedOverride = path.isEmpty ? null : path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path.isEmpty
              ? 'FFmpeg path cleared — will auto-detect from PATH.'
              : 'FFmpeg path saved.',
        ),
      ),
    );
  }

  Future<void> _clear() async {
    await ref.read(ffmpegServiceProvider).setOverride(null);
    ref.invalidate(ffmpegAvailabilityProvider);
    setState(() {
      _loadedOverride = null;
      _pathCtrl.clear();
    });
  }
}

// ────────────────────────── Export Prefs card ──────────────────────────

/// Defaults used by the Video Dub editor's Export Audio / Export Video
/// buttons. Stored in `AppSettings`; loaded once on first build then
/// persisted on every dropdown change.
class ExportPrefsSettingsCard extends ConsumerStatefulWidget {
  const ExportPrefsSettingsCard({super.key});

  @override
  ConsumerState<ExportPrefsSettingsCard> createState() =>
      _ExportPrefsSettingsCardState();
}

class _ExportPrefsSettingsCardState
    extends ConsumerState<ExportPrefsSettingsCard> {
  ExportPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    // Defer the async load so initState stays sync — the card will
    // briefly render in a "loading" state until _prefs is set.
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final prefs = await ref.read(exportPrefsServiceProvider).load();
    if (!mounted) return;
    setState(() => _prefs = prefs);
  }

  Future<void> _setAudioFormat(String v) async {
    await ref.read(exportPrefsServiceProvider).setAudioFormat(v);
    if (!mounted) return;
    setState(() => _prefs = _prefs!.copyWith(audioFormat: v));
  }

  Future<void> _setVideoCodec(String v) async {
    await ref.read(exportPrefsServiceProvider).setVideoCodec(v);
    if (!mounted) return;
    setState(() => _prefs = _prefs!.copyWith(videoCodec: v));
  }

  Future<void> _setVideoAudioCodec(String v) async {
    await ref.read(exportPrefsServiceProvider).setVideoAudioCodec(v);
    if (!mounted) return;
    setState(() => _prefs = _prefs!.copyWith(videoAudioCodec: v));
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(platformCapabilitiesProvider);
    if (!capabilities.supportsFfmpegCli) return const SizedBox.shrink();

    final prefs = _prefs;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: prefs == null
            ? SizedBox(
                height: 40,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : Column(
                children: [
                  SettingsRow(
                    icon: Icons.tune_rounded,
                    title: AppLocalizations.of(context).uiExportDefaults,
                    subtitle: AppLocalizations.of(
                      context,
                    ).uiUsedByTheVideoDubEditorSExportAudioExportVideoButtons,
                    trailing: const SizedBox.shrink(),
                  ),
                  const Divider(),
                  _PrefRow(
                    icon: Icons.audiotrack_rounded,
                    title: AppLocalizations.of(context).uiAudioFormat,
                    subtitle: AppLocalizations.of(
                      context,
                    ).uiContainerCodecForExportAudioWAVFLACKeepFullQualityMP3Is,
                    value: prefs.audioFormat,
                    options: ExportPrefs.audioFormats,
                    onChanged: _setAudioFormat,
                  ),
                  const Divider(),
                  _PrefRow(
                    icon: Icons.movie_filter_rounded,
                    title: AppLocalizations.of(context).uiVideoCodec,
                    subtitle: AppLocalizations.of(
                      context,
                    ).uiCopyReusesTheSourceStreamFastLosslessH264H265Av1ForceA,
                    value: prefs.videoCodec,
                    options: ExportPrefs.videoCodecs,
                    onChanged: _setVideoCodec,
                  ),
                  const Divider(),
                  _PrefRow(
                    icon: Icons.graphic_eq_rounded,
                    title: AppLocalizations.of(context).uiVideoAudioCodec,
                    subtitle: AppLocalizations.of(
                      context,
                    ).uiAudioCodecForTheMuxedMP4AACIsTheBroadestCompatibleDefault,
                    value: prefs.videoAudioCodec,
                    options: ExportPrefs.videoAudioCodecs,
                    onChanged: _setVideoAudioCodec,
                  ),
                ],
              ),
      ),
    );
  }
}

class _PrefRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _PrefRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        items: [
          for (final o in options)
            DropdownMenuItem(value: o, child: Text(o.toUpperCase())),
        ],
        onChanged: (v) {
          if (v != null && v != value) onChanged(v);
        },
      ),
    );
  }
}
