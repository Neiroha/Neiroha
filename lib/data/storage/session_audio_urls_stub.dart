import 'dart:typed_data';

String createSessionAudioUrl(Uint8List bytes, String mime) =>
    throw UnsupportedError('Browser audio URLs require a web browser.');

void revokeSessionAudioUrl(String url) {}

void downloadSessionAudio(String url, String filename) =>
    throw UnsupportedError('Browser downloads require a web browser.');
