import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:record_platform_interface/record_platform_interface.dart';

import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

/// Mic-recording modal. Uses the Windows record plugin directly through its
/// platform interface (MediaFoundation), avoiding the federated `record`
/// package's Linux dependency while also avoiding ffmpeg DirectShow capture.
class RecordDialog extends StatefulWidget {
  const RecordDialog({super.key});

  @override
  State<RecordDialog> createState() => _RecordDialogState();
}

enum _Phase { idle, recording, preview }

class _RecordDialogState extends State<RecordDialog>
    with SingleTickerProviderStateMixin {
  final _recorder = RecordPlatform.instance;
  final _recorderId = 'voice_asset_record_dialog';
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

  File? _recordFile;
  RandomAccessFile? _recordRaf;
  Future<void> _recordWriteChain = Future.value();
  Completer<void>? _recordStreamDone;
  StreamSubscription<Uint8List>? _recordStreamSub;
  int _recordedBytes = 0;
  int _peakSampleAbs = 0;
  DateTime _lastLevelPaint = DateTime.fromMillisecondsSinceEpoch(0);

  Timer? _elapsedTimer;
  StreamSubscription<Duration>? _previewPosSub;
  StreamSubscription<Duration>? _previewDurSub;
  StreamSubscription<void>? _previewCompleteSub;

  @override
  void initState() {
    super.initState();
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

    if (!Platform.isWindows) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _initError =
            'Recording via MediaFoundation is only available on Windows.';
      });
      return;
    }

    try {
      await _recorder.create(_recorderId);
      _hasPermission = await _recorder.hasPermission(_recorderId);
      if (_hasPermission) {
        _devices = await _recorder.listInputDevices(_recorderId);
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
    unawaited(_recorder.dispose(_recorderId));
    unawaited(_recordStreamSub?.cancel());
    unawaited(_recordRaf?.close());
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
        'recording_${PathService.formatTimestamp()}.wav',
      );

      final file = File(path);
      final raf = await file.open(mode: FileMode.write);
      await raf.writeFrom(_wavHeader(0));
      _recordFile = file;
      _recordRaf = raf;

      final stream = await _recorder.startStream(
        _recorderId,
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 48000,
          numChannels: 1,
          device: _selectedDevice,
        ),
      );

      _recordWriteChain = Future.value();
      _recordStreamDone = Completer<void>();
      _recordedBytes = 0;
      _peakSampleAbs = 0;
      _levelNorm = 0;
      _recordStreamSub = stream.listen(
        _handlePcmChunk,
        onError: (Object e) {
          if (!(_recordStreamDone?.isCompleted ?? true)) {
            _recordStreamDone?.completeError(e);
          }
        },
        onDone: () {
          if (!(_recordStreamDone?.isCompleted ?? true)) {
            _recordStreamDone?.complete();
          }
        },
        cancelOnError: true,
      );

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
      await _cleanupPartialRecording();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Recording failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _handlePcmChunk(Uint8List chunk) {
    if (chunk.isEmpty) return;
    _recordedBytes += chunk.length;

    var localPeak = 0;
    for (var i = 0; i + 1 < chunk.length; i += 2) {
      var sample = (chunk[i + 1] << 8) | chunk[i];
      if (sample >= 0x8000) sample -= 0x10000;
      final abs = sample.abs();
      if (abs > localPeak) localPeak = abs;
    }
    if (localPeak > _peakSampleAbs) _peakSampleAbs = localPeak;

    final raf = _recordRaf;
    if (raf != null) {
      _recordWriteChain = _recordWriteChain.then((_) => raf.writeFrom(chunk));
    }

    final now = DateTime.now();
    if (mounted &&
        now.difference(_lastLevelPaint) > const Duration(milliseconds: 80)) {
      _lastLevelPaint = now;
      setState(() => _levelNorm = (localPeak / 32768.0).clamp(0.0, 1.0));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Recording failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _finishRecording({required bool keepFile}) async {
    final path = _recordedPath;
    if (path == null) return null;

    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    await _recorder.stop(_recorderId);
    try {
      await _recordStreamDone?.future.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      // Some plugin versions stop the stream without completing the Dart
      // event channel promptly. The write chain below still captures every
      // chunk that reached Dart before stop returned.
    }
    await _recordStreamSub?.cancel();
    _recordStreamSub = null;
    await _recordWriteChain;

    final file = _recordFile ?? File(path);
    final raf = _recordRaf;
    if (raf != null) {
      await raf.setPosition(0);
      await raf.writeFrom(_wavHeader(_recordedBytes));
      await raf.close();
    }
    _recordRaf = null;
    _recordFile = null;

    if (!keepFile) {
      await _deleteIfExists(file);
      return null;
    }

    if (_recordedBytes == 0 ||
        !await file.exists() ||
        await file.length() <= 44) {
      await _deleteIfExists(file);
      throw 'No audio samples were captured. Try another input device or enable Windows microphone access.';
    }
    if (_peakSampleAbs == 0) {
      await _deleteIfExists(file);
      throw 'Only digital silence was captured. Try another microphone input.';
    }
    return file.path;
  }

  Future<void> _cleanupPartialRecording() async {
    try {
      await _recordStreamSub?.cancel();
    } catch (_) {}
    _recordStreamSub = null;
    try {
      await _recordWriteChain;
    } catch (_) {}
    try {
      await _recordRaf?.close();
    } catch (_) {}
    final file = _recordFile;
    _recordRaf = null;
    _recordFile = null;
    _recordStreamDone = null;
    _recordedBytes = 0;
    _peakSampleAbs = 0;
    if (file != null) await _deleteIfExists(file);
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
          const SizedBox(width: 10),
          const Text('Record Audio'),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_initializing)
              const Padding(
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
                  style: TextStyle(color: Colors.orange.shade300, fontSize: 13),
                ),
              )
            else ...[
              _buildDeviceRow(),
              const SizedBox(height: 16),
              _buildRecordingIndicator(),
              const SizedBox(height: 12),
              _buildTimerRow(),
              const SizedBox(height: 16),
              if (_phase == _Phase.preview) _buildPreviewRow(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _cancel,
          child: const Text('Cancel'),
        ),
        if (_phase == _Phase.preview) ...[
          TextButton(
            onPressed: _busy ? null : _discardAndRetry,
            child: const Text('Re-record'),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _confirm,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Save'),
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
                ? FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent.shade400,
                  )
                : null,
          ),
      ],
    );
  }

  Widget _buildDeviceRow() {
    if (_devices.isEmpty) {
      return Text(
        'Default microphone',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      );
    }
    return DropdownButtonFormField<InputDevice?>(
      decoration: const InputDecoration(
        labelText: 'Input device',
        isDense: true,
      ),
      initialValue: _selectedDevice,
      items: [
        const DropdownMenuItem<InputDevice?>(
          value: null,
          child: Text('Default'),
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

  Widget _buildRecordingIndicator() {
    final active = _phase == _Phase.recording;
    final level = active ? _levelNorm : 0.0;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              final t = active ? _pulseCtrl.value : 0.0;
              return Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withValues(alpha: 0.10 + t * 0.18),
                ),
                child: Center(
                  child: Transform.scale(
                    scale: active ? 0.75 + t * 0.25 : 0.75,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? Colors.redAccent.shade200
                            : Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _phase == _Phase.recording
                      ? 'Recording'
                      : (_phase == _Phase.preview ? 'Preview ready' : 'Ready'),
                  style: TextStyle(
                    fontSize: 13,
                    color: active
                        ? Colors.redAccent.shade100
                        : Colors.white.withValues(alpha: 0.58),
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 5,
                    child: Stack(
                      children: [
                        Container(color: Colors.white.withValues(alpha: 0.08)),
                        FractionallySizedBox(
                          widthFactor: level,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.accentColor,
                                  level > 0.85
                                      ? Colors.redAccent
                                      : AppTheme.accentColor.withValues(
                                          alpha: 0.72,
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Uint8List _wavHeader(
    int dataLength, {
    int sampleRate = 48000,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    final out = Uint8List(44);
    final data = ByteData.view(out.buffer);
    void ascii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        out[offset + i] = value.codeUnitAt(i);
      }
    }

    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;

    ascii(0, 'RIFF');
    data.setUint32(4, 36 + dataLength, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, channels, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, byteRate, Endian.little);
    data.setUint16(32, blockAlign, Endian.little);
    data.setUint16(34, bitsPerSample, Endian.little);
    ascii(36, 'data');
    data.setUint32(40, dataLength, Endian.little);
    return out;
  }

  Widget _buildTimerRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _phase == _Phase.recording
              ? 'Writing WAV'
              : (_phase == _Phase.preview ? 'Preview' : 'Idle'),
          style: TextStyle(
            fontSize: 12,
            color: _phase == _Phase.recording
                ? Colors.redAccent.shade200
                : Colors.white.withValues(alpha: 0.5),
          ),
        ),
        Text(
          _fmt(
            _phase == _Phase.preview && _previewDuration != null
                ? _previewDuration!
                : _elapsed,
          ),
          style: const TextStyle(
            fontSize: 13,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewRow() {
    final dur = _previewDuration ?? _elapsed;
    final maxMs = dur.inMilliseconds == 0 ? 1 : dur.inMilliseconds;
    final pos = _previewPos.inMilliseconds.clamp(0, maxMs);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright,
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
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white54,
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
