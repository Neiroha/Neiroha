import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:q_vox_lab/data/database/app_database.dart' as db;
import 'package:q_vox_lab/providers/app_providers.dart';
import 'package:q_vox_lab/presentation/theme/app_theme.dart';

final _selectedAssetIdProvider = StateProvider<String?>((ref) => null);

/// Voice Assets — master-detail layout (VoiceBox-style).
/// Left: searchable table of voice assets. Right: inspector panel.
class VoiceAssetsScreen extends ConsumerWidget {
  const VoiceAssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(voiceAssetsStreamProvider);
    final selectedId = ref.watch(_selectedAssetIdProvider);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Row(
            children: [
              Text(
                'Voice Assets',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                'Manage character voices',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  // TODO: create voice asset dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Voice Asset creation coming soon')),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Voice'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Content
        Expanded(
          child: assetsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (assets) {
              if (assets.isEmpty) {
                return _buildEmpty();
              }

              final selected =
                  assets.where((a) => a.id == selectedId).firstOrNull;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left: asset list
                  Expanded(
                    flex: 3,
                    child: _AssetTable(
                      assets: assets,
                      selectedId: selectedId,
                      onSelect: (id) => ref
                          .read(_selectedAssetIdProvider.notifier)
                          .state = id,
                    ),
                  ),

                  if (selected != null) ...[
                    const VerticalDivider(width: 1),
                    // Right: inspector
                    SizedBox(
                      width: 340,
                      child: _AssetInspector(asset: selected),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.record_voice_over_outlined,
              size: 64, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text(
            'No voice assets yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a voice asset to get started.\nVoice assets map to TTS providers and are exposed via the API.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetTable extends StatelessWidget {
  final List<db.VoiceAsset> assets;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _AssetTable({
    required this.assets,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        final a = assets[index];
        final isSelected = a.id == selectedId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Material(
            color: isSelected
                ? AppTheme.accentColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onSelect(a.id),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isSelected
                          ? AppTheme.accentColor
                          : const Color(0xFF2A2A36),
                      child: Text(
                        a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                        style:
                            const TextStyle(fontSize: 14, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                          Text(
                            a.taskMode,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: a.enabled ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AssetInspector extends ConsumerWidget {
  final db.VoiceAsset asset;
  const _AssetInspector({required this.asset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Avatar + name
        Center(
          child: CircleAvatar(
            radius: 32,
            backgroundColor: AppTheme.accentColor.withValues(alpha: 0.2),
            child: Text(
              asset.name.isNotEmpty ? asset.name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 24, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            asset.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            asset.taskMode,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        _InspectorField(label: 'Provider ID', value: asset.providerId),
        _InspectorField(
            label: 'Model Binding', value: asset.modelBindingId),
        _InspectorField(label: 'Speed', value: '${asset.speed}x'),
        if (asset.presetVoiceName != null)
          _InspectorField(
              label: 'Preset Voice', value: asset.presetVoiceName!),
        if (asset.refAudioPath != null)
          _InspectorField(
              label: 'Reference Audio', value: asset.refAudioPath!),
        if (asset.promptText != null)
          _InspectorField(label: 'Prompt Text', value: asset.promptText!),
        if (asset.voiceInstruction != null)
          _InspectorField(
              label: 'Voice Instruction', value: asset.voiceInstruction!),

        const SizedBox(height: 24),
        Row(
          children: [
            const Text('Enabled'),
            const Spacer(),
            Switch(
              value: asset.enabled,
              onChanged: (v) {
                final updated = db.VoiceAsset(
                  id: asset.id,
                  name: asset.name,
                  providerId: asset.providerId,
                  modelBindingId: asset.modelBindingId,
                  taskMode: asset.taskMode,
                  refAudioPath: asset.refAudioPath,
                  promptText: asset.promptText,
                  promptLang: asset.promptLang,
                  voiceInstruction: asset.voiceInstruction,
                  presetVoiceName: asset.presetVoiceName,
                  speed: asset.speed,
                  enabled: v,
                );
                ref.read(databaseProvider).updateVoiceAsset(updated);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(databaseProvider).deleteVoiceAsset(asset.id);
            ref.read(_selectedAssetIdProvider.notifier).state = null;
          },
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Delete Voice Asset'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
          ),
        ),
      ],
    );
  }
}

class _InspectorField extends StatelessWidget {
  final String label;
  final String value;
  const _InspectorField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
