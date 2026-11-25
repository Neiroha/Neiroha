part of 'neiroha_mcp_tools.dart';

/// Handlers for workspace, provider, audio and character tools.
extension _VoiceHandlers on NeirohaMcpTools {
  Future<Object?> _overview(Map<String, dynamic> _) async {
    final providers = await db.getAllProviders();
    final ffmpegOk = await _ffmpeg.isAvailable();
    return {
      'app': 'Neiroha',
      'platform': PlatformCapabilities.current().platformLabel,
      'audio_library_root': PathService.instance.voiceAssetRoot.path,
      'ffmpeg_available': ffmpegOk,
      'counts': {
        'providers': providers.length,
        'enabled_providers': providers.where((p) => p.enabled).length,
        'voice_characters': (await db.getAllVoiceAssets()).length,
        'voice_banks': (await db.getAllBanks()).length,
        'audio_tracks': (await db.getAllAudioTracksRaw()).length,
        'video_dub_projects': (await db.getAllVideoDubProjects()).length,
      },
      'enabled_providers': [
        for (final pr in providers)
          if (pr.enabled)
            {'id': pr.id, 'name': pr.name, 'adapter_type': pr.adapterType},
      ],
    };
  }

  Future<Object?> _createProvider(Map<String, dynamic> args) async {
    final type = _adapterType(_req(args, 'adapter_type'));
    final providers = await db.getAllProviders();
    final id = _uuid.v4();
    final rpm = _int0(args, 'requests_per_minute');
    await db.insertProvider(
      TtsProvidersCompanion(
        id: Value(id),
        name: Value(_req(args, 'name')),
        adapterType: Value(type.name),
        baseUrl: Value(_opt(args, 'base_url') ?? _defaultBaseUrl(type)),
        apiKey: Value(_raw(args, 'api_key') ?? ''),
        defaultModelName: Value(
          _opt(args, 'default_model') ?? type.defaultModel,
        ),
        enabled: Value(_bool0(args, 'enabled') ?? true),
        position: Value(providers.length),
        maxConcurrency: Value(_int0(args, 'max_concurrency') ?? 1),
        requestsPerMinute: Value(rpm == null || rpm <= 0 ? null : rpm),
      ),
    );
    return _providerJson(await _provider(id));
  }

  Future<Object?> _updateProvider(Map<String, dynamic> args) async {
    final pr = await _provider(_req(args, 'provider_id'));
    final rpm = _int0(args, 'requests_per_minute');
    final updated = pr.copyWith(
      name: _opt(args, 'name') ?? pr.name,
      baseUrl: _raw(args, 'base_url')?.trim() ?? pr.baseUrl,
      apiKey: _raw(args, 'api_key') ?? pr.apiKey,
      defaultModelName: _opt(args, 'default_model') ?? pr.defaultModelName,
      enabled: _bool0(args, 'enabled') ?? pr.enabled,
      maxConcurrency: _int0(args, 'max_concurrency') ?? pr.maxConcurrency,
      requestsPerMinute: args.containsKey('requests_per_minute')
          ? Value(rpm == null || rpm <= 0 ? null : rpm)
          : Value(pr.requestsPerMinute),
    );
    await db.updateProvider(updated);
    return _providerJson(updated);
  }

  Future<AudioTrack> _importTrack(Map<String, dynamic> args) async {
    final filePath = _opt(args, 'file_path');
    final url = _opt(args, 'url');
    if (filePath == null && url == null) {
      throw const McpToolError('Pass file_path or url');
    }
    final dir = await PathService.instance.voiceCharacterRefDir();
    String source;
    File? tempDownload;
    if (filePath != null) {
      source = filePath;
      if (!await File(source).exists()) {
        throw McpToolError('File not found: $source');
      }
    } else {
      final uri = Uri.tryParse(url!);
      if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
        throw McpToolError('Unsupported URL: $url');
      }
      final ext = p.extension(uri.path).isEmpty
          ? '.bin'
          : p.extension(uri.path);
      final tmp = p.join(
        Directory.systemTemp.path,
        'neiroha_dl_${_uuid.v4()}$ext',
      );
      await Dio().download(url, tmp);
      tempDownload = File(tmp);
      source = tmp;
    }

