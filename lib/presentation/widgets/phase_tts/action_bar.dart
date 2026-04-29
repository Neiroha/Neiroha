import 'package:flutter/material.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

/// Bottom strip of the Phase TTS editor: segment count + Generate All.
///
/// The button is disabled when there are no segments, no bank assets, or a
/// batch generation is already running.
class PhaseTtsActionBar extends StatelessWidget {
  final int segmentCount;
  final bool hasBankAssets;
  final bool generatingAll;
  final VoidCallback onGenerateAll;

  const PhaseTtsActionBar({
    super.key,
    required this.segmentCount,
    required this.hasBankAssets,
    required this.generatingAll,
    required this.onGenerateAll,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = segmentCount == 0 || generatingAll || !hasBankAssets;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Text('$segmentCount segments',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
          const Spacer(),
          FilledButton.icon(
            onPressed: disabled ? null : onGenerateAll,
            icon: generatingAll
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Generate All'),
          ),
        ],
      ),
    );
  }
}
