import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:q_vox_lab/data/adapters/tts_adapter.dart';
import 'package:q_vox_lab/data/database/app_database.dart' as db;
import 'package:q_vox_lab/presentation/theme/app_theme.dart';
import 'package:q_vox_lab/providers/app_providers.dart';

/// Voice Bank — a named collection of Characters persisted in SQLite.
/// Only one bank can be "active" at a time; active bank is used for TTS.
class VoiceBankScreen extends ConsumerStatefulWidget {
  const VoiceBankScreen({super.key});

  @override
  ConsumerState<VoiceBankScreen> createState() => _VoiceBankScreenState();
}

class _VoiceBankScreenState extends ConsumerState<VoiceBankScreen> {
  String? _selectedBankId;

  @override
  Widget build(BuildContext context) {
    final banksAsync = ref.watch(voiceBanksStreamProvider);

    return Column(
      children: [
        _buildHeader(context),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 280, child: _buildBankList(banksAsync)),
              const VerticalDivider(width: 1),
              Expanded(child: _buildRoster()),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────── Header ─────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Text('Voice Bank',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('Character rosters for projects',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
          const Spacer(),
          FilledButton.icon(
            onPressed: _createBank,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Bank'),
          ),
        ],
      ),
    );
  }

  // ───────────────── Bank List (left) ─────────────────

