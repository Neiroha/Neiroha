import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:neiroha/data/database/app_database.dart' as db;

/// File digests are memoized for the render path. Reference edits invalidate
/// by size/mtime; renaming characters with a preset does not invalidate audio.
/// Editing the character's processing chain does ([VoiceChain.signature]).
class NovelAudioFingerprint {
  static final Map<String, ({int size, int modified, String digest})>
  _references = {};

  static String build({
    required db.NovelProject project,
    required db.NovelSegment segment,
    required db.VoiceAsset asset,
    required db.TtsProvider provider,
    String textFilterSignature = '',
    String? instruction,
    String protocolSignature = '',
    String chainSignature = '',
  }) {
    final refPath = asset.refAudioPath;
    String reference = '';
    if (refPath != null && refPath.isNotEmpty) {
      final stat = File(refPath).statSync();
      final previous = _references[refPath];
      if (stat.type != FileSystemEntityType.file) {
        reference = 'missing:$refPath';
      } else if (previous?.size == stat.size &&
          previous?.modified == stat.modified.microsecondsSinceEpoch) {
        reference = previous!.digest;
      } else {
        reference = sha256.convert(File(refPath).readAsBytesSync()).toString();
        if (_references.length > 128) _references.clear();
        _references[refPath] = (
          size: stat.size,
          modified: stat.modified.microsecondsSinceEpoch,
          digest: reference,
        );
      }
    }
    return 'novel-v2:${sha256.convert(utf8.encode(jsonEncode([segment.segmentText, textFilterSignature, project.autoSliceLongSegments, project.sliceOnlyAtPunctuation, project.maxSliceChars, provider.baseUrl, provider.adapterType, asset.modelName ?? provider.defaultModelName, asset.presetVoiceName ?? asset.name, asset.speed, instruction ?? asset.voiceInstruction, reference, asset.promptText, asset.promptLang, if (protocolSignature.isNotEmpty) protocolSignature, if (chainSignature.isNotEmpty) 'chain:$chainSignature'])))}';
  }
}
