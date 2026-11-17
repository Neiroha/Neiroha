import 'dart:math' as math;
import 'dart:typed_data';
import 'package:neiroha/domain/synthesis/tts_request.dart';

class NovelAudioTools {
  static List<String> chunks(
    String text, {
    required bool autoSlice,
    required int maxSliceChars,
    required bool punctuationOnly,
  }) {
    if (!autoSlice) return [text];
    final maxChars = maxSliceChars.clamp(20, 80).toInt();
    if (text.length <= maxChars) return [text];
    return punctuationOnly
        ? _splitTextForTtsAfterPunctuation(text, maxChars)
        : _splitTextForTts(text, maxChars);
  }

  static List<String> _splitTextForTts(String text, int maxChars) {
    final chunks = <String>[];
    var rest = text.trim();
    while (rest.length > maxChars) {
      final boundary = _bestTtsBoundary(rest, maxChars);
      chunks.add(rest.substring(0, boundary).trim());
      rest = rest.substring(boundary).trimLeft();
    }
    if (rest.isNotEmpty) chunks.add(rest);
    return chunks.where((chunk) => chunk.isNotEmpty).toList(growable: false);
  }

  static List<String> _splitTextForTtsAfterPunctuation(
    String text,
    int maxChars,
  ) {
    final chunks = <String>[];
    final hardLimit = math.max(maxChars + 20, (maxChars * 2.2).round());
    final parts = RegExp(
      r'[\s\S]*?(?:[。！？；;.!?，,、][”"’』」）\]\】]?|$)',
    ).allMatches(text.trim()).map((match) => match.group(0) ?? '');
    var current = '';

    for (final part in parts) {
      if (part.isEmpty) continue;
      current += part;
      final endsAtPunctuation = RegExp(
        r'[。！？；;.!?，,、][”"’』」）\]\】]?$',
      ).hasMatch(current);
      if (current.length >= maxChars && endsAtPunctuation) {
        chunks.add(current.trim());
        current = '';
        continue;
      }
      while (current.length >= hardLimit) {
        final splitAt = _bestTtsBoundary(current, maxChars);
        chunks.add(current.substring(0, splitAt).trim());
        current = current.substring(splitAt).trimLeft();
      }
    }

    if (current.trim().isNotEmpty) chunks.add(current.trim());
    return chunks.where((chunk) => chunk.isNotEmpty).toList(growable: false);
  }

  static int _bestTtsBoundary(String text, int maxChars) {
    final limit = math.min(maxChars, text.length);
    final min = math.max(1, (maxChars * 0.55).round());
    for (final pattern in const [
      r'[。！？；;.!?][”"’』」）\]\】]?',
      r'[，,、]',
      r'\s+',
    ]) {
      final matches = RegExp(pattern).allMatches(text.substring(0, limit));
      final candidates = matches
          .map((m) => m.end)
          .where((idx) => idx >= min)
          .toList();
      if (candidates.isNotEmpty) return candidates.last;
    }
    return limit;
  }

  static Uint8List? concatWavResults(List<TtsResult> results) {
    final wavs = <_WavParts>[];
    for (final result in results) {
      final parts = _parseWav(result.audioBytes);
      if (parts == null) return null;
      wavs.add(parts);
    }
    if (wavs.isEmpty) return null;
    final fmt = wavs.first.fmt;
    if (wavs.any((w) => !_sameBytes(w.fmt, fmt))) return null;
    final dataLength = wavs.fold<int>(0, (sum, w) => sum + w.data.length);
    final builder = BytesBuilder(copy: false);
    _writeAscii(builder, 'RIFF');
    _writeUint32(builder, 4 + (8 + fmt.length) + (8 + dataLength));
    _writeAscii(builder, 'WAVE');
    _writeAscii(builder, 'fmt ');
    _writeUint32(builder, fmt.length);
    builder.add(fmt);
    _writeAscii(builder, 'data');
    _writeUint32(builder, dataLength);
    for (final wav in wavs) {
      builder.add(wav.data);
    }
    return builder.takeBytes();
  }

  static _WavParts? _parseWav(Uint8List bytes) {
    if (bytes.length < 44) return null;
    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
      return null;
    }
    Uint8List? fmt;
    Uint8List? data;
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final size = ByteData.sublistView(
        bytes,
        offset + 4,
        offset + 8,
      ).getUint32(0, Endian.little);
      final start = offset + 8;
      final end = math.min(start + size, bytes.length);
      if (id == 'fmt ') {
        fmt = Uint8List.fromList(bytes.sublist(start, end));
      } else if (id == 'data') {
        data = Uint8List.fromList(bytes.sublist(start, end));
      }
      offset = start + size + (size.isOdd ? 1 : 0);
    }
    if (fmt == null || data == null) return null;
    return _WavParts(fmt: fmt, data: data);
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static void _writeAscii(BytesBuilder builder, String text) {
    builder.add(text.codeUnits);
  }

  static void _writeUint32(BytesBuilder builder, int value) {
    final bytes = ByteData(4)..setUint32(0, value, Endian.little);
    builder.add(bytes.buffer.asUint8List());
  }
}

class _WavParts {
  final Uint8List fmt;
  final Uint8List data;

  const _WavParts({required this.fmt, required this.data});
}
