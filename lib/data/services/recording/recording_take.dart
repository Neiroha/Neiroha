import 'dart:async';
import 'dart:typed_data';
import 'package:record_platform_interface/record_platform_interface.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import '../synthesis/audio_cache_writer.dart';
import 'recording_backend.dart';

/// A transactional PCM recording. A path becomes visible only after samples
/// are flushed and the WAV header is finalized; UI owns preview and timers.
class RecordingTake {
  RecordingTake(this.backend, {required this.onLevel});
  final RecordingBackend backend;
  final void Function(double) onLevel;
  AudioCacheWriter? _writer;
  StreamSubscription<Uint8List>? _subscription;
  Completer<void>? _done;
  Future<void> _writes = Future.value();
  Object? _failure;
  int _bytes = 0;
  int _peak = 0;
  int? _carry;
  bool _disposed = false;
  Future<String?>? _stopping;

  Future<void> start(String path, InputDevice? device) async {
    if (_disposed) throw StateError('Recording was disposed.');
    await abort();
    _bytes = 0;
    _peak = 0;
    _carry = null;
    _failure = null;
    final writer = AudioCacheWriter(
      path,
      const TtsAudioFormat(
        AudioEncoding.pcmS16le,
        sampleRate: 48000,
        channels: 1,
      ),
    );
    _writer = writer;
    try {
      await writer.open();
      if (_disposed) throw StateError('Recording was disposed.');
      final stream = await backend.start(device);
      if (_disposed) throw StateError('Recording was disposed.');
      _writes = Future.value();
      _done = Completer<void>();
      _subscription = stream.listen(
        (raw) {
          final bytes = Uint8List.fromList(raw);
          _bytes += bytes.length;
          final samples = _carry == null
              ? bytes
              : Uint8List.fromList([_carry!, ...bytes]);
          _carry = samples.length.isOdd ? samples.last : null;
          var peak = 0;
          for (var i = 0; i + 1 < samples.length; i += 2) {
            var sample = samples[i] | samples[i + 1] << 8;
            if (sample >= 0x8000) sample -= 0x10000;
            if (sample.abs() > peak) peak = sample.abs();
          }
          if (peak > _peak) _peak = peak;
          if (!_disposed) onLevel(peak / 32768);
          _writes = _writes
              .then((_) async {
                if (_failure == null) await writer.add(bytes);
              })
              .catchError((Object error) {
                _failure ??= error;
              });
        },
        onError: (Object error) {
          _failure ??= error;
          if (!(_done?.isCompleted ?? true)) _done!.complete();
        },
        onDone: () {
          if (!(_done?.isCompleted ?? true)) _done!.complete();
        },
      );
    } catch (_) {
      await writer.abort();
      await abort();
      rethrow;
    }
  }

  Future<String?> stop({required bool keepFile}) => _stopping ??= _finish(
    keepFile: keepFile,
  ).whenComplete(() => _stopping = null);

  Future<String?> _finish({required bool keepFile}) async {
    final writer = _writer;
    if (writer == null) return null;
    try {
      await backend.stop();
      try {
        await _done?.future.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        /* Some plugins don't close their event channel. */
      }
      await _subscription?.cancel();
      _subscription = null;
      await _writes;
      if (!keepFile || _disposed) return null;
      if (_failure != null) throw _failure!;
      if (_bytes == 0) throw StateError('No microphone samples were captured.');
      if (_peak == 0) {
        throw StateError(
          'Only digital silence was captured. Try another input device.',
        );
      }
      return await writer.commit();
    } finally {
      await _subscription?.cancel();
      _subscription = null;
      await _writes;
      _writer = null;
      await writer.abort();
    }
  }

  Future<void> abort() async {
    if (_stopping != null) {
      try {
        await _stopping;
      } catch (_) {}
      return;
    }
    if (_writer != null) {
      try {
        await backend.stop();
      } catch (_) {}
    }
    await _subscription?.cancel();
    _subscription = null;
    await _writes;
    await _writer?.abort();
    _writer = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await stop(keepFile: false);
    } finally {
      await abort();
      await backend.dispose();
    }
  }
}
