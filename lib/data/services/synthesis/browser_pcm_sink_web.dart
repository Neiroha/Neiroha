import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:web/web.dart' as web;

/// Construct within the generate button's user gesture to unlock Web Audio.
StreamingAudioSink createBrowserPcmSink() => _BrowserPcmSink();

class _BrowserPcmSink implements StreamingAudioSink {
  _BrowserPcmSink() {
    _ready = _context.resume().toDart.then<bool>(
      (_) => true,
      onError: (_) => false,
    );
  }

  final _context = web.AudioContext();
  final _drained = Completer<void>();
  final _pending = BytesBuilder(copy: false);
  final _nodes =
      <web.AudioBufferSourceNode, ({double start, int offset, int frames})>{};
  late final Future<bool> _ready;
  int _sampleRate = 24000;
  int _channels = 1;
  int _scheduledFrames = 0;
  int _playedFrames = 0;
  double _nextStart = 0;
  bool _ended = false;
  bool _stopped = false;

  int get _bytesPerFrame => _channels * 2;

  @override
  Future<void> open(TtsAudioFormat format) async {
    _checkActive();
    format.validate();
    if (format.encoding != AudioEncoding.pcmS16le) {
      throw const FormatException('Browser streaming requires PCM audio.');
    }
    _sampleRate = format.sampleRate!;
    _channels = format.channels!;
    final running = await Future.any([
      _ready,
      drained.then((_) => false),
    ]).timeout(const Duration(seconds: 3), onTimeout: () => false);
    _checkActive();
    if (!running) throw StateError('Browser audio could not start.');
  }

  @override
  Future<void> add(Uint8List bytes) async {
    _checkActive();
    _pending.add(bytes);
    // Coalesce tiny network chunks, while keeping the first play buffer small.
    if (_pending.length >= (_sampleRate ~/ 20) * _bytesPerFrame) {
      await _flush();
    }
  }

  Future<void> _flush() async {
    final bytes = _pending.takeBytes();
    final alignedLength = bytes.length - (bytes.length % _bytesPerFrame);
    if (alignedLength < bytes.length) {
      _pending.add(bytes.sublist(alignedLength));
    }
    final blockSize = (_sampleRate ~/ 2) * _bytesPerFrame;
    for (var offset = 0; offset < alignedLength; offset += blockSize) {
      while (!_stopped &&
          bufferedUntil - position > const Duration(seconds: 4)) {
        await Future.any([
          Future<void>.delayed(const Duration(milliseconds: 20)),
          drained,
        ]);
      }
      _checkActive();
      _schedule(
        ByteData.sublistView(
          bytes,
          offset,
          math.min(offset + blockSize, alignedLength),
        ),
      );
    }
  }

  void _schedule(ByteData samples) {
    final frames = samples.lengthInBytes ~/ _bytesPerFrame;
    final buffer = _context.createBuffer(_channels, frames, _sampleRate);
    for (var channel = 0; channel < _channels; channel++) {
      final values = Float32List(frames);
      for (var frame = 0; frame < frames; frame++) {
        final offset = (frame * _channels + channel) * 2;
        values[frame] = samples.getInt16(offset, Endian.little) / 32768;
      }
      buffer.copyToChannel(values.toJS, channel);
    }
    final now = _context.currentTime.toDouble();
    final start = _nextStart > now ? _nextStart : now + 0.025;
    final source = _context.createBufferSource()..buffer = buffer;
    source.connect(_context.destination);
    final firstFrame = _scheduledFrames;
    _nodes[source] = (start: start, offset: firstFrame, frames: frames);
    _scheduledFrames += frames;
    _nextStart = start + frames / _sampleRate;
    source.onended = ((web.Event _) {
      if (_nodes.remove(source) == null) return;
      source.onended = null;
      source.disconnect();
      _playedFrames = math.max(_playedFrames, firstFrame + frames);
      _completeIfDrained();
    }).toJS;
    source.start(start);
  }

  @override
  Future<void> finish() async {
    _checkActive();
    if (_pending.length % _bytesPerFrame != 0) {
      throw const FormatException('Incomplete PCM frame.');
    }
    await _flush();
    _ended = true;
    _completeIfDrained();
  }

  @override
  Duration get position {
    final node = _nodes.values.firstOrNull;
    if (node == null) return _duration(_playedFrames);
    final time = _context.currentTime - node.start;
    final consumedFrames = (time * _sampleRate).floor().clamp(0, node.frames);
    return _duration(node.offset + consumedFrames);
  }

  @override
  Duration get bufferedUntil => _duration(_scheduledFrames);

  @override
  bool get isBuffering => !_ended && _nodes.isEmpty;

  @override
  Future<void> get drained => _drained.future;

  @override
  Future<void> pause(bool paused) async {
    if (_stopped) return;
    final update = paused ? _context.suspend() : _context.resume();
    try {
      await update.toDart;
    } catch (_) {
      if (!_stopped) rethrow;
    }
  }

  @override
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    for (final source in _nodes.keys) {
      source.onended = null;
      source.disconnect();
    }
    _nodes.clear();
    _pending.clear();
    if (!_drained.isCompleted) _drained.complete();
    await _context.close().toDart;
  }

  void _checkActive() {
    if (_stopped) throw const TtsCancelledException();
  }

  void _completeIfDrained() {
    if (_ended && _nodes.isEmpty && !_drained.isCompleted) _drained.complete();
  }

  Duration _duration(int frames) => Duration(
    microseconds: frames * Duration.microsecondsPerSecond ~/ _sampleRate,
  );
}
