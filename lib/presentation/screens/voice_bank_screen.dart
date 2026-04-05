import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:q_vox_lab/presentation/theme/app_theme.dart';
import 'package:q_vox_lab/providers/app_providers.dart';
import 'package:q_vox_lab/data/database/app_database.dart' as db;

/// Voice Bank — a named collection of Characters for a project/config.
/// Maps to the "Voice Bank → Voice Config → API Service" part of the diagram.
/// UI: left = bank list, right = bank's character roster + API exposure settings.
class VoiceBankScreen extends ConsumerStatefulWidget {
  const VoiceBankScreen({super.key});

  @override
  ConsumerState<VoiceBankScreen> createState() => _VoiceBankScreenState();
}

class _VoiceBankScreenState extends ConsumerState<VoiceBankScreen> {
  // Placeholder: list of banks stored in memory until DB schema is extended.
  final List<_VoiceBank> _banks = [];
  _VoiceBank? _selectedBank;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: bank list
              SizedBox(
                width: 280,
                child: _buildBankList(),
              ),
              const VerticalDivider(width: 1),
              // Right: roster
              Expanded(child: _buildRoster()),
            ],
          ),
        ),
      ],
    );
  }

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

  Widget _buildBankList() {
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
          child: _banks.isEmpty
              ? Center(
                  child: Text('No banks yet',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 13)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _banks.length,
                  itemBuilder: (ctx, i) {
                    final bank = _banks[i];
                    final selected = _selectedBank?.id == bank.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Material(
                        color: selected
                            ? AppTheme.accentColor.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () =>
                              setState(() => _selectedBank = bank),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Icon(Icons.people_alt_rounded,
                                    size: 18,
                                    color: selected
                                        ? AppTheme.accentColor
                                        : Colors.white
                                            .withValues(alpha: 0.4)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(bank.name,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500)),
                                      Text(
                                          '${bank.characterIds.length} characters',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white
                                                  .withValues(alpha: 0.4))),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded,
                                      size: 16,
                                      color: Colors.white
                                          .withValues(alpha: 0.3)),
                                  onPressed: () => setState(() {
                                    _banks.removeAt(i);
                                    if (_selectedBank?.id == bank.id) {
                                      _selectedBank = null;
                                    }
                                  }),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRoster() {
    if (_selectedBank == null) {
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
              'A Voice Bank groups characters for a project.\nThe bank\'s roster is exposed via the API as selectable voices.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
            ),
          ],
        ),
      );
    }

    final bank = _selectedBank!;
    final assetsAsync = ref.watch(voiceAssetsStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bank info bar
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(
            children: [
              Icon(Icons.people_alt_rounded,
                  color: AppTheme.accentColor, size: 20),
              const SizedBox(width: 10),
              Text(bank.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              // API exposure indicator
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Colors.green),
                    ),
                    const SizedBox(width: 6),
                    const Text('Exposed via API',
                        style: TextStyle(
                            color: Colors.green, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _addCharacterToBank(bank, assetsAsync),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Add Character'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Character roster
        Expanded(
          child: assetsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (allAssets) {
              final rosterAssets = allAssets
                  .where((a) => bank.characterIds.contains(a.id))
                  .toList();
              if (rosterAssets.isEmpty) {
                return Center(
                  child: Text('No characters in this bank yet',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3))),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: rosterAssets.length,
                itemBuilder: (ctx, i) {
                  final a = rosterAssets[i];
                  return _RosterCard(
                    asset: a,
                    onRemove: () => setState(() =>
                        bank.characterIds.remove(a.id)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _createBank() async {
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
      setState(() {
        final bank = _VoiceBank(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: result,
        );
        _banks.add(bank);
        _selectedBank = bank;
      });
    }
  }

  void _addCharacterToBank(
      _VoiceBank bank, AsyncValue<List<db.VoiceAsset>> assetsAsync) {
    final allAssets = assetsAsync.valueOrNull ?? [];
    final available =
        allAssets.where((a) => !bank.characterIds.contains(a.id)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All characters already in bank')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Character'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: available.length,
            itemBuilder: (ctx, i) {
              final a = available[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.accentColor.withValues(alpha: 0.2),
                  child: Text(a.name[0].toUpperCase()),
                ),
                title: Text(a.name),
                onTap: () {
                  setState(() => bank.characterIds.add(a.id));
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _VoiceBank {
  final String id;
  final String name;
  final List<String> characterIds;

  _VoiceBank({required this.id, required this.name})
      : characterIds = [];
}

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
              backgroundColor:
                  AppTheme.accentColor.withValues(alpha: 0.2),
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
            // API voice ID tag
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
