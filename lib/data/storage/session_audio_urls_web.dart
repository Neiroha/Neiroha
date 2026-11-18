import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

String createSessionAudioUrl(Uint8List bytes, String mime) =>
    web.URL.createObjectURL(
      web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime)),
    );

void revokeSessionAudioUrl(String url) => web.URL.revokeObjectURL(url);

void downloadSessionAudio(String url, String filename) {
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.append(link);
  link.click();
  link.remove();
}
