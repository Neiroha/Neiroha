part of '../../screens/voice_bank_screen.dart';

/// The selected character's quick test and inspector.
extension _BankDetail on _VoiceBankScreenState {
  /// Builds [child] for the selected character, or the reason there is none.
  Widget _forSelected(Widget Function(db.VoiceAsset asset) child) {
    final l10n = AppLocalizations.of(context);
    if (_selectedBankId == null) {
      return _DetailHint(
        icon: Icons.tune_rounded,
        text: l10n.uiSelectABankAndCharacterToEdit,
      );
    }
    final selectedId = ref.watch(selectedCharacterIdProvider);
    if (selectedId == null) {
      return _DetailHint(
        icon: Icons.person_search_rounded,
        text: l10n.uiSelectACharacterToEdit,
      );
    }
    return ref
        .watch(voiceAssetsStreamProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l10n.uiError2(e))),
          data: (assets) {
            final asset = assets.where((a) => a.id == selectedId).firstOrNull;
            if (asset == null) {
              return _DetailHint(
                icon: Icons.person_off_rounded,
                text: l10n.uiCharacterNotFound,
              );
            }
            return child(asset);
          },
        );
  }

  // `ValueKey(asset.id)` gives each character fresh panel state.
  Widget _quickTest(db.VoiceAsset asset, {bool roomy = false}) => QuickTtsPanel(
    key: ValueKey('qtts_${asset.id}'),
    asset: asset,
    roomy: roomy,
  );

  Widget _inspector(db.VoiceAsset asset) => CharacterInspector(
    key: ValueKey(asset.id),
    asset: asset,
    bankId: _selectedBankId,
  );

  Widget _buildQuickTestColumn() =>
      _forSelected((asset) => _quickTest(asset, roomy: true));

  Widget _buildInspectorColumn() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _PaneHeader(
        icon: Icons.tune_rounded,
        label: AppLocalizations.of(context).paneCharacterSettings,
      ),
      const Divider(height: 1),
      Expanded(child: _forSelected(_inspector)),
    ],
  );

  /// Quick test over the inspector, for windows too narrow for both columns.
  Widget _buildStackedDetail() => _forSelected(
    (asset) => VerticalResizableSplitPane(
      initialTopFraction: 0.5,
      minPaneHeight: 140,
      top: _quickTest(asset),
      bottom: _inspector(asset),
    ),
  );
}

class _DetailHint extends StatelessWidget {
  const _DetailHint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: context.fg.withValues(alpha: 0.1)),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.fg.withValues(alpha: 0.4),
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}
