part of 'neiroha_mcp_tools.dart';

/// JSON shapes the tools return.
extension _JsonViews on NeirohaMcpTools {
  Map<String, dynamic> _providerJson(TtsProvider pr) => {
    'id': pr.id,
    'name': pr.name,
    'adapter_type': pr.adapterType,
    'base_url': pr.baseUrl,
    'has_api_key': pr.apiKey.isNotEmpty,
    'default_model': pr.defaultModelName,
    'enabled': pr.enabled,
    'max_concurrency': pr.maxConcurrency,
    'requests_per_minute': pr.requestsPerMinute,
  };

  Map<String, dynamic> _characterJson(VoiceAsset a, TtsProvider? pr) => {
    'id': a.id,
    'name': a.name,
    'description': a.description,
    'provider_id': a.providerId,
    'provider_name': pr?.name,
    'adapter_type': pr?.adapterType,
    'task_mode': a.taskMode,
    'model': a.modelName,
    'voice': a.presetVoiceName,
    'ref_audio_path': a.refAudioPath,
    'prompt_text': a.promptText,
    'prompt_lang': a.promptLang,
    'instruction': a.voiceInstruction,
    'speed': a.speed,
    'loudness_offset_db': a.loudnessOffsetDb,
    'enabled': a.enabled,
  };

  Map<String, dynamic> _bankJson(VoiceBank b) => {
    'id': b.id,
    'name': b.name,
    'description': b.description,
    'active': b.isActive,
    'loudness_target_lufs': b.loudnessTargetLufs,
  };

  Map<String, dynamic> _trackJson(AudioTrack t) => {
    'id': t.id,
    'name': t.name,
    'description': t.description,
    'path': t.audioPath,
    'ref_text': t.refText,
    'ref_lang': t.refLang,
    'duration_sec': t.durationSec,
    'missing': t.missing,
  };

  Map<String, dynamic> _projectJson(
    VideoDubProject pr,
    List<SubtitleCue> cues,
  ) => {
    'id': pr.id,
    'name': pr.name,
    'bank_id': pr.bankId,
    'video_path': pr.videoPath,
    'video_duration_sec': pr.videoDurationSec,
    'auto_normalize_loudness': pr.autoNormalizeLoudness,
    'cues': cues.length,
    'cues_with_character': cues.where((c) => c.voiceAssetId != null).length,
    'cues_with_audio': cues.where((c) => c.audioPath != null).length,
    'cues_with_error': cues.where((c) => c.error != null).length,
    'updated_at': pr.updatedAt.toIso8601String(),
  };

  Map<String, dynamic> _cueJson(SubtitleCue c, VoiceAsset? a) => {
    'id': c.id,
    'index': c.orderIndex,
    'start_ms': c.startMs,
    'end_ms': c.endMs,
    'text': c.cueText,
    'character_id': c.voiceAssetId,
    'character_name': a?.name,
    'audio_path': c.audioPath,
    'audio_duration_sec': c.audioDuration,
    'error': c.error,
  };

  Map<String, dynamic> _adapterJson(AdapterType t) => {
    'adapter_type': t.name,
    'display_name': t.displayName,
    'default_base_url': _defaultBaseUrl(t),
    'default_model': t.defaultModel,
    'supports_model_list': t.supportsModelQuery,
    'supports_voice_list': t.supportsVoiceQuery,
    'supports_cloud_voice_clone': t.supportsCloudVoiceClone,
    'requires_reference_audio': t.requiresReferenceAudio,
    'guide': _adapterGuide[t],
  };
}

String _defaultBaseUrl(AdapterType t) => switch (t) {
  AdapterType.openaiCompatible => 'http://localhost:8880/v1',
  AdapterType.openaiTts => 'https://api.openai.com/v1',
  AdapterType.chatCompletionsTts => 'https://api.xiaomimimo.com/v1',
  AdapterType.gptSovits => 'http://127.0.0.1:9880',
  AdapterType.cosyvoice => 'http://127.0.0.1:9880',
  AdapterType.voxcpm2Native => 'http://127.0.0.1:8000',
  AdapterType.azureTts => 'https://eastus.tts.speech.microsoft.com',
  AdapterType.systemTts => '',
  AdapterType.geminiTts => 'https://generativelanguage.googleapis.com',
  AdapterType.elevenLabs => 'https://api.elevenlabs.io',
  AdapterType.minimaxTts => 'https://api.minimax.io',
  AdapterType.indexTts => 'http://127.0.0.1:7860',
  AdapterType.irodori => 'http://127.0.0.1:19000',
  AdapterType.rvc => 'http://127.0.0.1:19001',
};

