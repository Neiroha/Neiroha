import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:q_vox_lab/domain/enums/adapter_type.dart';
import 'package:q_vox_lab/providers/app_providers.dart';
import 'package:q_vox_lab/data/database/app_database.dart' as db;
import 'package:q_vox_lab/presentation/theme/app_theme.dart';

class ProviderScreen extends ConsumerWidget {
  const ProviderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.watch(ttsProvidersStreamProvider);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Row(
            children: [
              Text(
                'Providers',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                'TTS service endpoints',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showAddDialog(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Provider'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Provider list
        Expanded(
          child: providersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (providers) {
              if (providers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.dns_outlined,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.1)),
                      const SizedBox(height: 16),
                      Text(
                        'No providers configured',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add a TTS provider to start generating speech',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: providers.length,
                itemBuilder: (context, index) {
                  final p = providers[index];
                  return _ProviderCard(provider: p);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final keyCtrl = TextEditingController();
    var selectedType = AdapterType.openaiCompatible;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Provider'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<AdapterType>(
                  initialValue: selectedType,
                  decoration:
                      const InputDecoration(labelText: 'Adapter Type'),
                  items: AdapterType.values
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(t.displayName)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedType = v!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: urlCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Base URL'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: keyCtrl,
                  decoration:
                      const InputDecoration(labelText: 'API Key (optional)'),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.isEmpty || urlCtrl.text.isEmpty) return;
                ref.read(databaseProvider).insertProvider(
                      db.TtsProvidersCompanion(
                        id: Value(const Uuid().v4()),
                        name: Value(nameCtrl.text),
                        adapterType: Value(selectedType.name),
                        baseUrl: Value(urlCtrl.text),
                        apiKey: Value(keyCtrl.text),
                      ),
                    );
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderCard extends ConsumerWidget {
  final db.TtsProvider provider;
  const _ProviderCard({required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: provider.enabled
                    ? AppTheme.accentColor.withValues(alpha: 0.15)
                    : const Color(0xFF2A2A36),
              ),
              child: Icon(
                provider.enabled ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                size: 20,
                color: provider.enabled ? AppTheme.accentColor : Colors.grey,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(provider.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    '${provider.adapterType} — ${provider.baseUrl}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Health check button
            IconButton(
              icon: const Icon(Icons.favorite_border_rounded, size: 20),
              tooltip: 'Test connection',
              onPressed: () {
                // TODO: health check
              },
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.4)),
              tooltip: 'Delete',
              onPressed: () =>
                  ref.read(databaseProvider).deleteProvider(provider.id),
            ),
          ],
        ),
      ),
    );
  }
}
