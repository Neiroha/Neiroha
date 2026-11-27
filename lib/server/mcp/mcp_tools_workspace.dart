part of 'neiroha_mcp_tools.dart';

/// Overview, provider and voice-bank tools.
extension _WorkspaceTools on NeirohaMcpTools {
  List<McpTool> _workspaceTools() => [
    // ── Overview ──
    McpTool(
      name: 'get_overview',
      title: 'Workspace overview',
      description:
          'Summary of the Neiroha workspace: counts of providers, characters, '
          'banks, audio tracks and dub projects, which providers are enabled, '
          'the audio library folder and whether ffmpeg is available. Call '
          'this first.',
      inputSchema: _obj({}),
      readOnly: true,
      handler: _overview,
    ),
    McpTool(
      name: 'list_adapter_types',
      title: 'List TTS engine types',
      description:
          'Every supported TTS engine (adapter_type) with its default base '
          'URL, default model, capabilities and a configuration guide that '
          'explains what "model", "voice", "instruction" and reference audio '
          'mean for that engine.',
      inputSchema: _obj({}),
      readOnly: true,
      handler: (_) async => {
        'adapter_types': [for (final t in _availableTypes()) _adapterJson(t)],
      },
    ),

    // ── Providers ──
    McpTool(
      name: 'list_providers',
      title: 'List providers',
      description:
          'Configured TTS providers (engine connections). API keys are never '
          'returned, only has_api_key.',
      inputSchema: _obj({}),
      readOnly: true,
      handler: (_) async {
        final providers = await db.getAllProviders();
        return {
          'providers': [for (final pr in providers) _providerJson(pr)],
        };
      },
    ),
    McpTool(
      name: 'create_provider',
      title: 'Create provider',
      description:
          'Add a TTS provider. base_url and default_model fall back to the '
          'adapter defaults from list_adapter_types. Enabled by default.',
      inputSchema: _obj(
        {
          'name': _str('Display name, e.g. "ElevenLabs".'),
          'adapter_type': _str(
            'Engine type (see list_adapter_types).',
            enumValues: [for (final t in AdapterType.values) t.name],
          ),
          'base_url': _str('Server / API base URL.'),
          'api_key': _str('API key or token (stored locally).'),
          'default_model': _str(
            'Default model used when a character sets none.',
          ),
          'enabled': _bool('Enable immediately (default true).'),
          'max_concurrency': _int('Parallel requests allowed (default 1).'),
          'requests_per_minute': _int('Optional RPM limit.'),
        },
        required: ['name', 'adapter_type'],
      ),
      handler: _createProvider,
    ),
    McpTool(
      name: 'update_provider',
      title: 'Update provider',
      description:
          'Change a provider\'s name, URL, API key, default model, enabled '
          'flag or rate limits. Omitted fields are left unchanged.',
      inputSchema: _obj(
        {
          'provider_id': _str('Provider id or exact name.'),
          'name': _str('New display name.'),
          'base_url': _str('New base URL.'),
          'api_key': _str('New API key ("" clears it).'),
          'default_model': _str('New default model.'),
          'enabled': _bool('Enable / disable the provider.'),
          'max_concurrency': _int('Parallel requests allowed.'),
          'requests_per_minute': _int('RPM limit (0 removes the limit).'),
        },
        required: ['provider_id'],
      ),
      handler: _updateProvider,
    ),
    McpTool(
      name: 'delete_provider',
      title: 'Delete provider',
      description:
          'Permanently delete a provider AND every voice character that uses '
          'it. Prefer update_provider with enabled=false to just disable it.',
      inputSchema: _obj(
        {'provider_id': _str('Provider id or exact name.')},
        required: ['provider_id'],
      ),
      destructive: true,
      handler: (args) async {
        final provider = await _provider(_req(args, 'provider_id'));
        final affected = (await db.getAllVoiceAssets())
            .where((a) => a.providerId == provider.id)
            .map((a) => a.name)
            .toList();
        await db.deleteProvider(provider.id);
        return {'deleted': provider.id, 'deleted_characters': affected};
      },
    ),
    McpTool(
      name: 'check_provider',
      title: 'Health-check provider',
      description:
          'Ping the provider\'s server/API to confirm the URL and key work.',
      inputSchema: _obj(
        {'provider_id': _str('Provider id or exact name.')},
        required: ['provider_id'],
      ),
      readOnly: true,
      openWorld: true,
      handler: (args) async {
        final provider = await _provider(_req(args, 'provider_id'));
        try {
          final ok = await createAdapter(provider).healthCheck();
          return {'provider_id': provider.id, 'healthy': ok};
        } catch (e) {
          return {'provider_id': provider.id, 'healthy': false, 'error': '$e'};
        }
      },
    ),
    McpTool(
      name: 'list_provider_models',
      title: 'List provider models',
      description:
          'Live list of models the provider offers (for IndexTTS this is the '
          'synthesis language list).',
      inputSchema: _obj(
        {'provider_id': _str('Provider id or exact name.')},
        required: ['provider_id'],
      ),
      readOnly: true,
      openWorld: true,
      handler: (args) async {
        final provider = await _provider(_req(args, 'provider_id'));
        final models = await createAdapter(provider).getModels();
        return {
          'provider_id': provider.id,
          'models': [
            for (final m in models) {'id': m.id, 'name': m.name},
          ],
        };
      },
    ),
    McpTool(
      name: 'list_provider_voices',
      title: 'List provider voices',
      description:
          'Live list of preset / account voices on the provider. Cloud voices '
          'look like "Name [voice_id]" — pass the whole string (or just the '
          'id) as the character voice.',
      inputSchema: _obj(
        {
          'provider_id': _str('Provider id or exact name.'),
          'query': _str('Case-insensitive substring filter.'),
          'limit': _int('Max voices to return (default 200).'),
        },
        required: ['provider_id'],
      ),
      readOnly: true,
      openWorld: true,
      handler: (args) async {
        final provider = await _provider(_req(args, 'provider_id'));
        final query = _opt(args, 'query')?.toLowerCase();
        final limit = _int0(args, 'limit') ?? 200;
        final voices = await createAdapter(provider).getSpeakers();
        final filtered = query == null
            ? voices
            : voices.where((v) => v.toLowerCase().contains(query)).toList();
        return {
          'provider_id': provider.id,
          'total': filtered.length,
          'voices': filtered.take(limit).toList(),
        };
      },
    ),

    // ── Voice banks ──
    McpTool(
      name: 'list_voice_banks',
      title: 'List voice banks',
      description:
          'Voice banks (named groups of characters) with their members. '
          'Projects use one bank; active banks are exposed by the local '
          'OpenAI-compatible API as models.',
      inputSchema: _obj({}),
      readOnly: true,
      handler: (_) async {
        final banks = await db.getAllBanks();
        final assets = {for (final a in await db.getAllVoiceAssets()) a.id: a};
        return {
          'banks': [
            for (final b in banks)
              {
                ..._bankJson(b),
                'members': [
                  for (final m in await db.getBankMembers(b.id))
                    if (assets[m.voiceAssetId] case final a?)
                      {'character_id': a.id, 'name': a.name},
                ],
              },
          ],
        };
      },
    ),
    McpTool(
      name: 'create_voice_bank',
      title: 'Create voice bank',
      description: 'Create a voice bank, optionally with initial characters.',
      inputSchema: _obj(
        {
          'name': _str('Bank name, e.g. "Movie X cast".'),
          'description': _str('Optional description.'),
          'active': _bool('Expose via the local API (default true).'),
          'character_ids': _arr(_str('Character id or name.')),
        },
        required: ['name'],
      ),
      handler: (args) async {
        final id = _uuid.v4();
        await db.insertBank(
          VoiceBanksCompanion(
            id: Value(id),
            name: Value(_req(args, 'name')),
            description: Value(_opt(args, 'description')),
            isActive: Value(_bool0(args, 'active') ?? true),
            createdAt: Value(DateTime.now()),
          ),
        );
        for (final ref in _strList(args, 'character_ids')) {
          final a = await _character(ref);
          await db.addMemberToBank(
            VoiceBankMembersCompanion(
              id: Value(_uuid.v4()),
              bankId: Value(id),
              voiceAssetId: Value(a.id),
            ),
          );
        }
        return _bankJson((await _bank(id)));
      },
    ),
    McpTool(
      name: 'update_voice_bank',
      title: 'Update voice bank',
      description: 'Rename a bank, change its description or active flag.',
      inputSchema: _obj(
        {
          'bank_id': _str('Bank id or exact name.'),
          'name': _str('New name.'),
          'description': _str('New description.'),
          'active': _bool('Active flag.'),
          'loudness_target_lufs': _num(
            'Base loudness (LUFS, -30..-10) the cast is normalized to; each '
            'character adds its loudness_offset_db. -16 suits narration, '
            '-20 ASMR.',
          ),
        },
        required: ['bank_id'],
      ),
      handler: (args) async {
        final bank = await _bank(_req(args, 'bank_id'));
        final updated = bank.copyWith(
          name: _opt(args, 'name') ?? bank.name,
          description: args.containsKey('description')
              ? Value(_opt(args, 'description'))
              : Value(bank.description),
          isActive: _bool0(args, 'active') ?? bank.isActive,
          loudnessTargetLufs:
              _num0(args, 'loudness_target_lufs')?.clamp(-30.0, -10.0) ??
              bank.loudnessTargetLufs,
        );
        await db.updateBank(updated);
        return _bankJson(updated);
      },
    ),
    McpTool(
      name: 'delete_voice_bank',
      title: 'Delete voice bank',
      description:
          'Delete a bank. Fails while a project uses it. Characters that '
          'belong to no other bank are deleted too.',
      inputSchema: _obj(
        {'bank_id': _str('Bank id or exact name.')},
        required: ['bank_id'],
      ),
      destructive: true,
      handler: (args) async {
        final bank = await _bank(_req(args, 'bank_id'));
        await db.deleteBank(bank.id);
        return {'deleted': bank.id};
      },
    ),
    McpTool(
      name: 'add_characters_to_bank',
      title: 'Add characters to bank',
      description: 'Add voice characters to a bank (duplicates are ignored).',
      inputSchema: _obj(
        {
          'bank_id': _str('Bank id or exact name.'),
          'character_ids': _arr(_str('Character id or name.')),
        },
        required: ['bank_id', 'character_ids'],
      ),
      handler: (args) async {
        final bank = await _bank(_req(args, 'bank_id'));
        final added = <String>[];
        for (final ref in _strList(args, 'character_ids')) {
          final a = await _character(ref);
          await db.addMemberToBank(
            VoiceBankMembersCompanion(
              id: Value(_uuid.v4()),
              bankId: Value(bank.id),
              voiceAssetId: Value(a.id),
            ),
          );
          added.add(a.id);
        }
        return {'bank_id': bank.id, 'added': added};
      },
    ),
    McpTool(
      name: 'remove_characters_from_bank',
      title: 'Remove characters from bank',
      description:
          'Remove characters from a bank. The characters themselves are kept.',
      inputSchema: _obj(
        {
          'bank_id': _str('Bank id or exact name.'),
          'character_ids': _arr(_str('Character id or name.')),
        },
        required: ['bank_id', 'character_ids'],
      ),
      handler: (args) async {
        final bank = await _bank(_req(args, 'bank_id'));
        var removed = 0;
        for (final ref in _strList(args, 'character_ids')) {
          final a = await _character(ref);
          removed += await db.removeMemberByAssetAndBank(bank.id, a.id);
        }
        return {'bank_id': bank.id, 'removed': removed};
      },
    ),
  ];
}
