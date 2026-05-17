import 'dart:async';

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
import 'package:neiroha/presentation/widgets/voice_bank/voice_bank_widgets.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

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
  final _bankSplitKey = GlobalKey<ResizableSplitPaneState>();
  final _characterSplitKey = GlobalKey<ResizableSplitPaneState>();

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
            key: _bankSplitKey,
            initialLeftFraction: 0.22,
            compactRightIcon: Icons.people_alt_rounded,
            compactRightLabel: AppLocalizations.of(context).uiCharacters,
            left: _buildBankList(),
            rightBuilder: (_) => ResizableSplitPane(
              key: _characterSplitKey,
              initialLeftFraction: 0.45,
              compactRightIcon: Icons.tune_rounded,
              compactRightLabel: AppLocalizations.of(context).uiDetails,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final iconOnlyCreate = constraints.maxWidth < 1100;
        return Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 24,
            compact ? 12 : 20,
            compact ? 16 : 24,
            compact ? 12 : 16,
          ),
          child: Row(
            children: [
              if (!compact) ...[
                Text(
                  AppLocalizations.of(context).navVoiceBank,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  AppLocalizations.of(context).uiBanksCharactersAndInspector,
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: compact ? 13 : 14,
                  ),
                ),
              ),
              SizedBox(width: 8),
              if (iconOnlyCreate)
                IconButton.filledTonal(
                  tooltip: AppLocalizations.of(context).uiNewBank,
                  onPressed: _createBank,
                  icon: const Icon(Icons.add_rounded),
                )
              else
                FilledButton.icon(
                  onPressed: _createBank,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(AppLocalizations.of(context).uiNewBank),
                ),
            ],
          ),
        );
      },
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
            AppLocalizations.of(context).uiBANKS,
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
            loading: () => Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text(AppLocalizations.of(context).uiError2(e))),
            data: (banks) {
              if (banks.isEmpty) {
                return Center(
                  child: Text(
                    AppLocalizations.of(context).uiNoBanksYet,
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
                  return VoiceBankTile(
                    bank: bank,
                    isSelected: selected,
                    onTap: () {
                      _clearVoiceBankInspectorState();
                      setState(() => _selectedBankId = bank.id);
                      _showBankCharactersPane();
                    },
                    onDelete: () async {
                      try {
                        await ref.read(databaseProvider).deleteBank(bank.id);
                        if (_selectedBankId == bank.id) {
                          _clearVoiceBankInspectorState();
                          setState(() => _selectedBankId = null);
                          _bankSplitKey.currentState?.showLeftPane(
                            onlyWhenCompact: true,
                          );
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
                      _showBankCharactersPane();
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
            SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).uiSelectOrCreateAVoiceBank,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
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
      return Center(child: CircularProgressIndicator());
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
          SizedBox(width: 8),
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
                      SizedBox(width: 8),
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
                        child: Text(
                          AppLocalizations.of(context).uiActive,
                          style: TextStyle(color: Colors.green, fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  AppLocalizations.of(context).uiCHARACTERS,
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
            tooltip: AppLocalizations.of(context).uiHealthCheck,
            onPressed: () => _healthCheckBank(
              bank,
              membersAsync,
              assetsAsync,
              providersAsync,
            ),
            icon: const Icon(Icons.favorite_border_rounded, size: 18),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).uiImportFromAnotherBank,
            onPressed: () => _openImportDialog(bank),
            icon: const Icon(Icons.download_rounded, size: 18),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).uiNewCharacterAddedToThisBank,
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
          hintText: AppLocalizations.of(context).uiSearchCharacters,
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
            SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).uiNoCharactersInThisBankYet,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
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
        return VoiceBankCharacterTile(
          asset: asset,
          isSelected: isSelected,
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
            SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).uiSelectABankAndCharacterToEdit,
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
            SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).uiSelectACharacterToEdit,
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
      loading: () => Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text(AppLocalizations.of(context).uiError2(e))),
      data: (assets) {
        final asset = assets.where((a) => a.id == selectedId).firstOrNull;
        if (asset == null) {
          return Center(
            child: Text(
              AppLocalizations.of(context).uiCharacterNotFound,
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
      setState(() => _selectedBankId = id);
      _showBankCharactersPane();
    }
  }

  void _renameBank(db.VoiceBank bank, List<db.VoiceBank> allBanks) async {
    final nameCtrl = TextEditingController(text: bank.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).uiRenameVoiceBank),
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
            child: Text(AppLocalizations.of(context).uiRename),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != bank.name) {
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

  void _showBankCharactersPane() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bankSplitKey.currentState?.showRightPane(onlyWhenCompact: true);
    });
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
    final members = membersAsync.valueOrNull ?? [];
    final allAssets = assetsAsync.valueOrNull ?? [];
    final allProviders = providersAsync.valueOrNull ?? [];
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
        title: Text(AppLocalizations.of(context).uiHealthCheckResults),
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
            child: Text(AppLocalizations.of(context).uiOK),
          ),
        ],
      ),
    );
  }
}
