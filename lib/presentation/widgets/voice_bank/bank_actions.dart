part of '../../screens/voice_bank_screen.dart';

/// Bank and character actions, plus the bank health check.
extension _BankActions on _VoiceBankScreenState {
  void _createBank() async {
    final banks = ref.read(voiceBanksStreamProvider).value ?? [];
    final nameCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).uiNewVoiceBank),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).uiBankName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).uiCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text),
            child: Text(AppLocalizations.of(context).uiCreate),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      if (banks.any((b) => b.name == result)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).uiABankWithThisNameAlreadyExists,
              ),
            ),
          );
        }
        return;
      }
      final id = const Uuid().v4();
      await ref
          .read(databaseProvider)
          .insertBank(
            db.VoiceBanksCompanion(
              id: Value(id),
              name: Value(result),
              createdAt: Value(DateTime.now()),
            ),
          );
      _clearVoiceBankInspectorState();
      _update(() => _selectedBankId = id);
    }
  }

  /// Bank settings: name and the base loudness target its cast is
  /// normalized to.
  void _renameBank(db.VoiceBank bank, List<db.VoiceBank> allBanks) async {
    final nameCtrl = TextEditingController(text: bank.name);
    var target = bank.loudnessTargetLufs;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context).bankSettingsTitle),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).uiBankName,
                  ),
                ),
                const SizedBox(height: 20),
                BankLoudnessTargetField(
                  value: target,
                  onChanged: (v) => setDialogState(() => target = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context).uiCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.of(context).uiSave),
            ),
          ],
        ),
      ),
    );
    final result = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (saved != true) return;
    if (target != bank.loudnessTargetLufs) {
      bank = bank.copyWith(loudnessTargetLufs: target);
      await ref.read(databaseProvider).updateBank(bank);
    }
    if (result.isNotEmpty && result != bank.name) {
      if (allBanks.any((b) => b.name == result && b.id != bank.id)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).uiABankWithThisNameAlreadyExists,
              ),
            ),
          );
        }
        return;
      }
      await ref.read(databaseProvider).updateBank(bank.copyWith(name: result));
    }
  }

  // ───────────────── Character actions ─────────────────

  void _createCharacterForBank(db.VoiceBank bank) {
    openCreateCharacterDialog(
      context,
      ref,
      onCreated: (assetId) async {
        // Auto-add the freshly-created character to this bank.
        await ref
            .read(databaseProvider)
            .addMemberToBank(
              db.VoiceBankMembersCompanion(
                id: Value(const Uuid().v4()),
                bankId: Value(bank.id),
                voiceAssetId: Value(assetId),
              ),
            );
        ref.read(selectedCharacterIdProvider.notifier).state = assetId;
        _showCharacterInspectorPane();
      },
    );
  }

  void _showCharacterInspectorPane() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _characterSplitKey.currentState?.showRightPane(onlyWhenCompact: true);
    });
  }

  void _openImportDialog(db.VoiceBank targetBank) {
    showDialog(
      context: context,
      builder: (ctx) => ImportFromBankDialog(targetBank: targetBank),
    );
  }

  Future<void> _healthCheckBank(
    db.VoiceBank bank,
    AsyncValue<List<db.VoiceBankMember>> membersAsync,
    AsyncValue<List<db.VoiceAsset>> assetsAsync,
    AsyncValue<List<db.TtsProvider>> providersAsync,
  ) async {
    final members = membersAsync.value ?? [];
    final allAssets = assetsAsync.value ?? [];
    final allProviders = providersAsync.value ?? [];
    final l10n = AppLocalizations.of(context);
    if (members.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).uiBankHasNoCharacters),
          ),
        );
      }
      return;
    }

    final assetMap = {for (final a in allAssets) a.id: a};
    final providerMap = {for (final p in allProviders) p.id: p};
    final timeout = await readHealthCheckTimeout(ref);
    if (!mounted) return;

    final checks = <Future<_VoiceHealthCheckResult>>[];
    for (final member in members) {
      final asset = assetMap[member.voiceAssetId];
      if (asset == null) continue;
      final provider = providerMap[asset.providerId];
      if (provider == null) {
        checks.add(
          Future.value(
            _VoiceHealthCheckResult(
              assetId: asset.id,
              name: asset.name,
              ok: false,
              message: l10n.uiProviderMissing,
            ),
          ),
        );
        continue;
      }
      checks.add(() async {
        final adapter = createAdapter(provider, modelName: asset.modelName);
        try {
          final ok = await adapter.healthCheck().timeout(
            timeout,
            onTimeout: () => false,
          );
          return _VoiceHealthCheckResult(
            assetId: asset.id,
            name: asset.name,
            ok: ok,
            message: ok ? l10n.uiReachable : l10n.uiUnreachable,
          );
        } catch (e) {
          return _VoiceHealthCheckResult(
            assetId: asset.id,
            name: asset.name,
            ok: false,
            message: e.toString(),
          );
        }
      }());
    }

    final results = await Future.wait(checks);
    if (!mounted) return;
    final dbx = ref.read(databaseProvider);
    for (final result in results) {
      await dbx.setSetting(
        VoiceHealthSettings.keyFor(result.assetId),
        result.ok
            ? VoiceHealthSettings.okValue
            : VoiceHealthSettings.failedValue,
      );
    }
    ref.invalidate(voiceHealthStatusProvider);

    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => _HealthCheckResultsDialog(results: results),
    );
  }
}

class _HealthCheckResultsDialog extends StatelessWidget {
  final List<_VoiceHealthCheckResult> results;

  const _HealthCheckResultsDialog({required this.results});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = (size.width - 64).clamp(280.0, 420.0).toDouble();
    final maxHeight = (size.height - 160).clamp(160.0, 520.0).toDouble();
    final listHeight = results.isEmpty
        ? 96.0
        : (results.length * 70.0).clamp(112.0, maxHeight).toDouble();

    return AlertDialog(
      title: Text(l10n.uiHealthCheckResults),
      content: SizedBox(
        width: width,
        height: listHeight,
        child: results.isEmpty
            ? Center(child: Text(l10n.uiNoHealthCheckResults))
            : ListView.separated(
                primary: false,
                itemCount: results.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (_, index) {
                  final result = results[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      result.ok
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      color: result.ok
                          ? context.colors.success
                          : context.colors.danger,
                      size: 20,
                    ),
                    title: Text(result.name, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      result.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.uiOK),
        ),
      ],
    );
  }
}

class _VoiceHealthCheckResult {
  final String assetId;
  final String name;
  final bool ok;
  final String message;

  const _VoiceHealthCheckResult({
    required this.assetId,
    required this.name,
    required this.ok,
    required this.message,
  });
}
