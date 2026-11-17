import 'dart:io';

/// Host requirements for opt-in hardware checks. Protocol/unit tests always run.
class TestCapabilities {
  const TestCapabilities({
    required this.operatingSystem,
    required this.audioEnabled,
    required this.ffmpegAvailable,
  });

  factory TestCapabilities.current() {
    final enabled = Platform.environment['NEIROHA_AUDIO_SMOKE'] == '1';
    var ffmpeg = false;
    if (enabled) {
      try {
        ffmpeg = Process.runSync('ffmpeg', ['-version']).exitCode == 0;
      } on ProcessException {
        // The MP3 encoder check is optional; PCM does not require FFmpeg.
      }
    }
    return TestCapabilities(
      operatingSystem: Platform.operatingSystem,
      audioEnabled: enabled,
      ffmpegAvailable: ffmpeg,
    );
  }

  final String operatingSystem;
  final bool audioEnabled;
  final bool ffmpegAvailable;

  String? get nativeAudioUnavailableReason =>
      ['windows', 'macos', 'linux'].contains(operatingSystem)
      ? null
      : 'Native audio smoke tests need a Windows, macOS or Linux desktop host.';

  Object audioSkipReason({bool requiresFfmpeg = false}) {
    if (!audioEnabled) return 'Set NEIROHA_AUDIO_SMOKE=1 to play test tones.';
    if (nativeAudioUnavailableReason case final String reason) return reason;
    if (requiresFfmpeg && !ffmpegAvailable) {
      return 'FFmpeg is not available on PATH; PCM playback is tested separately.';
    }
    return false;
  }
}
