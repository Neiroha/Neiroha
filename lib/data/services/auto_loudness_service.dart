import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/data/services/loudness_normalizer.dart';
import 'package:neiroha/data/storage/ffmpeg_service.dart';

/// Applies a project's "normalize after generation" setting to a freshly
/// written clip, using the speaker's bank target + character offset.
///
/// Best-effort by design: generation already succeeded, so a missing
/// ffmpeg or a failed pass leaves the raw take in place rather than
/// turning the segment into an error.
class AutoLoudnessService {
  AutoLoudnessService({
    required AppDatabase db,
    required FFmpegService ffmpeg,
    LoudnessNormalizer? normalizer,
  }) : _db = db,
       _ffmpeg = ffmpeg,
       _normalizer =
           normalizer ?? LoudnessNormalizer(resolveFfmpeg: ffmpeg.resolvePath);

  final AppDatabase _db;
  final FFmpegService _ffmpeg;
  final LoudnessNormalizer _normalizer;

  /// Target (LUFS) for [voiceAssetId] speaking in [bankId].
  Future<double> targetFor({
    required String bankId,
    String? voiceAssetId,
  }) async {
    final bank = await _db.getBankById(bankId);
    final asset = voiceAssetId == null
        ? null
        : await _db.getVoiceAssetById(voiceAssetId);
    return LoudnessNormalizer.targetFor(
      bankLufs: bank?.loudnessTargetLufs ?? -16,
      offsetDb: asset?.loudnessOffsetDb ?? 0,
    );
  }

  /// Normalize [path] when [enabled]. Returns null when skipped.
  Future<LoudnessOutcome?> normalizeGenerated({
    required bool enabled,
    required String path,
    required String bankId,
    String? voiceAssetId,
  }) async {
    if (!enabled) return null;
    // A cache hit (Novel Reader reuses file names) is already our output.
    if (LoudnessNormalizer.hasRestorableBackup(path)) return null;
    try {
      if (!await _ffmpeg.isAvailable()) return null;
      final lufs = await targetFor(bankId: bankId, voiceAssetId: voiceAssetId);
      return await _normalizer.normalizeFile(path, LoudnessTarget(lufs: lufs));
    } catch (_) {
      return null;
    }
  }
}
