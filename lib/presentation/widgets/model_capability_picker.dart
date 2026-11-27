import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/capabilities/model_discovery_service.dart';
import 'package:neiroha/data/services/capabilities/role_ai_connection.dart';
import 'package:neiroha/data/services/capabilities/role_ai_model.dart';
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/model_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/data/services/capabilities/provider_declaration_service.dart';

class ModelCapabilityPicker extends ConsumerStatefulWidget {
  const ModelCapabilityPicker({
    super.key,
    required this.provider,
    required this.route,
    required this.feature,
  });
  final db.TtsProvider provider;
  final ServiceRoute route;
  final String feature;
  @override
  ConsumerState<ModelCapabilityPicker> createState() =>
      _ModelCapabilityPickerState();
}

class _ModelCapabilityPickerState extends ConsumerState<ModelCapabilityPicker> {
  final _model = TextEditingController();
  List<DiscoveredModel> _models = [];
  bool _busy = true;
  String? _error;
  bool get _requiresTools => widget.feature == roleAiToolCapability;
  @override
  void initState() {
    super.initState();
    _load(refresh: false);
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _load({required bool refresh}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(modelDiscoveryServiceProvider);
      final cached = await service.cached(widget.provider, widget.route);
      final suggested = _requiresTools
          ? await service.suggestedRoleModel(widget.provider, widget.route)
          : null;
      if (!mounted) return;
      if (cached.isNotEmpty) {
        setState(() => _models = cached);
      } else if (suggested != null && _models.isEmpty) {
        setState(() => _models = [suggested]);
      }
      if (refresh || (_requiresTools && cached.isEmpty)) {
        final models = await service.discover(widget.provider, widget.route);
        if (mounted) setState(() => _models = models);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _redact(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _redact(Object error) {
    final key = widget.provider.apiKey;
    return key.isEmpty ? '$error' : '$error'.replaceAll(key, '[REDACTED]');
  }

  String _label(AppLocalizations l, CapabilitySupport support) =>
      switch (support) {
        CapabilitySupport.unknown => l.modelUnknown,
        CapabilitySupport.supported => l.modelSupported,
        CapabilitySupport.unsupported => l.modelUnsupported,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final query = _model.text.toLowerCase();
    final models = _models.where((m) {
      if (_requiresTools &&
          (RoleAiModel.documented(widget.provider, m.id, widget.route) ==
                  CapabilitySupport.unsupported ||
              m.capability.support('text') == CapabilitySupport.unsupported ||
              m.capability.support(roleAiToolCapability) ==
                  CapabilitySupport.unsupported)) {
        return false;
      }
      return m.id.toLowerCase().contains(query) ||
          m.name.toLowerCase().contains(query);
    }).toList();
    if (_requiresTools) {
      models.sort((a, b) {
        final verified = b.capability
            .support(roleAiToolCapability)
            .index
            .compareTo(a.capability.support(roleAiToolCapability).index);
        return verified != 0 ? verified : a.id.compareTo(b.id);
      });
    }
    return AlertDialog(
      title: Text(l.modelDiscover),
      content: SizedBox(
        width: 560,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.provider.name} · ${widget.route.name}'),
            TextButton.icon(
              icon: const Icon(Icons.dns_rounded),
              label: Text(l.modelReadDeclaration),
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      try {
                        final declared = await ProviderDeclarationService(
                          ref.read(databaseProvider),
                          ref.read(capabilityRepositoryProvider),
                        ).read(widget.provider, widget.route);
                        if (mounted) {
                          setState(
                            () => _models = [
                              ..._models.where(
                                (m) => !declared.any((d) => d.id == m.id),
                              ),
                              ...declared,
                            ],
                          );
                        }
                      } catch (e) {
                        if (mounted) setState(() => _error = _redact(e));
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
            ),
            Text(
              _requiresTools ? l.roleToolModelHint : l.modelCapabilityHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextField(
              controller: _model,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Model ID'),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: models.isEmpty
                  ? Center(child: Text(l.modelNoModels))
                  : ListView.builder(
                      itemCount: models.length,
                      itemBuilder: (_, i) {
                        final model = models[i];
                        final support = model.capability.support(
                          widget.feature,
                        );
                        return ListTile(
                          title: Text(model.name),
                          subtitle: Text(
                            '${model.id}\n${_label(l, support)} · ${model.capability.facts[widget.feature]?.source.name ?? l.modelUnknown} · ${model.capability.availability.name}',
                          ),
                          isThreeLine: true,
                          onTap: support == CapabilitySupport.unsupported
                              ? null
                              : () => Navigator.pop(context, model.id),
                          trailing: PopupMenuButton<CapabilitySupport>(
                            tooltip: l.modelOverride,
                            itemBuilder: (_) => [
                              for (final value in CapabilitySupport.values)
                                PopupMenuItem(
                                  value: value,
                                  child: Text(_label(l, value)),
                                ),
                            ],
                            onSelected: (value) async {
                              final repository = ref.read(
                                capabilityRepositoryProvider,
                              );
                              await repository.save(
                                widget.provider,
                                ModelCapability(
                                  connectionId: repository.scope(
                                    widget.provider,
                                  ),
                                  modelId: model.id,
                                  route: widget.route,
                                  facts: {
                                    widget.feature: CapabilityEvidence(
                                      value,
                                      CapabilitySource.user,
                                      checkedAt: DateTime.now().toUtc(),
                                    ),
                                  },
                                ),
                              );
                              if (mounted) await _load(refresh: false);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => _load(refresh: true),
          child: Text(l.modelRefresh),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.uiCancel),
        ),
        FilledButton(
          onPressed: _model.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _model.text.trim()),
          child: Text(l.modelManual),
        ),
      ],
    );
  }
}
