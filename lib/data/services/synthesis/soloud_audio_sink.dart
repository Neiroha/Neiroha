import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

/// One decoder for an entire utterance, never one decoder per network chunk.
class SoloudAudioSink implements StreamingAudioSink {
  static Future<void>? _initializing;
  final _engine = SoLoud.instance;
  AudioSource? _source;
  SoundHandle? _handle;
  final _drained = Completer<void>();
  bool _stopped = false;
  bool _paused = false;
  bool _ended = false;
  bool _buffering = true;
  int _sampleRate = 24000;
  int _channels = 1;
  Duration _lastPosition = Duration.zero;
  Duration _lastBuffered = Duration.zero;
  Timer? _timer;
  Uint8List? _pendingByte;
  bool _pcm = false;

  @override
  Future<void> open(TtsAudioFormat format) async {
    format.validate();
    _checkActive();
    _initializing ??= _engine.init().catchError((Object error) {
      _initializing = null;
      throw error;
    });
    await _initializing;
    _checkActive();
    _sampleRate = format.sampleRate ?? 24000;
    _channels = format.channels ?? 1;
    _pcm = format.encoding == AudioEncoding.pcmS16le;
    _source = _engine.setBufferStream(
      bufferingType: BufferingType.released,
      maxBufferSizeBytes: 32 * 1024 * 1024,
      bufferingTimeNeeds: 0.15,
      sampleRate: _sampleRate,
      channels: _channels == 2 ? Channels.stereo : Channels.mono,
      format: _pcm ? BufferType.s16le : BufferType.auto,
      onBuffering: (buffering, _, _) => _buffering = buffering,
    );
    // TTS carries ordinary encoded bytes, never ICY radio metadata. The
    // decoder's radio default would otherwise strip valid MP3 frame bytes.
    if (!_pcm) _engine.setBufferIcyMetaInt(_source!, 0);
  }

  @override
  Future<void> add(Uint8List bytes) async {
    _checkActive();
    if (_pcm) {
      if (_pendingByte != null) {
        bytes = Uint8List.fromList([..._pendingByte!, ...bytes]);
        _pendingByte = null;
      }
      final align = _channels * 2;
      final tail = bytes.length % align;
      if (tail != 0) {
        _pendingByte = Uint8List.fromList(bytes.sublist(bytes.length - tail));
        bytes = Uint8List.sublistView(bytes, 0, bytes.length - tail);
      }
    }
    if (bytes.isEmpty) return;
    // Keep ahead by seconds, not by an entire chapter. Waiting is interruptible
    // by stop; user pause eventually backpressures the network subscription.
    while (!_stopped &&
        _handle != null &&
        bufferedUntil - position > const Duration(seconds: 4)) {
      await Future.any([
        Future<void>.delayed(const Duration(milliseconds: 20)),
        drained,
      ]);
    }
    _checkActive();
    _engine.addAudioDataStream(_source!, bytes);
    _lastBuffered = _engine.getLength(_source!);
    if (_handle == null) {
      final handle = _engine.play(_source!, paused: _paused);
      if (_stopped) {
        await _engine.stop(handle);
        return;
      }
      _handle = handle;
      _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (_stopped) return;
        if (_ended && !_engine.getIsValidVoiceHandle(handle)) {
          // Encoded decoders may flush on a native worker after finish().
          // Capture the final length before freezing the drained state.
          _lastBuffered = _engine.getLength(_source!);
          _lastPosition = _lastBuffered;
          if (!_drained.isCompleted) _drained.complete();
          _timer?.cancel();
        }
      });
    }
  }

  @override
  Future<void> finish() async {
    _checkActive();
    if (_pendingByte != null) {
      throw const FormatException('Incomplete PCM frame.');
    }
    _ended = true;
    _engine.setDataIsEnded(_source!);
    _lastBuffered = _engine.getLength(_source!);
    if (_handle == null && !_drained.isCompleted) _drained.complete();
  }

  @override
  Duration get position {
    if (_source != null && !_stopped && !_drained.isCompleted) {
      _lastPosition = _engine.getStreamTimeConsumed(_source!);
    }
    return _lastPosition;
  }

  @override
  Duration get bufferedUntil {
    if (_source != null && !_stopped && !_drained.isCompleted) {
      _lastBuffered = _engine.getLength(_source!);
    }
    return _lastBuffered;
  }

  @override
  bool get isBuffering => _buffering && !_ended;
  @override
  Future<void> get drained => _drained.future;

  @override
  Future<void> pause(bool paused) async {
    _paused = paused;
    if (!_stopped && _handle != null) _engine.setPause(_handle!, paused);
  }

  @override
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _timer?.cancel();
    if (!_drained.isCompleted) _drained.complete();
    final source = _source;
    _source = null;
    if (source != null) await _engine.disposeSource(source);
  }

  void _checkActive() {
    if (_stopped) throw const TtsCancelledException();
  }
}
