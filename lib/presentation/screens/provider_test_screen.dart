import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:q_vox_lab/data/adapters/chat_completions_tts_adapter.dart';
import 'package:q_vox_lab/data/adapters/openai_compatible_adapter.dart';
import 'package:q_vox_lab/data/adapters/tts_adapter.dart';
import 'package:q_vox_lab/presentation/theme/app_theme.dart';
import 'package:q_vox_lab/providers/app_providers.dart';

/// API mode determines which HTTP endpoint pattern to use.
enum _ApiMode {
  standardTts('Standard TTS (/v1/audio/speech)', 'OpenAI, Alibaba TTS...'),
  chatCompletions(
      'Chat Completions TTS (/v1/chat/completions)', 'MiMo, and similar');

  final String label;
  final String hint;
  const _ApiMode(this.label, this.hint);
}

enum _TestState { idle, loading, success, error }

class ProviderTestScreen extends ConsumerStatefulWidget {
  const ProviderTestScreen({super.key});

  @override
  ConsumerState<ProviderTestScreen> createState() => _ProviderTestScreenState();
}

class _ProviderTestScreenState extends ConsumerState<ProviderTestScreen> {
  final _baseUrlCtrl =
      TextEditingController(text: 'https://api.xiaomimimo.com/v1');
  final _apiKeyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController(text: 'mimo-v2-tts');
  final _voiceCtrl = TextEditingController(text: 'mimo_default');
  final _textCtrl = TextEditingController(
      text: '<style>开心</style>明天就是周五了，真开心！');
  final _styleCtrl = TextEditingController(); // for user-role context in MiMo

  _ApiMode _mode = _ApiMode.chatCompletions;
  _TestState _state = _TestState.idle;
  String _errorMsg = '';
  String? _savedPath;
  Uint8List? _audioBytes;

  final _player = AudioPlayer();

