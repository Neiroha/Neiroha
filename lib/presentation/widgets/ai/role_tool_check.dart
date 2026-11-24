import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/capabilities/role_ai_model.dart';
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/model_capability_providers.dart';

/// Tool-calling mark for a model in a picker: role analysis corrects
/// itself through function calls, so models without them are flagged.
Widget? toolCallingBadge(BuildContext context, bool? tools) {
  final l = AppLocalizations.of(context);
  return switch (tools) {
    true => Tooltip(
      message: l.roleToolSupported,
      child: const Icon(
        Icons.build_circle_rounded,
        size: 16,
        color: Colors.greenAccent,
      ),
    ),
    false => Tooltip(
      message: l.roleToolUnsupported,
      child: const Icon(Icons.block_rounded, size: 16, color: Colors.white38),
    ),
    null => null,
  };
}

/// Whether [model] on [provider] calls tools: the saved or documented
/// answer, a one-request test when [verifyNow] is set and the answer is
/// unknown, and a button to test again.
class RoleToolCheck extends ConsumerStatefulWidget {
  const RoleToolCheck({
    super.key,
    required this.provider,
    required this.model,
    this.verifyNow = false,
  });
  final db.TtsProvider? provider;
  final String model;
  final bool verifyNow;

  @override
  ConsumerState<RoleToolCheck> createState() => _RoleToolCheckState();
}

enum _State { loading, checking, supported, unsupported, unknown, failed }

class _RoleToolCheckState extends ConsumerState<RoleToolCheck> {
  var _state = _State.loading;
  String _error = '';

  RoleAiModel get _models =>
      RoleAiModel(ref.read(capabilityRepositoryProvider));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = widget.provider;
    if (provider == null || widget.model.trim().isEmpty) return;
    try {
      final support = await _models.support(
        provider,
        widget.model,
        ServiceRoute.chatCompletions,
      );
      if (!mounted) return;
      setState(() => _state = _from(support));
      if (widget.verifyNow && support == CapabilitySupport.unknown) {
        await _verify();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _state = _State.failed;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _verify() async {
    final provider = widget.provider;
    if (provider == null) return;
    setState(() => _state = _State.checking);
    try {
      final ok = await _models.verify(
        provider,
        widget.model,
        ServiceRoute.chatCompletions,
      );
      if (mounted) {
        setState(() => _state = ok ? _State.supported : _State.unsupported);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _state = _State.failed;
          _error = '$error'.replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  static _State _from(CapabilitySupport s) => switch (s) {
    CapabilitySupport.supported => _State.supported,
    CapabilitySupport.unsupported => _State.unsupported,
    CapabilitySupport.unknown => _State.unknown,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (widget.provider == null || _state == _State.loading) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, text) = switch (_state) {
      _State.checking => (null, null, l.roleToolChecking),
      _State.supported => (
        Icons.check_circle_rounded,
        Colors.greenAccent,
        l.roleToolSupported,
      ),
      _State.unsupported => (
        Icons.error_rounded,
        scheme.error,
        l.roleToolUnsupported,
      ),
      _State.failed => (
        Icons.warning_amber_rounded,
        Colors.orangeAccent,
        l.roleToolFailed(_error),
      ),
      _ => (Icons.help_outline_rounded, Colors.white54, l.roleToolUnknown),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        children: [
          if (icon == null)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color ?? Colors.white70),
            ),
          ),
          if (_state != _State.checking)
            TextButton.icon(
              onPressed: _verify,
              icon: const Icon(Icons.network_check_rounded, size: 16),
              label: Text(l.roleToolTest),
            ),
        ],
      ),
    );
  }
}
