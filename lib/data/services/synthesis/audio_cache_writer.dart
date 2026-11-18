import 'dart:io';
import 'dart:typed_data';

import 'package:neiroha/data/adapters/wav_utils.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:uuid/uuid.dart';

/// Writes beside the destination so rename is atomic on the same volume.
class AudioCacheWriter {
  AudioCacheWriter(this.destination, this.format);

  final String destination;
  final TtsAudioFormat format;
  RandomAccessFile? _file;
  late final File _temporary = File(
    '$destination.${const Uuid().v4()}.partial',
  );
  int _length = 0;
  bool _committed = false;

  Future<void> open() async {
    format.validate();
    await File(destination).parent.create(recursive: true);
    _file = await _temporary.open(mode: FileMode.write);
    if (format.encoding == AudioEncoding.pcmS16le) {
      await _file!.writeFrom(Uint8List(44));
    }
  }

  Future<void> add(Uint8List bytes) async {
    // A single utterance cannot grow without bound on disk or in the player.
    if (_length + bytes.length > 256 * 1024 * 1024) {
      throw const FormatException(
        'Audio exceeded the 256 MiB utterance limit.',
      );
    }
    await _file!.writeFrom(bytes);
    _length += bytes.length;
  }

  Future<String> commit() async {
    if (_length == 0) throw const FormatException('Empty synthesis audio.');
    if (format.encoding == AudioEncoding.pcmS16le) {
      if (_length % (2 * format.channels!) != 0) {
        throw const FormatException('Incomplete PCM sample frame.');
      }
      final header = wrapPcmAsWav(
        Uint8List(0),
        sampleRate: format.sampleRate!,
        channels: format.channels!,
      );
      final view = ByteData.sublistView(header);
      view.setUint32(4, 36 + _length, Endian.little);
      view.setUint32(40, _length, Endian.little);
      await _file!.setPosition(0);
      await _file!.writeFrom(header);
    }
    await _file!.flush();
    await _file!.close();
    _file = null;
    // Callers choose a unique destination; never replace an existing cache.
    if (await File(destination).exists()) {
      throw FileSystemException(
        'Audio destination already exists',
        destination,
      );
    }
    await _temporary.rename(destination);
    _committed = true;
    return destination;
  }

  Future<void> abort() async {
    final file = _file;
    _file = null;
    await file?.close();
    if (!_committed && await _temporary.exists()) await _temporary.delete();
  }
}
