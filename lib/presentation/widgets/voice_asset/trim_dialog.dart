import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

part 'trim_apply.dart';

/// User-selected range from [TrimDialog]. The caller runs ffmpeg + the DB
/// update; the dialog stays presentation-only so its lifecycle doesn't have
/// to outlive its tree.
class TrimResult {
  final double startSec;
  final double endSec;

  /// `true` → overwrite the source file in place.
  /// `false` → write to a sibling path and create a new track row.
  final bool replaceOriginal;

  const TrimResult({
    required this.startSec,
    required this.endSec,
    required this.replaceOriginal,
  });

  double get durationSec => endSec - startSec;
}

class TrimDialog extends ConsumerStatefulWidget {
  final String audioPath;
  final double totalSec;
  final String trackName;

  const TrimDialog({
    super.key,
    required this.audioPath,
    required this.totalSec,
    required this.trackName,
  });

  @override
  ConsumerState<TrimDialog> createState() => _TrimDialogState();
}

class _TrimDialogState extends ConsumerState<TrimDialog> {
  final _player = AudioPlayer();

  List<double>? _peaks;
  bool _waveformLoading = true;

  late double _startSec;
  late double _endSec;
  double _playheadSec = 0;

  bool _playing = false;
  bool _replaceOriginal = true;

  Timer? _previewWatchdog;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();
    _startSec = 0;
    _endSec = widget.totalSec;
    unawaited(_loadWaveform());
    _initPlayer();
  }

  Future<void> _loadWaveform() async {
    final capabilities = ref.read(platformCapabilitiesProvider);
    if (!capabilities.supportsFfmpegCli) {
      if (mounted) setState(() => _waveformLoading = false);
      return;
    }
    final svc = ref.read(ffmpegServiceProvider);
    final peaks = await svc.extractWaveformPeaks(
      widget.audioPath,
      bucketCount: 600,
    );
    if (!mounted) return;
    setState(() {
      _peaks = peaks;
      _waveformLoading = false;
    });
  }

  void _initPlayer() {
    _player.setSource(DeviceFileSource(widget.audioPath));
    _posSub = _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      final secs = pos.inMilliseconds / 1000.0;
      setState(() => _playheadSec = secs);
      // Hard stop at the trim end, otherwise the preview keeps going.
      if (_playing && secs >= _endSec) {
        unawaited(_stopPreview());
      }
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _previewWatchdog?.cancel();
    unawaited(_posSub?.cancel());
    unawaited(_completeSub?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _togglePreview() async {
    if (_playing) {
      await _stopPreview();
      return;
    }
    await _player.seek(Duration(milliseconds: (_startSec * 1000).round()));
    await _player.resume();
    setState(() {
      _playing = true;
      _playheadSec = _startSec;
    });
  }

  Future<void> _stopPreview() async {
    await _player.pause();
    if (mounted) setState(() => _playing = false);
  }

  void _confirm() {
    Navigator.of(context).pop(
      TrimResult(
        startSec: _startSec,
        endSec: _endSec,
        replaceOriginal: _replaceOriginal,
      ),
    );
  }

  // ───────────────────── UI ─────────────────────

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.content_cut_rounded, color: AppTheme.accentColor),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Trim "${widget.trackName}"',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWaveformPanel(),
            SizedBox(height: 12),
            _buildTimeReadout(),
            SizedBox(height: 16),
            _buildRangeSliders(),
            SizedBox(height: 12),
            _buildPreviewRow(),
            SizedBox(height: 16),
            const Divider(height: 1),
            SizedBox(height: 12),
            _buildSaveModeRow(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(AppLocalizations.of(context).uiCancel),
        ),
        FilledButton.icon(
          onPressed: _endSec > _startSec ? _confirm : null,
          icon: const Icon(Icons.save_rounded, size: 18),
          label: Text(AppLocalizations.of(context).uiSave),
        ),
      ],
    );
  }

  Widget _buildWaveformPanel() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_waveformLoading) {
            return Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return CustomPaint(
            painter: _TrimWaveformPainter(
              peaks: _peaks ?? const [],
              totalSec: widget.totalSec,
              startSec: _startSec,
              endSec: _endSec,
              playheadSec: _playing ? _playheadSec : null,
              accent: AppTheme.accentColor,
            ),
            size: Size(constraints.maxWidth, 120),
          );
        },
      ),
    );
  }

  Widget _buildTimeReadout() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Start  ${_fmt(_startSec)}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.7),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          'Length  ${_fmt(_endSec - _startSec)}',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.accentColor,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          'End  ${_fmt(_endSec)}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.7),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildRangeSliders() {
    final total = widget.totalSec.clamp(0.001, double.infinity);
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  AppLocalizations.of(context).uiStart,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Expanded(
                child: Slider(
                  min: 0,
                  max: total,
                  value: _startSec.clamp(0, total),
                  onChanged: (v) {
                    if (_playing) unawaited(_stopPreview());
                    setState(() {
                      _startSec = v;
                      if (_endSec <= _startSec) _endSec = _startSec + 0.05;
                    });
                  },
                ),
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  AppLocalizations.of(context).uiEnd,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Expanded(
                child: Slider(
                  min: 0,
                  max: total,
                  value: _endSec.clamp(0, total),
                  onChanged: (v) {
                    if (_playing) unawaited(_stopPreview());
                    setState(() {
                      _endSec = v;
                      if (_startSec >= _endSec) _startSec = _endSec - 0.05;
                      if (_startSec < 0) _startSec = 0;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow() {
    return Row(
      children: [
        FilledButton.icon(
          onPressed: _endSec > _startSec ? _togglePreview : null,
          icon: Icon(
            _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
            size: 18,
          ),
          label: Text(_playing ? 'Stop' : 'Preview range'),
        ),
        SizedBox(width: 12),
        Text(
          _playing ? _fmt(_playheadSec) : '',
          style: const TextStyle(
            fontSize: 12,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveModeRow() {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: Text(AppLocalizations.of(context).uiReplaceOriginal),
                icon: Icon(Icons.swap_horiz_rounded, size: 16),
              ),
              ButtonSegment(
                value: false,
                label: Text(AppLocalizations.of(context).uiSaveAsNew),
                icon: Icon(Icons.note_add_outlined, size: 16),
              ),
            ],
            selected: {_replaceOriginal},
            onSelectionChanged: (s) =>
                setState(() => _replaceOriginal = s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
            ),
          ),
        ),
      ],
    );
  }

  static String _fmt(double sec) {
    final ms = (sec * 1000).round();
    final m = (ms ~/ 60000).toString().padLeft(2, '0');
    final s = ((ms ~/ 1000) % 60).toString().padLeft(2, '0');
    final r = (ms % 1000).toString().padLeft(3, '0');
    return '$m:$s.$r';
  }
}
