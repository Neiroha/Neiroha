import 'package:flutter/material.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

String capabilityLabel(AppLocalizations l, AiCapability cap) => switch (cap) {
  AiCapability.llm => l.capLlm,
  AiCapability.tts => l.capTts,
  AiCapability.stt => l.capStt,
  AiCapability.realtime => l.capRealtime,
  AiCapability.translate => l.capTranslate,
  AiCapability.vc => l.capVc,
  AiCapability.vad => l.capVad,
  AiCapability.music => l.capMusic,
};

IconData capabilityIcon(AiCapability cap) => switch (cap) {
  AiCapability.llm => Icons.psychology_rounded,
  AiCapability.tts => Icons.record_voice_over_rounded,
  AiCapability.stt => Icons.hearing_rounded,
  AiCapability.realtime => Icons.forum_rounded,
  AiCapability.translate => Icons.translate_rounded,
  AiCapability.vc => Icons.transform_rounded,
  AiCapability.vad => Icons.graphic_eq_rounded,
  AiCapability.music => Icons.music_note_rounded,
};

String connectionName(ProviderConnection c) =>
    c.config.name.isEmpty ? c.plugin.displayName : c.config.name;
