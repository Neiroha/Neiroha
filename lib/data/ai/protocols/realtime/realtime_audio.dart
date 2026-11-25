import 'dart:convert';

import 'package:neiroha/domain/ai/ai_exception.dart';

/// OpenAI realtime audio is PCM16 mono at 24 kHz in both directions.
const openAiRealtimeRate = 24000;

const openAiRealtimePcmFormat = {
  'type': 'audio/pcm',
  'rate': openAiRealtimeRate,
};

List<String> realtimeLanguages(Object? raw) => [
  if (raw is List)
    for (final item in raw)
      if (item is Map && item['code'] is String)
        item['code'] as String
      else if (item is String)
        item,
];

List<int> base64DecodeSafe(String value) {
  try {
    return base64Decode(value);
  } on FormatException {
    throw const AiProviderException('Realtime sent invalid base64 audio.');
  }
}
