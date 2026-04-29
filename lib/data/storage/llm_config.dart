import '../database/app_database.dart';

/// User-tunable LLM client config persisted in `AppSettings`. Reuses the
/// existing `TtsProviders` table (each row is also an OpenAI-compatible
/// chat endpoint) — `providerId` points at one of those rows. `modelName`
/// is stored separately so the user can target an LLM model name even when
/// the provider's `defaultModelName` is a TTS model.
///
/// All fields are nullable on disk; missing values fall back to the
/// defaults in [LlmConfig.defaults].
class LlmConfig {
  /// `TtsProviders.id` of the chat endpoint to use. `null` until the user
  /// picks one.
  final String? providerId;

  /// Model name to send in the chat-completions request. Independent of
  /// the provider's TTS default model.
  final String modelName;

  /// Per-call timeout. Applies to send + receive separately.
  final Duration timeout;

  /// When true, LLM-assigned segments are persisted without a confirmation
  /// dialog. The UI is still responsible for surfacing errors.
  final bool autoApply;

  /// Display name to seed [defaultSpeakerLabel] in the role-assignment
  /// service when the LLM leaves a segment without a speaker. Mapped to
  /// a voice asset by the role-assignment normalizer.
  final String defaultSpeakerLabel;

  const LlmConfig({
    this.providerId,
    this.modelName = '',
    this.timeout = const Duration(seconds: 60),
    this.autoApply = false,
    this.defaultSpeakerLabel = '',
  });

  static const LlmConfig defaults = LlmConfig();

  bool get isConfigured =>
      providerId != null && providerId!.isNotEmpty && modelName.isNotEmpty;

  LlmConfig copyWith({
    String? providerId,
    String? modelName,
    Duration? timeout,
    bool? autoApply,
    String? defaultSpeakerLabel,
  }) =>
      LlmConfig(
        providerId: providerId ?? this.providerId,
        modelName: modelName ?? this.modelName,
        timeout: timeout ?? this.timeout,
        autoApply: autoApply ?? this.autoApply,
        defaultSpeakerLabel: defaultSpeakerLabel ?? this.defaultSpeakerLabel,
      );
}

/// Reader/writer over the `AppSettings` key/value table for [LlmConfig].
class LlmConfigService {
  LlmConfigService(this._db);

  final AppDatabase _db;

  static const String kProviderId = 'llm.providerId';
  static const String kModelName = 'llm.modelName';
  static const String kTimeoutSec = 'llm.timeoutSec';
  static const String kAutoApply = 'llm.autoApply';
  static const String kDefaultSpeaker = 'llm.defaultSpeakerLabel';

  Future<LlmConfig> load() async {
    final providerId = await _db.getSetting(kProviderId);
    final modelName = await _db.getSetting(kModelName);
    final timeoutRaw = await _db.getSetting(kTimeoutSec);
    final autoApplyRaw = await _db.getSetting(kAutoApply);
    final defaultSpeaker = await _db.getSetting(kDefaultSpeaker);

    final timeoutSec = int.tryParse(timeoutRaw ?? '') ?? 60;
    return LlmConfig(
      providerId:
          (providerId == null || providerId.isEmpty) ? null : providerId,
      modelName: modelName ?? '',
      timeout: Duration(seconds: timeoutSec.clamp(5, 600)),
      autoApply: autoApplyRaw == 'true',
      defaultSpeakerLabel: defaultSpeaker ?? '',
    );
  }

  Future<void> save(LlmConfig config) async {
    if (config.providerId == null || config.providerId!.isEmpty) {
      await _db.deleteSetting(kProviderId);
    } else {
      await _db.setSetting(kProviderId, config.providerId!);
    }
    await _db.setSetting(kModelName, config.modelName);
    await _db.setSetting(kTimeoutSec, config.timeout.inSeconds.toString());
    await _db.setSetting(kAutoApply, config.autoApply ? 'true' : 'false');
    await _db.setSetting(kDefaultSpeaker, config.defaultSpeakerLabel);
  }
}
