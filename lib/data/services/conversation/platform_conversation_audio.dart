import 'dart:typed_data';

import 'package:neiroha/data/services/recording/recording_backend.dart';
import 'package:neiroha/data/services/synthesis/soloud_audio_sink.dart';
import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';

import 'conversation_engine.dart';

/// Desktop microphone (48 kHz PCM16 mono) and SoLoud speakers.
class PlatformConversationAudio implements ConversationAudioIo {
  PlatformConversationAudio({RecordingBackend? recorder})
    : _recorder = recorder ?? RecordingBackend.platform();
  final RecordingBackend _recorder;
  bool _initialized = false;

  bool get microphoneSupported => _recorder.supported;

  @override
  int get microphoneRate => 48000;

  @override
  Future<Stream<Uint8List>> startMicrophone() async {
    if (!_initialized) {
      await _recorder.initialize();
      _initialized = true;
    }
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission was denied.');
    }
    return _recorder.start(null);
  }

  @override
  Future<void> stopMicrophone() async {
    if (_initialized) await _recorder.stop();
  }

  @override
  StreamingAudioSink newSink() => SoloudAudioSink();

  @override
  Future<void> dispose() => _recorder.dispose();
}
