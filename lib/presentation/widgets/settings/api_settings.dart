import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/server/api_server.dart';

import 'settings_shared.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

part 'api_log_panel.dart';

// ───────────────────────────── API server card ─────────────────────────────

class ApiServerSettingsCard extends ConsumerStatefulWidget {
  const ApiServerSettingsCard({super.key});

  @override
  ConsumerState<ApiServerSettingsCard> createState() =>
      _ApiServerSettingsCardState();
}

class _ApiServerSettingsCardState extends ConsumerState<ApiServerSettingsCard> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _corsCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  bool _hydrated = false;
  bool _showKey = false;
  bool _apiLogEnabled = false;
  bool _mcpEnabled = true;
  bool _autoStart = false;

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _keyCtrl.dispose();
    _corsCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    final cfg = await ApiServerConfig.load(ref.read(databaseProvider));
    if (!mounted) return;
    setState(() {
      _hostCtrl.text = cfg.bindHost;
      _portCtrl.text = '${cfg.port}';
      _keyCtrl.text = cfg.apiKey ?? '';
      _corsCtrl.text = cfg.corsOrigins.join(', ');
      _rateCtrl.text = '${cfg.rateLimitPerMin}';
      _apiLogEnabled = cfg.apiLogEnabled;
      _mcpEnabled = cfg.mcpEnabled;
      _autoStart = cfg.autoStart;
      _hydrated = true;
    });
  }

  ApiServerConfig _readConfig() {
    return ApiServerConfig(
      bindHost: _hostCtrl.text.trim().isEmpty
          ? '127.0.0.1'
          : _hostCtrl.text.trim(),
      port: int.tryParse(_portCtrl.text.trim()) ?? 8976,
      apiKey: _keyCtrl.text.trim().isEmpty ? null : _keyCtrl.text.trim(),
      corsOrigins: _corsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      rateLimitPerMin: int.tryParse(_rateCtrl.text.trim()) ?? 60,
      apiLogEnabled: _apiLogEnabled,
      mcpEnabled: _mcpEnabled,
      autoStart: _autoStart,
    );
  }

  Future<void> _apply() async {
    final cfg = _readConfig();
    final db = ref.read(databaseProvider);
    final server = ref.read(apiServerProvider);
    await ApiServerConfig.save(db, cfg);
    if (server.isRunning) {
      await server.restart(config: cfg);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).uiAPIConfigSaved)),
    );
  }

  String _mcpDisplayHost() {
    final host = _hostCtrl.text.trim();
    return host.isEmpty || host == '0.0.0.0' ? '127.0.0.1' : host;
  }

  Future<void> _setApiLogEnabled(bool enabled) async {
    setState(() => _apiLogEnabled = enabled);
    await ref.read(apiServerProvider).setApiLogEnabled(enabled);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? AppLocalizations.of(context).uiAPILogOutputEnabled
              : AppLocalizations.of(context).uiAPILogOutputDisabled,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final running = ref.watch(serverRunningProvider);
    final server = ref.read(apiServerProvider);
    final apiLogs = ref
        .watch(apiServerLogsProvider)
        .maybeWhen(data: (logs) => logs, orElse: () => server.logs);

    if (!_hydrated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
    }

    final isPublicBind = _hostCtrl.text.trim() == '0.0.0.0';
    final hasNoKey = _keyCtrl.text.trim().isEmpty;
    final exposedWithoutAuth = isPublicBind && hasNoKey;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsRow(
              icon: Icons.power_settings_new_rounded,
              title: AppLocalizations.of(context).settingsApi,
              subtitle: running
                  ? AppLocalizations.of(
                      context,
                    ).uiRunningOn('${server.bindHost}:${server.port}')
                  : AppLocalizations.of(context).uiStopped,
              trailing: Switch(
                value: running,
                onChanged: (value) async {
                  if (value) {
                    await server.start();
                  } else {
                    await server.stop();
                  }
                  ref.read(serverRunningProvider.notifier).state = value;
                },
              ),
            ),
            const Divider(),
            if (exposedWithoutAuth)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(
                          context,
                        ).uiBoundTo0000WithNoAPIKeyAnyoneOn,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final hostField = TextField(
                  controller: _hostCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).uiBindHost,
                    hintText: '127.0.0.1',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                );
                final portField = TextField(
                  controller: _portCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).uiPort,
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                );

                if (compact) {
                  return Column(
                    children: [hostField, SizedBox(height: 12), portField],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: hostField),
                    SizedBox(width: 12),
                    SizedBox(width: 110, child: portField),
                  ],
                );
              },
            ),
            SizedBox(height: 12),
            TextField(
              controller: _keyCtrl,
              obscureText: !_showKey,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).uiAPIKeyOptional,
                hintText: AppLocalizations.of(context).uiBearerTokenXAPIKey,
                isDense: true,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showKey ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _corsCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).uiCORSOriginAllowlistCSVEmptyDenyAll,
                hintText: AppLocalizations.of(
                  context,
                ).uiHttpsExampleComHttpLocalhost3000,
                isDense: true,
              ),
            ),
            SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final rateField = TextField(
                  controller: _rateCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(
                      context,
                    ).uiRateLimitReqMinIP0Off,
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                );
                final saveButton = FilledButton.icon(
                  onPressed: _hydrated ? _apply : null,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: Text(running ? 'Save & restart' : 'Save'),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      rateField,
                      SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: saveButton,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    SizedBox(width: 200, child: rateField),
                    const Spacer(),
                    saveButton,
                  ],
                );
              },
            ),
            const Divider(),
            SettingsRow(
              icon: Icons.play_circle_outline_rounded,
              title: AppLocalizations.of(context).uiApiAutoStart,
              subtitle: AppLocalizations.of(context).uiApiAutoStartDescription,
              trailing: Switch(
                value: _autoStart,
                onChanged: _hydrated
                    ? (v) async {
                        setState(() => _autoStart = v);
                        await ApiServerConfig.saveAutoStart(
                          ref.read(databaseProvider),
                          v,
                        );
                      }
                    : null,
              ),
            ),
            const Divider(),
            SettingsRow(
              icon: Icons.smart_toy_outlined,
              title: AppLocalizations.of(context).uiMcpEndpoint,
              subtitle: AppLocalizations.of(context).uiMcpEndpointDescription(
                'http://${_mcpDisplayHost()}:${_portCtrl.text.trim()}/mcp',
              ),
              trailing: Switch(
                value: _mcpEnabled,
                onChanged: _hydrated
                    ? (v) async {
                        setState(() => _mcpEnabled = v);
                        await _apply();
                      }
                    : null,
              ),
            ),
            const Divider(),
            SettingsRow(
              icon: Icons.receipt_long_rounded,
              title: AppLocalizations.of(context).uiAPILogOutput,
              subtitle: AppLocalizations.of(
                context,
              ).uiRecordExternalAPIRequestMetadataInThisPanelRequestBodiesAndAuth,
              trailing: Switch(
                value: _apiLogEnabled,
                onChanged: _hydrated ? _setApiLogEnabled : null,
              ),
            ),
            if (_apiLogEnabled) ...[
              SizedBox(height: 8),
              _ApiLogPanel(
                logs: apiLogs,
                onClear: () => ref.read(apiServerProvider).clearLogs(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
