import 'dart:typed_data';

typedef SpeechHttpResponse = ({
  String? Function(String) header,
  Stream<Uint8List> chunks,
  void Function() close,
});

/// Fetch deliberately does not expose whether a failed request was blocked by
/// CORS or failed at the network layer.
class BrowserSpeechConnectionException implements Exception {
  const BrowserSpeechConnectionException();

  @override
  String toString() => 'Browser could not connect to the speech API.';
}