const Map<AdapterType, String> _adapterGuide = {
  AdapterType.openaiCompatible:
      'Any OpenAI /v1/audio/speech server (also Qwen3-TTS / Kokoro '
      'FastAPI wrappers). model = TTS model id (tts-1, gpt-4o-mini-tts…); '
      'voice = preset voice (alloy…). task_mode presetVoice.',
  AdapterType.openaiTts:
      'OpenAI official (api.openai.com, Bearer API key). model = '
      'gpt-realtime-2.1-mini (default, Realtime API, the official '
      'replacement) / gpt-realtime-2.1, or the Speech API models '
      'gpt-4o-mini-tts / tts-1 / tts-1-hd, which OpenAI shuts down on '
      '2027-01-06. voice = marin / cedar (best) or another built-in voice; '
      'a custom voice id voice_... also works. instruction = delivery style '
      '(not for tts-1). Speech API input is limited to 4096 characters.',
  AdapterType.chatCompletionsTts:
      'MiMo-style chat-completions TTS. The model decides the mode: names '
      'containing "voiceclone" need reference audio (cloneWithPrompt), '
      '"voicedesign" need an instruction (voiceDesign), others use a '
      'preset voice. instruction = style direction.',
  AdapterType.cosyvoice:
      'CosyVoice launcher. model = mode: zero_shot (reference audio + '
      'prompt_text), cross_lingual (reference audio), instruct '
      '(instruction, optional reference audio). voice = optional '
      'server profile name.',
  AdapterType.voxcpm2Native:
      'VoxCPM2 launcher. model = design (instruction required) | clone '
      '(reference audio) | ultimate_clone (reference audio + prompt_text). '
      'voice = optional server-registered voice id.',
  AdapterType.gptSovits:
      'GPT-SoVITS launcher. presetVoice: voice = trained speaker, model = '
      'text language (zh/en/ja/ko). cloneWithPrompt: reference audio + '
      'prompt_text + prompt_lang, model = text language.',
  AdapterType.rvc:
      'Neiroha-RVC voice conversion only; it cannot be a character voice. '
      'Use it as a VC step (character processing chain or live settings): '
      'model = checkpoint id or auto, voice = catalog voice id.',
  AdapterType.irodori:
      'Irodori launcher. model = voice set (default, meanflow, azurlane, '
      'or local). voice = registered speaker ID. For cloneWithPrompt, '
      'supply reference audio and optionally instruction as a style caption.',
  AdapterType.azureTts:
      'Azure Speech. base_url = https://{region}.tts.speech.microsoft.com; '
      'api_key = subscription key; voice = e.g. zh-CN-XiaoxiaoNeural.',
  AdapterType.systemTts:
      'Windows SAPI voices. No URL / key. voice = installed voice name.',
  AdapterType.geminiTts:
      'Google AI Studio. model = gemini-3.8-flash-tts (default), '
      'gemini-3.8-flash-lite-tts, or legacy 2.5/3.1 preview models; voice '
      '= prebuilt voice (Kore, Puck, Charon…) or library voice; '
      'instruction = delivery style (emotion, pace). No cloning.',
  AdapterType.elevenLabs:
      'ElevenLabs. model = eleven_v4 (default), eleven_v4_turbo, '
      'eleven_v3, eleven_multilingual_v2, eleven_flash_v2_5; voice = '
      '"Name [voice_id]" or raw voice_id; instruction = v3/v4 audio tag '
      'such as "whispers". Reference audio without a voice creates an '
      'instant voice clone on the account.',
  AdapterType.minimaxTts:
      'MiniMax speech. base_url https://api.minimax.io (mainland China '
      'accounts: https://api.minimaxi.com). model = speech-2.8-hd '
      '(default) / speech-2.8-turbo / speech-2.6-*; voice = voice_id; '
      'instruction = one emotion keyword (happy, sad, angry, fearful, '
      'disgusted, surprised, calm, fluent, whisper). Reference audio '
      '(10 s–5 min) without a voice clones it; MiniMax deletes clones '
      'unused for 7 days.',
  AdapterType.indexTts:
      'IndexTTS 2.5 through its Gradio WebUI (community one-click '
      'packages, start-webui.bat, default http://127.0.0.1:7860). '
      'Zero-shot: every character needs reference audio (5–15 s clean '
      'speech). model = synthesis language auto | ZH | EN | JA | AR | ES. '
      'instruction = emotion description (only when the WebUI loads the '
      'experimental emotion model).',
};
