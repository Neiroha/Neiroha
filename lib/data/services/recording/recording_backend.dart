import 'dart:typed_data';
import 'package:record_platform_interface/record_platform_interface.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';
import 'package:uuid/uuid.dart';

abstract interface class RecordingBackend {
  factory RecordingBackend.platform() = PluginRecordingBackend;
  bool get supported;
  Future<void> initialize();
  Future<bool> hasPermission();
  Future<List<InputDevice>> devices();
  Future<Stream<Uint8List>> start(InputDevice? device);
  Future<void> stop();
  Future<void> dispose();
}

/// The native Windows/Darwin plugin registers RecordPlatform on its platform.
/// Using those implementations directly keeps Linux dependencies out.
class PluginRecordingBackend implements RecordingBackend {
  PluginRecordingBackend({
    RecordPlatform? platform,
    PlatformCapabilities? capabilities,
  }) : _platform = platform ?? RecordPlatform.instance,
       _capabilities = capabilities ?? PlatformCapabilities.current();
  final RecordPlatform _platform;
  final PlatformCapabilities _capabilities;
  final _id = 'neiroha_record_${const Uuid().v4()}';
  bool _created = false;
  bool _disposed = false;
  @override
  bool get supported => _capabilities.supportsMicrophoneRecording;
  @override
  Future<void> initialize() async {
    if (!supported) {
      throw UnsupportedError(
        'Microphone recording is unavailable on this platform.',
      );
    }
    await _platform.create(_id);
    _created = true;
    if (_disposed) await _platform.dispose(_id);
  }

  @override
  Future<bool> hasPermission() =>
      _disposed ? Future.value(false) : _platform.hasPermission(_id);
  @override
  Future<List<InputDevice>> devices() => _platform.listInputDevices(_id);
  @override
  Future<Stream<Uint8List>> start(InputDevice? device) {
    if (_disposed) throw StateError('Recording backend was disposed.');
    return _platform.startStream(
      _id,
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 48000,
        numChannels: 1,
        device: device,
      ),
    );
  }

  @override
  Future<void> stop() async {
    if (_created && !_disposed) await _platform.stop(_id);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_created) await _platform.dispose(_id);
  }
}
