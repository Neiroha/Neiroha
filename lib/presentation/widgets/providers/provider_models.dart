import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/registry/model_badges.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/ai/model_retirement_widgets.dart';
import 'package:neiroha/presentation/widgets/settings/ai_capability_settings.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';

/// Models and voices fetched into or typed for one provider row.
final providerBindingsProvider = FutureProvider.autoDispose
    .family<List<db.ModelBinding>, String>(
      (ref, id) => ref.watch(databaseProvider).getBindingsForProvider(id),
    );

/// The saved row's connection; null for an unknown adapter type.
ProviderConnection? connectionOf(db.TtsProvider row) {
  if (AdapterType.values.asNameMap()[row.adapterType] == null) return null;
  try {
    return connectionForProvider(row);
  } catch (_) {
    return null;
  }
}

/// Whether a fetched model key is a speech model (vs LLM/ASR/multimodal).
bool isTtsModelKey(AdapterType type, String modelKey) {
  // The local launchers list voice sets; OpenAI uses its curated TTS models.
  if (type == AdapterType.gptSovits ||
      type == AdapterType.irodori ||
      type == AdapterType.rvc ||
      type == AdapterType.openaiTts) {
    return true;
  }
  final k = modelKey.toLowerCase();
  return k.contains('tts') ||
      k.contains('sovits') ||
      k.contains('speech-synthesis') ||
      k.contains('voiceclone') ||
      k.contains('voicedesign') ||
      k.endsWith('-voice');
}

/// The capability tab a fetched non-speech model belongs to; null for
/// kinds the app does not use (embeddings, images…).
AiCapability? bindingCapability(String modelKey, ProviderConnection? c) =>
    switch (modelBadges(modelKey, c).firstOrNull) {
      'LLM' => AiCapability.llm,
      'ASR' => AiCapability.stt,
      'Realtime' => AiCapability.realtime,
      'Translate' => AiCapability.translate,
      'Music' => AiCapability.music,
      _ => null,
    };

/// A feature badge key (`AiFeature`) in the UI language.
String featureLabel(AppLocalizations l, String key) => switch (key) {
  AiFeature.presetVoices => l.featPresetVoices,
  AiFeature.instructions => l.featInstructions,
  AiFeature.streamingOutput => l.featStreamingOutput,
  AiFeature.cloudClone => l.featCloudClone,
  AiFeature.zeroShotClone => l.featZeroShotClone,
  AiFeature.fileTranscription => l.featFileTranscription,
  AiFeature.streamingTranscription => l.featStreamingTranscription,
  AiFeature.wordTimestamps => l.featWordTimestamps,
  AiFeature.diarization => l.featDiarization,
  AiFeature.languageDetection => l.featLanguageDetection,
  AiFeature.keywords => l.featKeywords,
  AiFeature.audioOutput => l.featAudioOutput,
  AiFeature.textOutput => l.featTextOutput,
  AiFeature.toolCalls => l.featToolCalls,
  AiFeature.serverVad => l.featServerVad,
  AiFeature.inputTranscription => l.featInputTranscription,
  AiFeature.sourceTranscript => l.featSourceTranscript,
  AiFeature.structuredOutput => l.featStructuredOutput,
  AiFeature.reasoning => l.featReasoning,
  AiFeature.vocals => l.featVocals,
  AiFeature.timedLyrics => l.featTimedLyrics,
  AiFeature.imagePrompt => l.featImagePrompt,
  AiFeature.losslessOutput => l.featLosslessOutput,
  AiFeature.zeroShot => l.featZeroShot,
  AiFeature.local => l.featLocal,
  _ => key,
};

/// The switch that turns [cap] on or off for one connection.
class CapabilitySwitch extends ConsumerWidget {
  const CapabilitySwitch({
    super.key,
    required this.connectionId,
    required this.cap,
  });
  final String connectionId;
  final AiCapability cap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final lanes = ref.watch(connectionCapabilitiesProvider).value ?? const [];
    final on =
        lanes
            .where((r) => r.connectionId == connectionId)
            .where((r) => r.capability == cap.name)
            .firstOrNull
            ?.enabled ??
        true;
    final label = capabilityLabel(l, cap);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(capabilityIcon(cap)),
          title: Text(l.provCapUse(label)),
          value: on,
          onChanged: (v) => ref
              .read(databaseProvider)
              .upsertConnectionCapability(
                db.ConnectionCapabilitiesCompanion(
                  connectionId: Value(connectionId),
                  capability: Value(cap.name),
                  enabled: Value(v),
                ),
              ),
        ),
        if (!on)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l.provCapOffHint(label),
              style: const TextStyle(fontSize: 12, color: Colors.amber),
            ),
          ),
      ],
    );
  }
}

/// One model under a capability: name, id and source, feature chips, a
/// retirement date, default star and delete for models the user added.
class ProviderModelTile extends StatelessWidget {
  const ProviderModelTile({
    super.key,
    required this.label,
    required this.id,
    required this.source,
    this.features = const [],
    this.details,
    this.shutdownAt,
    this.isDefault = false,
    this.onSetDefault,
    this.onDelete,
  });
  final String label;
  final String id;
  final String source;
  final Iterable<String> features;

  /// Extra content under the title, e.g. language-model traits.
  final Widget? details;
  final String? shutdownAt;
  final bool isDefault;
  final VoidCallback? onSetDefault;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright,
        borderRadius: BorderRadius.circular(8),
        border: isDefault
            ? Border.all(color: AppTheme.accentColor.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 13)),
                    for (final f in features) _Chip(f),
                    if (shutdownAt case final date?)
                      RetirementChip(shutdownAt: date),
                  ],
                ),
                Text(
                  label == id ? source : '$id · $source',
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
                if (details case final d?)
                  Padding(padding: const EdgeInsets.only(top: 4), child: d),
              ],
            ),
          ),
          if (isDefault)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Tooltip(
                message: l.provIsDefault,
                child: const Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: AppTheme.accentColor,
                ),
              ),
            )
          else if (onSetDefault != null)
            IconButton(
              tooltip: l.provSetDefault,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.star_border_rounded, size: 18),
              onPressed: onSetDefault,
            ),
          if (onDelete != null)
            IconButton(
              tooltip: l.uiDelete,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 16),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 10, color: Colors.white60),
    ),
  );
}

/// A section title with optional actions on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actions = const []});
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        ...actions,
      ],
    ),
  );
}
