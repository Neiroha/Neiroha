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
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Row(
            children: [
              Text('Providers',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text('TTS service endpoints',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14)),
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
                      Text('No providers configured',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.4))),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: providers.length,
                itemBuilder: (ctx, i) =>
                    _ProviderCard(provider: providers[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _AddProviderDialog(
        onAdd: (companion) => ref.read(databaseProvider).insertProvider(companion),
      ),
    );
  }
}

class _AddProviderDialog extends StatefulWidget {
  final Future<int> Function(db.TtsProvidersCompanion) onAdd;
  const _AddProviderDialog({required this.onAdd});

  @override
  State<_AddProviderDialog> createState() => _AddProviderDialogState();
}

class _AddProviderDialogState extends State<_AddProviderDialog> {
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController(text: 'tts-1');
  AdapterType _selectedType = AdapterType.openaiCompatible;


  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Text('Add Provider',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AdapterType>(
                      decoration:
                          const InputDecoration(labelText: 'Adapter Type'),
                      items: AdapterType.values
                          .map((t) => DropdownMenuItem(
                              value: t, child: Text(t.displayName)))
                          .toList(),
                      initialValue: _selectedType,
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _selectedType = v;
                          _modelCtrl.text = v.defaultModel;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _urlCtrl,
                      decoration: InputDecoration(
                        labelText: 'Base URL',
                        hintText:
                            _selectedType == AdapterType.chatCompletionsTts
                                ? 'https://api.xiaomimimo.com/v1'
                                : 'https://api.openai.com/v1',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _keyCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'API Key (optional)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _modelCtrl,
                      decoration: InputDecoration(
                        labelText: 'Default Model Name',
                        hintText: _selectedType.defaultModel,
                        helperText: 'Used when generating via this provider',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      if (_nameCtrl.text.isEmpty || _urlCtrl.text.isEmpty) {
                        return;
                      }
                      widget.onAdd(db.TtsProvidersCompanion(
                        id: Value(const Uuid().v4()),
                        name: Value(_nameCtrl.text),
                        adapterType: Value(_selectedType.name),
                        baseUrl: Value(_urlCtrl.text),
                        apiKey: Value(_keyCtrl.text),
                        defaultModelName: Value(_modelCtrl.text.isNotEmpty
                            ? _modelCtrl.text
                            : 'tts-1'),
                      ));
                      Navigator.pop(context);
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
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
                provider.enabled
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_off_rounded,
                size: 20,
                color: provider.enabled ? AppTheme.accentColor : Colors.grey,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(provider.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDim,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(provider.defaultModelName,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.6),
                                fontFamily: 'monospace')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${provider.adapterType}  ·  ${provider.baseUrl}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.4)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.favorite_border_rounded, size: 20),
              tooltip: 'Test connection',
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  size: 20, color: Colors.white.withValues(alpha: 0.4)),
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
