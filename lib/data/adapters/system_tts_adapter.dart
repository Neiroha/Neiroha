import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tts_adapter.dart';

/// Adapter for the built-in Windows SAPI (System.Speech) TTS engine.
///
/// Uses PowerShell to invoke the .NET SpeechSynthesizer, which is available
/// on all Windows 10/11 installations without any additional setup.
/// No base URL or API key required.
class SystemTtsAdapter extends TtsAdapter {
  final String baseUrl; // unused
  final String apiKey; // unused
  final String modelName; // unused

  SystemTtsAdapter({
    this.baseUrl = '',
    this.apiKey = '',
    this.modelName = '',
  });

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    final tempDir = await getTemporaryDirectory();
    final outFile = p.join(tempDir.path, 'sapi_tts_${DateTime.now().millisecondsSinceEpoch}.wav');

    // Escape single quotes for PowerShell string
    final escapedText = request.text.replaceAll("'", "''");
    final voiceName = request.presetVoiceName ?? '';

    // Build PowerShell script
    final script = StringBuffer()
      ..writeln('Add-Type -AssemblyName System.Speech')
      ..writeln('\$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer');

    // Select voice if specified
    if (voiceName.isNotEmpty) {
      final escapedVoice = voiceName.replaceAll("'", "''");
      script.writeln('try { \$synth.SelectVoice(\'$escapedVoice\') } catch {}');
    }

    // Adjust rate: SAPI rate is -10..10, map speed 0.5..2.0 to roughly -5..5
    final rate = ((request.speed - 1.0) * 5).round().clamp(-10, 10);
    script.writeln('\$synth.Rate = $rate');

    // Output to WAV file
    final escapedPath = outFile.replaceAll("'", "''");
    script
      ..writeln('\$synth.SetOutputToWaveFile(\'$escapedPath\')')
      ..writeln('\$synth.Speak(\'$escapedText\')')
      ..writeln('\$synth.Dispose()');

    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-NonInteractive', '-Command', script.toString()],
    );

    if (result.exitCode != 0) {
      throw Exception('SAPI TTS failed: ${result.stderr}');
    }

    final file = File(outFile);
    if (!await file.exists()) {
      throw Exception('SAPI TTS: output file not created');
    }

    final bytes = await file.readAsBytes();
    // Clean up temp file
    await file.delete().catchError((_) => file);

    return TtsResult(
      audioBytes: Uint8List.fromList(bytes),
      contentType: 'audio/wav',
    );
  }

  @override
  Future<bool> healthCheck() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Add-Type -AssemblyName System.Speech; '
            '\$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; '
            '\$s.Dispose(); '
            'Write-Output "ok"',
      ]);
      return result.exitCode == 0 &&
          result.stdout.toString().trim().contains('ok');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> getSpeakers() async {
    if (!Platform.isWindows) return [];
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Add-Type -AssemblyName System.Speech; '
            '\$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; '
            '\$s.GetInstalledVoices() | '
            'ForEach-Object { \$_.VoiceInfo.Name }; '
            '\$s.Dispose()',
      ]);
      if (result.exitCode == 0) {
        return result.stdout
            .toString()
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
