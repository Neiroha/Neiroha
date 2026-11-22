import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/storage/session_audio_urls.dart';
import 'package:neiroha/providers/session_audio_provider.dart';
import 'package:path/path.dart' as p;

/// Suggested download name for generated audio, derived from its title.
@visibleForTesting
String audioDownloadFileName(String? title, String extension) {
  final cleaned = (title ?? '')
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final base = cleaned.isEmpty
      ? 'audio'
      : String.fromCharCodes(cleaned.runes.take(40)).trim();
  final ext = extension.isEmpty
      ? '.wav'
      : (extension.startsWith('.') ? extension : '.$extension');
  return 'neiroha-$base$ext';
}

/// Saves a copy of generated audio where the user chooses.
///
/// Web clips are downloaded by the browser. Returns false when the user
/// cancels the save dialog.
Future<bool> downloadGeneratedAudio(
  WidgetRef ref,
  String audioPath, {
  String? title,
}) async {
  if (kIsWeb) {
    final extension =
        ref.read(sessionAudioProvider.notifier).extensionForUrl(audioPath) ??
        '.wav';
    downloadSessionAudio(audioPath, audioDownloadFileName(title, extension));
    return true;
  }
  final bytes = await File(audioPath).readAsBytes();
  final uri = await FilePicker.saveFile(
    fileName: audioDownloadFileName(title, p.extension(audioPath)),
    bytes: bytes,
    mimeType: _mimeType(p.extension(audioPath)),
  );
  return uri != null;
}

String _mimeType(String extension) => switch (extension.toLowerCase()) {
  '.mp3' => 'audio/mpeg',
  '.ogg' || '.opus' => 'audio/ogg',
  '.flac' => 'audio/flac',
  '.aac' || '.m4a' => 'audio/mp4',
  _ => 'audio/wav',
};
