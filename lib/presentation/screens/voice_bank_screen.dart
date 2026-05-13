import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/screens/voice_character_screen.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/quick_tts_panel.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';

/// Merged Voice Bank + Voice Characters screen.
///
/// Three columns:
///   • Left   — Bank list (select / create / rename / duplicate / activate)
///   • Middle — Characters in the selected bank (search, new, import-from-other-bank)
///   • Right  — Character inspector (inline editor, from voice_character_screen.dart)
///
/// "Import from other bank" just adds an existing [db.VoiceAsset] as a
/// [db.VoiceBankMember] of the current bank — characters are shared across
/// banks, never deep-copied.
class VoiceBankScreen extends ConsumerStatefulWidget {
  const VoiceBankScreen({super.key});

  @override
  ConsumerState<VoiceBankScreen> createState() => _VoiceBankScreenState();
}

class _VoiceBankScreenState extends ConsumerState<VoiceBankScreen> {
  String? _selectedBankId;
  String _characterFilter = '';
  late final TextEditingController _searchCtrl;

  // Cached notifier references captured while the widget is still mounted.
  // Reading via `ref` inside [dispose] throws — the ConsumerStatefulElement
  // has already been disposed by then. Notifiers themselves live in the
  // enclosing ProviderScope, so calling them after widget dispose is safe.
  late final StateController<String?> _selectedCharacterCtl;
  late final PlaybackNotifier _playbackNotifier;

