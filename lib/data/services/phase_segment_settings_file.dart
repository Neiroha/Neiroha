import 'dart:convert';

import 'package:neiroha/data/storage/path_service.dart';

/// Per-segment generation overrides for one Phase TTS project.
///
/// These are intentionally file-backed instead of DB-backed so we can add
/// lightweight per-sentence tuning without forcing a schema migration. The
/// generated audio still uses `PhaseTtsSegment.voiceAssetId` as its base
/// voice; these settings only override fields on that selected voice for a
/// single segment.
class PhaseSegmentSettings {
  final Map<String, SegmentVoiceSettings> bySegmentId;
  final int version;

  const PhaseSegmentSettings({this.bySegmentId = const {}, this.version = 1});

  PhaseSegmentSettings copyWith({
    Map<String, SegmentVoiceSettings>? bySegmentId,
  }) => PhaseSegmentSettings(
    bySegmentId: bySegmentId ?? this.bySegmentId,
    version: version,
  );

  Map<String, dynamic> toJson() => {
    'version': version,
    'segments': {
      for (final entry in bySegmentId.entries) entry.key: entry.value.toJson(),
    },
  };

  factory PhaseSegmentSettings.fromJson(Map<String, dynamic> json) {
    final raw = json['segments'];
    final segments = <String, SegmentVoiceSettings>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is Map) {
          segments[key.toString()] = SegmentVoiceSettings.fromJson(
            value.cast<String, dynamic>(),
          );
        }
      });
    }
    return PhaseSegmentSettings(
      bySegmentId: segments,
      version: json['version'] is int ? json['version'] as int : 1,
    );
  }
}

class SegmentVoiceSettings {
  final String? voiceInstruction;
  final String? audioTagPrefix;

  const SegmentVoiceSettings({this.voiceInstruction, this.audioTagPrefix});

  bool get isEmpty =>
      (voiceInstruction == null || voiceInstruction!.isEmpty) &&
      (audioTagPrefix == null || audioTagPrefix!.isEmpty);

  Map<String, dynamic> toJson() => {
    if (voiceInstruction != null && voiceInstruction!.isNotEmpty)
      'voiceInstruction': voiceInstruction,
    if (audioTagPrefix != null && audioTagPrefix!.isNotEmpty)
      'audioTagPrefix': audioTagPrefix,
  };

  factory SegmentVoiceSettings.fromJson(Map<String, dynamic> json) {
    final rawInstruction = json['voiceInstruction']?.toString().trim();
    final rawAudioTag = json['audioTagPrefix']?.toString().trim();
    return SegmentVoiceSettings(
      voiceInstruction: rawInstruction == null || rawInstruction.isEmpty
          ? null
          : rawInstruction,
      audioTagPrefix: rawAudioTag == null || rawAudioTag.isEmpty
          ? null
          : rawAudioTag,
    );
  }
}

class PhaseSegmentSettingsFileService {
  Future<PhaseSegmentSettings> load(String projectSlug) async {
    final file = await PathService.instance.phaseTtsSegmentSettingsFile(
      projectSlug,
    );
    if (!await file.exists()) return const PhaseSegmentSettings();
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return const PhaseSegmentSettings();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'phase_segment_settings.json is not a JSON object',
        raw,
      );
    }
    return PhaseSegmentSettings.fromJson(decoded);
  }

  Future<void> save(String projectSlug, PhaseSegmentSettings settings) async {
    final file = await PathService.instance.phaseTtsSegmentSettingsFile(
      projectSlug,
    );
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(settings.toJson()), flush: true);
  }

  Future<void> delete(String projectSlug) async {
    final file = await PathService.instance.phaseTtsSegmentSettingsFile(
      projectSlug,
    );
    if (await file.exists()) await file.delete();
  }
}
