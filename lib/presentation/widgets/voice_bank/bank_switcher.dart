part of '../../screens/voice_bank_screen.dart';

/// The bank switcher heading the cast column, with the bank's own actions.
extension _BankSwitcher on _VoiceBankScreenState {
  static const _newBank = '\u0000new';

  Widget _buildBankSwitcher(db.VoiceBank bank, List<db.VoiceBank> banks) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: PopupMenuButton<String>(
              tooltip: l10n.uiBANKS,
              position: PopupMenuPosition.under,
              onSelected: (id) {
                if (id == _newBank) {
                  _createBank();
                  return;
                }
                if (id == _selectedBankId) return;
                _clearVoiceBankInspectorState();
                _update(() => _selectedBankId = id);
              },
              itemBuilder: (_) => [
                for (final b in banks)
                  PopupMenuItem(
                    value: b.id,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: b.id == bank.id
                              ? const Icon(Icons.check_rounded, size: 16)
                              : null,
                        ),
                        Expanded(
                          child: Text(b.name, overflow: TextOverflow.ellipsis),
                        ),
                        if (b.isActive) _ActiveBadge(label: l10n.uiActive),
                      ],
                    ),
                  ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: _newBank,
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 24,
                        child: Icon(Icons.add_rounded, size: 16),
                      ),
                      Text(l10n.uiNewBank),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBright,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.people_alt_rounded,
                      size: 18,
                      color: bank.isActive
                          ? Colors.green
                          : AppTheme.accentColor,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        bank.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (bank.isActive) ...[
                      const SizedBox(width: 8),
                      _ActiveBadge(label: l10n.uiActive),
                    ],
                    const Spacer(),
                    const Icon(Icons.unfold_more_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 18),
            onSelected: (v) {
              switch (v) {
                case 'activate':
                  _toggleBankActive(bank);
                case 'rename':
                  _renameBank(bank, banks);
                case 'duplicate':
                  _duplicateBank(bank);
                case 'delete':
                  _deleteBank(bank);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'activate',
                child: Text(
                  bank.isActive ? l10n.bankDeactivate : l10n.bankSetActive,
                ),
              ),
              PopupMenuItem(
                value: 'rename',
                child: Text(l10n.bankSettingsMenu),
              ),
              PopupMenuItem(value: 'duplicate', child: Text(l10n.uiDuplicate)),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  l10n.uiDelete,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBankActive(db.VoiceBank bank) async {
    final database = ref.read(databaseProvider);
    if (bank.isActive) {
      await database.deactivateAllBanks();
    } else {
      await database.setActiveBank(bank.id);
    }
  }

  Future<void> _duplicateBank(db.VoiceBank bank) async {
    final copy = await ref
        .read(databaseProvider)
        .duplicateBank(bank.id, '${bank.name} (copy)');
    _clearVoiceBankInspectorState();
    _update(() => _selectedBankId = copy.id);
  }

  Future<void> _deleteBank(db.VoiceBank bank) async {
    try {
      await ref.read(databaseProvider).deleteBank(bank.id);
      // The next bank is chosen by _keepBankSelected.
      if (_selectedBankId == bank.id) _clearVoiceBankInspectorState();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_databaseErrorMessage(e))));
    }
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.green.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: const TextStyle(color: Colors.green, fontSize: 11),
    ),
  );
}