  @override
  void initState() {
    super.initState();
    _selectedCharacterCtl = ref.read(selectedCharacterIdProvider.notifier);
    _playbackNotifier = ref.read(playbackNotifierProvider.notifier);
    _searchCtrl = TextEditingController();
    _searchCtrl.addListener(() {
      setState(() => _characterFilter = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    // Capture locally — fields become unreadable after super.dispose().
    final selectedCtl = _selectedCharacterCtl;
    final playback = _playbackNotifier;
    // Defer provider mutations: writing to a StateProvider while the widget
    // tree is being torn down raises "Tried to modify a provider while the
    // widget tree was building". Future(...) schedules it on the next event-
    // loop tick, after finalizeTree completes.
    Future(() {
      selectedCtl.state = null;
      unawaited(playback.stopIfSourceTag(voiceBankQuickTestPlaybackSource));
    });
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Call while the widget is still mounted (e.g. from a button handler).
  /// Not safe from [dispose] — that path uses a deferred variant inline.
  void _clearVoiceBankInspectorState() {
    _selectedCharacterCtl.state = null;
    unawaited(
      _playbackNotifier.stopIfSourceTag(voiceBankQuickTestPlaybackSource),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        const Divider(height: 1),
        Expanded(
          child: ResizableSplitPane(
            initialLeftFraction: 0.22,
            left: _buildBankList(),
            rightBuilder: (_) => ResizableSplitPane(
              initialLeftFraction: 0.45,
              left: _buildCharacterColumn(),
              rightBuilder: (_) => _buildInspectorColumn(),
            ),
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
          Text(
            'Voice Bank',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Banks, characters and inspector',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _createBank,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Bank'),
          ),
        ],
      ),
    );
  }

  // ───────────────── Left column: Bank list ─────────────────

  Widget _buildBankList() {
    final banksAsync = ref.watch(voiceBanksStreamProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'BANKS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
        Expanded(
          child: banksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (banks) {
              if (banks.isEmpty) {
                return Center(
                  child: Text(
                    'No banks yet',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 13,
                    ),
                  ),
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
                    onTap: () {
                      _clearVoiceBankInspectorState();
                      setState(() => _selectedBankId = bank.id);
                    },
                    onDelete: () async {
                      try {
                        await ref.read(databaseProvider).deleteBank(bank.id);
                        if (_selectedBankId == bank.id) {
                          _clearVoiceBankInspectorState();
                          setState(() => _selectedBankId = null);
                        }
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_databaseErrorMessage(e))),
                        );
                      }
                    },
                    onDuplicate: () async {
                      final newBank = await ref
                          .read(databaseProvider)
                          .duplicateBank(bank.id, '${bank.name} (copy)');
                      _clearVoiceBankInspectorState();
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

  String _databaseErrorMessage(Object error) {
    if (error is StateError) return error.message;
    return error.toString();
  }

  // ───────────────── Middle column: Characters in bank ─────────────────

  Widget _buildCharacterColumn() {
    if (_selectedBankId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 64,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 16),
            Text(
              'Select or create a Voice Bank',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A Voice Bank groups characters for a project.\n'
              'Only one bank can be active at a time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 13,
              ),
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

    final bank = banksAsync.valueOrNull
        ?.where((b) => b.id == bankId)
        .firstOrNull;
    if (bank == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCharacterColumnHeader(
          bank,
          membersAsync,
          assetsAsync,
          providersAsync,
        ),
        const Divider(height: 1),
        _buildCharacterSearchBar(),
        Expanded(
          child: membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (members) => assetsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (allAssets) => _buildMemberList(bank, members, allAssets),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterColumnHeader(
    db.VoiceBank bank,
    AsyncValue<List<db.VoiceBankMember>> membersAsync,
    AsyncValue<List<db.VoiceAsset>> assetsAsync,
    AsyncValue<List<db.TtsProvider>> providersAsync,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(
            Icons.people_alt_rounded,
            color: bank.isActive ? Colors.green : AppTheme.accentColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(color: Colors.green, fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'CHARACTERS',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Health Check',
            onPressed: () => _healthCheckBank(
              bank,
              membersAsync,
              assetsAsync,
              providersAsync,
            ),
            icon: const Icon(Icons.favorite_border_rounded, size: 18),
          ),
          IconButton(
            tooltip: 'Import from another bank',
            onPressed: () => _openImportDialog(bank),
            icon: const Icon(Icons.download_rounded, size: 18),
          ),
          IconButton(
            tooltip: 'New Character (added to this bank)',
            onPressed: () => _createCharacterForBank(bank),
            icon: const Icon(Icons.person_add_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Search characters...',
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
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 12),
            Text(
              'No characters in this bank yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _createCharacterForBank(bank),
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('New Character'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openImportDialog(bank),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Import from another bank'),
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
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 13,
          ),
        ),
      );
    }

    final selectedId = ref.watch(selectedCharacterIdProvider);
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final asset = filtered[i];
        final isSelected = asset.id == selectedId;
        return _CharacterTile(
          asset: asset,
          isSelected: isSelected,
          onTap: () =>
              ref.read(selectedCharacterIdProvider.notifier).state = asset.id,
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

  // ───────────────── Right column: Inspector ─────────────────

  Widget _buildInspectorColumn() {
    if (_selectedBankId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 12),
            Text(
              'Select a bank and character to edit',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final selectedId = ref.watch(selectedCharacterIdProvider);
    if (selectedId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 12),
            Text(
              'Select a character to edit',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }
    final assetsAsync = ref.watch(voiceAssetsStreamProvider);
    return assetsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (assets) {
        final asset = assets.where((a) => a.id == selectedId).firstOrNull;
        if (asset == null) {
          return Center(
            child: Text(
              'Character not found',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            ),
          );
        }
        // Quick Test sits on top so the user can audition the voice while
        // editing; inspector sits below. `ValueKey(asset.id)` forces fresh
        // state on both panes when switching characters.
        return VerticalResizableSplitPane(
          initialTopFraction: 0.5,
          minPaneHeight: 140,
          top: QuickTtsPanel(key: ValueKey('qtts_${asset.id}'), asset: asset),
          bottom: CharacterInspector(
            key: ValueKey(asset.id),
            asset: asset,
            bankId: _selectedBankId,
          ),
        );
      },
    );
  }

  // ───────────────── Bank actions ─────────────────

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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      if (banks.any((b) => b.name == result)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A bank with this name already exists'),
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != bank.name) {
      if (allBanks.any((b) => b.name == result && b.id != bank.id)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A bank with this name already exists'),
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
      },
    );
  }

  void _openImportDialog(db.VoiceBank targetBank) {
    showDialog(
      context: context,
      builder: (ctx) => _ImportFromBankDialog(targetBank: targetBank),
    );
  }

  Future<void> _healthCheckBank(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bank has no characters')));
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
        final adapter = createAdapter(provider, modelName: asset.modelName);
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
                .map(
                  (e) => ListTile(
                    dense: true,
                    leading: Icon(
                      e.value
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      color: e.value ? Colors.green : Colors.redAccent,
                      size: 20,
                    ),
                    title: Text(e.key),
                    subtitle: Text(e.value ? 'Reachable' : 'Unreachable'),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
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
                const SizedBox(width: 10),
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
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Text('Duplicate'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
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

class _CharacterTile extends StatelessWidget {
  final db.VoiceAsset asset;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _CharacterTile({
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
                const SizedBox(width: 10),
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
                  tooltip: 'Remove from bank',
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

class _ImportFromBankDialog extends ConsumerStatefulWidget {
  final db.VoiceBank targetBank;
  const _ImportFromBankDialog({required this.targetBank});

  @override
  ConsumerState<_ImportFromBankDialog> createState() =>
      _ImportFromBankDialogState();
}

class _ImportFromBankDialogState extends ConsumerState<_ImportFromBankDialog> {
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
                'Characters are shared — importing just adds them as '
                'members of this bank.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Source Bank',
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
                    hintText: 'Search characters...',
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
                    child: const Text('Import All'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Done'),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
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
                'All characters from this bank are already members',
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
                tooltip: 'Import this character',
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
        SnackBar(content: Text('Imported ${toAdd.length} character(s)')),
      );
    }
  }
}
