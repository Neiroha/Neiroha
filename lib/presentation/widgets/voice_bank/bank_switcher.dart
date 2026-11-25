part of '../../screens/voice_bank_screen.dart';

/// Height shared by the three column headers so their lines align.
const double _paneHeaderHeight = 52;

/// The bank switcher heading the cast column, with the bank's own actions.
extension _BankSwitcher on _VoiceBankScreenState {
  static const _newBank = '\u0000new';

  Widget _buildBankSwitcher(
    db.VoiceBank bank,
    List<db.VoiceBank> banks, {
    required int? count,
    required VoidCallback healthCheck,
  }) {
    final l10n = AppLocalizations.of(context);
    final muted = context.fg.withValues(alpha: 0.4);
    return SizedBox(
      height: _paneHeaderHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 4, 0),
        child: Row(
          children: [
            Expanded(
              child: PopupMenuButton<String>(
                tooltip: l10n.bankSwitch,
                position: PopupMenuPosition.under,
                constraints: const BoxConstraints(minWidth: 240),
                borderRadius: BorderRadius.circular(8),
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
                            width: 28,
                            child: b.id == bank.id
                                ? const Icon(Icons.check_rounded, size: 18)
                                : null,
                          ),
                          Expanded(
                            child: Text(
                              b.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (b.isActive) ...[
                            const SizedBox(width: 12),
                            _ActiveDot(tooltip: l10n.uiActive),
                          ],
                        ],
                      ),
                    ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: _newBank,
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 28,
                          child: Icon(Icons.add_rounded, size: 18),
                        ),
                        Text(l10n.uiNewBank),
                      ],
                    ),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      if (bank.isActive) ...[
                        _ActiveDot(tooltip: l10n.uiActive),
                        const SizedBox(width: 8),
                      ],
                      // Name and cast size fill the row; the arrow sits
                      // at its right end, next to the bank menu.
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: bank.name,
                            children: [
                              if (count != null)
                                TextSpan(
                                  text: '  $count',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: muted,
                                  ),
                                ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.expand_more_rounded, size: 20, color: muted),
                    ],
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: l10n.bankActions,
              icon: Icon(Icons.more_horiz_rounded, size: 20, color: muted),
              position: PopupMenuPosition.under,
              onSelected: (v) {
                switch (v) {
                  case 'health':
                    healthCheck();
                  case 'import':
                    _openImportDialog(bank);
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
                _menuItem(
                  'health',
                  Icons.favorite_border_rounded,
                  l10n.uiHealthCheck,
                ),
                _menuItem(
                  'import',
                  Icons.download_rounded,
                  l10n.uiImportFromAnotherBank,
                ),
                const PopupMenuDivider(),
                _menuItem(
                  'activate',
                  bank.isActive
                      ? Icons.radio_button_unchecked_rounded
                      : Icons.check_circle_outline_rounded,
                  bank.isActive ? l10n.bankDeactivate : l10n.bankSetActive,
                ),
                _menuItem('rename', Icons.tune_rounded, l10n.bankSettingsMenu),
                _menuItem('duplicate', Icons.copy_rounded, l10n.uiDuplicate),
                _menuItem(
                  'delete',
                  Icons.delete_outline_rounded,
                  l10n.uiDelete,
                  color: Colors.redAccent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    Color? color,
  }) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    ),
  );

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

/// The green dot of the active bank.
class _ActiveDot extends StatelessWidget {
  const _ActiveDot({required this.tooltip});
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.green,
        shape: BoxShape.circle,
      ),
    ),
  );
}

/// A column header: [_paneHeaderHeight] tall, so the columns line up.
class _PaneHeader extends StatelessWidget {
  const _PaneHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _paneHeaderHeight,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.fg.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
