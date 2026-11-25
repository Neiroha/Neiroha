import 'dart:io';
import 'dart:typed_data';

import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/synthesis/tts_request.dart';
import 'package:neiroha/server/mcp/mcp_server.dart';
import 'package:path/path.dart' as p;

/// One clip an MCP tool wrote to disk.
class McpSynthResult {
  final String path;
  final String contentType;
  final double? durationSec;
  const McpSynthResult({
    required this.path,
    required this.contentType,
    required this.durationSec,
  });
}

/// The character's line as a TTS request. With [applyChain] the request
/// names the character, so its processing chain (translate / rewrite / VC)
/// runs around the TTS like in the app.
TtsRequest characterSpeechRequest(
  VoiceAsset asset,
  TtsProvider provider,
  String text, {
  double? speed,
  String? instruction,
  bool applyChain = true,
}) => TtsRequest(
  text: text,
  voice: asset.presetVoiceName ?? asset.name,
  speed: speed ?? asset.speed,
  textLang: provider.adapterType == 'gptSovits' ? asset.modelName : null,
  presetVoiceName: asset.presetVoiceName,
  voiceInstruction: instruction ?? asset.voiceInstruction,
  refAudioPath: asset.refAudioPath,
  promptText: asset.promptText,
  promptLang: asset.promptLang,
  voiceAssetId: applyChain ? asset.id : null,
);

/// Speaks [text] with [asset] through the shared TTS queue and writes the
/// clip to [outPathOrBase] (the extension follows the audio type).
Future<McpSynthResult> synthesizeCharacterToFile(
  AppDatabase db,
  VoiceAsset asset,
  String text,
  String outPathOrBase, {
  required String source,
  required Future<double?> Function(String path, {Uint8List? bytes}) probe,
  String? label,
  double? speed,
  String? instruction,
  bool applyChain = true,
}) async {
  if (!asset.enabled) {
    throw McpToolError('Character "${asset.name}" is disabled');
  }
  final provider = (await db.getAllProviders())
      .where((pr) => pr.id == asset.providerId)
      .firstOrNull;
  if (provider == null) {
    throw McpToolError('Provider of "${asset.name}" not found');
  }
  if (!provider.enabled) {
    throw McpToolError(
      'Provider "${provider.name}" is disabled — enable it with '
      'update_provider.',
    );
  }
  final result = await TtsQueueService.instance.synthesize(
    provider: provider,
    modelName: asset.modelName,
    source: source,
    label: label ?? '${asset.name}: $text',
    request: characterSpeechRequest(
      asset,
      provider,
      text,
      speed: speed,
      instruction: instruction,
      applyChain: applyChain,
    ),
  );
  var path = outPathOrBase;
  if (p.extension(path).isEmpty) {
    path = '$path${audioExtForContentType(result.contentType)}';
  }
  await File(path).writeAsBytes(result.audioBytes);
  return McpSynthResult(
    path: path,
    contentType: result.contentType,
    durationSec: await probe(path, bytes: result.audioBytes),
  );
}

String audioExtForContentType(String ct) {
  final c = ct.toLowerCase();
  if (c.contains('wav')) return '.wav';
  if (c.contains('flac')) return '.flac';
  if (c.contains('ogg') || c.contains('opus')) return '.ogg';
  if (c.contains('aac') || c.contains('mp4')) return '.m4a';
  return '.mp3';
}

/// Duration of a PCM RIFF/WAVE buffer, or null for other formats.
double? wavDurationSeconds(Uint8List b) {
  if (b.length < 44 || String.fromCharCodes(b.sublist(0, 4)) != 'RIFF') {
    return null;
  }
  final bd = ByteData.sublistView(b);
  var offset = 12;
  int? byteRate;
  while (offset + 8 <= b.length) {
    final id = String.fromCharCodes(b.sublist(offset, offset + 4));
    final size = bd.getUint32(offset + 4, Endian.little);
    if (id == 'fmt ') byteRate = bd.getUint32(offset + 16, Endian.little);
    if (id == 'data' && byteRate != null && byteRate > 0) {
      final dataLen = size == 0xFFFFFFFF || offset + 8 + size > b.length
          ? b.length - offset - 8
          : size;
      return dataLen / byteRate;
    }
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }
  return null;
}
