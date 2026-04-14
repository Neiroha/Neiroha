import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

/// Voice Design — generate new voice profiles using voice design models
/// like Qwen3-TTS voice_design mode. Describe the voice you want in text,
/// preview it, then save as a VoiceAsset.
class VoiceDesignScreen extends ConsumerStatefulWidget {
  const VoiceDesignScreen({super.key});

  @override
  ConsumerState<VoiceDesignScreen> createState() => _VoiceDesignScreenState();
}

class _VoiceDesignScreenState extends ConsumerState<VoiceDesignScreen> {
  final _instructionController = TextEditingController();
  final _previewTextController = TextEditingController(
    text: 'Hello, this is a preview of the designed voice.',
  );

  @override
  void dispose() {
    _instructionController.dispose();
    _previewTextController.dispose();
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
                'Voice Design',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                'Create voices from text descriptions',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: voice instruction editor
              Expanded(
                flex: 3,
                child: _buildDesignPanel(),
              ),
              const VerticalDivider(width: 1),

              // Right: saved designs gallery
              Expanded(
                flex: 2,
                child: _buildDesignGallery(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesignPanel() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VOICE INSTRUCTION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _instructionController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  'Describe the voice you want...\ne.g. "A warm, gentle female voice with slight breathiness, suitable for audiobook narration"',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
              ),
              filled: true,
              fillColor: AppTheme.surfaceDim,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'PREVIEW TEXT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _previewTextController,
            maxLines: 2,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.surfaceDim,
            ),
          ),
          const SizedBox(height: 20),

          // Provider selector
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Design Provider',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'qwen3',
                      child: Text('Qwen3-TTS Voice Design'),
                    ),
                  ],
                  onChanged: (v) {},
                  hint: const Text('Select provider'),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () {
                  // TODO: call voice design API
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Voice design generation coming soon')),
                  );
                },
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: const Text('Design & Preview'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Audio preview placeholder
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDim,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Audio preview will appear here',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          const Spacer(),

          // Save button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: null, // enabled after preview
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save as Voice Asset'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'DESIGNED VOICES',
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
                Icon(Icons.auto_fix_high_rounded,
                    size: 48, color: Colors.white.withValues(alpha: 0.1)),
                const SizedBox(height: 12),
                Text(
                  'Designed voices will appear here',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