    try {
      final baseName =
          _opt(args, 'name') ??
          p.basenameWithoutExtension(filePath ?? Uri.parse(url!).path);
      final stem =
          '${PathService.sanitizeSegment(baseName, fallback: 'ref')}_${PathService.formatTimestamp()}';
      final start = _num0(args, 'start_sec');
      final end = _num0(args, 'end_sec');
      final ext = p.extension(source).toLowerCase();
      final needsConvert =
          start != null || end != null || !_audioExts.contains(ext);

      String dest;
      if (needsConvert) {
        if (!await _ffmpeg.isAvailable()) {
          throw const McpToolError(
            'ffmpeg is required to trim or extract audio from video; '
            'configure it in Neiroha Settings or pass a plain audio file.',
          );
        }
        dest = PathService.dedupeFilename(dir, stem, '.wav');
        await _extractAudio(source, dest, start: start, end: end);
      } else {
        dest = PathService.dedupeFilename(dir, stem, ext);
        await File(source).copy(dest);
      }

      final id = _uuid.v4();
      await db.insertAudioTrack(
        AudioTracksCompanion(
          id: Value(id),
          name: Value(baseName),
          description: Value(_opt(args, 'description')),
          audioPath: Value(dest),
          refText: Value(_opt(args, 'ref_text')),
          refLang: Value(_opt(args, 'ref_lang')),
          durationSec: Value(await _probeDuration(dest)),
          sourceType: const Value('upload'),
          createdAt: Value(DateTime.now()),
        ),
      );
      return (await db.getAllAudioTracksRaw()).firstWhere((t) => t.id == id);
    } finally {
      if (tempDownload != null && await tempDownload.exists()) {
        await tempDownload.delete();
      }
    }
  }

  Future<Object?> _createCharacter(Map<String, dynamic> args) async {
    final provider = await _provider(_req(args, 'provider_id'));
    final type = _adapterType(provider.adapterType);
    final name = _req(args, 'name');
    var voice = _opt(args, 'voice');
    final model = _opt(args, 'model');
    final instruction = _opt(args, 'instruction');
    var promptText = _opt(args, 'prompt_text');
    var promptLang = _opt(args, 'prompt_lang');

    // Resolve reference audio (library track preferred).
    String? refAudio;
    final trackId = _opt(args, 'audio_track_id');
    if (trackId != null) {
      final track = await _track(trackId);
      refAudio = track.audioPath;
      promptText ??= track.refText;
      promptLang ??= track.refLang;
    } else if (_opt(args, 'ref_audio_path') case final rawPath?) {
      final track = await _importTrack({
        'file_path': rawPath,
        'name': name,
        'ref_text': ?promptText,
        'ref_lang': ?promptLang,
      });
      refAudio = track.audioPath;
    }

    // ElevenLabs / MiniMax: clone into a reusable account voice.
    final cloneOnProvider =
        type.supportsCloudVoiceClone &&
        refAudio != null &&
        (_bool0(args, 'clone_on_provider') ?? voice == null);
    if (cloneOnProvider) {
      final adapter = createAdapter(provider, modelName: model);
      if (adapter is! VoiceCloneCapable) {
        throw McpToolError('${type.displayName} cannot clone voices');
      }
      voice = await (adapter as VoiceCloneCapable).cloneVoice(
        name: name,
        audioPath: refAudio,
        promptText: promptText,
        description: _opt(args, 'description'),
      );
      refAudio = null;
    }

    final taskMode = _opt(args, 'task_mode') != null
        ? _taskMode(_opt(args, 'task_mode')!)
        : _inferTaskMode(type, model, voice, refAudio, instruction);

    if (type.requiresReferenceAudio && refAudio == null) {
      throw McpToolError(
        '${type.displayName} clones from reference audio on every request: '
        'pass audio_track_id or ref_audio_path.',
      );
    }
    if (taskMode == TaskMode.cloneWithPrompt &&
        refAudio == null &&
        voice == null) {
      throw const McpToolError(
        'cloneWithPrompt needs reference audio (audio_track_id or '
        'ref_audio_path) or a server-registered voice.',
      );
    }
    if (taskMode == TaskMode.presetVoice &&
        voice == null &&
        type != AdapterType.cosyvoice) {
      throw const McpToolError(
        'presetVoice needs a voice — see list_provider_voices.',
      );
    }

    final id = _uuid.v4();
    await db.insertVoiceAsset(
      VoiceAssetsCompanion(
        id: Value(id),
        name: Value(name),
        description: Value(_opt(args, 'description')),
        providerId: Value(provider.id),
        modelName: Value(model),
        taskMode: Value(taskMode.name),
        refAudioPath: Value(refAudio),
        promptText: Value(promptText),
        promptLang: Value(promptLang),
        voiceInstruction: Value(instruction),
        presetVoiceName: Value(voice),
        speed: Value(_num0(args, 'speed') ?? 1.0),
        loudnessOffsetDb: Value(
          (_num0(args, 'loudness_offset_db') ?? 0).clamp(-12.0, 12.0),
        ),
      ),
    );
    for (final bankRef in _strList(args, 'bank_ids')) {
      final bank = await _bank(bankRef);
      await db.addMemberToBank(
        VoiceBankMembersCompanion(
          id: Value(_uuid.v4()),
          bankId: Value(bank.id),
          voiceAssetId: Value(id),
        ),
      );
    }
    return {
      ..._characterJson((await db.getVoiceAssetById(id))!, provider),
      if (cloneOnProvider) 'cloned_on_provider': true,
    };
  }

  Future<Object?> _updateCharacter(Map<String, dynamic> args) async {
    final a = await _character(_req(args, 'character_id'));
    Value<String?> textField(String key, String? current) =>
        args.containsKey(key) ? Value(_opt(args, key)) : Value(current);

    var refAudio = a.refAudioPath;
    var promptText = a.promptText;
    var promptLang = a.promptLang;
    if (_opt(args, 'audio_track_id') case final trackId?) {
      final track = await _track(trackId);
      refAudio = track.audioPath;
      promptText = track.refText ?? promptText;
      promptLang = track.refLang ?? promptLang;
    }
    final updated = a.copyWith(
      name: _opt(args, 'name') ?? a.name,
      description: textField('description', a.description),
      modelName: textField('model', a.modelName),
      presetVoiceName: textField('voice', a.presetVoiceName),
      voiceInstruction: textField('instruction', a.voiceInstruction),
      refAudioPath: Value(refAudio),
      promptText: args.containsKey('prompt_text')
          ? Value(_opt(args, 'prompt_text'))
          : Value(promptText),
      promptLang: args.containsKey('prompt_lang')
          ? Value(_opt(args, 'prompt_lang'))
          : Value(promptLang),
      speed: _num0(args, 'speed') ?? a.speed,
      loudnessOffsetDb:
          _num0(args, 'loudness_offset_db')?.clamp(-12.0, 12.0) ??
          a.loudnessOffsetDb,
      enabled: _bool0(args, 'enabled') ?? a.enabled,
    );
    await db.updateVoiceAsset(updated);
    final provider = (await db.getAllProviders())
        .where((pr) => pr.id == updated.providerId)
        .firstOrNull;
    return _characterJson(updated, provider);
  }

  Future<Object?> _synthesizeSpeech(Map<String, dynamic> args) async {
    final asset = await _character(_req(args, 'character_id'));
    final text = _req(args, 'text');
    String outPath;
    if (_opt(args, 'output_path') case final custom?) {
      outPath = custom;
      await File(outPath).parent.create(recursive: true);
    } else {
      final slug = await _storage.ensureVoiceAssetSlug(asset.id);
      final dir = await PathService.instance.quickTtsDir(slug);
      outPath = PathService.dedupeFilename(
        dir,
        'mcp_${PathService.formatTimestamp()}',
        '',
      );
    }
    final result = await synthesizeCharacterToFile(
      db,
      asset,
      text,
      outPath,
      source: 'MCP',
      probe: _probeDuration,
      speed: _num0(args, 'speed'),
      instruction: _raw(args, 'instruction'),
      applyChain: _bool0(args, 'apply_chain') ?? true,
    );
    await db.insertQuickTtsHistory(
      QuickTtsHistoriesCompanion(
        id: Value(_uuid.v4()),
        voiceAssetId: Value(asset.id),
        voiceName: Value(asset.name),
        inputText: Value(text),
        audioPath: Value(result.path),
        audioDuration: Value(result.durationSec),
        createdAt: Value(DateTime.now()),
      ),
    );
    return {
      'character_id': asset.id,
      'path': result.path,
      'content_type': result.contentType,
      'duration_sec': result.durationSec,
      if (_bool0(args, 'return_audio') == true)
        'audio_base64': base64Encode(await File(result.path).readAsBytes()),
    };
  }
}
