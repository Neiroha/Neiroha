import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:q_vox_lab/presentation/theme/app_theme.dart';

/// Dialog TTS — multi-character conversation. Each line gets assigned
/// to a character/voice, then batch-generated and concatenated.
class DialogTtsScreen extends ConsumerStatefulWidget {
  const DialogTtsScreen({super.key});

  @override
  ConsumerState<DialogTtsScreen> createState() => _DialogTtsScreenState();
}

class _DialogTtsScreenState extends ConsumerState<DialogTtsScreen> {
  final List<_DialogLine> _lines = [];

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
                'Dialog TTS',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                'Multi-character conversations',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Line'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Dialog lines
        Expanded(
          child: _lines.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _lines.length,
                  itemBuilder: (context, index) =>
                      _buildDialogLine(context, index),
                ),
        ),

        // Bottom action bar
        _buildActionBar(context),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined,
              size: 64, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text(
            'Create a conversation',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add dialog lines and assign voices to each character',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _addLine,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add First Line'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogLine(BuildContext context, int index) {
    final line = _lines[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Character avatar / name
              SizedBox(
                width: 120,
                child: TextField(
                  controller: line.characterController,
                  decoration: InputDecoration(
                    hintText: 'Character',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.surfaceDim,
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Dialog text
              Expanded(
                child: TextField(
                  controller: line.textController,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Dialog text...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.surfaceDim,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Actions
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    onPressed: () {
                      // TODO: generate single line
                    },
                    tooltip: 'Generate this line',
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.4)),
                    onPressed: () => setState(() => _lines.removeAt(index)),
                    tooltip: 'Remove',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
            '${_lines.length} lines',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _lines.isEmpty ? null : () {},
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Export'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _lines.isEmpty ? null : () {},
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Generate All'),
          ),
        ],
      ),
    );
  }

  void _addLine() {
    setState(() {
      _lines.add(_DialogLine());
    });
  }
}

class _DialogLine {
  final TextEditingController characterController = TextEditingController();
  final TextEditingController textController = TextEditingController();
}
