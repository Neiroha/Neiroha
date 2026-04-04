import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:q_vox_lab/presentation/theme/app_theme.dart';
import 'package:q_vox_lab/providers/app_providers.dart';

/// Quick TTS — simple text-to-speech test with a voice selector and text input.
/// Inspired by VoiceBox's Generate page with floating generate box.
class QuickTtsScreen extends ConsumerStatefulWidget {
  const QuickTtsScreen({super.key});

  @override
  ConsumerState<QuickTtsScreen> createState() => _QuickTtsScreenState();
}

class _QuickTtsScreenState extends ConsumerState<QuickTtsScreen> {
  final _textController = TextEditingController();
  String? _selectedVoiceId;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetsAsync = ref.watch(voiceAssetsStreamProvider);

    return Column(
      children: [
        // Header
        _buildHeader(context),

        // Content area
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: voice selector cards
              SizedBox(
                width: 280,
                child: _buildVoiceSelector(assetsAsync),
              ),
              const VerticalDivider(width: 1),

              // Right: generation history (placeholder)
              Expanded(
                child: _buildHistory(),
              ),
            ],
          ),
        ),

        // Bottom: floating generate bar
        _buildGenerateBar(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Text(
            'Quick TTS',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            'Test voices with short text',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceSelector(AsyncValue<List<dynamic>> assetsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'VOICES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
        Expanded(
          child: assetsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (assets) {
              if (assets.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.record_voice_over_outlined,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(height: 12),
                        Text(
                          'No voices yet',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create a Voice Asset first',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: assets.length,
                itemBuilder: (context, index) {
                  final a = assets[index];
                  final isSelected = _selectedVoiceId == a.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: isSelected
                          ? AppTheme.accentColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () =>
                            setState(() => _selectedVoiceId = a.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: isSelected
                                    ? AppTheme.accentColor
                                    : const Color(0xFF2A2A36),
                                child: Text(
                                  a.name.isNotEmpty
                                      ? a.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(a.name,
                                        style: const TextStyle(
                                            fontSize: 14)),
                                    Text(
                                      a.taskMode,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistory() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded,
              size: 64, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          Text(
            'Generation history will appear here',
            style:
                TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Type something to synthesize...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
              ),
            ),
          ),
          // Generate button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton.filled(
              onPressed: _selectedVoiceId == null ||
                      _textController.text.isEmpty
                  ? null
                  : () {
                      // TODO: trigger TTS synthesis
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('TTS generation queued')),
                      );
                    },
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                disabledBackgroundColor:
                    AppTheme.accentColor.withValues(alpha: 0.3),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
