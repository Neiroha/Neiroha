import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

class VoiceBankTile extends StatelessWidget {
  final db.VoiceBank bank;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onToggleActive;
  final VoidCallback onRename;

  const VoiceBankTile({
    super.key,
    required this.bank,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    required this.onDuplicate,
    required this.onToggleActive,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isSelected
            ? AppTheme.accentColor.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  bank.isActive
                      ? Icons.check_circle_rounded
                      : Icons.people_alt_rounded,
                  size: 18,
                  color: bank.isActive
                      ? Colors.green
                      : (isSelected
                            ? AppTheme.accentColor
                            : Colors.white.withValues(alpha: 0.4)),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    bank.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  onSelected: (v) {
                    switch (v) {
                      case 'activate':
                        onToggleActive();
                      case 'rename':
                        onRename();
                      case 'duplicate':
                        onDuplicate();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'activate',
                      child: Text(bank.isActive ? 'Deactivate' : 'Set Active'),
                    ),
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(AppLocalizations.of(context).uiRename),
                    ),
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Text(AppLocalizations.of(context).uiDuplicate),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        AppLocalizations.of(context).uiDelete,
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────── Character Tile ───────────────────────

class VoiceBankCharacterTile extends StatelessWidget {
  final db.VoiceAsset asset;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const VoiceBankCharacterTile({
    super.key,
    required this.asset,
    required this.isSelected,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected
            ? AppTheme.accentColor.withValues(alpha: 0.12)
            : AppTheme.surfaceDim,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _MiniAvatar(
                  name: asset.name,
                  avatarPath: asset.avatarPath,
                  selected: isSelected,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _modeLabel(asset.taskMode),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: asset.enabled ? Colors.green : Colors.grey,
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).uiRemoveFromBank,
                  icon: Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  final String name;
  final String? avatarPath;
  final bool selected;

  const _MiniAvatar({
    required this.name,
    required this.avatarPath,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarPath != null && File(avatarPath!).existsSync()) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: FileImage(File(avatarPath!)),
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: selected
          ? AppTheme.accentColor
          : const Color(0xFF2A2A36),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
    );
  }
}

String _modeLabel(String mode) => switch (mode) {
  'cloneWithPrompt' => 'Voice Clone',
  'presetVoice' => 'Preset Voice',
  'voiceDesign' => 'Voice Design',
  _ => mode,
};

// ─────────────────── Import From Another Bank dialog ────────────────────

class ImportFromBankDialog extends ConsumerStatefulWidget {
  final db.VoiceBank targetBank;
  const ImportFromBankDialog({super.key, required this.targetBank});

  @override
  ConsumerState<ImportFromBankDialog> createState() =>
      _ImportFromBankDialogState();
}

class _ImportFromBankDialogState extends ConsumerState<ImportFromBankDialog> {
  String? _sourceBankId;
  final _searchCtrl = TextEditingController();
  String _filter = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _filter = _searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banks = ref.watch(voiceBanksStreamProvider).valueOrNull ?? const [];
    final otherBanks = banks
        .where((b) => b.id != widget.targetBank.id)
        .toList();
    final allAssets =
        ref.watch(voiceAssetsStreamProvider).valueOrNull ?? const [];
    final targetMembers =
        ref
            .watch(bankMembersStreamProvider(widget.targetBank.id))
            .valueOrNull ??
        const [];
    final targetAssetIds = targetMembers.map((m) => m.voiceAssetId).toSet();

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                'Import into "${widget.targetBank.name}"',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text(
                AppLocalizations.of(
                  context,
                ).uiCharactersAreSharedImportingJustAddsThemAsMembersOfThisBank,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).uiSourceBank,
                  prefixIcon: Icon(Icons.account_tree_rounded, size: 18),
                  isDense: true,
                ),
                initialValue: _sourceBankId,
                isExpanded: true,
                items: otherBanks
                    .map(
                      (b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(b.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _sourceBankId = v),
              ),
            ),
            if (_sourceBankId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).uiSearchCharacters,
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _filter.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () => _searchCtrl.clear(),
                          ),
                    isDense: true,
                  ),
                ),
              ),
            Flexible(
              child: _sourceBankId == null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          otherBanks.isEmpty
                              ? 'No other banks to import from'
                              : 'Select a source bank above',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    )
                  : _buildAvailableList(allAssets, targetAssetIds),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _sourceBankId == null || _busy
                        ? null
                        : () => _addAll(allAssets, targetAssetIds),
                    child: Text(AppLocalizations.of(context).uiImportAll),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context).uiDone),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableList(
    List<db.VoiceAsset> allAssets,
    Set<String> targetAssetIds,
  ) {
    final sourceMembersAsync = ref.watch(
      bankMembersStreamProvider(_sourceBankId!),
    );
    return sourceMembersAsync.when(
      loading: () => Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text(AppLocalizations.of(context).uiError2(e))),
      data: (sourceMembers) {
        final assetMap = {for (final a in allAssets) a.id: a};
        final candidates = sourceMembers
            .map((m) => assetMap[m.voiceAssetId])
            .whereType<db.VoiceAsset>()
            .where((a) => !targetAssetIds.contains(a.id))
            .toList();
        final q = _filter.trim().toLowerCase();
        final filtered = q.isEmpty
            ? candidates
            : candidates
                  .where((a) => a.name.toLowerCase().contains(q))
                  .toList();

        if (candidates.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                AppLocalizations.of(
                  context,
                ).uiAllCharactersFromThisBankAreAlreadyMembers,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              ),
            ),
          );
        }
        if (filtered.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No characters match "$_filter"',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shrinkWrap: true,
          itemCount: filtered.length,
          itemBuilder: (ctx, i) {
            final a = filtered[i];
            return ListTile(
              leading: _MiniAvatar(
                name: a.name,
                avatarPath: a.avatarPath,
                selected: false,
              ),
              title: Text(a.name, style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                _modeLabel(a.taskMode),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                tooltip: AppLocalizations.of(context).uiImportThisCharacter,
                onPressed: _busy ? null : () => _addOne(a),
              ),
              onTap: _busy ? null : () => _addOne(a),
            );
          },
        );
      },
    );
  }

  Future<void> _addOne(db.VoiceAsset asset) async {
    setState(() => _busy = true);
    await ref
        .read(databaseProvider)
        .addMemberToBank(
          db.VoiceBankMembersCompanion(
            id: Value(const Uuid().v4()),
            bankId: Value(widget.targetBank.id),
            voiceAssetId: Value(asset.id),
          ),
        );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _addAll(
    List<db.VoiceAsset> allAssets,
    Set<String> targetAssetIds,
  ) async {
    final sourceMembers =
        ref.read(bankMembersStreamProvider(_sourceBankId!)).valueOrNull ??
        const [];
    final assetMap = {for (final a in allAssets) a.id: a};
    final toAdd = sourceMembers
        .map((m) => assetMap[m.voiceAssetId])
        .whereType<db.VoiceAsset>()
        .where((a) => !targetAssetIds.contains(a.id))
        .toList();
    if (toAdd.isEmpty) return;
    setState(() => _busy = true);
    final database = ref.read(databaseProvider);
    for (final a in toAdd) {
      await database.addMemberToBank(
        db.VoiceBankMembersCompanion(
          id: Value(const Uuid().v4()),
          bankId: Value(widget.targetBank.id),
          voiceAssetId: Value(a.id),
        ),
      );
    }
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).uiImportedCharacterS(toAdd.length),
          ),
        ),
      );
    }
  }
}
