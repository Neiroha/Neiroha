import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';

StreamingAudioSink createBrowserPcmSink() =>
    throw UnsupportedError('Web Audio requires a browser.');
