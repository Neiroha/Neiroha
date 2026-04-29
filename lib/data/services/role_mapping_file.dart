import 'dart:convert';

import 'package:neiroha/data/storage/path_service.dart';

/// Persistent character → voice mapping for one Phase TTS project, kept on
/// disk as `{voiceAssetRoot}/phase_tts/{slug}/role_mapping.json`. We keep
/// it as a file (not a DB table) so projects stay self-contained: the user
/// can move a project folder between installs and the mapping travels with
/// the audio.
///
/// The schema is intentionally tiny — the per-segment voice override lives
/// on `PhaseTtsSegment.voiceAssetId`. This file only answers "for character
/// X in this project, which voice config should I default to?".
class RoleMapping {
  /// Speaker label (LLM-detected, e.g. `悟空` / `旁白`) → `VoiceAsset.id`.
  /// Values may be `null` if the user explicitly cleared a binding.
  final Map<String, String?> speakerToVoice;

  /// Schema version, so we can migrate future formats without guessing.
  final int version;

  const RoleMapping({
    this.speakerToVoice = const {},
    this.version = 1,
  });

  RoleMapping copyWith({Map<String, String?>? speakerToVoice}) =>
      RoleMapping(
        speakerToVoice: speakerToVoice ?? this.speakerToVoice,
        version: version,
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'speakerToVoice': speakerToVoice,
      };

  factory RoleMapping.fromJson(Map<String, dynamic> json) {
    final raw = json['speakerToVoice'];
    final mapping = <String, String?>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        mapping[key.toString()] = value?.toString();
      });
    }
    return RoleMapping(
      speakerToVoice: mapping,
      version: json['version'] is int ? json['version'] as int : 1,
    );
  }
}

/// Reads / writes the per-project [RoleMapping] file. Missing files produce
/// an empty mapping; malformed files throw so the caller can surface the
/// problem rather than silently dropping the user's bindings.
class RoleMappingFileService {
  /// Caller passes the **slug** (filesystem-safe project folder name),
  /// not the project id. Use `StorageService.ensurePhaseProjectSlug`
  /// to resolve it.
  Future<RoleMapping> load(String projectSlug) async {
    final file = await PathService.instance.phaseTtsRoleMappingFile(projectSlug);
    if (!await file.exists()) return const RoleMapping();
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return const RoleMapping();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('role_mapping.json is not a JSON object', raw);
    }
    return RoleMapping.fromJson(decoded);
  }

  Future<void> save(String projectSlug, RoleMapping mapping) async {
    final file = await PathService.instance.phaseTtsRoleMappingFile(projectSlug);
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(mapping.toJson()), flush: true);
  }

  Future<void> delete(String projectSlug) async {
    final file = await PathService.instance.phaseTtsRoleMappingFile(projectSlug);
    if (await file.exists()) await file.delete();
  }
}
