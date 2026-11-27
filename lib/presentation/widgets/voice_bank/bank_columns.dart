part of '../../screens/voice_bank_screen.dart';

/// Middle (characters in the bank) and right (inspector) columns.
extension _BankColumns on _VoiceBankScreenState {
  Widget _buildCharacterColumn() {
    if (_selectedBankId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 64,
              color: context.fg.withValues(alpha: 0.1),
            ),
            SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).uiSelectOrCreateAVoiceBank,
              style: TextStyle(
                color: context.fg.withValues(alpha: 0.4),
                fontSize: 15,
              ),
            ),
            SizedBox(height: 8),
            Text(
              AppLocalizations.of(
                context,
              ).uiAVoiceBankGroupsCharactersForAProjectOnlyOneBankCan,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.fg.withValues(alpha: 0.25),
                fontSize: 13,
              ),
            ),
            SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _createBank,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(AppLocalizations.of(context).uiNewBank),
            ),
          ],
        ),
      );
    }

    final bankId = _selectedBankId!;
    final banksAsync = ref.watch(voiceBanksStreamProvider);
    final membersAsync = ref.watch(bankMembersStreamProvider(bankId));
    final assetsAsync = ref.watch(voiceAssetsStreamProvider);
    final providersAsync = ref.watch(ttsProvidersStreamProvider);

    final banks = banksAsync.value ?? const <db.VoiceBank>[];
    final bank = banks.where((b) => b.id == bankId).firstOrNull;
    if (bank == null) {
      return Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBankSwitcher(
          bank,
          banks,
          count: membersAsync.value?.length,
          healthCheck: () =>
              _healthCheckBank(bank, membersAsync, assetsAsync, providersAsync),
        ),
        const Divider(height: 1),
        _buildCastToolbar(bank),
        Expanded(
          child: membersAsync.when(
            loading: () => Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text(AppLocalizations.of(context).uiError2(e))),
            data: (members) => assetsAsync.when(
              loading: () => Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text(AppLocalizations.of(context).uiError2(e))),
              data: (allAssets) => _buildMemberList(bank, members, allAssets),
            ),
          ),
        ),
      ],
    );
  }

  /// Search the cast, beside the button that adds a character.
  Widget _buildCastToolbar(db.VoiceBank bank) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: l10n.uiSearchCharacters,
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _characterFilter.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () => _searchCtrl.clear(),
                      ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: l10n.uiNewCharacterAddedToThisBank,
            onPressed: () => _createCharacterForBank(bank),
            icon: const Icon(Icons.person_add_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberList(
    db.VoiceBank bank,
    List<db.VoiceBankMember> members,
    List<db.VoiceAsset> allAssets,
  ) {
    if (members.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 48,
              color: context.fg.withValues(alpha: 0.1),
            ),
            SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).uiNoCharactersInThisBankYet,
              style: TextStyle(
                color: context.fg.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
            SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _createCharacterForBank(bank),
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: Text(AppLocalizations.of(context).uiNewCharacter),
            ),
            SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openImportDialog(bank),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text(AppLocalizations.of(context).uiImportFromAnotherBank),
            ),
          ],
        ),
      );
    }

    final assetMap = {for (final a in allAssets) a.id: a};
    final q = _characterFilter.trim().toLowerCase();
    final filtered = members
        .map((m) => assetMap[m.voiceAssetId])
        .whereType<db.VoiceAsset>()
        .where((a) {
          if (q.isEmpty) return true;
          return a.name.toLowerCase().contains(q) ||
              (a.description?.toLowerCase().contains(q) ?? false) ||
              a.taskMode.toLowerCase().contains(q);
        })
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No characters match "$_characterFilter"',
          style: TextStyle(
            color: context.fg.withValues(alpha: 0.4),
            fontSize: 13,
          ),
        ),
      );
    }

    final selectedId = ref.watch(selectedCharacterIdProvider);
    final healthStatus =
        ref.watch(voiceHealthStatusProvider).value ?? const <String, bool>{};
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final asset = filtered[i];
        final isSelected = asset.id == selectedId;
        return VoiceBankCharacterTile(
          asset: asset,
          isSelected: isSelected,
          healthOk: healthStatus[asset.id],
          onTap: () {
            ref.read(selectedCharacterIdProvider.notifier).state = asset.id;
            _showCharacterInspectorPane();
          },
          onRemove: () async {
            await ref
                .read(databaseProvider)
                .removeMemberByAssetAndBank(
                  bank.id,
                  asset.id,
                  deleteOrphanAsset: true,
                );
            if (selectedId == asset.id) {
              _clearVoiceBankInspectorState();
            }
          },
        );
      },
    );
  }
}