  @override
  void dispose() {
    _player.dispose();
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    _voiceCtrl.dispose();
    _textCtrl.dispose();
    _styleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: config
        SizedBox(
          width: 400,
          child: _buildConfigPanel(),
        ),
        const VerticalDivider(width: 1),
        // Right: result
        Expanded(child: _buildResultPanel()),
      ],
    );
  }

  Widget _buildConfigPanel() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Provider Test',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Test any TTS endpoint before wiring it to a Voice Asset',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
        const SizedBox(height: 20),

        // Quick-fill from saved providers
        _buildProviderQuickFill(),
        const SizedBox(height: 20),

        // API mode
        _sectionLabel('API MODE'),
        const SizedBox(height: 8),
        for (final mode in _ApiMode.values)
          _ApiModeOption(
            mode: mode,
            selected: _mode == mode,
            onTap: () => setState(() => _mode = mode),
          ),
        const SizedBox(height: 16),

        // Connection fields
        _sectionLabel('ENDPOINT'),
        const SizedBox(height: 8),
        _field('Base URL', _baseUrlCtrl,
            hint: 'https://api.xiaomimimo.com/v1'),
        const SizedBox(height: 8),
        _field('API Key', _apiKeyCtrl, hint: 'sk-...', obscure: true),
        const SizedBox(height: 16),

        // Model / voice
        _sectionLabel('MODEL & VOICE'),
        const SizedBox(height: 8),
        _field('Model Name', _modelCtrl,
            hint: 'mimo-v2-tts  /  tts-1  /  cosyvoice'),
        const SizedBox(height: 8),
        _field('Voice / Speaker', _voiceCtrl,
            hint: 'mimo_default  /  alloy  /  default_zh'),

        if (_mode == _ApiMode.chatCompletions) ...[
          const SizedBox(height: 8),
          _field('User context (optional)', _styleCtrl,
              hint:
                  'Influences tone — e.g. "a cheerful conversation"'),
        ],
        const SizedBox(height: 16),

        // Text to synthesize
        _sectionLabel('TEXT TO SYNTHESIZE'),
        const SizedBox(height: 8),
        TextField(
          controller: _textCtrl,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Enter text...\n\nMiMo tip: prepend <style>开心</style>',
            hintStyle:
                TextStyle(color: Colors.white.withValues(alpha: 0.25)),
            filled: true,
            fillColor: AppTheme.surfaceDim,
          ),
        ),
        const SizedBox(height: 20),

        // Generate button
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: _state == _TestState.loading ? null : _generate,
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accentColor),
            icon: _state == _TestState.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.science_rounded, size: 20),
            label: Text(_state == _TestState.loading
                ? 'Generating...'
                : 'Run Test'),
          ),
        ),
      ],
    );
  }

  Widget _buildProviderQuickFill() {
    final providersAsync = ref.watch(ttsProvidersStreamProvider);
    return providersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (providers) {
        if (providers.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('QUICK FILL FROM SAVED PROVIDER'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                  labelText: 'Fill from provider...'),
              items: providers
                  .map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (id) {
                final p = providers.firstWhere((p) => p.id == id);
                _baseUrlCtrl.text = p.baseUrl;
                _apiKeyCtrl.text = p.apiKey;
                // Detect MiMo by URL
                if (p.baseUrl.contains('xiaomimimo')) {
                  setState(() => _mode = _ApiMode.chatCompletions);
                  _modelCtrl.text = 'mimo-v2-tts';
                  _voiceCtrl.text = 'mimo_default';
                }
              },
              hint: const Text('Select...'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResultPanel() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Result',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(child: _buildResultContent()),
        ],
      ),
    );
  }

  Widget _buildResultContent() {
    return switch (_state) {
      _TestState.idle => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.science_outlined,
                  size: 64, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 16),
              Text('Configure and run a test',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 15)),
            ],
          ),
        ),
      _TestState.loading => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Calling API...'),
            ],
          ),
        ),
      _TestState.error => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 56, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text('Request failed',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_errorMsg,
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
              ),
            ],
          ),
        ),
      _TestState.success => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success badge
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text('Success',
                    style: TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                if (_audioBytes != null)
                  Text(
                    '${(_audioBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Audio player controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AUDIO PLAYBACK',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: Colors.white.withValues(alpha: 0.4))),
                    const SizedBox(height: 12),
                    StreamBuilder<PlayerState>(
                      stream: _player.onPlayerStateChanged,
                      builder: (context, snapshot) {
                        final playing =
                            snapshot.data == PlayerState.playing;
                        return Row(
                          children: [
                            IconButton.filled(
                              onPressed: () => playing ? _player.pause() : _playAudio(),
                              style: IconButton.styleFrom(
                                  backgroundColor: AppTheme.accentColor),
                              icon: Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: () => _player.stop(),
                              icon: const Icon(Icons.stop_rounded),
                              tooltip: 'Stop',
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: StreamBuilder<Duration>(
                                stream: _player.onPositionChanged,
                                builder: (context, posSnap) {
                                  return StreamBuilder<Duration>(
                                    stream: _player.onDurationChanged,
                                    builder: (context, durSnap) {
                                      final pos =
                                          posSnap.data ?? Duration.zero;
                                      final dur = durSnap.data ??
                                          const Duration(seconds: 1);
                                      return Column(
                                        children: [
                                          LinearProgressIndicator(
                                            value: dur.inMilliseconds > 0
                                                ? pos.inMilliseconds /
                                                    dur.inMilliseconds
                                                : 0,
                                            backgroundColor:
                                                Colors.white.withValues(alpha: 0.1),
                                            color: AppTheme.accentColor,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(_formatDur(pos),
                                                  style: const TextStyle(
                                                      fontSize: 11)),
                                              Text(_formatDur(dur),
                                                  style: const TextStyle(
                                                      fontSize: 11)),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Saved path
            if (_savedPath != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.audio_file_rounded,
                          color: Colors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Saved to temp file',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            Text(_savedPath!,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontFamily: 'monospace'),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
    };
  }

  Future<void> _generate() async {
    if (_textCtrl.text.trim().isEmpty) return;
    if (_baseUrlCtrl.text.trim().isEmpty) return;

    setState(() {
      _state = _TestState.loading;
      _errorMsg = '';
      _savedPath = null;
      _audioBytes = null;
    });
    await _player.stop();

    try {
      final TtsAdapter adapter;
      if (_mode == _ApiMode.chatCompletions) {
        adapter = ChatCompletionsTtsAdapter(
          baseUrl: _baseUrlCtrl.text.trim(),
          apiKey: _apiKeyCtrl.text.trim(),
          modelName: _modelCtrl.text.trim().isNotEmpty
              ? _modelCtrl.text.trim()
              : 'mimo-v2-tts',
          apiKeyHeader: 'api-key',
        );
      } else {
        adapter = OpenAiCompatibleAdapter(
          baseUrl: _baseUrlCtrl.text.trim(),
          apiKey: _apiKeyCtrl.text.trim(),
          modelName: _modelCtrl.text.trim().isNotEmpty
              ? _modelCtrl.text.trim()
              : 'tts-1',
        );
      }

      final request = TtsRequest(
        text: _textCtrl.text.trim(),
        voice: _voiceCtrl.text.trim(),
        presetVoiceName: _voiceCtrl.text.trim().isNotEmpty
            ? _voiceCtrl.text.trim()
            : null,
        voiceInstruction: _styleCtrl.text.trim().isNotEmpty
            ? _styleCtrl.text.trim()
            : null,
        responseFormat: 'wav',
      );

      final result = await adapter.synthesize(request);

      // Save to temp file
      final dir = await getTemporaryDirectory();
      final filename =
          'qvox_test_${DateTime.now().millisecondsSinceEpoch}.wav';
      final file = File(p.join(dir.path, filename));
      await file.writeAsBytes(result.audioBytes);

      setState(() {
        _state = _TestState.success;
        _audioBytes = result.audioBytes;
        _savedPath = file.path;
      });

      // Auto-play
      await _playAudio();
    } on DioException catch (e) {
      setState(() {
        _state = _TestState.error;
        _errorMsg =
            '${e.response?.statusCode ?? ''} ${e.message}\n\n${e.response?.data ?? ''}';
      });
    } catch (e) {
      setState(() {
        _state = _TestState.error;
        _errorMsg = e.toString();
      });
    }
  }

  Future<void> _playAudio() async {
    if (_savedPath == null) return;
    await _player.stop();
    await _player.play(DeviceFileSource(_savedPath!));
  }

  String _formatDur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.4)),
      );

  Widget _field(String label, TextEditingController ctrl,
          {String? hint, bool obscure = false}) =>
      TextField(
        controller: ctrl,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle:
              TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12),
        ),
      );
}

/// Replaces the deprecated RadioListTile pattern.
class _ApiModeOption extends StatelessWidget {
  final _ApiMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ApiModeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppTheme.accentColor
                      : Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mode.label, style: const TextStyle(fontSize: 13)),
                  Text(mode.hint,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