  Widget _buildBankList(AsyncValue<List<db.VoiceBank>> banksAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('BANKS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.4))),
        ),
        Expanded(
          child: banksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (banks) {
              if (banks.isEmpty) {
                return Center(
                  child: Text('No banks yet',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 13)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: banks.length,
                itemBuilder: (ctx, i) {
                  final bank = banks[i];
                  final selected = _selectedBankId == bank.id;
                  return _BankTile(
                    bank: bank,
                    isSelected: selected,
                    onTap: () => setState(() => _selectedBankId = bank.id),
                    onDelete: () async {
                      await ref.read(databaseProvider).deleteBank(bank.id);
                      if (_selectedBankId == bank.id) {
                        setState(() => _selectedBankId = null);
                      }
                    },
                    onDuplicate: () async {
                      final newBank = await ref
                          .read(databaseProvider)
                          .duplicateBank(bank.id, '${bank.name} (copy)');
                      setState(() => _selectedBankId = newBank.id);
                    },
                    onToggleActive: () async {
                      final database = ref.read(databaseProvider);
                      if (bank.isActive) {
                        await database.deactivateAllBanks();
                      } else {
                        await database.setActiveBank(bank.id);
                      }
                    },
                    onRename: () => _renameBank(bank, banks),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ───────────────── Roster (right) ─────────────────

  Widget _buildRoster() {
    if (_selectedBankId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 64, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text('Select or create a Voice Bank',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 15)),
            const SizedBox(height: 8),
            Text(
              'A Voice Bank groups characters for a project.\n'
              'Only one bank can be active at a time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
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

    final bank = banksAsync.valueOrNull?.where((b) => b.id == bankId).firstOrNull;
    if (bank == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bank info bar
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(
            children: [
              Icon(Icons.people_alt_rounded,
                  color: bank.isActive ? Colors.green : AppTheme.accentColor,
                  size: 20),
              const SizedBox(width: 10),
              Text(bank.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              if (bank.isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 12, color: Colors.green),
                      SizedBox(width: 4),
                      Text('Active',
                          style: TextStyle(color: Colors.green, fontSize: 12)),
                    ],
                  ),
                ),
              const Spacer(),
              // Health check button
              OutlinedButton.icon(
                onPressed: () => _healthCheckBank(bank, membersAsync, assetsAsync, providersAsync),
                icon: const Icon(Icons.favorite_border_rounded, size: 16),
                label: const Text('Health Check'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _showAddCharacterDialog(bank),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Add Character'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Members list
        Expanded(
          child: membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (members) {
              if (members.isEmpty) {
                return Center(
                  child: Text('No characters in this bank yet',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3))),
                );
              }
              return assetsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (allAssets) {
                  final assetMap = {for (final a in allAssets) a.id: a};
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: members.length,
                    itemBuilder: (ctx, i) {
                      final member = members[i];
                      final asset = assetMap[member.voiceAssetId];
                      if (asset == null) return const SizedBox.shrink();
                      return _RosterCard(
                        asset: asset,
                        onRemove: () => ref
                            .read(databaseProvider)
                            .removeMemberByAssetAndBank(
                                bankId, asset.id),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ───────────────── Actions ─────────────────

  void _createBank() async {
    final banks = ref.read(voiceBanksStreamProvider).valueOrNull ?? [];
    final nameCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Voice Bank'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Bank name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, nameCtrl.text),
              child: const Text('Create')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      if (banks.any((b) => b.name == result)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('A bank with this name already exists')));
        }
        return;
      }
      final id = const Uuid().v4();
      await ref.read(databaseProvider).insertBank(db.VoiceBanksCompanion(
            id: Value(id),
            name: Value(result),
            createdAt: Value(DateTime.now()),
          ));
      setState(() => _selectedBankId = id);
    }
  }

  void _renameBank(db.VoiceBank bank, List<db.VoiceBank> allBanks) async {
    final nameCtrl = TextEditingController(text: bank.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Voice Bank'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Bank name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, nameCtrl.text),
              child: const Text('Rename')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != bank.name) {
      if (allBanks.any((b) => b.name == result && b.id != bank.id)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('A bank with this name already exists')));
        }
        return;
      }
      await ref.read(databaseProvider).updateBank(
            bank.copyWith(name: result),
          );
    }
  }

  void _showAddCharacterDialog(db.VoiceBank bank) {
    showDialog(
      context: context,
      builder: (ctx) => _AddCharacterDialog(
        bankId: bank.id,
        database: ref.read(databaseProvider),
        assetsAsync: ref.read(voiceAssetsStreamProvider),
        existingMembers: ref.read(bankMembersStreamProvider(bank.id)),
      ),
    );
  }

  void _healthCheckBank(
    db.VoiceBank bank,
    AsyncValue<List<db.VoiceBankMember>> membersAsync,
    AsyncValue<List<db.VoiceAsset>> assetsAsync,
    AsyncValue<List<db.TtsProvider>> providersAsync,
  ) async {
    final members = membersAsync.valueOrNull ?? [];
    final allAssets = assetsAsync.valueOrNull ?? [];
    final allProviders = providersAsync.valueOrNull ?? [];
    if (members.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bank has no characters')));
      }
      return;
    }

    final assetMap = {for (final a in allAssets) a.id: a};
    final providerMap = {for (final p in allProviders) p.id: p};

    final results = <String, bool>{};
    for (final m in members) {
      final asset = assetMap[m.voiceAssetId];
      if (asset == null) continue;
      final provider = providerMap[asset.providerId];
      if (provider == null) {
        results[asset.name] = false;
        continue;
      }
      try {
        final adapter =
            createAdapter(provider, modelName: asset.modelName);
        results[asset.name] = await adapter.healthCheck();
      } catch (_) {
        results[asset.name] = false;
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Health Check Results'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: results.entries
                .map((e) => ListTile(
                      dense: true,
                      leading: Icon(
                        e.value
                            ? Icons.check_circle_rounded
                            : Icons.error_rounded,
                        color: e.value ? Colors.green : Colors.redAccent,
                        size: 20,
                      ),
                      title: Text(e.key),
                      subtitle:
                          Text(e.value ? 'Reachable' : 'Unreachable'),
                    ))
                .toList(),
          ),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK')),
        ],
      ),
    );
  }
}

// ─────────────────────── Bank Tile ───────────────────────

class _BankTile extends StatelessWidget {
  final db.VoiceBank bank;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onToggleActive;
  final VoidCallback onRename;

  const _BankTile({
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
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                const SizedBox(width: 10),
                Expanded(
                  child: Text(bank.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: Icon(Icons.more_vert_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.3)),
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
                      child: Text(
                          bank.isActive ? 'Deactivate' : 'Set Active'),
                    ),
                    const PopupMenuItem(
                      value: 'rename',
                      child: Text('Rename'),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Text('Duplicate'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete',
                          style: TextStyle(color: Colors.redAccent)),
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

// ─────────────────────── Add Character Dialog ───────────────────────

class _AddCharacterDialog extends StatefulWidget {
  final String bankId;
  final db.AppDatabase database;
  final AsyncValue<List<db.VoiceAsset>> assetsAsync;
  final AsyncValue<List<db.VoiceBankMember>> existingMembers;

  const _AddCharacterDialog({
    required this.bankId,
    required this.database,
    required this.assetsAsync,
    required this.existingMembers,
  });

  @override
  State<_AddCharacterDialog> createState() => _AddCharacterDialogState();
}

class _AddCharacterDialogState extends State<_AddCharacterDialog> {
  final _searchCtrl = TextEditingController();
  String _filter = '';

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
    final allAssets = widget.assetsAsync.valueOrNull ?? [];
    final existingIds = (widget.existingMembers.valueOrNull ?? [])
        .map((m) => m.voiceAssetId)
        .toSet();

    final available =
        allAssets.where((a) => !existingIds.contains(a.id)).toList();
    final filtered = _filter.isEmpty
        ? available
        : available
            .where(
                (a) => a.name.toLowerCase().contains(_filter.toLowerCase()))
            .toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Text('Add Characters',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search by name...',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                ),
              ),
            ),
            Flexible(
              child: available.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          existingIds.length == allAssets.length
                              ? 'All characters already in this bank'
                              : 'No voice characters created yet',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4)),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final a = filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                AppTheme.accentColor.withValues(alpha: 0.2),
                            child: Text(a.name[0].toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                          ),
                          title: Text(a.name, style: const TextStyle(fontSize: 14)),
                          subtitle: Text(a.taskMode,
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Colors.white.withValues(alpha: 0.4))),
                          onTap: () => _addSingle(a),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: filtered.isEmpty ? null : () => _addAll(filtered),
                    child: const Text('Add All'),
                  ),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSingle(db.VoiceAsset asset) async {
    await widget.database
        .addMemberToBank(db.VoiceBankMembersCompanion(
      id: Value(const Uuid().v4()),
      bankId: Value(widget.bankId),
      voiceAssetId: Value(asset.id),
    ));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addAll(List<db.VoiceAsset> assets) async {
    for (final a in assets) {
      await widget.database
          .addMemberToBank(db.VoiceBankMembersCompanion(
        id: Value(const Uuid().v4()),
        bankId: Value(widget.bankId),
        voiceAssetId: Value(a.id),
      ));
    }
    if (mounted) Navigator.pop(context);
  }
}

// ─────────────────────── Roster Card ───────────────────────

class _RosterCard extends StatelessWidget {
  final db.VoiceAsset asset;
  final VoidCallback onRemove;

  const _RosterCard({required this.asset, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.accentColor.withValues(alpha: 0.2),
              child: Text(asset.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asset.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  Text(asset.taskMode,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.4))),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDim,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('voice: "${asset.name}"',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                      fontFamily: 'monospace')),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.remove_circle_outline_rounded,
                  size: 18, color: Colors.white.withValues(alpha: 0.4)),
              onPressed: onRemove,
              tooltip: 'Remove from bank',
            ),
          ],
        ),
      ),
    );
  }
}
