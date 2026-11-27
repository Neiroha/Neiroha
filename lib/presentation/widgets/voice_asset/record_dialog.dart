import 'package:neiroha/data/services/recording/recording_backend.dart';
import 'package:neiroha/data/services/recording/recording_take.dart';
import 'package:uuid/uuid.dart';
import 'recording_indicator.dart';
import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:record_platform_interface/record_platform_interface.dart';

import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

/// Recording UI shared by Windows and macOS; capture/file lifetime is owned
/// by RecordingTake and platform registration is hidden by RecordingBackend.
class RecordDialog extends StatefulWidget {
  const RecordDialog({super.key});

  @override
  State<RecordDialog> createState() => _RecordDialogState();
}

enum _Phase { idle, recording, preview }

class _RecordDialogState extends State<RecordDialog>
    with SingleTickerProviderStateMixin {
  final _recorder = RecordingBackend.platform();
  late final RecordingTake _take;
  final _previewer = AudioPlayer();

  late final AnimationController _pulseCtrl;

  _Phase _phase = _Phase.idle;
  List<InputDevice> _devices = const [];
  InputDevice? _selectedDevice;
  bool _initializing = true;
  bool _hasPermission = false;
  bool _busy = false;

  String? _initError;
  String? _recordedPath;
  Duration _elapsed = Duration.zero;
  Duration? _previewDuration;
  Duration _previewPos = Duration.zero;
  bool _previewPlaying = false;
  double _levelNorm = 0;

  DateTime _lastLevelPaint = DateTime.fromMillisecondsSinceEpoch(0);

  Timer? _elapsedTimer;
  StreamSubscription<Duration>? _previewPosSub;
  StreamSubscription<Duration>? _previewDurSub;
  StreamSubscription<void>? _previewCompleteSub;

  @override
  void initState() {
    super.initState();
    _take = RecordingTake(
      _recorder,
      onLevel: (level) {
        final now = DateTime.now();
        if (mounted &&
            now.difference(_lastLevelPaint) >
                const Duration(milliseconds: 80)) {
          _lastLevelPaint = now;
          setState(() => _levelNorm = level);
        }
      },
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    unawaited(_init());
  }

  Future<void> _init() async {
    _previewPosSub = _previewer.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() => _previewPos = pos);
    });
    _previewDurSub = _previewer.onDurationChanged.listen((dur) {
      if (!mounted) return;
      setState(() => _previewDuration = dur);
    });
    _previewCompleteSub = _previewer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _previewPlaying = false;
        _previewPos = Duration.zero;
      });
    });

    if (!_recorder.supported) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _initError = 'Microphone recording is available on Windows and macOS.';
      });
      return;
    }

    try {
      await _recorder.initialize();
      _hasPermission = await _recorder.hasPermission();
      if (_hasPermission) {
        _devices = await _recorder.devices();
        _selectedDevice = _preferredInputDevice(_devices);
      }
    } catch (e) {
      _initError = 'Microphone initialization failed: $e';
    }

    if (!mounted) return;
    if (!_hasPermission && _initError == null) {
      setState(() {
        _initializing = false;
        _initError = 'Microphone permission denied.';
      });
      return;
    }
    setState(() {
      _initializing = false;
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _pulseCtrl.dispose();
    unawaited(_take.dispose());
    unawaited(_previewPosSub?.cancel());
    unawaited(_previewDurSub?.cancel());
    unawaited(_previewCompleteSub?.cancel());
    unawaited(_previewer.dispose());
    super.dispose();
  }

  // ───────────── Recording control ─────────────

  Future<void> _startRecording() async {
    if (_busy || !_canRecord) return;
    setState(() => _busy = true);
    try {
      final dir = await PathService.instance.voiceCharacterRefDir();
      final path = p.join(
        dir.path,
        'recording_${PathService.formatTimestamp()}_${const Uuid().v4()}.wav',
      );

      await _take.start(path, _selectedDevice);
      _levelNorm = 0;
      _recordedPath = path;
      _elapsed = Duration.zero;
      _previewDuration = null;
      _previewPos = Duration.zero;
      _previewPlaying = false;
      _elapsedTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        setState(() => _elapsed += const Duration(milliseconds: 200));
      });

      setState(() => _phase = _Phase.recording);
    } catch (e) {
      await _take.abort();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).uiRecordingFailed(e)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopRecording() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await _finishRecording(keepFile: true);
      if (path != null && await File(path).exists()) {
        await _previewer.setSource(DeviceFileSource(path));
        final duration = await _previewer.getDuration();
        if (!mounted) return;
        setState(() {
          _phase = _Phase.preview;
          _recordedPath = path;
          _previewDuration = duration ?? _elapsed;
          _previewPos = Duration.zero;
          _previewPlaying = false;
        });
      } else if (mounted) {
        setState(() => _phase = _Phase.idle);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.idle;
          _recordedPath = null;
          _levelNorm = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).uiRecordingFailed(e)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _finishRecording({required bool keepFile}) {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    return _take.stop(keepFile: keepFile);
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> _discardAndRetry() async {
    final path = _recordedPath;
    setState(() {
      _phase = _Phase.idle;
      _recordedPath = null;
      _previewDuration = null;
      _previewPos = Duration.zero;
      _previewPlaying = false;
      _elapsed = Duration.zero;
      _levelNorm = 0;
    });
    await _previewer.stop();
    if (path != null) await _deleteIfExists(File(path));
  }

  Future<void> _togglePreview() async {
    if (_recordedPath == null) return;
    if (_previewPlaying) {
      await _previewer.pause();
      setState(() => _previewPlaying = false);
      return;
    }
    final dur = _previewDuration;
    if (dur != null && _previewPos >= dur) {
      await _previewer.seek(Duration.zero);
    }
    await _previewer.resume();
    setState(() => _previewPlaying = true);
  }

  void _confirm() => Navigator.of(context).pop(_recordedPath);

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _previewer.stop();
    if (_phase == _Phase.recording) {
      await _finishRecording(keepFile: false);
    } else if (_recordedPath != null) {
      await _deleteIfExists(File(_recordedPath!));
    }
    if (mounted) Navigator.of(context).pop(null);
  }

  // ───────────── UI ─────────────

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.mic_rounded, color: AppTheme.accentColor),
          SizedBox(width: 10),
          Text(AppLocalizations.of(context).uiRecordAudio),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_initializing)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_initError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _initError!,
                  style: TextStyle(color: context.colors.warning, fontSize: 13),
                ),
              )
            else ...[
              _buildDeviceRow(),
              SizedBox(height: 16),
              RecordingIndicator(
                active: _phase == _Phase.recording,
                level: _phase == _Phase.recording ? _levelNorm : 0,
                pulse: _pulseCtrl,
                status: _phase == _Phase.recording
                    ? AppLocalizations.of(context).statusWritingWav
                    : _phase == _Phase.preview
                    ? AppLocalizations.of(context).statusPreview
                    : AppLocalizations.of(context).statusIdle,
              ),
              SizedBox(height: 12),
              RecordingTimerRow(
                status: _phase == _Phase.recording
                    ? AppLocalizations.of(context).statusWritingWav
                    : _phase == _Phase.preview
                    ? AppLocalizations.of(context).statusPreview
                    : AppLocalizations.of(context).statusIdle,
                time: _fmt(
                  _phase == _Phase.preview
                      ? _previewDuration ?? _elapsed
                      : _elapsed,
                ),
                recording: _phase == _Phase.recording,
              ),
              SizedBox(height: 16),
              if (_phase == _Phase.preview) _buildPreviewRow(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _cancel,
          child: Text(AppLocalizations.of(context).uiCancel),
        ),
        if (_phase == _Phase.preview) ...[
          TextButton(
            onPressed: _busy ? null : _discardAndRetry,
            child: Text(AppLocalizations.of(context).uiReRecord),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _confirm,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(AppLocalizations.of(context).uiSave),
          ),
        ] else
          FilledButton.icon(
            onPressed: _busy || !_canRecord
                ? null
                : (_phase == _Phase.recording
                      ? _stopRecording
                      : _startRecording),
            icon: Icon(
              _phase == _Phase.recording
                  ? Icons.stop_rounded
                  : Icons.fiber_manual_record_rounded,
              size: 18,
            ),
            label: Text(_phase == _Phase.recording ? 'Stop' : 'Record'),
            style: _phase == _Phase.recording
                ? FilledButton.styleFrom(backgroundColor: context.colors.danger)
                : null,
          ),
      ],
    );
  }

  Widget _buildDeviceRow() {
    if (_devices.isEmpty) {
      return Text(
        AppLocalizations.of(context).uiDefaultMicrophone,
        style: TextStyle(
          fontSize: 12,
          color: context.fg.withValues(alpha: 0.5),
        ),
      );
    }
    return DropdownButtonFormField<InputDevice?>(
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).uiInputDevice,
        isDense: true,
      ),
      initialValue: _selectedDevice,
      items: [
        DropdownMenuItem<InputDevice?>(
          value: null,
          child: Text(AppLocalizations.of(context).uiDefault),
        ),
        for (final d in _devices)
          DropdownMenuItem<InputDevice?>(
            value: d,
            child: Text(d.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: _phase == _Phase.recording
          ? null
          : (v) => setState(() => _selectedDevice = v),
    );
  }

  bool get _canRecord => _hasPermission && _initError == null;

  InputDevice? _preferredInputDevice(List<InputDevice> devices) {
    for (final device in devices) {
      if (!_isLikelyVirtualInput(device.label)) return device;
    }
    return devices.firstOrNull;
  }

  bool _isLikelyVirtualInput(String label) {
    final lower = label.toLowerCase();
    return lower.contains('steam') ||
        lower.contains('virtual') ||
        lower.contains('oculus') ||
        lower.contains('desktop audio') ||
        lower.contains('streaming');
  }

  Widget _buildPreviewRow() {
    final dur = _previewDuration ?? _elapsed;
    final maxMs = dur.inMilliseconds == 0 ? 1 : dur.inMilliseconds;
    final pos = _previewPos.inMilliseconds.clamp(0, maxMs);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.raised,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            iconSize: 28,
            color: AppTheme.accentColor,
            icon: Icon(
              _previewPlaying
                  ? Icons.pause_circle_rounded
                  : Icons.play_circle_rounded,
            ),
            onPressed: _togglePreview,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                min: 0,
                max: maxMs.toDouble(),
                value: pos.toDouble(),
                onChanged: (v) =>
                    _previewer.seek(Duration(milliseconds: v.toInt())),
              ),
            ),
          ),
          Text(
            '${_fmt(_previewPos)} / ${_fmt(dur)}',
            style: TextStyle(
              fontSize: 11,
              color: context.fg.withValues(alpha: 0.54),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
