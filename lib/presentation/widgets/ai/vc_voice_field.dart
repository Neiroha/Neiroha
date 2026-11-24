import 'dart:async';

import 'package:flutter/material.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/domain/ai/capability.dart';

/// Target-voice input for a voice-conversion step. Typing an id always works;
/// connections that list voices live (local RVC) add a picker.
class VcVoiceField extends StatefulWidget {
  const VcVoiceField({
    super.key,
    required this.controller,
    required this.connection,
    required this.label,
    this.modelId,
    this.helperText,
  });

  final TextEditingController controller;
  final ProviderConnection? connection;
  final String? modelId;
  final String label;
  final String? helperText;

  @override
  State<VcVoiceField> createState() => _VcVoiceFieldState();
}

class _VcVoiceFieldState extends State<VcVoiceField> {
  List<VoiceOption> _voices = const [];
  bool _loading = false;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(VcVoiceField old) {
    super.didUpdateWidget(old);
    if (old.connection?.id != widget.connection?.id ||
        old.modelId != widget.modelId) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final connection = widget.connection;
    final request = ++_request;
    if (connection is! LiveModelDiscovery) {
      setState(() => _voices = const []);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final voices = await (connection as LiveModelDiscovery).listVoices(
        AiCapability.vc,
        modelId: widget.modelId,
      );
      if (!mounted || request != _request) return;
      setState(() => _voices = voices);
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final picker = _loading
        ? const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : _voices.isEmpty
        ? null
        : PopupMenuButton<String>(
            icon: const Icon(Icons.arrow_drop_down),
            tooltip: widget.label,
            onSelected: (id) => setState(() => widget.controller.text = id),
            itemBuilder: (_) => [
              for (final v in _voices)
                PopupMenuItem(
                  value: v.id,
                  child: Text(
                    v.name == v.id ? v.id : '${v.name}  ·  ${v.id}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          );
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: _error == null
            ? widget.helperText ??
                  (_voices.isEmpty ? null : '${_voices.length} voices')
            : null,
        errorText: _error,
        errorMaxLines: 2,
        suffixIcon: picker,
      ),
    );
  }
}
