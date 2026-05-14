import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/server/api_server.dart';

import 'settings_shared.dart';

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('API config saved.')));
  }

  Future<void> _setApiLogEnabled(bool enabled) async {
    setState(() => _apiLogEnabled = enabled);
    await ref.read(apiServerProvider).setApiLogEnabled(enabled);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled ? 'API log output enabled.' : 'API log output disabled.',
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsRow(
              icon: Icons.power_settings_new_rounded,
              title: 'API Server',
              subtitle: running
                  ? 'Running on ${server.bindHost}:${server.port}'
                  : 'Stopped',
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
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bound to 0.0.0.0 with no API key — anyone on the LAN '
                        'can call your providers. Set an API key or rebind to '
                        '127.0.0.1.',
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
                  decoration: const InputDecoration(
                    labelText: 'Bind host',
                    hintText: '127.0.0.1',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                );
                final portField = TextField(
                  controller: _portCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                );

                if (compact) {
                  return Column(
                    children: [
                      hostField,
                      const SizedBox(height: 12),
                      portField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: hostField),
                    const SizedBox(width: 12),
                    SizedBox(width: 110, child: portField),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyCtrl,
              obscureText: !_showKey,
              decoration: InputDecoration(
                labelText: 'API key (optional)',
                hintText: 'Bearer token / X-API-Key',
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
            const SizedBox(height: 12),
            TextField(
              controller: _corsCtrl,
              decoration: const InputDecoration(
                labelText: 'CORS origin allowlist (CSV, empty = deny all)',
                hintText: 'https://example.com, http://localhost:3000',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final rateField = TextField(
                  controller: _rateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Rate limit (req/min/IP, 0 = off)',
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
                      const SizedBox(height: 12),
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
              icon: Icons.receipt_long_rounded,
              title: 'API Log Output',
              subtitle:
                  'Record external API request metadata in this panel. Request bodies and auth headers are not stored.',
              trailing: Switch(
                value: _apiLogEnabled,
                onChanged: _hydrated ? _setApiLogEnabled : null,
              ),
            ),
            if (_apiLogEnabled) ...[
              const SizedBox(height: 8),
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

class _ApiLogPanel extends StatelessWidget {
  const _ApiLogPanel({required this.logs, required this.onClear});

  final List<ApiLogEntry> logs;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Text(
                  '${logs.length} request(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: logs.isEmpty ? null : onClear,
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 220,
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      'No API requests logged yet.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: logs.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    itemBuilder: (context, index) =>
                        _ApiLogRow(entry: logs[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ApiLogRow extends StatelessWidget {
  const _ApiLogRow({required this.entry});

  final ApiLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final ok = entry.statusCode < 400;
    final color = ok ? Colors.greenAccent : Colors.redAccent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '${entry.statusCode}',
              style: TextStyle(
                color: color.withValues(alpha: 0.92),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.method} ${entry.path}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatClock(entry.startedAt)}  ${entry.remoteAddress}  ${entry.durationMs} ms',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.46),
                  ),
                ),
                if (entry.errorMessage != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.errorMessage!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatClock(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  final second = time.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}
