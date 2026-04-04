import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:q_vox_lab/presentation/theme/app_theme.dart';

/// Phase TTS — long-form / novel TTS. Split text into paragraphs/chapters,
/// assign a voice, and batch-generate audio for each segment.
class PhaseTtsScreen extends ConsumerStatefulWidget {
  const PhaseTtsScreen({super.key});

  @override
  ConsumerState<PhaseTtsScreen> createState() => _PhaseTtsScreenState();
}

class _PhaseTtsScreenState extends ConsumerState<PhaseTtsScreen> {
  final _scriptController = TextEditingController();

  @override
  void dispose() {
    _scriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Row(
            children: [
              Text(
                'Phase TTS',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                'Novel & long-form narration',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  // TODO: import text file
                },
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Import Text'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Main content: left = script editor, right = segment list
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: text editor
              Expanded(
                flex: 3,
                child: _buildScriptEditor(),
              ),
              const VerticalDivider(width: 1),

              // Right: segment list + voice assignment
              Expanded(
                flex: 2,
                child: _buildSegmentPanel(),
              ),
            ],
          ),
        ),

        // Bottom action bar
        _buildActionBar(context),
      ],
    );
  }

  Widget _buildScriptEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                'SCRIPT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  // TODO: auto-split by paragraph
                },
                icon: const Icon(Icons.splitscreen_rounded, size: 16),
                label: const Text('Auto Split'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _scriptController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText:
                    'Paste your novel text here...\n\nEach paragraph will become a TTS segment.',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                filled: true,
                fillColor: AppTheme.surfaceDim,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'SEGMENTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.segment_rounded,
                    size: 48, color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(height: 12),
                Text(
                  'Paste text and click "Auto Split"\nto create segments',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context) {
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
          Text(
            '0 segments',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: null, // TODO: batch generate
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Generate All'),
          ),
        ],
      ),
    );
  }
}
